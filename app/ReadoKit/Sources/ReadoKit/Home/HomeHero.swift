import Foundation

/// ux-redesign-r1 T2 (ADR-054): hero đầu màn "Hôm nay" — MỘT việc cần làm lúc này, suy từ
/// dữ liệu thật (không lưu tiến trình riêng). Thay `OnboardingChecklist` 3 hàng: onboarding
/// vẫn 3 bước nhưng mỗi lúc chỉ hiện một, làm CTA duy nhất.
public struct HomeHero: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Bước 1 onboarding — "Trình độ đọc: B2 [Đúng][Đổi]".
        case confirmCefr
        /// Bước 2 — chưa có agent chạy được.
        case connectAgent
        /// Bước 3 — chụp trang đầu tiên.
        case firstCapture
        /// Còn thẻ đến hạn hôm nay (đã theo hạn mức, FR-11) — payload = số thẻ.
        case review(Int)
        /// Xong phần hôm nay nhưng còn Ôn thêm — payload = số thẻ của MỘT lượt (đã kẹp
        /// `ReviewQueue.extraBatchSize`), view hiện thẳng số này.
        case extra(Int)
        /// Hết sạch việc hôm nay.
        case done
    }

    public let state: State
    /// Người dùng đã có trang nhưng agent hỏng/mất key — dòng cảnh báo phụ, KHÔNG phải CTA và
    /// không che thẻ đến hạn. Luôn false ở 3 trạng thái onboarding (CTA đã là việc sửa agent).
    public let agentWarning: Bool

    public init(state: State, agentWarning: Bool) {
        self.state = state
        self.agentWarning = agentWarning
    }

    /// Luật ưu tiên: trạng thái onboarding CHỈ khi `!hasFirstPage`. Đã có trang → luôn
    /// `review/extra/done`, kể cả khi agent hỏng — bỏ tab Ôn thì hero là cửa ôn chính, agent
    /// hỏng không được giấu thẻ đến hạn. CEFR dùng lại `OnboardingChecklist.isDone(.cefr)`
    /// (`cefrConfirmed || hasFirstPage`).
    ///
    /// `backlog` (thẻ mới chưa vào hạn mức hôm nay) chưa ảnh hưởng state: new-order-r1 không
    /// hiện số tồn (vision Retention "không cần học hết"), và `.done` đã đủ cho cả ca có/không tồn.
    public static func resolve(
        cefrConfirmed: Bool,
        agentReady: Bool,
        hasFirstPage: Bool,
        dueToday: Int,
        extraAvailable: Int,
        backlog: Int
    ) -> HomeHero {
        guard hasFirstPage else {
            let checklist = OnboardingChecklist(
                cefrConfirmed: cefrConfirmed, agentReady: agentReady,
                hasFirstPage: hasFirstPage, dismissed: false)
            if !checklist.isDone(.cefr) { return HomeHero(state: .confirmCefr, agentWarning: false) }
            if !checklist.isDone(.agent) { return HomeHero(state: .connectAgent, agentWarning: false) }
            return HomeHero(state: .firstCapture, agentWarning: false)
        }
        let warning = !agentReady
        if dueToday > 0 {
            return HomeHero(state: .review(dueToday), agentWarning: warning)
        }
        if extraAvailable > 0 {
            return HomeHero(
                state: .extra(min(extraAvailable, ReviewQueue.extraBatchSize)),
                agentWarning: warning)
        }
        return HomeHero(state: .done, agentWarning: warning)
    }
}
