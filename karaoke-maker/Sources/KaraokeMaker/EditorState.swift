import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum EditorTab: String, CaseIterable, Identifiable {
    case lyrics, sync, video
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lyrics: return "1 · Testo e audio"
        case .sync: return "2 · Sincronizza"
        case .video: return "3 · Video"
        }
    }
}

enum SyncMode: String, CaseIterable, Identifiable {
    case mark, check
    var id: String { rawValue }
    var label: String { self == .mark ? "Segna" : "Controlla" }
}

struct WordRef: Equatable, Hashable {
    var l: Int
    var w: Int
}

/// Stato della finestra di lavoro (uno per documento).
final class EditorState: ObservableObject {
    @Published var tab: EditorTab = .lyrics
    @Published var sel = WordRef(l: 0, w: 0)
    @Published var mode: SyncMode = .mark
    @Published var live: WordRef?
    @Published var showExport = false
    @Published var lastTapped: WordRef?
    var tapHistory: [WordRef] = []
    weak var window: NSWindow?
    weak var undo: UndoManager?
}

/// Rileva la finestra che contiene una vista.
struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = AccessorView()
        v.onWindow = onWindow
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class AccessorView: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}

/// Disposizione "a capo automatico" per le parole.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW {
                y += rowH + lineSpacing
                x = 0; rowH = 0
            }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > bounds.width {
                y += rowH + lineSpacing
                x = 0; rowH = 0
            }
            sv.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

func chooseFile(types: [UTType], title: String) -> URL? {
    let p = NSOpenPanel()
    p.title = title
    p.allowedContentTypes = types
    p.allowsMultipleSelection = false
    p.canChooseDirectories = false
    return p.runModal() == .OK ? p.url : nil
}
