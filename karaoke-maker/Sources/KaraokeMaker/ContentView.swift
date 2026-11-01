import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorActions {
    var setTab: (EditorTab) -> Void
    var export: () -> Void
    var exportLRC: () -> Void
}

struct EditorActionsKey: FocusedValueKey {
    typealias Value = EditorActions
}

extension FocusedValues {
    var editorActions: EditorActions? {
        get { self[EditorActionsKey.self] }
        set { self[EditorActionsKey.self] = newValue }
    }
}

struct ContentView: View {
    @ObservedObject var document: KaraokeDocument
    let fileURL: URL?

    @StateObject private var editor = EditorState()
    @StateObject private var syncPlayer = PlayerModel()
    @StateObject private var previewPlayer = PlayerModel()
    @StateObject private var exporter = VideoExporter()
    @Environment(\.undoManager) private var undo

    var body: some View {
        Group {
            switch editor.tab {
            case .lyrics:
                LyricsView(document: document, editor: editor, fileURL: fileURL)
            case .sync:
                SyncView(document: document, editor: editor, player: syncPlayer, audioURL: syncURL)
            case .video:
                VideoView(document: document, editor: editor, player: previewPlayer)
            }
        }
        .background(WindowAccessor { editor.window = $0 })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Sezione", selection: $editor.tab) {
                    ForEach(EditorTab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 440)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor.showExport = true
                } label: {
                    Label("Esporta video", systemImage: "film")
                }
                .help("Esporta il video karaoke (⌘E)")
            }
        }
        .sheet(isPresented: $editor.showExport) {
            ExportSheet(document: document, exporter: exporter, audioURL: videoAudioURL)
        }
        .focusedSceneValue(\.editorActions, EditorActions(
            setTab: { editor.tab = $0 },
            export: { editor.showExport = true },
            exportLRC: exportLRC
        ))
        .onAppear {
            let p = document.project
            let hasAudio = p.vocalAudio != nil || p.backingAudio != nil
            editor.tab = (!p.lines.isEmpty && hasAudio) ? .sync : .lyrics
            reloadAudio()
        }
        .onChange(of: document.project.vocalAudio) { _ in reloadAudio() }
        .onChange(of: document.project.backingAudio) { _ in reloadAudio() }
        .onChange(of: editor.tab) { _ in
            syncPlayer.pause()
            previewPlayer.pause()
        }
    }

    private func resolve(_ ref: AudioRef?) -> URL? {
        guard let ref else { return nil }
        let fm = FileManager.default
        if fm.fileExists(atPath: ref.path) { return URL(fileURLWithPath: ref.path) }
        if let dir = fileURL?.deletingLastPathComponent() {
            let u = dir.appendingPathComponent(ref.name)
            if fm.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    private var syncURL: URL? { resolve(document.project.vocalAudio) ?? resolve(document.project.backingAudio) }
    private var videoAudioURL: URL? { resolve(document.project.backingAudio) ?? resolve(document.project.vocalAudio) }

    private func reloadAudio() {
        syncPlayer.load(syncURL)
        previewPlayer.load(videoAudioURL)
    }

    private func exportLRC() {
        let p = NSSavePanel()
        p.allowedContentTypes = [UTType(filenameExtension: "lrc") ?? .plainText]
        p.nameFieldStringValue = (document.project.title.isEmpty ? "karaoke" : document.project.title) + ".lrc"
        guard p.runModal() == .OK, let url = p.url else { return }
        try? LRCExporter.make(document.project).write(to: url, atomically: true, encoding: .utf8)
    }
}
