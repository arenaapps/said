import AVFoundation

/// Keeps the most recent dictation as a WAV file on this Mac only, replaced on
/// every dictation, so a bad transcript can be replayed through other models.
enum LastRecording {
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Said/last-recording.wav")
    }

    static func save(_ samples: [Float]) {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Recorder.sampleRate,
                                         channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: Recorder.sampleRate,
                                       AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                                       AVLinearPCMIsFloatKey: false]
        guard let file = try? AVAudioFile(forWriting: url, settings: settings,
                                          commonFormat: .pcmFormatFloat32, interleaved: false) else { return }
        try? file.write(from: buffer)
    }
}
