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

    /// `Card` cho engine. `elapsedDays` = số ngày tròn (làm tròn) kể từ
    /// last_review — 0 với thẻ mới. LongTermScheduler dùng giá trị này làm
    /// `interval` khi tính recall stability, nên phải truyền đầy đủ.
    func schedulerCard(now: Date) throws -> Card {
        guard let cardState = CardStateCode.toState(state) else {
            throw ReviewSchedulerError.invalidCardStateCode(state)
        }
        return Card(
            due: due,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: Self.dayDiff(from: lastReview, to: now),
            scheduledDays: Double(scheduledDays),
            learningSteps: learningSteps,
            reps: reps,
            lapses: lapses,
            state: cardState,
            lastReview: lastReview
        )
    }

    /// Ngày tròn kiểu ts-fsrs: |Δ|/ngày rồi làm tròn, không âm.
    public static func dayDiff(from: Date?, to: Date) -> Double {
        guard let from else { return 0 }
        return max(0, (to.timeIntervalSince(from) / 86_400).rounded())
    }
}