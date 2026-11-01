import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var karaokeProject: UTType {
        UTType(exportedAs: "ch.aromatovunque.karaokemaker.project", conformingTo: .json)
    }
    static var lrc: UTType {
        UTType(importedAs: "ch.aromatovunque.karaokemaker.lrc", conformingTo: .plainText)
    }
}

final class KaraokeDocument: ReferenceFileDocument {
    typealias Snapshot = KaraokeProject

    static var readableContentTypes: [UTType] { [.karaokeProject, .json, .lrc, .plainText, .text, .audio] }
    static var writableContentTypes: [UTType] { [.karaokeProject] }

    @Published var project: KaraokeProject

    init() {
        project = KaraokeProject()
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let type = configuration.contentType
        let name = ((configuration.file.filename ?? "") as NSString).deletingPathExtension
        if type.conforms(to: .audio) {
            // file audio: nuovo progetto con questo audio (copiato in Application Support)
            var p = KaraokeProject()
            p.title = name
            p.vocalAudio = AudioRef(path: try KaraokeDocument.storeAudio(data, filename: configuration.file.filename ?? "audio.m4a").path)
            project = p
        } else if type.conforms(to: .karaokeProject) || type.conforms(to: .json) {
            project = try KaraokeProject.load(from: data)
        } else {
            // .txt o .lrc: testo della canzone (con tempi se è un LRC)
            project = KaraokeProject.importText(KaraokeProject.decodeText(data))
            if project.title.isEmpty { project.title = name }
        }
    }

    static func storeAudio(_ data: Data, filename: String) throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Karaoke Maker/Audio", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appendingPathComponent(String(UUID().uuidString.prefix(8)) + "-" + filename)
        try data.write(to: url)
        return url
    }

    func snapshot(contentType: UTType) throws -> KaraokeProject { project }

    func fileWrapper(snapshot: KaraokeProject, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try snapshot.encoded())
    }

    // MARK: Modifiche con Annulla/Ripeti

    func update(_ undo: UndoManager?, _ action: String, _ change: (inout KaraokeProject) -> Void) {
        let old = project
        var p = project
        change(&p)
        guard p != old else { return }
        project = p
        registerUndo(old, undo, action)
    }

    /// Modifica "dal vivo" senza registrare un passo di Annulla (es. durante un trascinamento).
    func updateLive(_ change: (inout KaraokeProject) -> Void) {
        var p = project
        change(&p)
        project = p
    }

    /// Registra un singolo passo di Annulla che riporta a `old`.
    func commit(from old: KaraokeProject, _ undo: UndoManager?, _ action: String) {
        guard old != project else { return }
        registerUndo(old, undo, action)
    }

    private func registerUndo(_ old: KaraokeProject, _ undo: UndoManager?, _ action: String) {
        guard let undo else { return }
        undo.registerUndo(withTarget: self) { doc in
            let current = doc.project
            doc.project = old
            doc.registerUndo(current, undo, action)
        }
        undo.setActionName(action)
    }

    func binding<T: Equatable>(_ kp: WritableKeyPath<KaraokeProject, T>, _ undo: UndoManager?, _ action: String = "Modifica") -> Binding<T> {
        Binding(
            get: { self.project[keyPath: kp] },
            set: { v in self.update(undo, action) { $0[keyPath: kp] = v } }
        )
    }
}

extension Binding where Value == RGBA {
    var color: Binding<Color> {
        Binding<Color>(
            get: { Color(nsColor: wrappedValue.nsColor) },
            set: { wrappedValue = RGBA(nsColor: NSColor($0)) }
        )
    }
}
