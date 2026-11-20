import Foundation

/// One dictation. While the mic is open it transcribes finished stretches of
/// speech in the background, so when the key is let go only the last few
/// seconds are left to do. Everything runs on the one whisper queue.
final class LiveSession {
    private let transcriber: Transcriber
    private let queue: DispatchQueue
    private let read: (Int) -> [Float]
    private let vocabulary: [String]
    private var timer: DispatchSourceTimer?
    private var cursor = 0
    private var text = ""
    private(set) var chunks = 0

    /// `read(i)` returns the audio recorded so far, starting at sample `i`.
    init(transcriber: Transcriber, queue: DispatchQueue, vocabulary: [String], read: @escaping (Int) -> [Float]) {
        self.transcriber = transcriber
        self.queue = queue
        self.vocabulary = vocabulary
        self.read = read
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 0.5)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    private func tick() {
        let pending = read(cursor)
        guard let cut = Chunker.cutPoint(pending) else { return }
        transcribe(Array(pending[..<cut]))
        cursor += cut
    }

    /// Call once the mic has stopped, with the whole recording. Waits for any
    /// chunk in progress, transcribes what is left, and hands back the text.
    func finish(all: [Float], completion: @escaping (_ text: String, _ chunks: Int) -> Void) {
        queue.async {
            self.timer?.cancel()
            let rest = Array(all[min(self.cursor, all.count)...])
            if Double(rest.count) >= 0.2 * 16_000, !Speech.isSilent(rest) { self.transcribe(rest) }
            completion(self.text, self.chunks)
        }
    }

    func cancel() {
        queue.async { self.timer?.cancel() }
    }

    private func transcribe(_ samples: [Float]) {
        let part = transcriber.transcribe(samples, vocabulary: vocabulary, context: String(text.suffix(200)))
        chunks += 1
        Trace.log(String(format: "chunk %d: %.1f s of audio", chunks, Double(samples.count) / 16_000))
        guard !part.isEmpty else { return }
        text = text.isEmpty ? part : text + " " + part
    }
}
