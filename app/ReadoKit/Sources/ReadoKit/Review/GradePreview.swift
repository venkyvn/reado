import Foundation

/// fsrs-queue-fix-r1 T2 (D-2): lịch xem trước của 4 nút chấm, giữ lại để lần chấm
/// thật DÙNG LẠI đúng outcome đã hiện nhãn.
///
/// Vì sao cần cache: fuzz của `swift-fsrs` seed theo timestamp (`reviewTime`),
/// nên tính lại ở `now` lúc bấm có thể ra `scheduled_days` khác nhãn đã thấy.
/// Cache khoá theo (thẻ, snapshot) và hết hạn sau `maxAge`: trong cửa sổ đó
/// `due` được tính từ lúc nhãn hiện (lệch ≤ 30 phút so với lúc bấm — D-2 đã
/// chốt), còn `reviewed_at`/`last_review_at` vẫn là giờ bấm thật do caller ghi.
///
/// Không tự tính FSRS: outcome đến từ `IntervalPreview.outcomes` → `ReviewScheduler`.
public struct GradePreview: Equatable, Sendable {
    /// Quá ngưỡng này nhãn coi như cũ — caller tính lại ở `now` mới.
    public static let maxAge: TimeInterval = 30 * 60

    public let cardID: String
    public let snapshot: CardSnapshot
    public let computedAt: Date
    public let outcomes: [ReadoRating: ReviewOutcome]

    public init(
        cardID: String,
        snapshot: CardSnapshot,
        computedAt: Date,
        outcomes: [ReadoRating: ReviewOutcome]
    ) {
        self.cardID = cardID
        self.snapshot = snapshot
        self.computedAt = computedAt
        self.outcomes = outcomes
    }

    /// Tính 4 outcome ở `now` (cùng settings, kể cả fuzz, với lần chấm thật).
    public static func make(
        scheduler: ReviewScheduler, snapshot: CardSnapshot, now: Date
    ) throws -> GradePreview {
        GradePreview(
            cardID: snapshot.id,
            snapshot: snapshot,
            computedAt: now,
            outcomes: try IntervalPreview.outcomes(
                scheduler: scheduler, snapshot: snapshot, now: now))
    }

    /// Outcome đã xem trước cho `rating` — chỉ khi đúng thẻ, đúng snapshot, và
    /// `now` nằm trong `[computedAt, computedAt + maxAge)`. Ngược lại `nil`
    /// (caller tính lại bằng `ReviewScheduler.grade`). Đồng hồ lùi (`now <
    /// computedAt`) cũng trượt: không tin cache khi thời gian không đơn điệu.
    public func outcome(
        for rating: ReadoRating,
        cardID: String,
        snapshot: CardSnapshot,
        now: Date
    ) -> ReviewOutcome? {
        guard cardID == self.cardID, snapshot == self.snapshot else { return nil }
        let age = now.timeIntervalSince(computedAt)
        guard age >= 0, age < Self.maxAge else { return nil }
        return outcomes[rating]
    }
}
