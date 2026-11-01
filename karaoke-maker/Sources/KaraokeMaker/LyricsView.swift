import SwiftUI
import UniformTypeIdentifiers

struct LyricsView: View {
    @ObservedObject var document: KaraokeDocument
    @ObservedObject var editor: EditorState
    let fileURL: URL?
    @Environment(\.undoManager) private var undo
    @State private var draft = ""
    @State private var loaded = false

    private var changed: Bool { draft != document.project.lyrics || document.project.lines.isEmpty && !draft.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // colonna sinistra: info e audio
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox("Canzone") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Titolo", text: document.binding(\.title, undo, "Titolo"))
                            TextField("Artista", text: document.binding(\.artist, undo, "Artista"))
                            Text("Titolo e artista appaiono all'inizio del video (si può disattivare nella sezione Video).")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(6)
                    }
                    AudioSlot(title: "Audio con la voce",
                              subtitle: "Serve per sincronizzare il testo.",
                              icon: "mic.fill",
                              ref: document.project.vocalAudio,
                              onSet: { url in document.update(undo, "Audio voce") { $0.vocalAudio = url.map { AudioRef(path: $0.path) } } })
                    AudioSlot(title: "Base senza voce",
                              subtitle: "Facoltativa: è l'audio del video finale. Se manca uso quello con la voce.",
                              icon: "music.note",
                              ref: document.project.backingAudio,
                              onSet: { url in document.update(undo, "Base musicale") { $0.backingAudio = url.map { AudioRef(path: $0.path) } } })
                    GroupBox("Stato") {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("\(document.project.lines.count) righe", systemImage: "text.alignleft")
                            Label("\(document.project.timedCount) / \(document.project.wordCount) parole sincronizzate", systemImage: "metronome")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }
                .padding(18)
            }
            .frame(width: 320)

            Divider()

            // colonna destra: testo
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Testo della canzone").font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        if let u = chooseFile(types: [.plainText, .text, .lrc], title: "Importa testo (.txt o .lrc)"),
                           let data = try? Data(contentsOf: u) {
                            let imp = KaraokeProject.importText(KaraokeProject.decodeText(data))
                            draft = imp.lyrics
                            if imp.timedCount > 0 {
                                // LRC con tempi: li applico subito
                                document.update(undo, "Importa LRC") { p in
                                    p.lyrics = imp.lyrics
                                    p.lines = imp.lines
                                    if p.title.isEmpty { p.title = imp.title }
                                    if p.artist.isEmpty { p.artist = imp.artist }
                                }
                            }
                        }
                    } label: { Label("Importa .txt / .lrc…", systemImage: "square.and.arrow.down") }
                }
                Text("Una riga = una riga del karaoke. Lascia una riga vuota tra strofe e ritornelli. Le righe tra parentesi quadre, come [Ritornello], vengono ignorate.")
                    .font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $draft)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                HStack {
                    Button {
                        apply()
                    } label: {
                        Label("Usa questo testo e sincronizza", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if changed {
                        Text("Testo modificato: le righe rimaste uguali tengono i loro tempi.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                }
            }
            .padding(18)
        }
        .onAppear {
            if !loaded { draft = document.project.lyrics; loaded = true }
        }
    }

    private func apply() {
        let lines = LyricsParser.merge(newText: draft, old: document.project.lines)
        document.update(undo, "Applica testo") {
            $0.lyrics = draft
            $0.lines = lines
        }
        if editor.sel.l >= lines.count { editor.sel = WordRef(l: 0, w: 0) }
        editor.tab = .sync
    }
}

struct AudioSlot: View {
    let title: String
    let subtitle: String
    let icon: String
    let ref: AudioRef?
    let onSet: (URL?) -> Void
    @State private var targeted = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).foregroundStyle(Color.accentColor)
                    Text(title).font(.headline)
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Image(systemName: ref == nil ? "waveform.badge.plus" : "waveform")
                    Text(ref?.name ?? "Trascina qui un file audio")
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(ref == nil ? .secondary : .primary)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(targeted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08)))
                HStack {
                    Button("Scegli…") {
                        if let u = chooseFile(types: [.audio], title: title) { onSet(u) }
                    }
                    if ref != nil {
                        Button("Rimuovi") { onSet(nil) }
                    }
                }
            }
            .padding(6)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let u = urls.first else { return false }
            onSet(u)
            return true
        } isTargeted: { targeted = $0 }
    }
}
