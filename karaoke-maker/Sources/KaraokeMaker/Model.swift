import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - Decoding helper

extension KeyedDecodingContainer {
    func v<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

// MARK: - Colors

struct RGBA: Codable, Equatable {
    var r: Double, g: Double, b: Double, a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? NSColor.white
        r = Double(c.redComponent); g = Double(c.greenComponent)
        b = Double(c.blueComponent); a = Double(c.alphaComponent)
    }

    var cgColor: CGColor {
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)])!
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    func mixed(with o: RGBA, _ f: Double) -> RGBA {
        RGBA(r + (o.r - r) * f, g + (o.g - g) * f, b + (o.b - b) * f, a + (o.a - a) * f)
    }

    func withAlpha(_ x: Double) -> RGBA { RGBA(r, g, b, x) }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)
    static let yellow = RGBA(1, 0.83, 0)
}

// MARK: - Style

enum HighlightMode: String, Codable, CaseIterable, Identifiable {
    case sweep, word
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sweep: return "Scorrimento"
        case .word: return "Parola per parola"
        }
    }
}

enum LineLayoutMode: String, Codable, CaseIterable, Identifiable {
    case currentAndNext, alternating
    var id: String { rawValue }
    var label: String {
        switch self {
        case .currentAndNext: return "Riga + successiva"
        case .alternating: return "Due righe alternate"
        }
    }
}

enum BackgroundKind: String, Codable, CaseIterable, Identifiable {
    case gradient, solid, image, transparent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gradient: return "Sfumato animato"
        case .solid: return "Tinta unita"
        case .image: return "Immagine"
        case .transparent: return "Trasparente"
        }
    }
}

struct KaraokeStyle: Codable, Equatable {
    var highlightMode: HighlightMode = .sweep
    var layout: LineLayoutMode = .currentAndNext
    var keepSungHighlighted = true
    var wordPop = true
    var fontFamily = "Helvetica Neue"
    var bold = true
    var fontSize: Double = 96          // pixel, riferiti al lato corto 1080
    var nextLineScale: Double = 0.7
    var uppercase = false
    var textColor = RGBA.white
    var highlightColor = RGBA.yellow
    var nextLineColor = RGBA(0.66, 0.69, 0.78)
    var outlineColor = RGBA(0.04, 0.04, 0.12, 0.92)
    var outlineWidth: Double = 6
    var shadow = true
    var verticalPosition: Double = 0.5
    var showNextLine = true
    var wordOffset: Double = 0.10
    var lineLead: Double = 1.1
    var background: BackgroundKind = .gradient
    var bgColor1 = RGBA(0.106, 0.063, 0.208)
    var bgColor2 = RGBA(0.051, 0.165, 0.29)
    var bgImagePath: String? = nil
    var bgDim: Double = 0.35
    var showTitle = true
    var showCountdown = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KaraokeStyle()
        highlightMode = c.v(.highlightMode, d.highlightMode)
        layout = c.v(.layout, d.layout)
        keepSungHighlighted = c.v(.keepSungHighlighted, d.keepSungHighlighted)
        wordPop = c.v(.wordPop, d.wordPop)
        fontFamily = c.v(.fontFamily, d.fontFamily)
        bold = c.v(.bold, d.bold)
        fontSize = c.v(.fontSize, d.fontSize)
        nextLineScale = c.v(.nextLineScale, d.nextLineScale)
        uppercase = c.v(.uppercase, d.uppercase)
        textColor = c.v(.textColor, d.textColor)
        highlightColor = c.v(.highlightColor, d.highlightColor)
        nextLineColor = c.v(.nextLineColor, d.nextLineColor)
        outlineColor = c.v(.outlineColor, d.outlineColor)
        outlineWidth = c.v(.outlineWidth, d.outlineWidth)
        shadow = c.v(.shadow, d.shadow)
        verticalPosition = c.v(.verticalPosition, d.verticalPosition)
        showNextLine = c.v(.showNextLine, d.showNextLine)
        wordOffset = c.v(.wordOffset, d.wordOffset)
        lineLead = c.v(.lineLead, d.lineLead)
        background = c.v(.background, d.background)
        bgColor1 = c.v(.bgColor1, d.bgColor1)
        bgColor2 = c.v(.bgColor2, d.bgColor2)
        bgImagePath = c.v(.bgImagePath, d.bgImagePath)
        bgDim = c.v(.bgDim, d.bgDim)
        showTitle = c.v(.showTitle, d.showTitle)
        showCountdown = c.v(.showCountdown, d.showCountdown)
    }
}

// MARK: - Export settings

enum VideoFormat: String, Codable, CaseIterable, Identifiable {
    case h264, hevc, prores422, prores4444Alpha, hevcAlpha
    var id: String { rawValue }

    var label: String {
        switch self {
        case .h264: return "MP4 · H.264 (con sfondo)"
        case .hevc: return "MP4 · HEVC/H.265 (con sfondo)"
        case .prores422: return "MOV · ProRes 422 HQ (con sfondo)"
        case .prores4444Alpha: return "MOV · ProRes 4444 TRASPARENTE"
        case .hevcAlpha: return "MOV · HEVC TRASPARENTE"
        }
    }

    var hasAlpha: Bool { self == .prores4444Alpha || self == .hevcAlpha }
    var fileExtension: String { (self == .h264 || self == .hevc) ? "mp4" : "mov" }
    var utType: UTType { fileExtension == "mp4" ? .mpeg4Movie : .quickTimeMovie }

    var note: String {
        switch self {
        case .h264: return "Compatibile ovunque: YouTube, Instagram, TV, telefoni."
        case .hevc: return "Qualità migliore a parità di peso. Per Mac, iPhone e YouTube."
        case .prores422: return "Qualità da montaggio professionale. File grandi."
        case .prores4444Alpha: return "Canale alfa per Final Cut, Premiere, DaVinci, After Effects. File grandi. Lo sfondo non viene incluso."
        case .hevcAlpha: return "Canale alfa leggero, per Final Cut, iMovie, Motion e dispositivi Apple. Lo sfondo non viene incluso."
        }
    }
}

enum VideoResolution: String, Codable, CaseIterable, Identifiable {
    case fhd, hd, uhd, vertical, square
    var id: String { rawValue }
    var size: CGSize {
        switch self {
        case .fhd: return CGSize(width: 1920, height: 1080)
        case .hd: return CGSize(width: 1280, height: 720)
        case .uhd: return CGSize(width: 3840, height: 2160)
        case .vertical: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
    var label: String {
        switch self {
        case .fhd: return "Full HD 1920×1080"
        case .hd: return "HD 1280×720"
        case .uhd: return "4K 3840×2160"
        case .vertical: return "Verticale 1080×1920 (Reels/TikTok)"
        case .square: return "Quadrato 1080×1080"
        }
    }
}

struct ExportSettings: Codable, Equatable {
    var format: VideoFormat = .h264
    var resolution: VideoResolution = .fhd
    var fps: Int = 30
    var includeAudio = true

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ExportSettings()
        format = c.v(.format, d.format)
        resolution = c.v(.resolution, d.resolution)
        fps = c.v(.fps, d.fps)
        includeAudio = c.v(.includeAudio, d.includeAudio)
    }
}

// MARK: - Project

struct KWord: Codable, Equatable {
    var w: String
    var t: Double?

    init(w: String, t: Double? = nil) { self.w = w; self.t = t }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        w = c.v(.w, "")
        t = c.v(.t, Double?.none)
    }
}

struct KLine: Codable, Equatable {
    var text: String
    var brk: Bool = false
    var words: [KWord]
    var end: Double? = nil

    init(text: String, brk: Bool, words: [KWord], end: Double? = nil) {
        self.text = text; self.brk = brk; self.words = words; self.end = end
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = c.v(.text, "")
        brk = c.v(.brk, false)
        words = c.v(.words, [KWord]())
        end = c.v(.end, Double?.none)
        if words.isEmpty && !text.isEmpty {
            words = text.split(whereSeparator: { $0.isWhitespace }).map { KWord(w: String($0)) }
        }
    }

    var isFullyTimed: Bool { !words.isEmpty && words.allSatisfy { $0.t != nil } }
}

struct AudioRef: Codable, Equatable {
    var path: String
    var name: String { (path as NSString).lastPathComponent }
}

struct KaraokeProject: Codable, Equatable {
    var version = 2
    var title = ""
    var artist = ""
    var lyrics = ""
    var lines: [KLine] = []
    var vocalAudio: AudioRef? = nil
    var backingAudio: AudioRef? = nil
    var style = KaraokeStyle()
    var export = ExportSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.v(.version, 2)
        title = c.v(.title, "")
        artist = c.v(.artist, "")
        lyrics = c.v(.lyrics, "")
        lines = c.v(.lines, [KLine]())
        vocalAudio = c.v(.vocalAudio, AudioRef?.none)
        backingAudio = c.v(.backingAudio, AudioRef?.none)
        style = c.v(.style, KaraokeStyle())
        export = c.v(.export, ExportSettings())
        if lyrics.isEmpty && !lines.isEmpty {
            lyrics = KaraokeProject.lyricsText(from: lines)
        }
    }

    /// Accetta sia il nuovo formato sia i progetti JSON della versione web
    /// (oggetto {lyrics, lines} oppure array di righe).
    static func load(from data: Data) throws -> KaraokeProject {
        let dec = JSONDecoder()
        if let lines = try? dec.decode([KLine].self, from: data) {
            var p = KaraokeProject()
            p.lines = lines
            p.lyrics = lyricsText(from: lines)
            return p
        }
        return try dec.decode(KaraokeProject.self, from: data)
    }

    static func lyricsText(from lines: [KLine]) -> String {
        var out: [String] = []
        for (i, l) in lines.enumerated() {
            if l.brk && i > 0 { out.append("") }
            out.append(l.text)
        }
        return out.joined(separator: "\n")
    }

    func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    var wordCount: Int { lines.reduce(0) { $0 + $1.words.count } }
    var timedCount: Int { lines.reduce(0) { $0 + $1.words.filter { $0.t != nil }.count } }
}

// MARK: - Lyrics parsing

enum LyricsParser {
    static func parse(_ text: String) -> [KLine] {
        var out: [KLine] = []
        var brk = false
        for raw in text.components(separatedBy: .newlines) {
            let s = raw.trimmingCharacters(in: .whitespaces)
            if s.isEmpty { brk = true; continue }
            if s.hasPrefix("[") && s.hasSuffix("]") { continue }
            let words = s.split(whereSeparator: { $0.isWhitespace }).map { KWord(w: String($0)) }
            out.append(KLine(text: s, brk: brk && !out.isEmpty, words: words))
            brk = false
        }
        return out
    }

    /// Applica un nuovo testo mantenendo i tempi delle righe rimaste identiche.
    static func merge(newText: String, old: [KLine]) -> [KLine] {
        var pool: [String: [KLine]] = [:]
        for l in old { pool[l.text, default: []].append(l) }
        var lines = parse(newText)
        for i in lines.indices {
            if var arr = pool[lines[i].text], !arr.isEmpty {
                let o = arr.removeFirst()
                pool[lines[i].text] = arr
                lines[i].words = o.words
                lines[i].end = o.end
            }
        }
        return lines
    }
}

// MARK: - LRC export

enum LRCExporter {
    static func stamp(_ t: Double) -> String {
        let t = max(0, t)
        let m = Int(t / 60)
        let s = t - Double(m * 60)
        return String(format: "%02d:%05.2f", m, s)
    }

    static func make(_ p: KaraokeProject) -> String {
        var out: [String] = []
        if !p.title.isEmpty { out.append("[ti:\(p.title)]") }
        if !p.artist.isEmpty { out.append("[ar:\(p.artist)]") }
        out.append("[re:Karaoke Maker]")
        for l in p.lines {
            guard let first = l.words.first(where: { $0.t != nil })?.t else { continue }
            var s = "[\(stamp(first))]"
            s += l.words.map { w in w.t.map { "<\(stamp($0))>\(w.w)" } ?? w.w }.joined(separator: " ")
            if let e = l.end { s += " <\(stamp(e))>" }
            out.append(s)
        }
        return out.joined(separator: "\n") + "\n"
    }
}

func formatTime(_ t: Double) -> String {
    guard t.isFinite else { return "0:00.0" }
    let t = max(0, t)
    let m = Int(t / 60)
    let s = t - Double(m * 60)
    return String(format: "%d:%04.1f", m, s)
}
