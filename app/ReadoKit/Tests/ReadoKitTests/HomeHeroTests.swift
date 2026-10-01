import ReadoKit
import XCTest

/// ux-redesign-r1 T2 (ADR-054) — hero Home chọn đúng MỘT trạng thái từ dữ liệu thật.
/// Chạy bằng `scripts/test.sh kit`.
final class HomeHeroTests: XCTestCase {

    private func hero(
        cefrConfirmed: Bool = true,
        agentReady: Bool = true,
        hasFirstPage: Bool = true,
        dueToday: Int = 0,
        extraAvailable: Int = 0,
        backlog: Int = 0
    ) -> HomeHero {
        HomeHero.resolve(
            cefrConfirmed: cefrConfirmed, agentReady: agentReady, hasFirstPage: hasFirstPage,
            dueToday: dueToday, extraAvailable: extraAvailable, backlog: backlog)
    }

    // MARK: — Người mới từng bước (chỉ khi chưa có trang)

    func testNewUserStartsAtConfirmCefr() {
        let result = hero(cefrConfirmed: false, agentReady: false, hasFirstPage: false)
        XCTAssertEqual(result, HomeHero(state: .confirmCefr, agentWarning: false))
    }

    func testCefrConfirmedWithoutAgentAsksToConnectAgent() {
        let result = hero(cefrConfirmed: true, agentReady: false, hasFirstPage: false)
        XCTAssertEqual(result, HomeHero(state: .connectAgent, agentWarning: false))
    }

    func testCefrAndAgentDoneAsksForFirstCapture() {
        let result = hero(cefrConfirmed: true, agentReady: true, hasFirstPage: false)
        XCTAssertEqual(result, HomeHero(state: .firstCapture, agentWarning: false))
    }

    func testAgentReadyButCefrNotConfirmedStillAsksCefrFirst() {
        // Thứ tự bước cố định: CEFR trước agent, dù agent đã sẵn.
        let result = hero(cefrConfirmed: false, agentReady: true, hasFirstPage: false)
        XCTAssertEqual(result.state, .confirmCefr)
    }

    // MARK: — Đã có trang: onboarding không bao giờ chiếm hero

    func testExistingUserNeverSeesOnboardingEvenWithoutCefrFlag() {
        // `isDone(.cefr)` = cefrConfirmed || hasFirstPage — user cũ không bị hỏi lại.
        let result = hero(cefrConfirmed: false, agentReady: true, hasFirstPage: true, dueToday: 3)
        XCTAssertEqual(result.state, .review(3))
    }

    func testBrokenAgentWithDueCardsStillShowsReviewPlusWarning() {
        let result = hero(agentReady: false, dueToday: 10, extraAvailable: 5)
        XCTAssertEqual(result, HomeHero(state: .review(10), agentWarning: true))
    }

    func testBrokenAgentNoDueButExtraShowsExtraPlusWarning() {
        let result = hero(agentReady: false, dueToday: 0, extraAvailable: 7)
        XCTAssertEqual(result, HomeHero(state: .extra(7), agentWarning: true))
    }

    func testBrokenAgentNothingLeftShowsDonePlusWarning() {
        let result = hero(agentReady: false)
        XCTAssertEqual(result, HomeHero(state: .done, agentWarning: true))
    }

    func testDueCardsShowReviewWithoutWarningWhenAgentOk() {
        let result = hero(dueToday: 4, extraAvailable: 12)
        XCTAssertEqual(result, HomeHero(state: .review(4), agentWarning: false))
    }

    func testNoDueButExtraAvailableShowsExtra() {
        let result = hero(dueToday: 0, extraAvailable: 9)
        XCTAssertEqual(result, HomeHero(state: .extra(9), agentWarning: false))
    }

    func testExtraIsClampedToOneBatch() {
        let result = hero(extraAvailable: ReviewQueue.extraBatchSize + 50)
        XCTAssertEqual(result.state, .extra(ReviewQueue.extraBatchSize))
    }

    func testNothingLeftIsDone() {
        XCTAssertEqual(hero(), HomeHero(state: .done, agentWarning: false))
    }

    func testBacklogAloneDoesNotChangeDone() {
        // Còn từ mới chưa vào hạn mức nhưng không có Ôn thêm: vẫn "xong", không hiện số tồn.
        XCTAssertEqual(hero(backlog: 40), HomeHero(state: .done, agentWarning: false))
    }
}
