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

    /// Turns a loudness into a bar height from 0 to 1. Normal speech sits around
    /// 0.02-0.08, so that range fills most of the bar; background noise stays flat.
    static func barLevel(_ rms: Float) -> Double {
        guard rms > silenceRMS else { return 0 }
        return min(1, pow(Double(rms) / 0.06, 0.7))
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
