import SwiftUI
import AppKit

struct SyncView: View {
    @ObservedObject var document: KaraokeDocument
    @ObservedObject var editor: EditorState
    @ObservedObject var player: PlayerModel
    let audioURL: URL?
    @Environment(\.undoManager) private var envUndo
    private var undo: UndoManager? { editor.undo }

    @State private var monitor: Any?
    @State private var wave: WaveformData?
    @State private var dragSnapshot: KaraokeProject?
    @State private var confirmReset = false

    private var lines: [KLine] { document.project.lines }

    var body: some View {
        VStack(spacing: 0) {
            transport
                .padding(.horizontal, 16).padding(.top, 10)
            banner
                .padding(.horizontal, 16).padding(.top, 8)
            VStack(spacing: 6) {
                WaveformView(data: wave, clock: player.clock, duration: player.duration,
                             markers: markers, selected: editor.sel,
                             onSeek: { player.seek($0) },
                             onSelect: { editor.sel = $0 },
                             onDragBegan: { dragSnapshot = document.project },
                             onDragMarker: { ref, t in
                                 document.updateLive { $0.lines[ref.l].words[ref.w].t = (t * 100).rounded() / 100 }
                             },
                             onDragEnded: {
                                 if let s = dragSnapshot { document.commit(from: s, undo, "Sposta") }
                                 dragSnapshot = nil
                             },
                             midiMarkers: midiMarkers,
                             onDragMidi: { id, t in
                                 document.updateLive { p in
                                     if let i = p.midi.events.firstIndex(where: { $0.id == id }) {
                                         p.midi.events[i].t = (t * 100).rounded() / 100
                                     }
                                 }
                             })
                .frame(height: 120)
                OverviewView(data: wave, clock: player.clock, duration: player.duration, markers: markers,
                             onSeek: { player.seek($0) })
                .frame(height: 26)
                helpLine
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            Divider()
            wordList
        }
        .task(id: audioURL) {
            wave = nil
            if let u = audioURL { wave = await WaveformLoader.load(u) }
        }
        .onAppear {
            editor.undo = envUndo
            // nessun campo di testo deve trattenere la barra spaziatrice
            DispatchQueue.main.async { editor.window?.makeFirstResponder(nil) }
            installMonitor()
        }
        .onDisappear(perform: removeMonitor)
        .onReceive(player.clock.$time) { t in updateLive(t) }
        .confirmationDialog("Cancellare tutti i tempi?", isPresented: $confirmReset) {
            Button("Cancella tutti i tempi", role: .destructive) {
                document.update(undo, "Cancella tempi") { p in
                    for i in p.lines.indices {
                        p.lines[i].end = nil
                        for j in p.lines[i].words.indices { p.lines[i].words[j].t = nil }
                    }
                }
                editor.sel = WordRef(l: 0, w: 0)
            }
        } message: { Text("Si può sempre annullare con ⌘Z.") }
    }

    // MARK: Banner con la prossima parola

    private var nextWordText: String? {
        guard valid(editor.sel) else { return nil }
        return lines[editor.sel.l].words[editor.sel.w].w
    }

    private var banner: some View {
        let allDone = document.project.wordCount > 0 && document.project.timedCount == document.project.wordCount
        return HStack(spacing: 14) {
            if !player.hasAudio {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Nessun audio caricato: aggiungilo nella sezione 1 · Testo e audio.")
                Spacer()
                Button("Vai alla sezione 1") { editor.tab = .lyrics }
            } else if lines.isEmpty {
                Image(systemName: "text.badge.plus").foregroundStyle(.orange)
                Text("Nessun testo: incollalo nella sezione 1.")
                Spacer()
            } else if editor.mode == .check {
                Image(systemName: "eye.fill").foregroundStyle(.secondary)
                Text("CONTROLLA · **Spazio** = play/pausa · la parola cantata si illumina")
                Spacer()
            } else if editor.mode == .line {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").font(.title2).foregroundStyle(.yellow)
                if !player.isPlaying {
                    Text("FRASI (StageTraxx) · premi **SPAZIO** per avviare, poi SPAZIO **o clic sulla frase** quando inizia")
                } else if valid(editor.sel) {
                    Text("Premi **SPAZIO** o clicca quando inizia")
                    Text("«\(lines[editor.sel.l].text)»")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .id(editor.sel.l)
                }
                Spacer()
                if player.isPlaying {
                    Button { tapLine() } label: { Label("Segna frase", systemImage: "hand.tap") }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                    Button { player.pause() } label: { Image(systemName: "pause.fill") }
                } else {
                    Button { player.play() } label: { Label("Avvia", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent)
                }
            } else if !player.isPlaying {
                Image(systemName: "space").font(.title2).foregroundStyle(Color.accentColor)
                Text("Premi **SPAZIO** per far partire l'audio")
                if let w = nextWordText, !allDone {
                    Text("· poi SPAZIO quando inizia **«\(w)»**").foregroundStyle(.secondary)
                }
                Spacer()
                Button { player.play() } label: { Label("Avvia", systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent)
            } else if let w = nextWordText {
                Image(systemName: "hand.tap.fill").font(.title2).foregroundStyle(.yellow)
                Text("Premi **SPAZIO** quando inizia")
                Text("«\(w)»")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.yellow)
                    .id(editor.sel)
                    .transition(.scale)
                Spacer()
                Button { tap() } label: { Label("Segna", systemImage: "hand.tap") }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                Button { player.pause() } label: { Image(systemName: "pause.fill") }
            }
            if allDone && editor.mode == .mark && player.hasAudio {
                Label("Tutte le parole sono sincronizzate", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.title3)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.12)))
    }

    // MARK: Barra di trasporto

    private var transport: some View {
        HStack(spacing: 12) {
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 22)
            }
            .controlSize(.large)
            .disabled(!player.hasAudio)
            Button { player.seek(player.currentTime - 5) } label: { Image(systemName: "gobackward.5") }
                .disabled(!player.hasAudio)
            TimeLabel(clock: player.clock, duration: player.duration)
            Picker("", selection: $player.rate) {
                Text("100%").tag(Float(1))
                Text("85%").tag(Float(0.85))
                Text("70%").tag(Float(0.7))
                Text("50%").tag(Float(0.5))
            }
            .frame(width: 90)
            .help("Velocità di riproduzione (l'intonazione resta uguale)")
            Picker("", selection: $editor.mode) {
                ForEach(SyncMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            .help("Parole: Spazio su ogni parola (karaoke) · Frasi: Spazio o clic su ogni frase (StageTraxx) · Controlla: riascolto")
            Spacer()
            Text("\(document.project.timedCount) / \(document.project.wordCount) parole")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.yellow)
            Button { undo?.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .help("Annulla (⌫ o ⌘Z)")
                .disabled(!(undo?.canUndo ?? false))
            Button(role: .destructive) { confirmReset = true } label: { Image(systemName: "trash") }
                .help("Cancella tutti i tempi")
        }
    }

    private var helpLine: some View {
        Group {
            if audioURL == nil {
                Label("Nessun audio: aggiungilo nella sezione 1 · Testo e audio.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if let e = player.loadError {
                Label(e, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            } else if editor.mode == .line {
                Text("**FRASI (per StageTraxx):** **Spazio** o **clic sulla frase** = segna l'inizio della frase al tempo attuale e passa alla successiva · a riproduzione ferma il clic fa riascoltare la frase · **⌫** annulla · **← →** sposta di 0,05 s (**⇧** 0,2 s) · **↑ ↓** frase precedente/successiva · **1–9** comando MIDI. Esporta con ⇧⌘E: ogni riga riceve il suo [MM:SS.xx].")
            } else if editor.mode == .mark {
                Text("**SEGNA:** premi **Spazio** quando il cantante *inizia* la parola col bordo giallo (la prima volta Spazio avvia l'audio) · **↩** segna la fine della riga · **Esc** pausa · **⌫** annulla · **← →** sposta di 0,05 s (**⇧** 0,2 s) · **↑ ↓** parola precedente/successiva · clic su una parola = riascolta da 3 s prima · trascina i marcatori sull'onda per correggere · **1–9** inserisce un comando MIDI (es. 1 Clean, 2 Crunch, 3 Distorto, 4 Solo)")
            } else {
                Text("**CONTROLLA:** la parola cantata si accende · **Spazio** play/pausa · clic su una parola = riascolta da 3 s prima · **← →** correggi la parola selezionata · trascina i marcatori sull'onda · **1–9** inserisce un comando MIDI")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Elenco parole

    private var wordList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if lines.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.badge.plus").font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("Prima incolla il testo nella sezione 1.").foregroundStyle(.secondary)
                        Button("Vai al testo") { editor.tab = .lyrics }
                    }
                    .frame(maxWidth: .infinity).padding(60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(lines.indices, id: \.self) { i in
                            LineRow(index: i, line: lines[i],
                                    selectedWord: editor.sel.l == i ? editor.sel.w : nil,
                                    liveWord: editor.live?.l == i ? editor.live?.w : nil,
                                    lineMode: editor.mode == .line,
                                    onTap: { j in
                                        if editor.mode == .line { tapLine(i) } else { select(WordRef(l: i, w: j), seek: true) }
                                    },
                                    onReplay: { j in select(WordRef(l: i, w: j), seek: true) },
                                    onClear: { j in
                                        document.update(undo, "Cancella tempo") { $0.lines[i].words[j].t = nil }
                                    },
                                    onSetNow: { j in
                                        document.update(undo, "Imposta tempo") { $0.lines[i].words[j].t = round2(player.currentTime) }
                                    },
                                    onClearEnd: {
                                        document.update(undo, "Cancella fine riga") { $0.lines[i].end = nil }
                                    })
                            .equatable()
                            .id(i)
                            .padding(.top, lines[i].brk ? 14 : 0)
                        }
                    }
                    .padding(16)
                }
            }
            .onChange(of: editor.sel.l) { l in
                if editor.mode == .mark || !player.isPlaying {
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(l, anchor: .center) }
                }
            }
            .onChange(of: editor.live?.l) { l in
                if let l, editor.mode == .check, player.isPlaying {
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(l, anchor: .center) }
                }
            }
        }
    }

    private var midiMarkers: [MidiMarker] {
        document.project.midi.events.map { MidiMarker(id: $0.id, t: $0.t, label: $0.label) }
    }

    private func addMidi(preset index: Int) {
        let presets = document.project.midi.presets
        guard index < presets.count else { return }
        let pr = presets[index]
        let t = round2(player.currentTime)
        document.update(undo, "Comando MIDI") { $0.midi.events.append(MidiEvent(t: t, command: pr.command, name: pr.name)) }
    }

    private var markers: [WordMarker] {
        var out: [WordMarker] = []
        for (i, l) in lines.enumerated() {
            for (j, w) in l.words.enumerated() {
                if let t = w.t { out.append(WordMarker(ref: WordRef(l: i, w: j), t: t, label: w.w)) }
            }
        }
        return out
    }

    // MARK: Logica

    private func round2(_ t: Double) -> Double { (t * 100).rounded() / 100 }

    private func valid(_ r: WordRef) -> Bool {
        r.l >= 0 && r.l < lines.count && r.w >= 0 && r.w < lines[r.l].words.count
    }

    private func select(_ r: WordRef, seek: Bool) {
        guard valid(r) else { return }
        editor.sel = r
        if seek && player.hasAudio {
            var t: Double?
            var x = r
            while t == nil {
                t = lines[x.l].words[x.w].t
                guard let p = previous(x) else { break }
                x = p
            }
            player.seek(max(0, (t ?? 0) - 3))
            player.play()
        }
    }

    private func next(_ r: WordRef) -> WordRef? {
        if r.w + 1 < lines[r.l].words.count { return WordRef(l: r.l, w: r.w + 1) }
        var l = r.l + 1
        while l < lines.count {
            if !lines[l].words.isEmpty { return WordRef(l: l, w: 0) }
            l += 1
        }
        return nil
    }

    private func previous(_ r: WordRef) -> WordRef? {
        if r.w > 0 { return WordRef(l: r.l, w: r.w - 1) }
        var l = r.l - 1
        while l >= 0 {
            if !lines[l].words.isEmpty { return WordRef(l: l, w: lines[l].words.count - 1) }
            l -= 1
        }
        return nil
    }

    private func tap() {
        let r = editor.sel
        guard valid(r) else { return }
        let t = round2(player.currentTime)
        document.update(undo, "Segna parola") { $0.lines[r.l].words[r.w].t = t }
        editor.tapHistory.append(r)
        editor.lastTapped = r
        if let n = next(r) { editor.sel = n }
    }

    /// Modalità Frasi: tempo di inizio della frase (= prima parola).
    private func nextLine(after l: Int) -> Int? {
        var k = l + 1
        while k < lines.count { if !lines[k].words.isEmpty { return k }; k += 1 }
        return nil
    }

    private func previousLine(before l: Int) -> Int? {
        var k = l - 1
        while k >= 0 { if !lines[k].words.isEmpty { return k }; k -= 1 }
        return nil
    }

    private func tapLine(_ l: Int? = nil) {
        let li = l ?? editor.sel.l
        guard li >= 0, li < lines.count, !lines[li].words.isEmpty else { return }
        guard player.hasAudio else { return }
        if !player.isPlaying {
            // a riproduzione ferma il clic seleziona la frase e la fa riascoltare
            select(WordRef(l: li, w: 0), seek: true)
            return
        }
        let t = round2(player.currentTime)
        let r = WordRef(l: li, w: 0)
        document.update(undo, "Segna frase") { $0.lines[li].words[0].t = t }
        editor.tapHistory.append(editor.sel)
        editor.lastTapped = r
        if let n = nextLine(after: li) { editor.sel = WordRef(l: n, w: 0) } else { editor.sel = r }
    }

    private func markLineEnd() {
        guard let r = editor.lastTapped ?? (valid(editor.sel) ? editor.sel : nil), r.l < lines.count else { return }
        let t = round2(player.currentTime)
        guard let lastT = lines[r.l].words.compactMap({ $0.t }).max(), t > lastT else { return }
        document.update(undo, "Fine riga") { $0.lines[r.l].end = t }
    }

    private func undoLast() {
        guard let u = undo, u.canUndo else { return }
        let wasTap = u.undoActionName == "Segna parola" || u.undoActionName == "Segna frase"
        u.undo()
        if wasTap, let r = editor.tapHistory.popLast(), valid(r) {
            editor.sel = r
            editor.lastTapped = editor.tapHistory.last
        }
    }

    private func nudge(_ d: Double) {
        var r = editor.sel
        if editor.mode == .line { r.w = 0 }
        guard valid(r), let t = lines[r.l].words[r.w].t else { return }
        document.update(undo, "Sposta parola") { $0.lines[r.l].words[r.w].t = round2(max(0, t + d)) }
    }

    private func updateLive(_ t: Double) {
        var best: WordRef?
        var bt = -1.0
        for (i, L) in lines.enumerated() {
            for (j, W) in L.words.enumerated() {
                if let wt = W.t, wt <= t, wt >= bt { best = WordRef(l: i, w: j); bt = wt }
            }
        }
        if let b = best {
            let L = lines[b.l]
            var nx: Double?
            if b.w + 1 < L.words.count { nx = L.words[b.w + 1].t }
            else if b.l + 1 < lines.count { nx = lines[b.l + 1].words.first?.t }
            if let e = L.end, b.w == L.words.count - 1, t > e { best = nil }
            else if (nx == nil || nx! < bt) && t - bt > 1.5 { best = nil }
        }
        if best != editor.live { editor.live = best }
    }

    // MARK: Tastiera

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            handleKey(e) ? nil : e
        }
    }

    private func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    private func handleKey(_ e: NSEvent) -> Bool {
        guard editor.tab == .sync, let win = editor.window, e.window === win, win.attachedSheet == nil else { return false }
        // in questa sezione non ci sono campi di testo: se uno è rimasto attivo, lo libero
        if win.firstResponder is NSText { win.makeFirstResponder(nil) }
        let mods = e.modifierFlags.intersection([.command, .control, .option])
        if !mods.isEmpty { return false }
        let shift = e.modifierFlags.contains(.shift)
        // tasti 1…9: comando MIDI rapido al tempo attuale
        if let ch = e.charactersIgnoringModifiers, ch.count == 1, let d = Int(ch), d >= 1, d <= 9 {
            addMidi(preset: d - 1)
            return true
        }
        switch e.keyCode {
        case 49: // spazio
            guard player.hasAudio else { return true }
            if !player.isPlaying { player.play(); return true }
            switch editor.mode {
            case .mark: tap()
            case .line: tapLine()
            case .check: player.pause()
            }
            return true
        case 36, 76: // invio
            if editor.mode == .mark { markLineEnd() }
            return true
        case 53: // esc
            player.pause(); return true
        case 51, 117: // cancella
            undoLast(); return true
        case 123: nudge(shift ? -0.2 : -0.05); return true
        case 124: nudge(shift ? 0.2 : 0.05); return true
        case 126:
            if editor.mode == .line {
                if let p = previousLine(before: editor.sel.l) { editor.sel = WordRef(l: p, w: 0) }
            } else if let p = previous(editor.sel) { editor.sel = p }
            return true
        case 125:
            if editor.mode == .line {
                if let n = nextLine(after: editor.sel.l) { editor.sel = WordRef(l: n, w: 0) }
            } else if let n = next(editor.sel) { editor.sel = n }
            return true
        default: return false
        }
    }
}

struct TimeLabel: View {
    @ObservedObject var clock: Clock
    let duration: Double
    var body: some View {
        Text("\(formatTime(clock.time)) / \(formatTime(duration))")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(minWidth: 130, alignment: .leading)
    }
}

struct LineRow: View, Equatable {
    let index: Int
    let line: KLine
    let selectedWord: Int?
    let liveWord: Int?
    var lineMode = false
    let onTap: (Int) -> Void
    var onReplay: (Int) -> Void = { _ in }
    let onClear: (Int) -> Void
    let onSetNow: (Int) -> Void
    let onClearEnd: () -> Void

    static func == (a: LineRow, b: LineRow) -> Bool {
        a.index == b.index && a.line == b.line && a.selectedWord == b.selectedWord && a.liveWord == b.liveWord
            && a.lineMode == b.lineMode
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if lineMode {
                Text(line.words.first?.t.map { MidiSyntax.stamp($0) } ?? "--:--.--")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(line.words.first?.t == nil ? Color.secondary : Color.yellow)
                    .frame(width: 80, alignment: .trailing)
                    .padding(.top, 8)
            } else {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, alignment: .trailing)
                    .padding(.top, 8)
            }
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(line.words.indices, id: \.self) { j in
                    WordChip(word: line.words[j], selected: selectedWord == j, live: liveWord == j)
                        .onTapGesture { onTap(j) }
                        .contextMenu {
                            Button("Riascolta da qui") { onReplay(j) }
                            Button("Imposta al tempo attuale") { onSetNow(j) }
                            Button("Cancella tempo") { onClear(j) }
                        }
                }
                if let e = line.end {
                    Text("fine \(String(format: "%.2f", e))")
                        .font(.system(size: 10).monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 10)
                        .foregroundStyle(.secondary)
                        .contextMenu { Button("Cancella fine riga") { onClearEnd() } }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(selectedWord != nil ? 0.16 : 0.07))
        )
        .contentShape(Rectangle())
        .onTapGesture { if lineMode { onTap(0) } }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectedWord != nil ? Color.yellow.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
}

struct WordChip: View {
    let word: KWord
    let selected: Bool
    let live: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(word.w)
                .font(.system(size: 16, weight: .medium))
            Text(word.t.map { String(format: "%.2f", $0) } ?? "·")
                .font(.system(size: 9).monospacedDigit())
                .opacity(0.7)
        }
        .foregroundStyle(live ? Color.black : (word.t == nil ? Color.secondary : Color.primary))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(live ? Color.yellow : (word.t == nil ? Color.clear : Color.secondary.opacity(0.12)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(selected ? Color.yellow : Color.secondary.opacity(0.25), lineWidth: selected ? 2.5 : 1)
        )
        .contentShape(Rectangle())
    }
}
