import AppKit
import AVFoundation

// Test mode: `Said --file clip.wav` transcribes (and tidies) a recording and
// prints the result with timings, without the menu bar or the Fn key.
if let i = CommandLine.arguments.firstIndex(of: "--file"), i + 1 < CommandLine.arguments.count {
    let url = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    guard format.sampleRate == Recorder.sampleRate, format.channelCount == 1,
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))
    else { print("Needs a 16 kHz mono file"); exit(1) }
    try file.read(into: buffer)
    let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))

    let transcriber = Transcriber()
    let modelPath = CommandLine.arguments.firstIndex(of: "--model").flatMap { Transcriber.modelPath(name: CommandLine.arguments[$0 + 1]) }
    guard let path = modelPath ?? Transcriber.defaultModelPath(), transcriber.load(path: path) else { print("No model"); exit(1) }
    let vocabulary = Vocabulary.load()
    let raw: String
    if CommandLine.arguments.contains("--live") {
        // Feed the file in at real speed, as the mic would, then time the wait after "release".
        let queue = DispatchQueue(label: "whisper")
        let lock = NSLock()
        var heard = 0
        let session = LiveSession(transcriber: transcriber, queue: queue, vocabulary: vocabulary) { from in
            lock.withLock { from < heard ? Array(samples[from..<heard]) : [] }
        }
        session.start()
        let step = 1_600
        while lock.withLock({ heard }) < samples.count {
            usleep(100_000)
            lock.withLock { heard = min(samples.count, heard + step) }
        }
        let released = Date()
        let (result, chunks) = await withCheckedContinuation { done in
            session.finish(all: samples) { text, n in done.resume(returning: (text, n)) }
        }
        raw = result
        print(String(format: "speech %.2f s after release, %d chunks: %@", Date().timeIntervalSince(released), chunks, raw))
    } else {
        let t0 = Date()
        raw = transcriber.transcribe(samples, vocabulary: vocabulary)
        print(String(format: "speech %.2f s: %@", Date().timeIntervalSince(t0), raw))
    }
    if let key = Tidier.apiKey() {
        let t1 = Date()
        let tidied = try await Tidier().tidy(raw, apiKey: key, vocabulary: vocabulary)
        print(String(format: "tidy   %.2f s: %@", Date().timeIntervalSince(t1), tidied))
    } else {
        print("tidy   skipped, no API key in Keychain")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
