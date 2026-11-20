import XCTest
@testable import Said

final class SpeechTests: XCTestCase {
    func testRemovesWhisperMarkers() {
        XCTAssertEqual(Speech.tidyTranscript(" [BLANK_AUDIO] Hello (music)  there\n"), "Hello there")
    }

    func testSilenceIsSkipped() {
        XCTAssertTrue(Speech.isSilent([Float](repeating: 0.001, count: 16_000)))
        XCTAssertFalse(Speech.isSilent((0..<16_000).map { sin(Float($0) / 10) * 0.2 }))
        XCTAssertTrue(Speech.isSilent([]))
    }

    func testPromptKeepsHedges() {
        XCTAssertTrue(Tidier.systemPrompt.contains("I think"))
    }
}

final class VocabularyTests: XCTestCase {
    func testParsesOneTermPerLineAndSkipsComments() {
        XCTAssertEqual(Vocabulary.parse("O'Neill\n\n# people\n  Acme \n"), ["O'Neill", "Acme"])
    }

    func testHintsAndPromptIncludeTheWords() {
        XCTAssertEqual(Vocabulary.whisperHint(["O'Neill", "Kubernetes"]), "Names and terms: O'Neill, Kubernetes.")
        XCTAssertNil(Vocabulary.whisperHint([]))
        XCTAssertTrue(Tidier.prompt(vocabulary: ["O'Neill"]).contains("O'Neill"))
        XCTAssertEqual(Tidier.prompt(vocabulary: []), Tidier.systemPrompt)
    }

    func testStarterFileHasOnlyOneRealWord() {
        XCTAssertEqual(Vocabulary.parse(Vocabulary.starter), ["Claude"])
    }
}

final class ChunkerTests: XCTestCase {
    private func tone(_ seconds: Double) -> [Float] {
        (0..<Int(seconds * 16_000)).map { sin(Float($0) / 8) * 0.1 }
    }
    private func silence(_ seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * 16_000))
    }

    func testWaitsUntilThereIsEnoughAudio() {
        XCTAssertNil(Chunker.cutPoint(tone(2) + silence(0.5) + tone(2)))
    }

    func testCutsInTheMiddleOfAPause() throws {
        let cut = try XCTUnwrap(Chunker.cutPoint(tone(4) + silence(0.6) + tone(3)))
        XCTAssertEqual(Double(cut) / 16_000, 4.3, accuracy: 0.1)
    }

    func testDoesNotCutContinuousSpeechUnderTheLimit() {
        XCTAssertNil(Chunker.cutPoint(tone(12)))
    }

    func testForcesACutInVeryLongSpeech() throws {
        let cut = try XCTUnwrap(Chunker.cutPoint(tone(21)))
        XCTAssertGreaterThanOrEqual(Double(cut) / 16_000, 10)
    }

    func testIgnoresAPauseRightAtTheEnd() {
        // The speaker may only be taking a breath; the newest half second is off limits.
        XCTAssertNil(Chunker.cutPoint(tone(6.5) + silence(0.4)))
    }
}
