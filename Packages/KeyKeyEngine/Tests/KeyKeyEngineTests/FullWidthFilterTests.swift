import XCTest
@testable import KeyKeyEngine

final class FullWidthFilterTests: XCTestCase {
    func testLetter() {
        XCTAssertEqual(FullWidthFilter.convert("A"), "Ａ")
    }

    func testDigit() {
        XCTAssertEqual(FullWidthFilter.convert("1"), "１")
    }

    func testPunctuation() {
        XCTAssertEqual(FullWidthFilter.convert("!"), "！")
    }

    func testSpace() {
        XCTAssertEqual(FullWidthFilter.convert(" "), "\u{3000}")
    }

    func testCJKUnchanged() {
        XCTAssertEqual(FullWidthFilter.convert("中"), "中")
    }

    func testMixedString() {
        XCTAssertEqual(FullWidthFilter.convert("Hi 中!"), "Ｈｉ\u{3000}中！")
    }
}
