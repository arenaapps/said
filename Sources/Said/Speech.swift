import Foundation

/// Small pure helpers, kept separate so they can be tested.
enum Speech {
    /// Shortest hold that counts as a dictation rather than a tap of Fn.
    static let minimumSeconds = 0.3

    /// Whisper invents text ("Thank you.", "you") when given silence, so very
    /// quiet recordings are skipped instead of transcribed.
    static let silenceRMS: Float = 0.004

    static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    static func isSilent(_ samples: [Float]) -> Bool {
        rms(samples) < silenceRMS
    }

    /// Removes whisper's non-speech markers such as [BLANK_AUDIO] or (music),
    /// and tidies the spacing.
    static func tidyTranscript(_ text: String) -> String {
        let withoutMarkers = text.replacingOccurrences(
            of: #"\[[^\]]*\]|\([^)]*\)"#, with: " ", options: .regularExpression)
        return withoutMarkers
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
