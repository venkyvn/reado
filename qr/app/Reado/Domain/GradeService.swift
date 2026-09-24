import Foundation
import GRDB

enum GradeService {
    @discardableResult
    static func grade(
        db: Database,
        cardId: String,
        rating: Int,
        settings: SettingsRecord,
        clock: Clock
    ) throws -> String {
        guard let card = try CardRecord.fetchOne(db, key: cardId) else {
            throw AppError.missingSettings
        }
        let now = clock.now
        let elapsed: Int
        if card.state == "new" || card.lastReviewAt == nil {
            elapsed = 0
        } else if let last = card.lastReviewAt.flatMap(ISO8601UTC.date(from:)) {
            elapsed = max(0, Int(now.timeIntervalSince(last) / 86_400))
        } else {
            elapsed = 0
        }
        let logId = IDs.uuid()
        let log = ReviewLogRecord(
            id: logId,
            cardId: card.id,
            mode: "srs",
            rating: rating,
            stateBefore: card.state,
            stabilityBefore: card.stability,
            difficultyBefore: card.difficulty,
            learningStepsBefore: card.learningSteps,
            dueBefore: card.dueAt,
            elapsedDays: elapsed,
            scheduledDays: card.scheduledDays,
            reviewedAt: ISO8601UTC.string(from: now)
        )
        let fsrs = FSRSEngine.make(settings: settings)
        let updated = try fsrs.next(
            card: FSRSEngine.toFSRS(card),
            now: now,
            grade: FSRSEngine.rating(rating)
        ).card
        try log.insert(db)
        try FSRSEngine.apply(updated, onto: card).update(db)
        return logId
    }

    static func undo(db: Database, logId: String) throws {
        guard let log = try ReviewLogRecord.fetchOne(db, key: logId),
              var card = try CardRecord.fetchOne(db, key: log.cardId)
        else { return }
        card.state = log.stateBefore
        card.stability = log.stabilityBefore
        card.difficulty = log.difficultyBefore
        card.learningSteps = log.learningStepsBefore
        card.dueAt = log.dueBefore
        card.scheduledDays = log.scheduledDays
        card.reps = max(0, card.reps - 1)
        if log.rating == 1 && log.stateBefore == "review" {
            card.lapses = max(0, card.lapses - 1)
        }
        let previous = try ReviewLogRecord
            .filter(Column("card_id") == log.cardId && Column("id") != logId)
            .order(Column("reviewed_at").desc)
            .fetchOne(db)
        card.lastReviewAt = previous?.reviewedAt
        try card.update(db)
        try log.delete(db)
    }
}
