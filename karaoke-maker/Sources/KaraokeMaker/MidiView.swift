import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Sezione 4: comandi MIDI per la pedaliera (formato StageTraxx).
struct MidiView: View {
    @ObservedObject var document: KaraokeDocument
    @ObservedObject var editor: EditorState
    @ObservedObject var player: PlayerModel
    @Environment(\.undoManager) private var undo
    @State private var copied = false

    private var midi: MidiSettings { document.project.midi }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // sinistra: comandi nel brano
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 22)
                    }
                    .controlSize(.large)
                    .disabled(!player.hasAudio)
                    Button { player.seek(player.currentTime - 5) } label: { Image(systemName: "gobackward.5") }
                        .disabled(!player.hasAudio)
                    Scrubber(clock: player.clock, player: player)
                }
                HStack(spacing: 8) {
                    Text("Aggiungi al tempo attuale:").font(.callout).foregroundStyle(.secondary)
                    ForEach(Array(midi.presets.enumerated()), id: \.element.id) { i, pr in
                        Button("\(i + 1) · \(pr.name)") { add(pr) }
                            .disabled(!MidiSyntax.isValid(pr.command))
                    }
                }
                Text("Suggerimento: nella sezione **2 · Sincronizza** puoi premere i tasti **1–9** mentre ascolti; i comandi compaiono come bandierine arancioni sulla forma d'onda e si possono trascinare.")
                    .font(.caption).foregroundStyle(.secondary)

                Text("Cambi durante il brano").font(.headline).padding(.top, 4)
                if midi.events.isEmpty {
                    Text("Nessun comando. Avvia l'audio e premi un pulsante qui sopra (o i tasti 1–9 nella sezione Sincronizza).")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    List {
                        ForEach(midi.sortedEvents) { ev in
                            EventRow(event: ev, presets: midi.presets,
                                     onChange: { new in replace(new) },
                                     onDelete: { delete(ev.id) },
                                     onPlay: { player.seek(max(0, ev.t - 2)); player.play() },
                                     onSetNow: { var e = ev; e.t = round2(player.currentTime); replace(e) })
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            // destra: impostazioni ed esportazione
            Form {
                Section("Pedaliera") {
                    Stepper(value: Binding(get: { midi.channel },
                                           set: { ch in document.update(undo, "Canale MIDI") { $0.midi.setChannel(ch) } }),
                            in: 1...16) {
                        Text("Canale MIDI: \(midi.channel)")
                    }
                    Text("Deve corrispondere a RX CHANNEL della GX-100 (MENU → MIDI → MIDI SETTINGS).")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("All'avvio del brano", text: document.binding(\.midi.onLoad, undo, "Comando iniziale"))
                        Menu("Patch") {
                            Button("Nessuno") { setOnLoad("") }
                            ForEach(midi.presets) { pr in Button(pr.name) { setOnLoad(pr.command) } }
                        }
                        .fixedSize()
                    }
                    Text("Comando inviato quando StageTraxx carica il brano (es. la patch iniziale).")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Comandi rapidi (tasti 1–9)") {
                    ForEach(Array(midi.presets.enumerated()), id: \.element.id) { i, pr in
                        HStack {
                            Text("\(i + 1)").font(.headline.monospacedDigit()).frame(width: 18)
                            TextField("Nome", text: presetBinding(i, \.name)).frame(width: 90)
                            TextField("Comando", text: presetBinding(i, \.command))
                                .font(.system(.body, design: .monospaced))
                            Image(systemName: MidiSyntax.isValid(pr.command) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(MidiSyntax.isValid(pr.command) ? .green : .orange)
                                .help(MidiSyntax.isValid(pr.command) ? "Comando valido" : "Comando non riconosciuto")
                            Button { removePreset(i) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        Button("Aggiungi") {
                            document.update(undo, "Comando rapido") { p in
                                let n = p.midi.presets.count, ch = p.midi.channel
                                p.midi.presets.append(MidiPreset(name: "Patch \(n + 1)", command: "PC\(n)@\(ch)"))
                            }
                        }
                        .disabled(midi.presets.count >= 9)
                        Spacer()
                        Button("Ripristina GX-100") {
                            document.update(undo, "Comandi GX-100") { $0.midi.presets = MidiSettings.gx100Presets(channel: $0.midi.channel) }
                        }
                    }
                    Text("Sintassi StageTraxx: **PC0@1** = programma 0 sul canale 1 (StageTraxx conta da 0: PC0 è la prima memoria). Altri: **CC80.127@1**, **PC5.1@1** (con banco), più comandi separati da virgola.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("StageTraxx") {
                    Button {
                        exportFile()
                    } label: {
                        Label("Esporta testo per StageTraxx…", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(StageTraxxExporter.make(document.project), forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label(copied ? "Copiato!" : "Copia negli appunti", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        importFile()
                    } label: {
                        Label("Importa comandi da un testo…", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    Text("Il testo contiene le parole della canzone con i comandi su righe dedicate, ad esempio **[midi@01:34.50: PC2@1]**. Incollalo nei Lyrics del brano in StageTraxx: i cambi di patch partono da soli al momento giusto.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 400)
        }
    }

    // MARK: Azioni

    private func round2(_ t: Double) -> Double { (t * 100).rounded() / 100 }

    private func add(_ pr: MidiPreset) {
        let t = round2(player.currentTime)
        document.update(undo, "Comando MIDI") { $0.midi.events.append(MidiEvent(t: t, command: pr.command, name: pr.name)) }
    }

    private func replace(_ e: MidiEvent) {
        document.update(undo, "Modifica comando MIDI") { p in
            if let i = p.midi.events.firstIndex(where: { $0.id == e.id }) { p.midi.events[i] = e }
        }
    }

    private func delete(_ id: UUID) {
        document.update(undo, "Elimina comando MIDI") { $0.midi.events.removeAll { $0.id == id } }
    }

    private func setOnLoad(_ s: String) {
        document.update(undo, "Comando iniziale") { $0.midi.onLoad = s }
    }

    private func removePreset(_ i: Int) {
        document.update(undo, "Elimina comando rapido") { p in
            if i < p.midi.presets.count { p.midi.presets.remove(at: i) }
        }
    }

    private func presetBinding(_ i: Int, _ kp: WritableKeyPath<MidiPreset, String>) -> Binding<String> {
        Binding(
            get: { i < document.project.midi.presets.count ? document.project.midi.presets[i][keyPath: kp] : "" },
            set: { v in
                document.update(undo, "Comando rapido") { p in
                    guard i < p.midi.presets.count else { return }
                    let old = p.midi.presets[i]
                    p.midi.presets[i][keyPath: kp] = v
                    // aggiorna anche i comandi già inseriti con questo nome/comando
                    let new = p.midi.presets[i]
                    for j in p.midi.events.indices where p.midi.events[j].name == old.name && p.midi.events[j].command == old.command {
                        p.midi.events[j].name = new.name
                        p.midi.events[j].command = new.command
                    }
                }
            }
        )
    }

    private func exportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        let base = document.project.title.isEmpty ? "brano" : document.project.title
        panel.nameFieldStringValue = base + " - StageTraxx.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? StageTraxxExporter.make(document.project).write(to: url, atomically: true, encoding: .utf8)
    }

    private func importFile() {
        guard let u = chooseFile(types: [.plainText, .text, .lrc], title: "Importa comandi MIDI"),
              let data = try? Data(contentsOf: u) else { return }
        let imp = KaraokeProject.importText(KaraokeProject.decodeText(data))
        document.update(undo, "Importa comandi MIDI") { p in
            p.midi.events = imp.midi.events.map { e in
                var e = e
                if let pr = p.midi.presets.first(where: { $0.command.replacingOccurrences(of: " ", with: "").lowercased()
                    == e.command.replacingOccurrences(of: " ", with: "").lowercased() }) { e.name = pr.name }
                return e
            }
            if !imp.midi.onLoad.isEmpty { p.midi.onLoad = imp.midi.onLoad }
            p.midi.extraTags = imp.midi.extraTags
            // se il progetto non ha ancora testo, prendo anche le parole
            if p.lines.isEmpty && !imp.lines.isEmpty {
                p.lyrics = imp.lyrics
                p.lines = imp.lines
            }
        }
    }
}

struct EventRow: View {
    let event: MidiEvent
    let presets: [MidiPreset]
    let onChange: (MidiEvent) -> Void
    let onDelete: () -> Void
    let onPlay: () -> Void
    let onSetNow: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPlay) { Image(systemName: "play.circle") }
                .buttonStyle(.borderless)
                .help("Ascolta da 2 secondi prima")
            Text(MidiSyntax.stamp(event.t))
                .font(.system(.body, design: .monospaced))
                .frame(width: 76, alignment: .leading)
            Stepper("", onIncrement: { var e = event; e.t = ((e.t + 0.05) * 100).rounded() / 100; onChange(e) },
                    onDecrement: { var e = event; e.t = max(0, ((e.t - 0.05) * 100).rounded() / 100); onChange(e) })
                .labelsHidden()
                .help("Sposta di 0,05 s")
            Menu(event.label) {
                ForEach(presets) { pr in
                    Button(pr.name) { var e = event; e.name = pr.name; e.command = pr.command; onChange(e) }
                }
            }
            .frame(width: 130)
            Text(event.command)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(MidiSyntax.isValid(event.command) ? Color.secondary : Color.orange)
            Spacer()
            Button("Qui", action: onSetNow)
                .help("Sposta al tempo attuale di riproduzione")
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
    }
}
