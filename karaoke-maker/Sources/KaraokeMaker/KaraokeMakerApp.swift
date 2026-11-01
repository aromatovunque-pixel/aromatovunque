import SwiftUI

@main
struct KaraokeMakerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { KaraokeDocument() }) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .commands {
            EditorCommands()
        }
    }
}

struct EditorCommands: Commands {
    @FocusedValue(\.editorActions) private var actions

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Esporta video…") { actions?.export() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(actions == nil)
            Button("Esporta testo sincronizzato (.lrc)…") { actions?.exportLRC() }
                .disabled(actions == nil)
        }
        CommandMenu("Karaoke") {
            Button("Testo e audio") { actions?.setTab(.lyrics) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Sincronizza") { actions?.setTab(.sync) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Video") { actions?.setTab(.video) }
                .keyboardShortcut("3", modifiers: .command)
        }
    }
}
