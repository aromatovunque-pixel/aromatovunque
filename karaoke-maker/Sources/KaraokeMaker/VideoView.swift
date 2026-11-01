import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Anteprima

final class PreviewNSView: NSView {
    var renderer: KaraokeRenderer?
    var time: Double = 0
    var transparent = false

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let b = bounds
        if transparent {
            let sq: CGFloat = 12
            ctx.setFillColor(NSColor(white: 0.32, alpha: 1).cgColor)
            ctx.fill(b)
            ctx.setFillColor(NSColor(white: 0.42, alpha: 1).cgColor)
            var y: CGFloat = 0
            var row = 0
            while y < b.height {
                var x: CGFloat = (row % 2 == 0) ? 0 : sq
                while x < b.width {
                    ctx.fill(CGRect(x: x, y: y, width: sq, height: sq))
                    x += sq * 2
                }
                y += sq; row += 1
            }
        } else {
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(b)
        }
        guard let r = renderer else { return }
        ctx.saveGState()
        let k = b.width / r.size.width
        ctx.scaleBy(x: k, y: k)
        r.render(in: ctx, time: time, drawBackground: !transparent)
        ctx.restoreGState()
    }
}

struct KaraokePreview: NSViewRepresentable {
    let renderer: KaraokeRenderer
    @ObservedObject var clock: Clock
    let transparent: Bool

    func makeNSView(context: Context) -> PreviewNSView { PreviewNSView() }

    func updateNSView(_ v: PreviewNSView, context: Context) {
        v.renderer = renderer
        v.time = clock.time
        v.transparent = transparent
        v.needsDisplay = true
    }
}

struct Scrubber: View {
    @ObservedObject var clock: Clock
    @ObservedObject var player: PlayerModel

    var body: some View {
        HStack {
            Slider(value: Binding(get: { min(clock.time, max(player.duration, 0.1)) },
                                  set: { player.seek($0) }),
                   in: 0...max(player.duration, 0.1))
            Text("\(formatTime(clock.time)) / \(formatTime(player.duration))")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sezione Video

struct VideoView: View {
    @ObservedObject var document: KaraokeDocument
    @ObservedObject var editor: EditorState
    @ObservedObject var player: PlayerModel
    @Environment(\.undoManager) private var undo

    private static let families: [String] = NSFontManager.shared.availableFontFamilies.sorted()

    private func b<T: Equatable>(_ kp: WritableKeyPath<KaraokeStyle, T>, _ name: String = "Stile") -> Binding<T> {
        document.binding((\KaraokeProject.style).appending(path: kp), undo, name)
    }

    var body: some View {
        let p = document.project
        let size = p.export.resolution.size
        let renderer = KaraokeRenderer(project: p, size: size)
        let transparent = p.style.background == .transparent
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                KaraokePreview(renderer: renderer, clock: player.clock, transparent: transparent)
                    .aspectRatio(size.width / size.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 12) {
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 22)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(!player.hasAudio)
                    Scrubber(clock: player.clock, player: player)
                }
                if renderer.lines.isEmpty {
                    Text("Nessuna riga completamente sincronizzata: segna i tempi nella sezione 2.")
                        .font(.callout).foregroundStyle(.orange)
                } else if p.timedCount < p.wordCount {
                    Text("Nel video compaiono solo le righe con tutte le parole sincronizzate (\(renderer.lines.count) di \(p.lines.count)).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)

            Divider()

            inspector
                .frame(width: 330)
        }
    }

    private var inspector: some View {
        Form {
            Section("Evidenziazione") {
                Picker("Modalità", selection: b(\.highlightMode, "Evidenziazione")) {
                    ForEach(HighlightMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(document.project.style.highlightMode == .sweep
                     ? "Il colore scorre dentro ogni parola mentre viene cantata."
                     : "Ogni parola si accende tutta insieme quando inizia.")
                    .font(.caption).foregroundStyle(.secondary)
                if document.project.style.highlightMode == .word {
                    Toggle("Lascia colorate le parole già cantate", isOn: b(\.keepSungHighlighted))
                    Toggle("Effetto “pop” sulla parola", isOn: b(\.wordPop))
                }
                Picker("Righe", selection: b(\.layout, "Disposizione")) {
                    ForEach(LineLayoutMode.allCases) { Text($0.label).tag($0) }
                }
                if document.project.style.layout == .currentAndNext {
                    Toggle("Mostra la riga successiva", isOn: b(\.showNextLine))
                }
            }

            Section("Testo") {
                Picker("Carattere", selection: b(\.fontFamily, "Carattere")) {
                    ForEach(Self.families, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Grassetto", isOn: b(\.bold))
                Toggle("Tutto maiuscolo", isOn: b(\.uppercase))
                LabeledContent("Dimensione") {
                    Slider(value: b(\.fontSize), in: 40...180)
                }
                if document.project.style.layout == .currentAndNext {
                    LabeledContent("Riga successiva") {
                        Slider(value: b(\.nextLineScale), in: 0.4...1)
                    }
                }
                ColorPicker("Colore testo", selection: b(\.textColor).color, supportsOpacity: false)
                ColorPicker("Colore evidenziato", selection: b(\.highlightColor).color, supportsOpacity: false)
                ColorPicker("Colore riga successiva", selection: b(\.nextLineColor).color, supportsOpacity: false)
                ColorPicker("Contorno", selection: b(\.outlineColor).color, supportsOpacity: true)
                LabeledContent("Spessore contorno") {
                    Slider(value: b(\.outlineWidth), in: 0...16)
                }
                Toggle("Ombra", isOn: b(\.shadow))
                LabeledContent("Posizione verticale") {
                    Slider(value: b(\.verticalPosition), in: 0.15...0.88)
                }
            }

            Section("Tempi") {
                LabeledContent("Anticipo parole") {
                    Stepper(value: b(\.wordOffset), in: -1...1, step: 0.05) {
                        Text(String(format: "%.2f s", document.project.style.wordOffset)).monospacedDigit()
                    }
                }
                LabeledContent("Anticipo riga") {
                    Stepper(value: b(\.lineLead), in: 0.2...5, step: 0.1) {
                        Text(String(format: "%.1f s", document.project.style.lineLead)).monospacedDigit()
                    }
                }
                Toggle("Conto alla rovescia dopo le pause", isOn: b(\.showCountdown))
                Toggle("Titolo e artista all'inizio", isOn: b(\.showTitle))
            }

            Section("Sfondo") {
                Picker("Tipo", selection: b(\.background, "Sfondo")) {
                    ForEach(BackgroundKind.allCases) { Text($0.label).tag($0) }
                }
                switch document.project.style.background {
                case .gradient:
                    ColorPicker("Colore 1", selection: b(\.bgColor1).color, supportsOpacity: false)
                    ColorPicker("Colore 2", selection: b(\.bgColor2).color, supportsOpacity: false)
                case .solid:
                    ColorPicker("Colore", selection: b(\.bgColor1).color, supportsOpacity: false)
                case .image:
                    HStack {
                        Text(document.project.style.bgImagePath.map { ($0 as NSString).lastPathComponent } ?? "Nessuna immagine")
                            .lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Scegli…") {
                            if let u = chooseFile(types: [.image], title: "Immagine di sfondo") {
                                document.update(undo, "Immagine di sfondo") { $0.style.bgImagePath = u.path }
                            }
                        }
                    }
                    LabeledContent("Scurisci") {
                        Slider(value: b(\.bgDim), in: 0...0.9)
                    }
                case .transparent:
                    Text("Il video si esporta con canale alfa (ProRes 4444 o HEVC trasparente): solo il testo, da sovrapporre nel programma di montaggio.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    editor.showExport = true
                } label: {
                    Label("Esporta video…", systemImage: "film")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Esportazione

struct ExportSheet: View {
    @ObservedObject var document: KaraokeDocument
    @ObservedObject var exporter: VideoExporter
    let audioURL: URL?
    @Environment(\.undoManager) private var undo
    @Environment(\.dismiss) private var dismiss

    private func b<T: Equatable>(_ kp: WritableKeyPath<ExportSettings, T>) -> Binding<T> {
        document.binding((\KaraokeProject.export).appending(path: kp), undo, "Impostazioni esportazione")
    }

    var body: some View {
        let ex = document.project.export
        VStack(alignment: .leading, spacing: 16) {
            Text("Esporta video karaoke").font(.title2.weight(.bold))
            Form {
                Picker("Formato", selection: b(\.format)) {
                    ForEach(VideoFormat.allCases) { Text($0.label).tag($0) }
                }
                Text(ex.format.note).font(.caption).foregroundStyle(.secondary)
                Picker("Risoluzione", selection: b(\.resolution)) {
                    ForEach(VideoResolution.allCases) { Text($0.label).tag($0) }
                }
                Picker("Fotogrammi al secondo", selection: b(\.fps)) {
                    ForEach([24, 25, 30, 50, 60], id: \.self) { Text("\($0) fps").tag($0) }
                }
                Toggle("Includi l'audio (\(audioURL?.lastPathComponent ?? "nessun file"))", isOn: b(\.includeAudio))
                    .disabled(audioURL == nil)
            }
            .formStyle(.grouped)
            .disabled(exporter.isRunning)

            if document.project.style.background == .transparent && !ex.format.hasAlpha {
                Label("Hai scelto lo sfondo trasparente: per mantenere la trasparenza usa ProRes 4444 o HEVC trasparente. Con questo formato lo sfondo sarà nero.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
            }

            switch exporter.state {
            case .running:
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: exporter.progress)
                    Text("\(Int(exporter.progress * 100))% · \(exporter.speedInfo)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            case .done(let url):
                HStack {
                    Label("Video esportato: \(url.lastPathComponent)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Mostra nel Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    Button("Apri") { NSWorkspace.shared.open(url) }
                }
            case .failed(let msg):
                Label("Errore: \(msg)", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            case .cancelled:
                Label("Esportazione annullata.", systemImage: "stop.circle").foregroundStyle(.secondary)
            case .idle:
                EmptyView()
            }

            HStack {
                if exporter.isRunning {
                    Button("Annulla esportazione", role: .cancel) { exporter.cancel() }
                } else {
                    Button("Chiudi") { dismiss() }.keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button {
                    startExport()
                } label: {
                    Label("Esporta…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(exporter.isRunning || document.project.lines.filter { $0.isFullyTimed }.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 560)
        .onAppear {
            if case .running = exporter.state {} else { exporter.state = .idle }
            if document.project.style.background == .transparent && !ex.format.hasAlpha {
                document.update(undo, "Formato") { $0.export.format = .prores4444Alpha }
            }
        }
    }

    private func startExport() {
        let ex = document.project.export
        let panel = NSSavePanel()
        panel.allowedContentTypes = [ex.format.utType]
        let base = document.project.title.isEmpty ? "karaoke" : document.project.title
        panel.nameFieldStringValue = base + (ex.format.hasAlpha ? " (trasparente)" : "") + "." + ex.format.fileExtension
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exporter.start(project: document.project, audioURL: audioURL, outURL: url)
    }
}
