import ReadoKit
import XCTest

/// Smoke test của package — chạy nhanh bằng `scripts/test.sh kit` trên macOS
/// (không cần Simulator). Bộ test đầy đủ hành vi nằm trong dự án app
/// (ReadoTests) chạy qua xcodebuild.
final class PrimitivesTests: XCTestCase {

    func testClockFixed() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = FixedClock(date)
        XCTAssertEqual(clock.now, date)
    }

    func testISOTimestampRoundtrip() {
        let date = Date(timeIntervalSince1970: 1_700_000_123)
        let value = ISOTimestamp.string(from: date)
        XCTAssertTrue(value.hasSuffix("Z"))
        XCTAssertEqual(ISOTimestamp.date(from: value), date)
    }

    func testIdentifierFormat() {
        let value = Identifier.uuid()
        XCTAssertEqual(value.count, 36)
        XCTAssertEqual(value, value.lowercased())
    }

    func testCardStateCodes() {
        XCTAssertEqual(
            CardStateCode.allCodes,
            ["new", "learning", "review", "relearning"])
        for code in CardStateCode.allCodes {
            XCTAssertTrue(CardStateCode.isValid(code))
        }
    }
}