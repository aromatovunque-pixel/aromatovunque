import Foundation

// MARK: - Modello MIDI (sintassi dei comandi di StageTraxx)

/// Un comando MIDI a un tempo preciso del brano, es. "PC0@1" o "CC0.0@1, PC2@1".
struct MidiEvent: Codable, Equatable, Identifiable {
    var id = UUID()
    var t: Double
    var command: String
    var name: String = ""

    init(t: Double, command: String, name: String = "") {
        self.t = t; self.command = command; self.name = name
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, UUID())
        t = c.v(.t, 0)
        command = c.v(.command, "")
        name = c.v(.name, "")
    }

    var label: String { name.isEmpty ? command : name }
}

/// Un comando pronto, richiamabile con i tasti 1…9 durante l'ascolto.
struct MidiPreset: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var command: String

    init(name: String, command: String) { self.name = name; self.command = command }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, UUID())
        name = c.v(.name, "")
        command = c.v(.command, "")
    }
}

struct MidiSettings: Codable, Equatable {
    var channel: Int = 1
    /// comando inviato al caricamento del brano ([midi: …]); vuoto = nessuno
    var onLoad: String = ""
    var presets: [MidiPreset] = MidiSettings.gx100Presets(channel: 1)
    var events: [MidiEvent] = []
    /// altri tag MIDI importati (es. [midi@play: …]) da conservare all'esportazione
    var extraTags: [String] = []

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MidiSettings()
        channel = c.v(.channel, d.channel)
        onLoad = c.v(.onLoad, d.onLoad)
        presets = c.v(.presets, d.presets)
        events = c.v(.events, d.events)
        extraTags = c.v(.extraTags, d.extraTags)
    }

    /// Prime 4 memorie della BOSS GX-100 (U01-1…U01-4 con la Program Map "FIX").
    /// StageTraxx conta i programmi da 0: PC0 = programma 1 del manuale.
    static func gx100Presets(channel: Int) -> [MidiPreset] {
        [
            MidiPreset(name: "Clean", command: "PC0@\(channel)"),
            MidiPreset(name: "Crunch", command: "PC1@\(channel)"),
            MidiPreset(name: "Distorto", command: "PC2@\(channel)"),
            MidiPreset(name: "Solo", command: "PC3@\(channel)")
        ]
    }

    /// Cambia il canale "@n" in tutti i comandi.
    mutating func setChannel(_ ch: Int) {
        let old = channel
        channel = ch
        func fix(_ s: String) -> String { MidiSyntax.replacingChannel(in: s, from: old, to: ch) }
        for i in presets.indices { presets[i].command = fix(presets[i].command) }
        for i in events.indices { events[i].command = fix(events[i].command) }
        onLoad = fix(onLoad)
    }

    var sortedEvents: [MidiEvent] { events.sorted { $0.t < $1.t } }
}

// MARK: - Sintassi StageTraxx

enum MidiSyntax {
    private static let cmdRx = try! NSRegularExpression(pattern:
        #"^(PC\d{1,3}(\.\d{1,3})?@\d{1,2}|CC\d{1,3}\.\d{1,3}@\d{1,2}|N\d{1,3}(\.\d{1,3})?@\d{1,2}|SX\s*([0-9A-F]{2}\s*)+|SS\d{1,3}|START|STOP|CONTINUE|\$\S+)$"#,
        options: [.caseInsensitive])
    private static let tagRx = try! NSRegularExpression(pattern:
        #"^\[\s*midi(?:@(play|stop|\d{2}:\d{2}(?:\.\d{1,3})?))?\s*:\s*(.*?)\s*\]$"#,
        options: [.caseInsensitive])

    /// Controlla ogni comando separato da virgola; ritorna quelli non validi.
    static func invalidParts(_ command: String) -> [String] {
        command.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { part in
            part.isEmpty || cmdRx.firstMatch(in: part, range: NSRange(part.startIndex..., in: part)) == nil
        }
    }

    static func isValid(_ command: String) -> Bool {
        !command.trimmingCharacters(in: .whitespaces).isEmpty && invalidParts(command).isEmpty
    }

    static func replacingChannel(in s: String, from: Int, to: Int) -> String {
        s.replacingOccurrences(of: "@\(from)\\b", with: "@\(to)", options: .regularExpression)
    }

    /// Tempo nel formato di StageTraxx: MM:SS.xx (minuti e secondi sempre a due cifre).
    static func stamp(_ t: Double) -> String {
        let cs = Int((max(0, t) * 100).rounded())
        return String(format: "%02d:%02d.%02d", cs / 6000, (cs / 100) % 60, cs % 100)
    }

    enum Tag {
        case timed(Double, String)
        case load(String)
        case other(String)   // play/stop: conservato com'è
    }

    /// Riconosce una riga "[midi…: …]".
    static func parseTag(_ line: String) -> Tag? {
        let s = line.trimmingCharacters(in: .whitespaces)
        guard let m = tagRx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let cr = Range(m.range(at: 2), in: s) else { return nil }
        let cmd = String(s[cr])
        guard let wr = Range(m.range(at: 1), in: s) else { return .load(cmd) }
        let when = String(s[wr])
        let parts = when.split(separator: ":")
        if parts.count == 2, let mm = Double(parts[0]), let ss = Double(parts[1]) {
            return .timed(mm * 60 + ss, cmd)
        }
        return .other(s)
    }
}

// MARK: - Esportazione per StageTraxx

enum StageTraxxExporter {
    /// Testo della canzone con i comandi MIDI su righe dedicate, nell'ordine dei tempi.
    /// Da incollare nel campo "Lyrics" del brano in StageTraxx.
    static func make(_ p: KaraokeProject, includeLyrics: Bool = true) -> String {
        var out: [String] = []
        let midi = p.midi
        if !midi.onLoad.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append("[midi: \(midi.onLoad)]")
        }
        out.append(contentsOf: midi.extraTags)
        var pending = midi.sortedEvents
        func flush(before t: Double?) {
            while let e = pending.first, t == nil || e.t <= t! {
                out.append("[midi@\(MidiSyntax.stamp(e.t)): \(e.command)]")
                pending.removeFirst()
            }
        }
        if includeLyrics {
            for (i, l) in p.lines.enumerated() {
                if l.brk && i > 0 { out.append("") }
                if let s = l.words.compactMap({ $0.t }).min() { flush(before: s) }
                out.append(l.text)
            }
        }
        flush(before: nil)
        return out.joined(separator: "\n") + "\n"
    }
}
