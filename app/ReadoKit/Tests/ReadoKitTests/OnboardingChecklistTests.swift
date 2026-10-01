import ReadoKit
import XCTest

/// ADR-041 (T5 ux-polish-r1) — checklist Home suy trạng thái từ dữ liệu thật,
/// không counter riêng.
final class OnboardingChecklistTests: XCTestCase {

    func testNewUserAllStepsPendingFirstPageDisabled() {
        let checklist = OnboardingChecklist(
            cefrConfirmed: false, agentReady: false, hasFirstPage: false, dismissed: false)
        XCTAssertTrue(checklist.isVisible)
        XCTAssertEqual(checklist.doneCount, 0)
        XCTAssertFalse(checklist.isEnabled(.firstPage))
        XCTAssertFalse(checklist.isDone(.cefr))
        XCTAssertFalse(checklist.isDone(.agent))
        XCTAssertFalse(checklist.isDone(.firstPage))
    }

    func testAgentReadyEnablesFirstPageStep() {
        let checklist = OnboardingChecklist(
            cefrConfirmed: false, agentReady: true, hasFirstPage: false, dismissed: false)
        XCTAssertTrue(checklist.isEnabled(.firstPage))
        XCTAssertEqual(checklist.doneCount, 1)
    }

    func testExistingUserWithDataIsInvisibleAndCefrCountsDone() {
        let checklist = OnboardingChecklist(
            cefrConfirmed: false, agentReady: true, hasFirstPage: true, dismissed: false)
        XCTAssertFalse(checklist.isVisible, "user cũ có agent + trang đầu — ẩn checklist")
        XCTAssertTrue(checklist.isDone(.cefr), "có trang đầu ≡ CEFR đã được dùng thật")
        XCTAssertEqual(checklist.doneCount, 3)
    }

    func testDismissedHidesRegardlessOfProgress() {
        let checklist = OnboardingChecklist(
            cefrConfirmed: false, agentReady: false, hasFirstPage: false, dismissed: true)
        XCTAssertFalse(checklist.isVisible)
    }

    func testFirstPageWithoutAgentStillVisible() {
        // Proxy lỗi/agent bị xoá sau khi đã có trang — vẫn nhắc kết nối lại.
        let checklist = OnboardingChecklist(
            cefrConfirmed: false, agentReady: false, hasFirstPage: true, dismissed: false)
        XCTAssertTrue(checklist.isVisible)
        XCTAssertEqual(checklist.doneCount, 2, "cefr (suy từ hasFirstPage) + firstPage, agent chưa xong")
    }
}
