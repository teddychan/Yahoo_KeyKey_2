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

    static let wildcardTable = CangjieTable(text: """
    a\t日
    ab\t明
    abc\t冒
    ax\t旮
    ba\t叭
    """)

    func testMatchingWithoutWildcardIsExact() {
        XCTAssertEqual(Self.wildcardTable.characters(matching: "ab"), ["明"])
        XCTAssertEqual(Self.wildcardTable.characters(matching: "zz"), [])
    }

    func testMatchingTrailingWildcard() {
        // "a*" matches codes starting with "a" plus one-or-more letters.
        // "a" alone does NOT match (* needs at least one letter).
        XCTAssertEqual(Self.wildcardTable.characters(matching: "a*"), ["明", "旮", "冒"])
    }

    func testMatchingWildcardBetweenLiterals() {
        // "a*c" matches codes starting "a", ending "c", with ≥1 letter between.
        XCTAssertEqual(Self.wildcardTable.characters(matching: "a*c"), ["冒"])
    }

    func testForEachEntryIteratesAll() {
        var count = 0
        Self.wildcardTable.forEachEntry { _, chars in count += chars.count }
        XCTAssertEqual(count, 5)
    }
}
