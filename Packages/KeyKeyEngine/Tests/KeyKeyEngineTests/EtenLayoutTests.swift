import XCTest
@testable import KeyKeyEngine

// ETen (倚天) layout, mapping verified against McBopomofo Mandarin.cpp CreateETenLayout().
final class EtenLayoutTests: XCTestCase {
    private let layout = EtenLayout()

    func testConsonants() {
        XCTAssertEqual(layout.component(for: "b"), .consonant("ㄅ"))
        XCTAssertEqual(layout.component(for: "v"), .consonant("ㄍ"))   // ETen: v == ㄍ
        XCTAssertEqual(layout.component(for: "g"), .consonant("ㄐ"))   // ETen: g == ㄐ
        XCTAssertEqual(layout.component(for: "7"), .consonant("ㄑ"))   // ETen: 7 == ㄑ
        XCTAssertEqual(layout.component(for: ","), .consonant("ㄓ"))
        XCTAssertEqual(layout.component(for: "/"), .consonant("ㄕ"))
        XCTAssertEqual(layout.component(for: "'"), .consonant("ㄘ"))
        XCTAssertEqual(layout.component(for: "s"), .consonant("ㄙ"))
    }

    func testMedials() {
        XCTAssertEqual(layout.component(for: "e"), .medial("ㄧ"))
        XCTAssertEqual(layout.component(for: "x"), .medial("ㄨ"))
        XCTAssertEqual(layout.component(for: "u"), .medial("ㄩ"))
    }

    func testVowels() {
        XCTAssertEqual(layout.component(for: "a"), .vowel("ㄚ"))
        XCTAssertEqual(layout.component(for: "r"), .vowel("ㄜ"))
        XCTAssertEqual(layout.component(for: "w"), .vowel("ㄝ"))
        XCTAssertEqual(layout.component(for: "0"), .vowel("ㄤ"))
        XCTAssertEqual(layout.component(for: "-"), .vowel("ㄥ"))
        XCTAssertEqual(layout.component(for: "="), .vowel("ㄦ"))
    }

    func testTones() {
        XCTAssertEqual(layout.component(for: "2"), .tone("ˊ"))   // Tone2
        XCTAssertEqual(layout.component(for: "3"), .tone("ˇ"))   // Tone3
        XCTAssertEqual(layout.component(for: "4"), .tone("ˋ"))   // Tone4
        XCTAssertEqual(layout.component(for: "1"), .tone("˙"))   // Tone5
    }

    func testUnmappedKeyReturnsNil() {
        XCTAssertNil(layout.component(for: "5"))   // no key 5 in ETen
        XCTAssertNil(layout.component(for: " "))   // ETen has no space tone key
    }
}
