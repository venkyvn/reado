import FSRS
import Foundation

/// Ảnh chụp card TRƯỚC lúc chấm — nguồn cột *_before của review_logs
/// (db.md A.2, rulebook mục 5: lưu TRƯỚC, không phải sau).
/// `state` là mã DB (String) — kiểu thư viện ngoài không lọt vào API công khai.
public struct CardSnapshot: Equatable, Sendable {
    public let id: String
    public let due: Date
    public let stability: Double
    public let difficulty: Double
    public let learningSteps: Int
    public let reps: Int
    public let lapses: Int
    /// Mã DB: new / learning / review / relearning.
    public let state: String
    public let lastReview: Date?
    public let scheduledDays: Int
    public let suspendedAt: Date?

    public init(
        id: String,
        due: Date,
        stability: Double,
        difficulty: Double,
        learningSteps: Int,
        reps: Int,
        lapses: Int,
        state: String,
        lastReview: Date?,
        scheduledDays: Int,
        suspendedAt: Date?
    ) {
        self.id = id
        self.due = due
        self.stability = stability
        self.difficulty = difficulty
        self.learningSteps = learningSteps
        self.reps = reps
        self.lapses = lapses
        self.state = state
        self.lastReview = lastReview
        self.scheduledDays = scheduledDays
        self.suspendedAt = suspendedAt
    }

    /// `Card` cho engine. `elapsedDays` truyền `0` vì **bị lib ghi đè** —
    /// `AbstractScheduler.init` (swift-fsrs @`4fbaf20`) tự tính lại bằng
    /// `Date.dateDiffInDays(from: lastReview, to: reviewTime)` = hiệu ngày
    /// lịch UTC (floor theo `startOfDay` UTC), không phải |Δ|/24h làm tròn.
    /// Định nghĩa thật của `elapsed_days` nằm ở `ReviewOutcome.elapsedDaysRounded`
    /// (xem `research/review.md` §4.1) — Reado không tự tính giá trị này.
    func schedulerCard(now: Date) throws -> Card {
        guard let cardState = CardStateCode.toState(state) else {
            throw ReviewSchedulerError.invalidCardStateCode(state)
        }
        return Card(
            due: due,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: 0,
            scheduledDays: Double(scheduledDays),
            learningSteps: learningSteps,
            reps: reps,
            lapses: lapses,
            state: cardState,
            lastReview: lastReview
        )
    }
}