import AppKit
import CoreText
import CoreGraphics
import ImageIO

// MARK: - Piano di visualizzazione

struct PlanLine {
    var words: [String]
    var T: [Double]          // inizio di ogni parola (già con anticipo)
    var E: [Double] = []     // fine di ogni parola
    var lineEnd: Double?
    var appear: Double = 0
    var hide: Double = 0
    var slot: Int = 0
    var showsNext = false
    var blockStart = false

    var first: Double { T[0] }
    var lastStart: Double { T[T.count - 1] }
    var lastEnd: Double { E[E.count - 1] }
}

enum Planner {
    static func build(_ project: KaraokeProject) -> [PlanLine] {
        let st = project.style
        var L: [PlanLine] = []
        for l in project.lines where l.isFullyTimed {
            var T = l.words.map { $0.t! - st.wordOffset }
            if T.count > 1 {
                for j in 1..<T.count where T[j] < T[j - 1] { T[j] = T[j - 1] }
            }
            let words = l.words.map { st.uppercase ? $0.w.uppercased() : $0.w }
            L.append(PlanLine(words: words, T: T, lineEnd: l.end.map { $0 - st.wordOffset }))
        }
        guard !L.isEmpty else { return [] }

        // fine di ogni parola
        for i in L.indices {
            let n = L[i].T.count
            var E = [Double](repeating: 0, count: n)
            for j in 0..<n {
                let tj = L[i].T[j]
                var e: Double
                if j + 1 < n {
                    e = L[i].T[j + 1]
                } else if let le = L[i].lineEnd, le > tj {
                    e = le
                } else {
                    let nextFirst = i + 1 < L.count ? L[i + 1].T[0] : Double.infinity
                    e = min(tj + 0.9, nextFirst)
                }
                e = min(e, tj + 6)
                E[j] = max(e, tj + 0.05)
            }
            L[i].E = E
        }

        for i in L.indices {
            L[i].blockStart = i == 0 || L[i].first - L[i - 1].lastEnd > 4
        }

        let lead = max(0.2, st.lineLead)
        switch st.layout {
        case .currentAndNext:
            for i in L.indices {
                var s = L[i].first - lead
                if !L[i].blockStart { s = max(s, L[i - 1].lastStart + 0.3) }
                s = min(s, L[i].first - 0.15)
                L[i].appear = max(0, s)
            }
            for i in L.indices {
                let gapAfter = i + 1 >= L.count || L[i + 1].blockStart
                L[i].hide = gapAfter ? L[i].lastEnd + 1.0 : L[i + 1].appear
                L[i].showsNext = !gapAfter
            }

        case .alternating:
            var b = 0
            for i in L.indices {
                if L[i].blockStart { b = i }
                let k = i - b
                L[i].slot = k % 2
                if k == 0 {
                    L[i].appear = max(0, L[i].first - lead)
                } else if k == 1 {
                    L[i].appear = L[b].appear
                } else {
                    L[i].appear = max(L[b].appear, min(L[i - 2].lastEnd + 0.3, L[i].first - 0.15))
                }
            }
            for i in L.indices {
                // ultima riga del blocco
                var last = i
                while last + 1 < L.count && !L[last + 1].blockStart { last += 1 }
                if i + 2 <= last {
                    L[i].hide = L[i + 2].appear
                } else {
                    L[i].hide = L[last].lastEnd + 1.0
                }
                L[i].hide = max(L[i].hide, L[i].appear + 0.1)
            }
        }
        return L
    }
}

// MARK: - Immagini di sfondo

enum ImageCache {
    private static var cache: [String: CGImage] = [:]
    private static let lock = NSLock()

    static func image(_ path: String?) -> CGImage? {
        guard let path, !path.isEmpty else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let c = cache[path] { return c }
        let url = URL(fileURLWithPath: path) as CFURL
        guard let src = CGImageSourceCreateWithURL(url, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        cache[path] = img
        return img
    }
}

// MARK: - Renderer

final class KaraokeRenderer {
    struct GlyphWord { let path: CGPath; let width: CGFloat }

    struct LineLayout {
        let glyphs: [GlyphWord]
        let rows: [[(idx: Int, x: CGFloat)]]
        let rowWidths: [CGFloat]
        let fontPx: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        let rowHeight: CGFloat
        var height: CGFloat { rowHeight * CGFloat(rows.count) }
    }

    struct WordState {
        var base: RGBA
        var progress: CGFloat = 0
        var scale: CGFloat = 1
    }

    let size: CGSize
    let style: KaraokeStyle
    let lines: [PlanLine]
    let title: String
    let artist: String
    private let s: CGFloat
    private let baseFont: CTFont
    private let bgImage: CGImage?
    private var cache: [String: LineLayout] = [:]
    private let lock = NSLock()
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    init(project: KaraokeProject, size: CGSize) {
        self.size = size
        self.style = project.style
        self.lines = Planner.build(project)
        self.title = project.title
        self.artist = project.artist
        self.s = min(size.width, size.height) / 1080
        self.baseFont = KaraokeRenderer.makeFont(family: project.style.fontFamily, bold: project.style.bold)
        self.bgImage = project.style.background == .image ? ImageCache.image(project.style.bgImagePath) : nil
    }

    /// Durata minima del contenuto (ultima riga + coda).
    var contentDuration: Double { (lines.last?.hide ?? 0) + 2 }

    static func makeFont(family: String, bold: Bool) -> CTFont {
        let fm = NSFontManager.shared
        let traits: NSFontTraitMask = bold ? .boldFontMask : .unboldFontMask
        if let f = fm.font(withFamily: family, traits: traits, weight: bold ? 9 : 5, size: 100) {
            return f as CTFont
        }
        if let f = NSFont(name: family, size: 100) { return f as CTFont }
        return NSFont.systemFont(ofSize: 100, weight: bold ? .heavy : .medium) as CTFont
    }

    // MARK: Layout del testo

    private func glyphWord(_ str: String, _ font: CTFont) -> GlyphWord {
        let attr = NSAttributedString(string: str, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attr)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let path = CGMutablePath()
        let runs = CTLineGetGlyphRuns(line) as NSArray
        for case let runObj in runs {
            let run = runObj as! CTRun
            let attrs = CTRunGetAttributes(run) as NSDictionary
            var runFont = font
            if let f = attrs[kCTFontAttributeName as String] {
                runFont = f as! CTFont
            }
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var pos = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &pos)
            for k in 0..<count {
                if let gp = CTFontCreatePathForGlyph(runFont, glyphs[k], nil) {
                    path.addPath(gp, transform: CGAffineTransform(translationX: pos[k].x, y: pos[k].y))
                }
            }
        }
        return GlyphWord(path: path, width: width)
    }

    private func makeLayout(_ words: [String], fontPx: CGFloat, maxW: CGFloat) -> LineLayout {
        var px = max(8, fontPx)
        var attempt = 0
        while true {
            let font = CTFontCreateCopyWithAttributes(baseFont, px, nil, nil)
            let glyphs = words.map { glyphWord($0, font) }
            let space = glyphWord(" ", font).width
            let n = glyphs.count
            func rowW(_ a: Int, _ b: Int) -> CGFloat {
                guard b > a else { return 0 }
                var w: CGFloat = 0
                for i in a..<b { w += glyphs[i].width }
                return w + space * CGFloat(b - a - 1)
            }
            var ranges: [Range<Int>] = [0..<n]
            if n > 1 && rowW(0, n) > maxW {
                var bestC = 1
                var bestV = CGFloat.infinity
                for c in 1..<n {
                    let v = max(rowW(0, c), rowW(c, n))
                    if v < bestV { bestV = v; bestC = c }
                }
                ranges = [0..<bestC, bestC..<n]
            }
            let widest = ranges.map { rowW($0.lowerBound, $0.upperBound) }.max() ?? 0
            if widest > maxW && attempt < 2 {
                px = max(8, px * maxW / widest * 0.98)
                attempt += 1
                continue
            }
            var rows: [[(idx: Int, x: CGFloat)]] = []
            var widths: [CGFloat] = []
            for r in ranges {
                var x: CGFloat = 0
                var row: [(idx: Int, x: CGFloat)] = []
                for i in r {
                    row.append((idx: i, x: x))
                    x += glyphs[i].width + space
                }
                rows.append(row)
                widths.append(rowW(r.lowerBound, r.upperBound))
            }
            let asc = CTFontGetAscent(font)
            let desc = CTFontGetDescent(font)
            return LineLayout(glyphs: glyphs, rows: rows, rowWidths: widths, fontPx: px,
                              ascent: asc, descent: desc, rowHeight: (asc + desc) * 1.1)
        }
    }

    private func layout(_ key: String, _ words: [String], scale: Double) -> LineLayout {
        lock.lock()
        if let c = cache[key] { lock.unlock(); return c }
        lock.unlock()
        let l = makeLayout(words, fontPx: CGFloat(style.fontSize * scale) * s, maxW: size.width * 0.9)
        lock.lock(); cache[key] = l; lock.unlock()
        return l
    }

    private func mainLayout(_ i: Int) -> LineLayout { layout("m\(i)", lines[i].words, scale: 1) }
    private func nextLayout(_ i: Int) -> LineLayout { layout("n\(i)", lines[i].words, scale: style.nextLineScale) }

    // MARK: Disegno

    func render(in ctx: CGContext, time t: Double, drawBackground: Bool) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.textMatrix = .identity
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        if drawBackground { drawBG(ctx, t) }

        let centerTop = CGFloat(style.verticalPosition) * size.height
        if lines.isEmpty {
            drawTitle(ctx, t: t, centerTop: centerTop, until: .infinity)
            return
        }
        // il titolo sparisce prima del conto alla rovescia iniziale
        var titleUntil = lines[0].appear
        if style.showCountdown { titleUntil = min(titleUntil, lines[0].first - 3.3) }
        drawTitle(ctx, t: t, centerTop: centerTop, until: titleUntil)

        switch style.layout {
        case .currentAndNext: renderCurrentAndNext(ctx, t, centerTop)
        case .alternating: renderAlternating(ctx, t, centerTop)
        }
    }

    private func fade(_ t: Double, _ a: Double, _ b: Double, _ d: Double = 0.2) -> CGFloat {
        let x = min(max((t - a) / d, 0), 1) * min(max((b - t) / d, 0), 1)
        return CGFloat(x)
    }

    private func wordStates(_ i: Int, _ t: Double) -> (Int) -> WordState {
        let L = lines[i]
        let st = style
        return { j in
            let T = L.T[j], E = L.E[j]
            var ws = WordState(base: st.textColor)
            switch st.highlightMode {
            case .sweep:
                if t >= E { ws.progress = 1 }
                else if t >= T { ws.progress = CGFloat((t - T) / max(0.01, E - T)) }
            case .word:
                var k = -1
                for q in 0..<L.T.count where L.T[q] <= t { k = q }
                if j == k {
                    ws.progress = 1
                    if st.wordPop {
                        let p = max(0, 1 - (t - T) / 0.3)
                        ws.scale = CGFloat(1 + 0.1 * p * p)
                    }
                } else if j < k && st.keepSungHighlighted {
                    ws.progress = 1
                }
            }
            return ws
        }
    }

    private func renderCurrentAndNext(_ ctx: CGContext, _ t: Double, _ centerTop: CGFloat) {
        if let i = lines.firstIndex(where: { $0.appear <= t && t < $0.hide }) {
            let L = lines[i]
            let m = mainLayout(i)
            let a = fade(t, L.appear, L.hide)
            drawLine(ctx, m, centerTop: centerTop, alpha: a, state: wordStates(i, t))
            if style.showNextLine && L.showsNext && i + 1 < lines.count {
                let n = nextLayout(i + 1)
                let y = centerTop + m.height / 2 + m.fontPx * 0.25 + n.height / 2
                let fi = CGFloat(min(max((t - L.appear) / 0.2, 0), 1))
                let col = style.nextLineColor
                drawLine(ctx, n, centerTop: y, alpha: fi, state: { _ in WordState(base: col) })
            }
            if L.blockStart { drawCountdown(ctx, t, line: i, aboveTop: centerTop - m.height / 2) }
        } else if let n = lines.firstIndex(where: { $0.appear > t }) {
            let m = mainLayout(n)
            drawCountdown(ctx, t, line: n, aboveTop: centerTop - m.height / 2)
        }
    }

    private func renderAlternating(_ ctx: CGContext, _ t: Double, _ centerTop: CGFloat) {
        let visible = lines.indices.filter { lines[$0].appear <= t && t < lines[$0].hide }
        if visible.isEmpty {
            if let n = lines.firstIndex(where: { $0.appear > t }) {
                let h = mainLayout(n).height
                drawCountdown(ctx, t, line: n, aboveTop: centerTop - h - mainLayout(n).fontPx * 0.15)
            }
            return
        }
        var hTop: CGFloat = 0, hBot: CGFloat = 0
        for i in visible {
            let h = mainLayout(i).height
            if lines[i].slot == 0 { hTop = max(hTop, h) } else { hBot = max(hBot, h) }
        }
        let ref = mainLayout(visible[0])
        if hTop == 0 { hTop = ref.rowHeight }
        if hBot == 0 { hBot = ref.rowHeight }
        let gap = ref.fontPx * 0.3
        let topY = centerTop - gap / 2 - hTop / 2
        let botY = centerTop + gap / 2 + hBot / 2
        for i in visible {
            let L = lines[i]
            let y = L.slot == 0 ? topY : botY
            drawLine(ctx, mainLayout(i), centerTop: y, alpha: fade(t, L.appear, L.hide), state: wordStates(i, t))
            if L.blockStart { drawCountdown(ctx, t, line: i, aboveTop: topY - hTop / 2) }
        }
    }

    private func drawLine(_ ctx: CGContext, _ lay: LineLayout, centerTop: CGFloat, alpha: CGFloat, state: (Int) -> WordState) {
        guard alpha > 0.001 else { return }
        let H = size.height, W = size.width
        ctx.saveGState()
        ctx.setAlpha(alpha)
        if style.shadow {
            ctx.setShadow(offset: CGSize(width: 0, height: -4 * s), blur: 16 * s,
                          color: CGColor(colorSpace: srgb, components: [0, 0, 0, 0.6]))
        }
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        let outline = CGFloat(style.outlineWidth) * lay.fontPx / CGFloat(max(1, style.fontSize))
        let top = centerTop - lay.height / 2
        for (ri, row) in lay.rows.enumerated() {
            let rowCenter = top + lay.rowHeight * (CGFloat(ri) + 0.5)
            let baselineTop = rowCenter + (lay.ascent - lay.descent) / 2
            let baseline = H - baselineTop
            let x0 = (W - lay.rowWidths[ri]) / 2
            for item in row {
                drawWord(ctx, lay.glyphs[item.idx], lay, x: x0 + item.x, baseline: baseline,
                         outline: outline, st: state(item.idx))
            }
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    private func drawWord(_ ctx: CGContext, _ g: GlyphWord, _ lay: LineLayout, x: CGFloat, baseline: CGFloat, outline: CGFloat, st: WordState) {
        ctx.saveGState()
        ctx.translateBy(x: x, y: baseline)
        if st.scale != 1 {
            let cx = g.width / 2, cy = (lay.ascent - lay.descent) / 2
            ctx.translateBy(x: cx, y: cy)
            ctx.scaleBy(x: st.scale, y: st.scale)
            ctx.translateBy(x: -cx, y: -cy)
        }
        if outline > 0.1 {
            ctx.addPath(g.path)
            ctx.setLineWidth(outline * 2)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(style.outlineColor.cgColor)
            ctx.strokePath()
        }
        ctx.addPath(g.path)
        ctx.setFillColor(st.base.cgColor)
        ctx.fillPath()
        if st.progress > 0 {
            ctx.saveGState()
            if st.progress < 1 {
                ctx.clip(to: CGRect(x: -outline - 2, y: -lay.fontPx,
                                    width: outline + 2 + g.width * st.progress, height: lay.fontPx * 3))
            }
            ctx.addPath(g.path)
            ctx.setFillColor(style.highlightColor.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    private func drawCountdown(_ ctx: CGContext, _ t: Double, line i: Int, aboveTop: CGFloat) {
        guard style.showCountdown else { return }
        let first = lines[i].first
        guard t < first, first - t <= 3 else { return }
        // conta alla rovescia solo dopo una pausa (inizio canzone o dopo ≥4 s di silenzio)
        if i > 0 {
            guard first - lines[i - 1].lastEnd >= 3 else { return }
        } else {
            guard first >= 1 else { return }
        }
        let count = Int(ceil(first - t))
        let r = 11 * s, gap = 38 * s
        let cy = size.height - (aboveTop - 36 * s)
        let x0 = size.width / 2 - gap
        for k in 0..<3 {
            let on = k < count
            let c = style.highlightColor.withAlpha(on ? 1 : 0.22)
            let rect = CGRect(x: x0 + CGFloat(k) * gap - r, y: cy - r, width: 2 * r, height: 2 * r)
            ctx.setFillColor(c.cgColor)
            ctx.fillEllipse(in: rect)
            if on && style.outlineWidth > 0 {
                ctx.setStrokeColor(style.outlineColor.cgColor)
                ctx.setLineWidth(2 * s)
                ctx.strokeEllipse(in: rect)
            }
        }
    }

    private func drawTitle(_ ctx: CGContext, t: Double, centerTop: CGFloat, until: Double) {
        guard style.showTitle else { return }
        let tt = title.trimmingCharacters(in: .whitespaces)
        let ar = artist.trimmingCharacters(in: .whitespaces)
        guard !tt.isEmpty || !ar.isEmpty else { return }
        guard until > 1.5, t < until - 0.2 else { return }
        let a = fade(t, -1, until - 0.2, 0.6)
        var y = centerTop
        if !tt.isEmpty {
            let lay = layout("title", tt.split(separator: " ").map(String.init), scale: 1.05)
            let hl = style.highlightColor
            y -= ar.isEmpty ? 0 : lay.height * 0.35
            drawLine(ctx, lay, centerTop: y, alpha: a, state: { _ in WordState(base: hl) })
            y += lay.height / 2
        }
        if !ar.isEmpty {
            let lay = layout("artist", ar.split(separator: " ").map(String.init), scale: 0.6)
            let col = style.textColor
            drawLine(ctx, lay, centerTop: y + lay.height * 0.75, alpha: a, state: { _ in WordState(base: col) })
        }
    }

    // MARK: Sfondo

    private func drawBG(_ ctx: CGContext, _ t: Double) {
        let W = size.width, H = size.height
        let full = CGRect(x: 0, y: 0, width: W, height: H)
        switch style.background {
        case .transparent:
            return
        case .solid:
            ctx.setFillColor(style.bgColor1.cgColor)
            ctx.fill(full)
        case .image:
            ctx.setFillColor(CGColor(colorSpace: srgb, components: [0, 0, 0, 1])!)
            ctx.fill(full)
            if let img = bgImage {
                let iw = CGFloat(img.width), ih = CGFloat(img.height)
                let k = max(W / iw, H / ih)
                let r = CGRect(x: (W - iw * k) / 2, y: (H - ih * k) / 2, width: iw * k, height: ih * k)
                ctx.draw(img, in: r)
                ctx.setFillColor(CGColor(colorSpace: srgb, components: [0, 0, 0, CGFloat(style.bgDim)])!)
                ctx.fill(full)
            }
        case .gradient:
            let c1 = style.bgColor1, c2 = style.bgColor2
            let mid = c1.mixed(with: c2, 0.5).mixed(with: RGBA.white, 0.06)
            let sv = sin(t * 0.15) * 0.5 + 0.5
            let loc: [CGFloat] = [0, CGFloat(0.5 + 0.3 * (sv - 0.5)), 1]
            if let g = CGGradient(colorsSpace: srgb, colors: [c1.cgColor, mid.cgColor, c2.cgColor] as CFArray, locations: loc) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            let R = max(W, H) * 0.55
            glow(ctx, center: CGPoint(x: W * CGFloat(0.5 + 0.3 * sin(t * 0.11)), y: H * CGFloat(0.5 + 0.25 * cos(t * 0.08))),
                 radius: R, color: style.highlightColor.withAlpha(0.09))
            glow(ctx, center: CGPoint(x: W * CGFloat(0.5 + 0.32 * cos(t * 0.07 + 1)), y: H * CGFloat(0.5 + 0.25 * sin(t * 0.09 + 2))),
                 radius: R, color: c2.mixed(with: RGBA.white, 0.35).withAlpha(0.13))
        }
    }

    private func glow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: RGBA) {
        guard let g = CGGradient(colorsSpace: srgb, colors: [color.cgColor, color.withAlpha(0).cgColor] as CFArray, locations: [0, 1]) else { return }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
}
