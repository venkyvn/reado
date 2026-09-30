import ReadoKit
import XCTest

/// T3a shell-chrome-r1 — logic thuần cuộn ẩn/hiện thanh tab. Chạy nhanh bằng
/// `scripts/test.sh kit` (không cần Simulator).
final class ScrollChromeTrackerTests: XCTestCase {

    func testScrollDown30FromOffset100Hides() {
        var tracker = ScrollChromeTracker()
        XCTAssertNil(tracker.update(offsetY: 100, maxOffset: 1000))
        XCTAssertEqual(tracker.update(offsetY: 130, maxOffset: 1000), true)
        XCTAssertTrue(tracker.isHidden)
    }

    func testScrollDown10StaysUnchanged() {
        var tracker = ScrollChromeTracker()
        XCTAssertNil(tracker.update(offsetY: 100, maxOffset: 1000))
        XCTAssertNil(tracker.update(offsetY: 110, maxOffset: 1000))
        XCTAssertFalse(tracker.isHidden)
    }

    func testScrollUp15WhileHiddenReveals() {
        var tracker = ScrollChromeTracker()
        XCTAssertNil(tracker.update(offsetY: 100, maxOffset: 1000))
        XCTAssertEqual(tracker.update(offsetY: 130, maxOffset: 1000), true)
        XCTAssertEqual(tracker.update(offsetY: 115, maxOffset: 1000), false)
        XCTAssertFalse(tracker.isHidden)
    }

    /// Rung ±5pt nhiều lần — không được đổi trạng thái, đổi dấu liên tục reset
    /// cộng dồn về đúng bước rung (không tích luỹ vượt ngưỡng).
    func testJitterPlusMinus5NeverChangesState() {
        var tracker = ScrollChromeTracker()
        XCTAssertNil(tracker.update(offsetY: 100, maxOffset: 1000))
        let offsets: [CGFloat] = [105, 100, 105, 100, 105, 100]
        for offset in offsets {
            XCTAssertNil(tracker.update(offsetY: offset, maxOffset: 1000))
        }
        XCTAssertFalse(tracker.isHidden)
    }

    func testReturnToOffset4Reveals() {
        var tracker = ScrollChromeTracker()
        XCTAssertNil(tracker.update(offsetY: 100, maxOffset: 1000))
        XCTAssertEqual(tracker.update(offsetY: 130, maxOffset: 1000), true)
        XCTAssertEqual(tracker.update(offsetY: 4, maxOffset: 1000), false)
        XCTAssertFalse(tracker.isHidden)
    }

    func testOffsetBeyondMaxOffsetIgnored() {
        var tracker = ScrollChromeTracker()
        XCTAssertNil(tracker.update(offsetY: 40, maxOffset: 50))
        XCTAssertNil(tracker.update(offsetY: 60, maxOffset: 50))
        XCTAssertFalse(tracker.isHidden)
    }
}
