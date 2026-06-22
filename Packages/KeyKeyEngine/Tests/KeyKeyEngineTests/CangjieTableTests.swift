import XCTest
@testable import KeyKeyEngine

final class CangjieTableTests: XCTestCase {
    static let table = CangjieTable(text: """
    # a small inline fixture
    a\t日
    a\t曰
    ab\t明
    abc\t冒
    """)

    func testLookupSingleCode() {
        XCTAssertEqual(Self.table.characters(forCode: "ab"), ["明"])
    }

    func testLookupReturnsAllCharactersForSharedCode() {
        XCTAssertEqual(Self.table.characters(forCode: "a"), ["日", "曰"])
    }

    func testUnknownCodeReturnsEmpty() {
        XCTAssertEqual(Self.table.characters(forCode: "zzz"), [])
        XCTAssertFalse(Self.table.hasCode("zzz"))
    }

    func testHasCode() {
        XCTAssertTrue(Self.table.hasCode("abc"))
    }

    func testCommentsAndBlankLinesIgnored() {
        let t = CangjieTable(text: "# comment\n\nm\t一\n")
        XCTAssertEqual(t.characters(forCode: "m"), ["一"])
    }
}
