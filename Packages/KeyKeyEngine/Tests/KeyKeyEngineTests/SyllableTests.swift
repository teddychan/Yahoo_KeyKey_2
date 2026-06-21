import XCTest
@testable import KeyKeyEngine

final class SyllableTests: XCTestCase {
    func testEmptySyllable() {
        XCTAssertTrue(Syllable().isEmpty)
        XCTAssertEqual(Syllable().bpmf, "")
    }

    func testComposeOrderedString() {
        var s = Syllable()
        s.medial = "ㄧ"; s.consonant = "ㄅ"; s.tone = "ˊ"; s.vowel = "ㄠ"
        // canonical order regardless of insertion order: consonant+medial+vowel+tone
        XCTAssertEqual(s.bpmf, "ㄅㄧㄠˊ")
    }

    func testToneOneHasNoMark() {
        var s = Syllable()
        s.consonant = "ㄇ"; s.vowel = "ㄚ"; s.tone = nil
        XCTAssertEqual(s.bpmf, "ㄇㄚ")
    }
}
