import XCTest
@testable import KeyKeyEngine

final class LanguageModelTests: XCTestCase {
    static let fixture = """
    # format org.openvanilla.mcbopomofo.sorted
    ㄅㄚ 八 -3.27631260
    ㄅㄚ 吧 -3.59800309
    ㄇㄠ 貓 -4.10000000
    ㄇㄠ-ㄇㄧ 貓咪 -5.20000000
    """

    func testLookupReturnsUnigramsInOrder() {
        let lm = LanguageModel(text: Self.fixture)
        let u = lm.unigrams(forKey: "ㄅㄚ")
        XCTAssertEqual(u.map(\.value), ["八", "吧"])
        XCTAssertEqual(u.first?.score ?? 0, -3.27631260, accuracy: 1e-6)
    }

    func testMultiSyllableKey() {
        let lm = LanguageModel(text: Self.fixture)
        XCTAssertEqual(lm.unigrams(forKey: "ㄇㄠ-ㄇㄧ").map(\.value), ["貓咪"])
    }

    func testHeaderAndBlanksIgnored() {
        let lm = LanguageModel(text: Self.fixture)
        XCTAssertTrue(lm.unigrams(forKey: "# format org.openvanilla.mcbopomofo.sorted").isEmpty)
    }

    func testMissingKey() {
        let lm = LanguageModel(text: Self.fixture)
        XCTAssertTrue(lm.unigrams(forKey: "ㄓㄨ").isEmpty)
        XCTAssertFalse(lm.hasKey("ㄓㄨ"))
        XCTAssertTrue(lm.hasKey("ㄅㄚ"))
    }
}
