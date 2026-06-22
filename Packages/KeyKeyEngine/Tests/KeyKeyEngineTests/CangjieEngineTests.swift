import XCTest
@testable import KeyKeyEngine

final class CangjieEngineTests: XCTestCase {
    // a=日, b=月, c=金, ... ; codes -> chars from the real Cangjie scheme.
    static let table = CangjieTable(text: """
    a\t日
    a\t曰
    ab\t明
    abc\t冒
    abcde\t韻
    abcdef\t漏
    """)

    private func make() -> CangjieEngine { CangjieEngine(table: Self.table) }

    func testAccumulatesRadicalGlyphs() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // 日
        XCTAssertTrue(e.handleKey("b"))   // 月
        XCTAssertEqual(e.composingText, "日月")
    }

    func testCandidatesForCurrentCode() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertEqual(e.candidates, ["日", "曰"])
        _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明"])
    }

    func testNoCandidatesWhenEmpty() {
        XCTAssertEqual(make().candidates, [])
    }

    func testSelectCandidateShowsItAsComposing() {
        let e = make()
        _ = e.handleKey("a")
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "曰")
    }

    func testSelectOutOfRangeIgnored() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(5)
        XCTAssertEqual(e.composingText, "日月")
    }

    func testCommitReturnsTextAndClears() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(0)
        XCTAssertEqual(e.commit(), "明")
        XCTAssertEqual(e.composingText, "")
        XCTAssertEqual(e.candidates, [])
    }

    func testCommitWithoutSelectionUsesRadicalGlyphs() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b"); _ = e.handleKey("c")
        XCTAssertEqual(e.commit(), "日月金")
    }

    func testBackspaceRemovesLastRadical() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.backspace()
        XCTAssertEqual(e.composingText, "日")
        XCTAssertEqual(e.candidates, ["日", "曰"])
    }

    func testBackspaceClearsSelection() {
        let e = make()
        _ = e.handleKey("a")
        e.selectCandidate(1)
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceOnEmptyIsSafe() {
        let e = make()
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testMaxFiveRadicalsCap() {
        let e = make()
        for k in "abcdef" { XCTAssertTrue(e.handleKey(k)) } // 6th still consumed, not stored
        XCTAssertEqual(e.composingText, "日月金木水")        // only 5 glyphs
        XCTAssertEqual(e.candidates, ["韻"])                 // code is "abcde"
    }

    func testNonLetterIgnored() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertFalse(e.handleKey("1"))
        XCTAssertFalse(e.handleKey(" "))
        XCTAssertFalse(e.handleKey("A"))   // uppercase is not a radical key
        XCTAssertEqual(e.composingText, "日")
    }

    func testRadicalMapCoversFullAlphabet() {
        for k in "abcdefghijklmnopqrstuvwxyz" {
            XCTAssertNotNil(CangjieEngine.radicals[k], "missing radical for \(k)")
        }
        XCTAssertEqual(CangjieEngine.radicals.count, 26)
    }
}
