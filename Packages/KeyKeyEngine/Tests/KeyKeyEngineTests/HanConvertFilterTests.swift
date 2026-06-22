import XCTest
@testable import KeyKeyEngine

final class HanConvertFilterTests: XCTestCase {
    // Small inline fixtures matching the OpenCC native format.
    // Includes a comment line, a multi-target line, and tab/space separators.
    private let tsFixture = """
    # comment line, should be ignored
    臺\t台
    蟲\t虫
    後\t后
    幹\t干 乾 幹
    """

    private let stFixture = """
    台 臺
    虫\t蟲 虫
    """

    func testTraditionalToSimplifiedMapsCharacters() {
        let table = HanConvertTable(text: tsFixture)
        let filter = HanConvertFilter(direction: .traditionalToSimplified, table: table)
        XCTAssertEqual(filter.convert("臺"), "台")
        XCTAssertEqual(filter.convert("蟲"), "虫")
        XCTAssertEqual(filter.convert("臺灣蟲"), "台灣虫")
    }

    func testUnmappedCharactersPassThrough() {
        let table = HanConvertTable(text: tsFixture)
        let filter = HanConvertFilter(direction: .traditionalToSimplified, table: table)
        // "灣" and "a" and "中" are not in the fixture.
        XCTAssertEqual(filter.convert("a灣中"), "a灣中")
    }

    func testSimplifiedToTraditionalDirection() {
        let table = HanConvertTable(text: stFixture)
        let filter = HanConvertFilter(direction: .simplifiedToTraditional, table: table)
        XCTAssertEqual(filter.convert("台"), "臺")
        XCTAssertEqual(filter.convert("虫"), "蟲")
    }

    func testMultiTargetTakesFirst() {
        let table = HanConvertTable(text: tsFixture)
        // "幹\t干 乾 幹" -> first target is "干".
        XCTAssertEqual(table.map["幹"], "干")
        let filter = HanConvertFilter(direction: .traditionalToSimplified, table: table)
        XCTAssertEqual(filter.convert("幹"), "干")
    }

    func testEmptyString() {
        let table = HanConvertTable(text: tsFixture)
        let filter = HanConvertFilter(direction: .traditionalToSimplified, table: table)
        XCTAssertEqual(filter.convert(""), "")
    }

    func testCommentAndBlankLinesIgnored() {
        let table = HanConvertTable(text: "# header\n\n臺\t台\n")
        XCTAssertEqual(table.map.count, 1)
        XCTAssertEqual(table.map["臺"], "台")
    }

    // Optional: load the real OpenCC tables IF the resource files exist; skip otherwise.
    func testRealTablesIfPresent() throws {
        let resourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // KeyKeyEngineTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // KeyKeyEngine package root
            .appendingPathComponent("Resources")
        let tsURL = resourcesDir.appendingPathComponent("opencc-TSCharacters.txt")
        let stURL = resourcesDir.appendingPathComponent("opencc-STCharacters.txt")

        guard FileManager.default.fileExists(atPath: tsURL.path),
              FileManager.default.fileExists(atPath: stURL.path) else {
            throw XCTSkip("Real OpenCC tables not present; skipping.")
        }

        let ts = try HanConvertTable(contentsOf: tsURL)
        let tsFilter = HanConvertFilter(direction: .traditionalToSimplified, table: ts)
        XCTAssertEqual(tsFilter.convert("臺"), "台")
        XCTAssertEqual(tsFilter.convert("蟲"), "虫")

        let st = try HanConvertTable(contentsOf: stURL)
        let stFilter = HanConvertFilter(direction: .simplifiedToTraditional, table: st)
        // ASCII / unmapped passes through.
        XCTAssertEqual(stFilter.convert("abc"), "abc")
    }
}
