import AVFoundation

/// Records the default microphone and converts it on the fly to what whisper
/// expects: 16 kHz, mono, 32-bit float samples.
final class Recorder {
    static let sampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private(set) var isRecording = false

    func start() throws {
        guard !isRecording else { return }
        lock.withLock { samples.removeAll(keepingCapacity: true) }

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Recorder.sampleRate,
                                             channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inFormat, to: outFormat)
        else { throw RecorderError.noConverter }

        let ratio = Recorder.sampleRate / inFormat.sampleRate
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
            guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
            var handedOver = false
            var error: NSError?
            converter.convert(to: out, error: &error) { _, status in
                if handedOver { status.pointee = .noDataNow; return nil }
                handedOver = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, let channel = out.floatChannelData?[0] else { return }
            let chunk = UnsafeBufferPointer(start: channel, count: Int(out.frameLength))
            self.lock.withLock { self.samples.append(contentsOf: chunk) }
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// The audio recorded so far, from sample `index` on. Safe to call while recording.
    func samples(from index: Int) -> [Float] {
        lock.withLock { index < samples.count ? Array(samples[index...]) : [] }
    }

    /// How loud the last `seconds` of audio were (root mean square), for the on-screen bars.
    func recentLevel(seconds: Double = 0.1) -> Float {
        lock.withLock {
            let n = min(samples.count, Int(seconds * Recorder.sampleRate))
            guard n > 0 else { return 0 }
            return Speech.rms(Array(samples.suffix(n)))
        }
    }

    /// Stops the mic and returns everything recorded since `start()`.
    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        return lock.withLock { samples }
    }

    enum RecorderError: Error { case noConverter }
}
