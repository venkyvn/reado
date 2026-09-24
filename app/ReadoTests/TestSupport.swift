import Foundation
import ReadoKit

/// Fixtures dùng chung cho test — dữ liệu dạng đúng dialect SQLite chốt
/// (uuid TEXT thường, timestamp ISO-8601 UTC `Z`).
enum Fixtures {
    static let timezoneID = "Asia/Ho_Chi_Minh"
    /// 2026-09-18 02:00 UTC = 09:00 VN.
    static let fixedNow: Date = iso("2026-09-18T02:00:00Z")

    static func iso(_ value: String) -> Date {
        guard let date = ISOTimestamp.date(from: value) else {
            preconditionFailure("ISO sai trong fixture: \(value)")
        }
        return date
    }

    @discardableResult
    static func insertCollection(
        in db: SQLiteDatabase,
        name: String,
        id: String = Identifier.uuid(),
        isDefault: Int64 = 0,
        createdAt: String = "2026-09-01T00:00:00Z"
    ) throws -> String {
        try db.run(
            """
            INSERT INTO collections (id, name, is_default, created_at)
            VALUES (?, ?, ?, ?);
            """,
            [.text(id), .text(name), .int(isDefault), .text(createdAt)])
        return id
    }

    @discardableResult
    static func insertVocab(
        in db: SQLiteDatabase,
        collectionID: String,
        term: String,
        normalized: String? = nil,
        id: String = Identifier.uuid(),
        pos: String = "noun",
        createdAt: String = "2026-09-01T00:00:00Z"
    ) throws -> String {
        try db.run(
            """
            INSERT INTO vocab_items (
              id, collection_id, term, term_normalized, pos, ipa,
              meaning_vi, example, cefr, created_at
            ) VALUES (?, ?, ?, ?, ?, NULL, 'nghĩa giả', 'câu ví dụ giả', NULL, ?);
            """,
            [
                .text(id),
                .text(collectionID),
                .text(term),
                .text(normalized ?? term),
                .text(pos),
                .text(createdAt),
            ])
        return id
    }

    @discardableResult
    static func insertCard(
        in db: SQLiteDatabase,
        vocabItemID: String,
        state: String = "new",
        dueIso: String = "2026-09-01T00:00:00Z",
        id: String = Identifier.uuid(),
        stability: Double = 0,
        difficulty: Double = 0,
        reps: Int64 = 0,
        lapses: Int64 = 0,
        lastReviewIso: String? = nil,
        suspendedIso: String? = nil,
        scheduledDays: Int64 = 0
    ) throws -> String {
        try db.run(
            """
            INSERT INTO cards (
              id, vocab_item_id, direction, state, stability, difficulty,
              reps, lapses, learning_steps, scheduled_days,
              last_review_at, due_at, suspended_at
            ) VALUES (?, ?, 'receptive', ?, ?, ?, ?, ?, 0, ?, ?, ?, ?);
            """,
            [
                .text(id),
                .text(vocabItemID),
                .text(state),
                .double(stability),
                .double(difficulty),
                .int(reps),
                .int(lapses),
                .int(scheduledDays),
                lastReviewIso.map { .text($0) } ?? .null,
                .text(dueIso),
                suspendedIso.map { .text($0) } ?? .null,
            ])
        return id
    }

    @discardableResult
    static func insertLog(
        in db: SQLiteDatabase,
        cardID: String,
        reviewedAtIso: String,
        id: String = Identifier.uuid()
    ) throws -> String {
        try db.run(
            """
            INSERT INTO review_logs (
              id, card_id, mode, rating, state_before, stability_before,
              difficulty_before, learning_steps_before, due_before,
              elapsed_days, scheduled_days, reviewed_at
            ) VALUES (?, ?, 'srs', 3, 'new', 0, 0, 0, '2026-09-01T00:00:00Z', 0, 1, ?);
            """,
            [.text(id), .text(cardID), .text(reviewedAtIso)])
        return id
    }

    /// DB đã migration + seed với timezone/clock cố định.
    static func seededDB() throws -> SQLiteDatabase {
        let db = try SQLiteDatabase(inMemory: ())
        try Migration.run(on: db)
        try Seeder.seed(on: db, timezone: timezoneID, now: fixedNow)
        return db
    }

    /// Snapshot thẻ theo đúng kiểu public của ReadoKit (không cần import FSRS).
    static func cardSnapshot(
        id: String = Identifier.uuid(),
        due: Date = fixedNow,
        stability: Double = 0,
        difficulty: Double = 0,
        learningSteps: Int = 0,
        reps: Int = 0,
        lapses: Int = 0,
        state: String = "new",
        lastReview: Date? = nil,
        scheduledDays: Int = 0,
        suspendedAt: Date? = nil
    ) -> CardSnapshot {
        CardSnapshot(
            id: id,
            due: due,
            stability: stability,
            difficulty: difficulty,
            learningSteps: learningSteps,
            reps: reps,
            lapses: lapses,
            state: state,
            lastReview: lastReview,
            scheduledDays: scheduledDays,
            suspendedAt: suspendedAt
        )
    }
}