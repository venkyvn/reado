import ReadoKit
import XCTest

/// engagement-r1 T3 — nhãn "N ngày trước" (hàm thuần).
final class DaysAgoTests: XCTestCase {

    func testText() {
        XCTAssertEqual(DaysAgo.text(0), "hôm nay")
        XCTAssertEqual(DaysAgo.text(1), "hôm qua")
        XCTAssertEqual(DaysAgo.text(12), "12 ngày trước")
    }

    func testFirstSeenLabelThreshold() {
        XCTAssertNil(DaysAgo.firstSeenLabel(days: nil))
        XCTAssertNil(DaysAgo.firstSeenLabel(days: 0))
        XCTAssertNil(DaysAgo.firstSeenLabel(days: 6), "từ mới lưu < 7 ngày thì không hiện")
        XCTAssertEqual(DaysAgo.firstSeenLabel(days: 7), "Gặp lần đầu 7 ngày trước")
        XCTAssertEqual(DaysAgo.firstSeenLabel(days: 40), "Gặp lần đầu 40 ngày trước")
    }
}
