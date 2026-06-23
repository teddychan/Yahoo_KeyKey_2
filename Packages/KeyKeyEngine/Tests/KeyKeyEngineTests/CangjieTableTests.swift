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

    // Fixture mixing renderable common CJK with tofu offenders:
    //   日   U+65E5  BMP CJK Unified           -> kept
    //   䫻   U+4AFB  CJK Extension A           -> kept
    //   U+E81C       Private Use Area          -> dropped (always tofu)
    //   𣇘   U+231D8 CJK Extension B (plane 2) -> dropped (no glyph on most systems)
    static let tofuTable = CangjieTable(text: """
    a\t日
    b\t䫻
    c\t\u{E81C}
    d\t𣇘
    """)

    func testKeepsBMPAndExtACharacters() {
        XCTAssertEqual(Self.tofuTable.characters(forCode: "a"), ["日"])
        XCTAssertEqual(Self.tofuTable.characters(forCode: "b"), ["䫻"])
    }

    func testDropsPrivateUseAreaCharacter() {
        XCTAssertEqual(Self.tofuTable.characters(forCode: "c"), [])
        XCTAssertFalse(Self.tofuTable.hasCode("c"))
    }

    func testDropsSupplementaryPlaneExtBCharacter() {
        XCTAssertEqual(Self.tofuTable.characters(forCode: "d"), [])
        XCTAssertFalse(Self.tofuTable.hasCode("d"))
    }

    func testFilteredCharactersExcludedFromWildcardMatch() {
        // "*" should never surface dropped tofu characters.
        XCTAssertEqual(Self.tofuTable.characters(matching: "*"), ["日", "䫻"])
    }

    func testSimplexInheritsFilterFromCangjie() {
        // SimplexTable derived from a CangjieTable sees only filtered entries.
        let simplex = SimplexTable(cangjie: Self.tofuTable)
        XCTAssertEqual(simplex.characters(forCode: "a"), ["日"])
        XCTAssertEqual(simplex.characters(forCode: "b"), ["䫻"])
        XCTAssertEqual(simplex.characters(forCode: "c"), [])
        XCTAssertEqual(simplex.characters(forCode: "d"), [])
    }
}
