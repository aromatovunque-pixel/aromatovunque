import Foundation
import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Verifica automatica: carica un progetto, disegna fotogrammi ed esporta video in tutti i formati.
enum SelfTest {
    @MainActor
    static func run(projectPath: String, outDir: String) async -> Bool {
        let out = URL(fileURLWithPath: outDir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var failures = 0
        func check(_ ok: Bool, _ msg: String) {
            print((ok ? "OK   " : "FAIL ") + msg)
            if !ok { failures += 1 }
        }

        // 1. progetto della versione web
        guard let data = FileManager.default.contents(atPath: projectPath),
              var project = try? KaraokeProject.load(from: data) else {
            print("FAIL impossibile leggere \(projectPath)")
            return false
        }
        check(project.lines.count > 10, "progetto web importato: \(project.lines.count) righe, \(project.timedCount)/\(project.wordCount) parole")

        // ricodifica e rilettura
        if let enc = try? project.encoded(), let back = try? KaraokeProject.load(from: enc) {
            check(back == project, "salvataggio/riapertura del progetto identici")
        } else { check(false, "codifica progetto") }

        // testo modificato: i tempi delle righe uguali restano
        let merged = LyricsParser.merge(newText: project.lyrics + "\n\nRiga nuova di prova", old: project.lines)
        check(merged.count == project.lines.count + 1 && merged[0].words == project.lines[0].words && merged.last!.words.allSatisfy { $0.t == nil },
              "unione testo mantiene i tempi")

        // accorcia: prime 5 righe, spostate a partire da ~2 s
        let shift = (project.lines.first?.words.first?.t ?? 0) - 2.5
        project.lines = Array(project.lines.prefix(5)).map { l in
            var l = l
            l.words = l.words.map { KWord(w: $0.w, t: $0.t.map { $0 - shift }) }
            return l
        }
        project.title = "Culla Baby Star"
        project.artist = "Prova automatica"
        let lastT = project.lines.last!.words.last!.t!
        let duration = lastT + 3

        // 2. audio di prova
        let audioURL = out.appendingPathComponent("test-audio.caf")
        do {
            try makeTone(url: audioURL, seconds: duration)
            check(true, "audio di prova creato (\(String(format: "%.1f", duration)) s)")
        } catch {
            check(false, "audio di prova: \(error)")
            return false
        }
        project.vocalAudio = AudioRef(path: audioURL.path)

        if let w = await WaveformLoader.load(audioURL) {
            check(w.peaks.count > Int(duration * 90), "forma d'onda: \(w.peaks.count) campioni")
        } else { check(false, "forma d'onda") }

        // 3. fotogrammi
        let lrc = LRCExporter.make(project)
        check(lrc.contains("<00:02."), "LRC generato")
        try? lrc.write(to: out.appendingPathComponent("test.lrc"), atomically: true, encoding: .utf8)

        let l1 = project.lines[1]
        let midWord = (l1.words[2].t! + l1.words[3].t!) / 2
        let times: [(String, Double)] = [("intro", 0.4), ("countdown", 1.2), ("riga2-meta", midWord), ("fine", lastT + 0.3)]
        let variants: [(String, (inout KaraokeStyle) -> Void, VideoResolution)] = [
            ("scorrimento", { _ in }, .fhd),
            ("parola", { $0.highlightMode = .word }, .fhd),
            ("alternate", { $0.layout = .alternating; $0.background = .solid; $0.bgColor1 = RGBA(0.1, 0.1, 0.1) }, .fhd),
            ("verticale", { $0.uppercase = true }, .vertical)
        ]
        for (name, mod, res) in variants {
            var p = project
            mod(&p.style)
            let r = KaraokeRenderer(project: p, size: res.size)
            check(r.lines.count == 5, "piano \(name): \(r.lines.count) righe")
            for (tn, t) in times {
                let url = out.appendingPathComponent("frame-\(name)-\(tn).png")
                let ok = renderPNG(r, time: t, url: url, background: true)
                check(ok, "fotogramma \(name) \(tn)")
            }
        }

        // 4. esportazioni
        for format in VideoFormat.allCases {
            var p = project
            p.export.format = format
            p.export.resolution = .fhd
            p.export.fps = 30
            let url = out.appendingPathComponent("export-\(format.rawValue).\(format.fileExtension)")
            let exporter = VideoExporter()
            let renderer = KaraokeRenderer(project: p, size: p.export.resolution.size)
            let start = Date()
            do {
                let ok = try await exporter.run(renderer: renderer, settings: p.export, audioURL: audioURL, outURL: url)
                let secs = Date().timeIntervalSince(start)
                check(ok, "esportazione \(format.rawValue) in \(String(format: "%.1f", secs)) s (video di \(String(format: "%.1f", duration)) s)")
                await verify(url: url, format: format, duration: duration, frameTime: midWord, out: out, check: check)
            } catch {
                check(false, "esportazione \(format.rawValue): \(error.localizedDescription)")
            }
        }

        print(failures == 0 ? "SELFTEST SUPERATO" : "SELFTEST FALLITO: \(failures) errori")
        return failures == 0
    }

    private static func verify(url: URL, format: VideoFormat, duration: Double, frameTime: Double, out: URL,
                               check: (Bool, String) -> Void) async {
        let asset = AVURLAsset(url: url)
        do {
            let v = try await asset.loadTracks(withMediaType: .video)
            let a = try await asset.loadTracks(withMediaType: .audio)
            let d = try await asset.load(.duration).seconds
            check(v.count == 1 && a.count == 1, "\(format.rawValue): 1 traccia video + 1 audio")
            check(abs(d - duration) < 0.5, "\(format.rawValue): durata \(String(format: "%.2f", d)) s")
            if let vt = v.first {
                let sz = try await vt.load(.naturalSize)
                check(sz == CGSize(width: 1920, height: 1080), "\(format.rawValue): risoluzione \(Int(sz.width))×\(Int(sz.height))")
                let fps = try await vt.load(.nominalFrameRate)
                check(abs(fps - 30) < 0.5, "\(format.rawValue): \(fps) fps")
            }
            let gen = AVAssetImageGenerator(asset: asset)
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = .zero
            let (img, _) = try await gen.image(at: CMTime(seconds: frameTime, preferredTimescale: 600))
            savePNG(img, out.appendingPathComponent("decoded-\(format.rawValue).png"))
            // trasparenza: angolo in alto a sinistra
            let corner = alphaAt(img, x: 5, y: 5)
            let center = maxAlphaInCenterRow(img)
            if format.hasAlpha {
                check(corner < 10, "\(format.rawValue): angolo trasparente (alfa \(corner))")
                check(center > 200, "\(format.rawValue): testo opaco (alfa max \(center))")
            } else {
                check(corner > 245, "\(format.rawValue): sfondo opaco (alfa \(corner))")
            }
        } catch {
            check(false, "\(format.rawValue): verifica fallita \(error.localizedDescription)")
        }
    }

    private static func pixels(_ img: CGImage) -> (Data, Int)? {
        let w = img.width, h = img.height
        var data = Data(count: w * h * 4)
        let ok = data.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (data, w) : nil
    }

    private static func alphaAt(_ img: CGImage, x: Int, y: Int) -> Int {
        guard let (d, w) = pixels(img) else { return -1 }
        return Int(d[(y * w + x) * 4 + 3])
    }

    private static func maxAlphaInCenterRow(_ img: CGImage) -> Int {
        guard let (d, w) = pixels(img) else { return -1 }
        var m = 0
        for y in stride(from: img.height / 3, to: img.height * 2 / 3, by: 4) {
            for x in stride(from: 0, to: w, by: 4) { m = max(m, Int(d[(y * w + x) * 4 + 3])) }
        }
        return m
    }

    private static func renderPNG(_ r: KaraokeRenderer, time: Double, url: URL, background: Bool) -> Bool {
        let w = Int(r.size.width), h = Int(r.size.height)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return false }
        r.render(in: ctx, time: time, drawBackground: background)
        guard let img = ctx.makeImage() else { return false }
        return savePNG(img, url)
    }

    @discardableResult
    private static func savePNG(_ img: CGImage, _ url: URL) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, img, nil)
        return CGImageDestinationFinalize(dest)
    }

    private static func makeTone(url: URL, seconds: Double) throws {
        try? FileManager.default.removeItem(at: url)
        let sr = 44100.0
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        let n = AVAudioFrameCount(sr * seconds)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!
        buf.frameLength = n
        let p = buf.floatChannelData![0]
        for i in 0..<Int(n) {
            let t = Double(i) / sr
            let env = 0.5 + 0.5 * sin(2 * .pi * 0.5 * t)
            p[i] = Float(0.3 * env * sin(2 * .pi * 220 * t))
        }
        try file.write(from: buf)
    }
}
