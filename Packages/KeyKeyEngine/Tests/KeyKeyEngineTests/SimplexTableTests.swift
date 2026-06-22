import XCTest
@testable import KeyKeyEngine

final class SimplexTableTests: XCTestCase {
    // Cangjie codes -> chars. Simplex code = first+last letter of the cangjie code.
    //   "ab"   -> "ab"   明
    //   "abc"  -> "ac"   冒
    //   "amb"  -> "ab"   昌   (shares simplex "ab" with 明)
    //   "abcde"-> "ae"   韻
    //   "a"    -> "a"    日   (length 1 -> single letter)
    static let cangjie = CangjieTable(text: """
    a\t日
    ab\t明
    amb\t昌
    abc\t冒
    abcde\t韻
    """)

    private func make() -> SimplexTable { SimplexTable(cangjie: Self.cangjie) }

    func testFirstPlusLastDerivation() {
        let t = make()
        XCTAssertEqual(t.characters(forCode: "ac"), ["冒"])   // "abc" -> "ac"
        XCTAssertEqual(t.characters(forCode: "ae"), ["韻"])   // "abcde" -> "ae"
    }

    func testSingleLetterCodeStaysSingle() {
        XCTAssertEqual(make().characters(forCode: "a"), ["日"])   // "a" -> "a"
    }

    func testMultipleCharsGroupedUnderSameSimplexCode() {
        // "ab" -> "ab" (明), "amb" -> "ab" (昌)
        XCTAssertEqual(make().characters(forCode: "ab"), ["明", "昌"])
    }

    func testUnknownCodeIsEmpty() {
        XCTAssertEqual(make().characters(forCode: "zz"), [])
    }

    func testInitFromTextMatchesInitFromCangjie() {
        let fromText = SimplexTable(text: """
        a\t日
        ab\t明
        amb\t昌
        abc\t冒
        abcde\t韻
        """)
        XCTAssertEqual(fromText.characters(forCode: "ab"), ["明", "昌"])
        XCTAssertEqual(fromText.characters(forCode: "ac"), ["冒"])
        XCTAssertEqual(fromText.characters(forCode: "a"), ["日"])
    }

    func testDeDupesRepeatedCharForSameSimplexCode() {
        // Two cangjie codes that both reduce to "ab" and both map to 明 -> de-duped.
        let t = SimplexTable(text: """
        ab\t明
        axb\t明
        """)
        XCTAssertEqual(t.characters(forCode: "ab"), ["明"])
    }
}
