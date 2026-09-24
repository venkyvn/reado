import Foundation
import GRDB

enum QueueService {
    struct Snapshot: Equatable {
        var newToday: Int
        var dueToday: Int
        var newBacklog: Int
        var newCards: [ReviewCardView]
        var dueCards: [ReviewCardView]
        var outsideDue: Int
    }

    static func snapshot(
        db: Database,
        settings: SettingsRecord,
        clock: Clock,
        scopeIds: [String]?
    ) throws -> Snapshot {
        let now = clock.now
        let nowISO = ISO8601UTC.string(from: now)
        let day = LearningDay.dayString(
            instant: now,
            timeZone: settings.timeZone,
            cutoffHour: settings.dayCutoffHour
        )
        guard let dayStart = LearningDay.startOfDay(
            day: day,
            timeZone: settings.timeZone,
            cutoffHour: settings.dayCutoffHour
        ) else {
            throw AppError.missingSettings
        }
        let dayStartISO = ISO8601UTC.string(from: dayStart)

        let newReviewedToday = try Int.fetchOne(
            db,
            sql: """
            SELECT COUNT(*) FROM review_logs
            WHERE state_before = 'new' AND reviewed_at >= ?
            """,
            arguments: [dayStartISO]
        ) ?? 0
        let remainingNew = max(0, settings.dailyNewLimit - newReviewedToday)

        let allNewRows = try CardRecord
            .filter(Column("state") == "new")
            .filter(Column("suspended_at") == nil)
            .filter(Column("direction") == "receptive")
            .order(Column("due_at"), Column("id"))
            .fetchAll(db)
        let allNew = try hydrate(db: db, cards: allNewRows)
        let scopedNew = allNew.filter { inScope($0, scopeIds) }
        let newTodayCards = Array(scopedNew.prefix(remainingNew))
        let newBacklog = max(0, scopedNew.count - remainingNew)

        let allDueRows = try CardRecord
            .filter(Column("state") != "new")
            .filter(Column("suspended_at") == nil)
            .filter(Column("direction") == "receptive")
            .filter(Column("due_at") <= nowISO)
            .order(Column("due_at"), Column("id"))
            .fetchAll(db)
        let allDue = try hydrate(db: db, cards: allDueRows)
        let dueScoped = allDue.filter { inScope($0, scopeIds) }
        let outsideDue = scopeIds == nil ? 0 : allDue.count - dueScoped.count

        return Snapshot(
            newToday: newTodayCards.count,
            dueToday: dueScoped.count,
            newBacklog: newBacklog,
            newCards: newTodayCards,
            dueCards: dueScoped,
            outsideDue: outsideDue
        )
    }

    private static func inScope(_ card: ReviewCardView, _ scopeIds: [String]?) -> Bool {
        guard let scopeIds else { return true }
        return scopeIds.contains(card.vocab.collectionId)
    }

    private static func hydrate(db: Database, cards: [CardRecord]) throws -> [ReviewCardView] {
        try cards.map { card in
            let vocab = try VocabItemRecord.fetchOne(db, key: card.vocabItemId)!
            let collection = try CollectionRecord.fetchOne(db, key: vocab.collectionId)!
            return ReviewCardView(card: card, vocab: vocab, collectionName: collection.name)
        }
    }
}
