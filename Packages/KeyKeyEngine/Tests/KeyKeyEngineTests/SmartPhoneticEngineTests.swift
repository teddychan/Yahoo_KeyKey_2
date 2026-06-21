import XCTest
@testable import KeyKeyEngine

final class SmartPhoneticEngineTests: XCTestCase {
    static let lm = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄇㄠ 貓 -4.0
    ㄇㄠ 毛 -4.2
    """)

    private func make() -> SmartPhoneticEngine { SmartPhoneticEngine(languageModel: Self.lm) }

    func testTypeOneSyllableShowsComposingAndCandidates() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // ㄇ
        XCTAssertTrue(e.handleKey("l"))   // ㄇㄠ
        XCTAssertTrue(e.handleKey(" "))   // tone 1 completes reading ㄇㄠ
        XCTAssertEqual(e.composingText, "貓")
        XCTAssertEqual(e.candidates, ["貓", "毛"])
    }

    func testSelectCandidateOverrides() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "毛")
    }

    func testCommitReturnsTextAndClears() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")
        XCTAssertEqual(e.commit(), "貓")
        XCTAssertEqual(e.composingText, "")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testBackspaceRemovesReading() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")  // one reading
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testUnmappedKeyNotConsumed() {
        let e = make()
        XCTAssertFalse(e.handleKey("`"))
    }

    static let phraseLM = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄐㄧㄣ 今 -4.0
    ㄐㄧㄣ 斤 -4.5
    ㄊㄧㄢ 天 -4.0
    ㄊㄧㄢ 田 -4.6
    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.2
    """)

    func testSelectionWorksWhenPhraseWinsWalk() {
        let e = SmartPhoneticEngine(languageModel: Self.phraseLM)
        // type ㄐㄧㄣ (r,u,p, space) then ㄊㄧㄢ (w,u,0, space)
        for k in ["r","u","p"," ","w","u","0"," "] { _ = e.handleKey(Character(k)) }
        XCTAssertEqual(e.composingText, "今天")            // phrase wins by default
        // candidates at the last position include 天/田 (and the phrase); pick 田
        let i = e.candidates.firstIndex(of: "田")
        XCTAssertNotNil(i)
        e.selectCandidate(i!)
        XCTAssertEqual(e.composingText, "今田")            // selection applied despite phrase walk
    }
}
