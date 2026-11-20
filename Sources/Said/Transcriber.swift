import CWhisper
import Foundation

/// Runs whisper.cpp on this Mac. The model is loaded once and kept in memory,
/// so each dictation only pays for the transcription itself.
final class Transcriber {
    private var ctx: OpaquePointer?

    var isLoaded: Bool { ctx != nil }

    /// Where Said looks for the model, in order.
    /// Small is the default: Base mis-heard real dictations (19 Nov 2026 test).
    static let preferredModels = ["ggml-small.en.bin", "ggml-base.en.bin"]

    static func defaultModelPath() -> String? {
        preferredModels.lazy.compactMap { modelPath(name: $0) }.first
    }

    static func modelPath(name: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var candidates = ["\(home)/Library/Application Support/Said/\(name)"]
        // SAID_APP_MODELS_ONLY=1 pretends the shared folder is empty, to test the first-run download.
        if ProcessInfo.processInfo.environment["SAID_APP_MODELS_ONLY"] == nil {
            candidates.append("\(home)/.local/whisper-models/\(name)")
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    func load(path: String) -> Bool {
        var params = whisper_context_default_params()
        #if arch(x86_64)
        // On Intel Macs the AMD graphics card gives wrong output and is slower
        // than the processor (measured 17 Nov 2026), so whisper stays on the CPU.
        params.use_gpu = false
        #endif
        ctx = whisper_init_from_file_with_params(path, params)
        return ctx != nil
    }

    /// Whisper normally encodes a fixed 30 s window, so short clips cost as much as long ones.
    /// Shrinking the window to the clip length makes short pieces much faster.
    var fitWindowToAudio = ProcessInfo.processInfo.environment["SAID_FULL_WINDOW"] == nil

    func transcribe(_ samples: [Float], vocabulary: [String] = [], context: String = "") -> String {
        guard let ctx, !samples.isEmpty else { return "" }
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.print_special = false
        params.no_timestamps = true
        params.suppress_blank = true
        if fitWindowToAudio {
            // 50 encoder frames per second of audio, plus a margin; 1500 is the full 30 s.
            let seconds = Double(samples.count) / 16_000
            params.audio_ctx = Int32(min(1500, Int(seconds * 50) + 128))
        }

        // whisper only borrows the hint, so it has to stay alive for the whole call.
        let prompt = [Vocabulary.whisperHint(vocabulary), context.isEmpty ? nil : context].compactMap { $0 }.joined(separator: " ")
        let hint = prompt.isEmpty ? nil : strdup(prompt)
        defer { free(hint) }
        params.initial_prompt = UnsafePointer(hint)
        let result = samples.withUnsafeBufferPointer { buffer in
            whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
        }
        guard result == 0 else { return "" }

        var text = ""
        for i in 0..<whisper_full_n_segments(ctx) {
            if let segment = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: segment)
            }
        }
        return Speech.tidyTranscript(text)
    }

    deinit {
        if let ctx { whisper_free(ctx) }
    }
}
