import Foundation
import AVFoundation
import CoreVideo
import CoreGraphics

final class VideoExporter: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case done(URL)
        case failed(String)
        case cancelled
    }

    @Published var state: State = .idle
    @Published var progress: Double = 0
    @Published var speedInfo: String = ""

    private let cancelLock = NSLock()
    private var _cancelled = false
    private var cancelled: Bool {
        get { cancelLock.lock(); defer { cancelLock.unlock() }; return _cancelled }
        set { cancelLock.lock(); _cancelled = newValue; cancelLock.unlock() }
    }

    var isRunning: Bool { state == .running }

    func cancel() { cancelled = true }

    func start(project: KaraokeProject, audioURL: URL?, outURL: URL) {
        guard !isRunning else { return }
        let settings = project.export
        let renderer = KaraokeRenderer(project: project, size: settings.resolution.size)
        cancelled = false
        progress = 0
        speedInfo = ""
        state = .running
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let ok = try await self.run(renderer: renderer, settings: settings,
                                            audioURL: settings.includeAudio ? audioURL : nil, outURL: outURL)
                await MainActor.run { self.state = ok ? .done(outURL) : .cancelled }
            } catch {
                try? FileManager.default.removeItem(at: outURL)
                await MainActor.run { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    private struct ExportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private func videoSettings(_ s: ExportSettings) -> [String: Any] {
        let size = s.resolution.size
        let w = Int(size.width), h = Int(size.height)
        let pixelFactor = Double(w * h) / (1920.0 * 1080.0)
        let fpsFactor = Double(s.fps) / 30.0
        var out: [String: Any] = [
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]
        switch s.format {
        case .h264:
            out[AVVideoCodecKey] = AVVideoCodecType.h264
            out[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: Int(16_000_000 * pixelFactor * fpsFactor),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: s.fps * 2
            ] as [String: Any]
        case .hevc:
            out[AVVideoCodecKey] = AVVideoCodecType.hevc
            out[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: Int(10_000_000 * pixelFactor * fpsFactor),
                AVVideoMaxKeyFrameIntervalKey: s.fps * 2
            ] as [String: Any]
        case .prores422:
            out[AVVideoCodecKey] = AVVideoCodecType.proRes422HQ
        case .prores4444Alpha:
            out[AVVideoCodecKey] = AVVideoCodecType.proRes4444
        case .hevcAlpha:
            out[AVVideoCodecKey] = AVVideoCodecType.hevcWithAlpha
            out[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: Int(14_000_000 * pixelFactor * fpsFactor)
            ] as [String: Any]
        }
        return out
    }

    private static func stereoLayoutData() -> Data {
        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        return Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
    }

    /// Ritorna false se annullato.
    func run(renderer: KaraokeRenderer, settings: ExportSettings, audioURL: URL?, outURL: URL) async throws -> Bool {
        try? FileManager.default.removeItem(at: outURL)
        let fileType: AVFileType = settings.format.fileExtension == "mp4" ? .mp4 : .mov
        let writer = try AVAssetWriter(outputURL: outURL, fileType: fileType)

        let vin = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings(settings))
        vin.expectsMediaDataInRealTime = false
        let size = settings.resolution.size
        let W = Int(size.width), H = Int(size.height)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: W,
            kCVPixelBufferHeightKey as String: H,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(vin) else { throw ExportError(message: "Formato video non supportato su questo Mac.") }
        writer.add(vin)

        var duration = renderer.contentDuration
        var reader: AVAssetReader?
        var aout: AVAssetReaderTrackOutput?
        var ain: AVAssetWriterInput?

        if let audioURL {
            let asset = AVURLAsset(url: audioURL)
            let d = try await asset.load(.duration).seconds
            if d.isFinite && d > 0 { duration = d }
            if let track = try await asset.loadTracks(withMediaType: .audio).first {
                let r = try AVAssetReader(asset: asset)
                let o = AVAssetReaderTrackOutput(track: track, outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 2,
                    AVChannelLayoutKey: Self.stereoLayoutData(),
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ])
                o.alwaysCopiesSampleData = false
                if r.canAdd(o) { r.add(o) }
                let i = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 2,
                    AVChannelLayoutKey: Self.stereoLayoutData(),
                    AVEncoderBitRateKey: 256_000
                ])
                i.expectsMediaDataInRealTime = false
                if writer.canAdd(i) {
                    writer.add(i)
                    reader = r; aout = o; ain = i
                }
            }
        }

        guard writer.startWriting() else {
            throw ExportError(message: writer.error?.localizedDescription ?? "Impossibile iniziare la scrittura del video.")
        }
        writer.startSession(atSourceTime: .zero)
        if let reader, !reader.startReading() {
            throw ExportError(message: reader.error?.localizedDescription ?? "Impossibile leggere l'audio.")
        }

        let fps = settings.fps
        let total = max(1, Int(ceil(duration * Double(fps))))
        let alpha = settings.format.hasAlpha
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let startDate = Date()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            let vq = DispatchQueue(label: "karaoke.video")
            let aq = DispatchQueue(label: "karaoke.audio")

            group.enter()
            var frame = 0
            var videoDone = false
            vin.requestMediaDataWhenReady(on: vq) { [weak self] in
                guard !videoDone else { return }
                while vin.isReadyForMoreMediaData {
                    if (self?.cancelled ?? true) || frame >= total || writer.status != .writing {
                        videoDone = true
                        vin.markAsFinished()
                        group.leave()
                        return
                    }
                    var ok = false
                    autoreleasepool {
                        var pbOut: CVPixelBuffer?
                        if let pool = adaptor.pixelBufferPool {
                            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
                        }
                        if pbOut == nil {
                            CVPixelBufferCreate(nil, W, H, kCVPixelFormatType_32BGRA, [
                                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
                            ] as CFDictionary, &pbOut)
                        }
                        guard let pb = pbOut else { return }
                        CVPixelBufferLockBaseAddress(pb, [])
                        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H,
                                               bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                               space: srgb,
                                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                            let full = CGRect(x: 0, y: 0, width: W, height: H)
                            ctx.clear(full)
                            if !alpha {
                                ctx.setFillColor(CGColor(colorSpace: srgb, components: [0, 0, 0, 1])!)
                                ctx.fill(full)
                            }
                            renderer.render(in: ctx, time: Double(frame) / Double(fps), drawBackground: !alpha)
                        }
                        CVPixelBufferUnlockBaseAddress(pb, [])
                        ok = adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps)))
                    }
                    if !ok {
                        videoDone = true
                        vin.markAsFinished()
                        group.leave()
                        return
                    }
                    frame += 1
                    if frame % 15 == 0 || frame == total {
                        let p = Double(frame) / Double(total)
                        let elapsed = Date().timeIntervalSince(startDate)
                        let speed = elapsed > 0 ? (Double(frame) / Double(fps)) / elapsed : 0
                        let remaining = speed > 0 ? (Double(total - frame) / Double(fps)) / speed : 0
                        DispatchQueue.main.async {
                            self?.progress = p
                            self?.speedInfo = String(format: "%.1f× tempo reale · circa %@ alla fine", speed, formatTime(remaining))
                        }
                    }
                }
            }

            if let ain, let aout {
                group.enter()
                var audioDone = false
                ain.requestMediaDataWhenReady(on: aq) { [weak self] in
                    guard !audioDone else { return }
                    while ain.isReadyForMoreMediaData {
                        if (self?.cancelled ?? true) || writer.status != .writing {
                            audioDone = true; ain.markAsFinished(); group.leave(); return
                        }
                        if let sb = aout.copyNextSampleBuffer() {
                            if !ain.append(sb) {
                                audioDone = true; ain.markAsFinished(); group.leave(); return
                            }
                        } else {
                            audioDone = true; ain.markAsFinished(); group.leave(); return
                        }
                    }
                }
            }

            group.notify(queue: .global()) { cont.resume() }
        }

        if cancelled {
            reader?.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outURL)
            return false
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }
        if writer.status != .completed {
            throw ExportError(message: writer.error?.localizedDescription ?? "Esportazione non riuscita.")
        }
        await MainActor.run { self.progress = 1 }
        return true
    }
}
