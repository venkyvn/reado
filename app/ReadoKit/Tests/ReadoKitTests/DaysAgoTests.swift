import ReadoKit
import XCTest

/// engagement-r1 T3 — nhãn "N ngày trước" (hàm thuần).
final class DaysAgoTests: XCTestCase {

    func testText() {
        XCTAssertEqual(DaysAgo.text(0), "hôm nay")
        XCTAssertEqual(DaysAgo.text(1), "hôm qua")
        XCTAssertEqual(DaysAgo.text(12), "12 ngày trước")
    }
}
