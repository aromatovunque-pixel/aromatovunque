import Foundation
import AVFoundation
import Combine

/// Orologio di riproduzione: pubblicato separatamente per non ridisegnare tutta l'interfaccia 60 volte al secondo.
final class Clock: ObservableObject {
    @Published var time: Double = 0
}

final class PlayerModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var url: URL?
    @Published private(set) var loadError: String?
    @Published var rate: Float = 1 {
        didSet { player?.rate = rate }
    }

    let clock = Clock()
    private var player: AVAudioPlayer?
    private var timer: Timer?

    override init() {
        super.init()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    deinit { timer?.invalidate() }

    var hasAudio: Bool { player != nil }
    var currentTime: Double { player?.currentTime ?? 0 }

    func load(_ newURL: URL?) {
        guard newURL != url else { return }
        player?.stop()
        player = nil
        isPlaying = false
        duration = 0
        loadError = nil
        clock.time = 0
        url = newURL
        guard let u = newURL else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: u)
            p.enableRate = true
            p.rate = rate
            p.delegate = self
            p.prepareToPlay()
            player = p
            duration = p.duration
        } catch {
            loadError = "Impossibile aprire l'audio: \(error.localizedDescription)"
        }
    }

    func play() {
        guard let p = player else { return }
        if p.currentTime >= p.duration - 0.05 { p.currentTime = 0 }
        p.rate = rate
        p.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
        tick()
    }

    func toggle() { isPlaying ? pause() : play() }

    func seek(_ t: Double) {
        guard let p = player else { return }
        p.currentTime = min(max(0, t), max(0, p.duration - 0.01))
        clock.time = p.currentTime
    }

    private func tick() {
        guard let p = player else { return }
        let t = p.currentTime
        if abs(clock.time - t) > 0.0005 { clock.time = t }
        if isPlaying && !p.isPlaying { isPlaying = false }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        clock.time = player.duration
    }
}

// MARK: - Forma d'onda

struct WaveformData {
    var peaks: [Float]
    var perSecond: Double
}

enum WaveformLoader {
    private static var cache: [URL: WaveformData] = [:]
    private static let lock = NSLock()

    static func load(_ url: URL) async -> WaveformData? {
        lock.lock()
        if let c = cache[url] { lock.unlock(); return c }
        lock.unlock()
        let result = await Task.detached(priority: .utility) { () -> WaveformData? in
            try? await compute(url)
        }.value
        if let r = result {
            lock.lock(); cache[url] = r; lock.unlock()
        }
        return result
    }

    private static func compute(_ url: URL) async throws -> WaveformData? {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let reader = try AVAssetReader(asset: asset)
        let sampleRate = 8000.0
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        out.alwaysCopiesSampleData = false
        reader.add(out)
        guard reader.startReading() else { return nil }
        let perSecond = 100.0
        let bucket = Int(sampleRate / perSecond)
        var peaks: [Float] = []
        var m: Float = 0
        var n = 0
        while let sb = out.copyNextSampleBuffer() {
            guard let bb = CMSampleBufferGetDataBuffer(sb) else { continue }
            let length = CMBlockBufferGetDataLength(bb)
            var data = [Float](repeating: 0, count: length / 4)
            data.withUnsafeMutableBytes { raw in
                _ = CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
            }
            for v in data {
                let a = abs(v)
                if a > m { m = a }
                n += 1
                if n == bucket { peaks.append(m); m = 0; n = 0 }
            }
        }
        if n > 0 { peaks.append(m) }
        let mx = peaks.max() ?? 1
        if mx > 0 { peaks = peaks.map { $0 / mx } }
        return WaveformData(peaks: peaks, perSecond: perSecond)
    }
}
