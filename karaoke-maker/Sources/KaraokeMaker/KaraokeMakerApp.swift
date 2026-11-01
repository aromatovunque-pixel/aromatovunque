import SwiftUI

@main
enum Main {
    static func main() {
        if let i = CommandLine.arguments.firstIndex(of: "--selftest") {
            // Verifica automatica senza interfaccia (usata dalla build su GitHub).
            let args = Array(CommandLine.arguments.dropFirst(i + 1))
            Task { @MainActor in
                let ok = await SelfTest.run(projectPath: args.first ?? "", outDir: args.count > 1 ? args[1] : "selftest-out")
                exit(ok ? 0 : 1)
            }
            RunLoop.main.run()
            return
        }
        KaraokeMakerApp.main()
    }
}

struct KaraokeMakerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { KaraokeDocument() }) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
                .frame(minWidth: 940, minHeight: 620)
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
