import Foundation

/// Names and words Said should get right, one per line in
/// ~/Library/Application Support/Said/vocabulary.txt. Whisper gets them as a
/// hint before it listens, and Claude uses them to fix near-misses.
enum Vocabulary {
    /// Written the first time, as a guide. Lines starting with # are ignored.
    static let starter = """
    # One name or word per line, spelled the way you want it written.
    # For example: people you mention, your company, product names.
    Claude
    """

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Said/vocabulary.txt")
    }

    /// Creates the file with the starter list the first time.
    static func load() -> [String] {
        let url = fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? (starter + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
        return parse((try? String(contentsOf: url, encoding: .utf8)) ?? "")
    }

    static func parse(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Whisper treats this as text that came just before, which nudges it towards these spellings.
    static func whisperHint(_ words: [String]) -> String? {
        words.isEmpty ? nil : "Names and terms: " + words.joined(separator: ", ") + "."
    }
}
