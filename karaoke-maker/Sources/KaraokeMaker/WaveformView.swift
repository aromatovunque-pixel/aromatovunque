import SwiftUI

struct WordMarker: Identifiable {
    let ref: WordRef
    let t: Double
    let label: String
    var id: WordRef { ref }
}

/// Forma d'onda ingrandita che segue la riproduzione, con i marcatori delle parole trascinabili.
struct WaveformView: View {
    let data: WaveformData?
    @ObservedObject var clock: Clock
    let duration: Double
    let markers: [WordMarker]
    let selected: WordRef?
    var window: Double = 8
    var onSeek: (Double) -> Void
    var onSelect: (WordRef) -> Void
    var onDragBegan: () -> Void
    var onDragMarker: (WordRef, Double) -> Void
    var onDragEnded: () -> Void

    @State private var dragging: (ref: WordRef, t0: Double)?
    @State private var isScrubbing = false
    @State private var frozenStart: Double?

    private func viewStart(_ t: Double) -> Double {
        if let f = frozenStart { return f }
        let s = t - window * 0.35
        return max(0, min(s, max(0, duration - window)))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let start = viewStart(clock.time)
            let pps = w / window
            Canvas { ctx, size in
                // sfondo
                ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                         with: .color(Color.black.opacity(0.35)))
                // griglia dei secondi
                var sec = floor(start)
                while sec < start + window {
                    let x = (sec - start) * pps
                    var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
                    ctx.stroke(p, with: .color(.white.opacity(0.06)))
                    ctx.draw(Text(formatTime(sec)).font(.system(size: 9).monospacedDigit()).foregroundColor(.white.opacity(0.35)),
                             at: CGPoint(x: x + 3, y: h - 3), anchor: .bottomLeading)
                    sec += 1
                }
                // onda
                if let d = data, !d.peaks.isEmpty {
                    var path = Path()
                    let mid = h / 2
                    let step: CGFloat = 2
                    var x: CGFloat = 0
                    while x < w {
                        let t = start + Double(x) / pps
                        let i = Int(t * d.perSecond)
                        if i >= 0 && i < d.peaks.count {
                            let a = CGFloat(d.peaks[i]) * (h * 0.42)
                            path.addRect(CGRect(x: x, y: mid - a, width: step - 0.5, height: max(1, a * 2)))
                        }
                        x += step
                    }
                    ctx.fill(path, with: .color(Color(red: 0.45, green: 0.6, blue: 1).opacity(0.75)))
                }
                // marcatori
                for m in markers where m.t >= start - 1 && m.t <= start + window {
                    let x = (m.t - start) * pps
                    let isSel = m.ref == selected
                    let col: Color = isSel ? .yellow : Color.white.opacity(0.75)
                    var p = Path(); p.move(to: CGPoint(x: x, y: 14)); p.addLine(to: CGPoint(x: x, y: h))
                    ctx.stroke(p, with: .color(col), lineWidth: isSel ? 2 : 1)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 4, y: 10, width: 8, height: 8)), with: .color(col))
                    ctx.draw(Text(m.label).font(.system(size: 11, weight: isSel ? .bold : .regular)).foregroundColor(col),
                             at: CGPoint(x: x + 5, y: 2), anchor: .topLeading)
                }
                // testina
                let px = (clock.time - start) * pps
                var ph = Path(); ph.move(to: CGPoint(x: px, y: 0)); ph.addLine(to: CGPoint(x: px, y: h))
                ctx.stroke(ph, with: .color(.red), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let st = viewStart(clock.time)
                        if dragging == nil && !isScrubbing {
                            // cerca un marcatore vicino al punto di partenza
                            let x0 = g.startLocation.x
                            var best: WordMarker?
                            var bd: CGFloat = 8
                            for m in markers {
                                let d = abs((m.t - st) * pps - x0)
                                if d < bd { bd = d; best = m }
                            }
                            if let b = best {
                                frozenStart = st
                                dragging = (b.ref, b.t)
                                onSelect(b.ref)
                                onDragBegan()
                            } else {
                                isScrubbing = true
                            }
                        }
                        if let d = dragging {
                            let nt = max(0, d.t0 + Double(g.translation.width) / pps)
                            onDragMarker(d.ref, nt)
                        } else if isScrubbing {
                            let st2 = viewStart(clock.time)
                            onSeek(st2 + Double(g.location.x) / pps)
                        }
                    }
                    .onEnded { _ in
                        if dragging != nil { onDragEnded() }
                        dragging = nil
                        isScrubbing = false
                        frozenStart = nil
                    }
            )
        }
    }
}

/// Panoramica dell'intera canzone: clic per spostarsi.
struct OverviewView: View {
    let data: WaveformData?
    @ObservedObject var clock: Clock
    let duration: Double
    let markers: [WordMarker]
    var onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let dur = max(duration, 0.1)
            Canvas { ctx, size in
                ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 5), with: .color(Color.black.opacity(0.25)))
                if let d = data, !d.peaks.isEmpty {
                    var path = Path()
                    let n = Int(w / 2)
                    for k in 0..<max(1, n) {
                        let t0 = Double(k) / Double(n) * dur
                        let t1 = Double(k + 1) / Double(n) * dur
                        let i0 = Int(t0 * d.perSecond), i1 = min(d.peaks.count, max(i0 + 1, Int(t1 * d.perSecond)))
                        guard i0 < d.peaks.count else { break }
                        var mx: Float = 0
                        for i in i0..<i1 { mx = max(mx, d.peaks[i]) }
                        let a = CGFloat(mx) * h * 0.45
                        path.addRect(CGRect(x: CGFloat(k) * 2, y: h / 2 - a, width: 1.5, height: max(0.5, a * 2)))
                    }
                    ctx.fill(path, with: .color(Color.gray.opacity(0.7)))
                }
                var mp = Path()
                for m in markers {
                    let x = m.t / dur * w
                    mp.addRect(CGRect(x: x, y: h - 4, width: 1, height: 4))
                }
                ctx.fill(mp, with: .color(.yellow.opacity(0.8)))
                let px = clock.time / dur * w
                ctx.fill(Path(CGRect(x: px - 1, y: 0, width: 2, height: h)), with: .color(.red))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                onSeek(max(0, min(1, g.location.x / w)) * dur)
            })
        }
    }
}
