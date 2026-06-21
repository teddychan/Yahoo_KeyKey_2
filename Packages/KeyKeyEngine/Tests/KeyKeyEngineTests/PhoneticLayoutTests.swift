import XCTest
@testable import KeyKeyEngine

final class PhoneticLayoutTests: XCTestCase {
    // A trivial custom layout: only key "a" maps, to consonant "ㄅ".
    struct StubLayout: PhoneticLayout {
        func component(for key: Character) -> Component? {
            key == "a" ? .consonant("ㄅ") : nil
        }
    }

    func testReadingBufferUsesInjectedLayout() {
        var b = ReadingBuffer(layout: StubLayout())
        // "a" maps in the stub, "l" does not.
        XCTAssertEqual(b.receive("a"), .updated("ㄅ"))
        XCTAssertEqual(b.receive("l"), .unhandled)
    }

    func testStandardLayoutConformsToProtocol() {
        let layout: PhoneticLayout = StandardLayout()
        XCTAssertEqual(layout.component(for: "1"), .consonant("ㄅ"))
    }
}
