import Foundation

/// Decides where to cut audio that is still being recorded, so whisper can
/// transcribe the first part while the speaker carries on. It cuts in the
/// middle of a pause so no word is split in half.
enum Chunker {
    static let minChunk = 6.0      // don't bother transcribing less than this early
    static let maxChunk = 20.0     // cut somewhere even without a clear pause
    static let earliestCut = 3.0   // keep chunks long enough to have context
    static let tailGuard = 0.5     // never cut right at the newest audio
    static let frame = 0.03
    static let minPause = 0.3

    /// Returns the sample index to cut at, or nil to keep waiting.
    static func cutPoint(_ samples: [Float], rate: Double = 16_000) -> Int? {
        let n = samples.count
        guard Double(n) >= minChunk * rate else { return nil }
        let size = Int(frame * rate)
        let count = n / size
        var levels = [Float](repeating: 0, count: count)
        samples.withUnsafeBufferPointer { buf in
            for i in 0..<count {
                var sum: Float = 0
                for j in (i * size)..<((i + 1) * size) { sum += buf[j] * buf[j] }
                levels[i] = (sum / Float(size)).squareRoot()
            }
        }
        let mean = levels.reduce(0, +) / Float(max(1, count))
        let quiet = min(0.02, max(0.002, mean * 0.3))
        let needed = Int(minPause / frame)
        let first = Int(earliestCut / frame)
        let last = count - Int(tailGuard / frame)
        guard last > first else { return nil }

        // The latest pause long enough to count.
        var best: Int?
        var run = 0
        for i in 0..<last {
            if levels[i] < quiet {
                run += 1
                let middle = i - run / 2
                if run >= needed && middle >= first { best = middle }
            } else {
                run = 0
            }
        }
        if let best { return best * size + size / 2 }

        // No pause in a long stretch: cut at the quietest moment after 10 s.
        guard Double(n) >= maxChunk * rate else { return nil }
        let start = min(Int(10.0 / frame), last - 1)
        var quietest = start
        for i in start..<last where levels[i] < levels[quietest] { quietest = i }
        return quietest * size + size / 2
    }
}
