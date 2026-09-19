import Foundation

/// Một lần chấm = `UPDATE cards` + `INSERT review_logs` CÙNG transaction
/// (db.md A.2, rulebook mục 5 — log không ghi thì mất training data vĩnh viễn).
/// Undo FR-12: xoá đúng dòng log vừa ghi trong transaction, không UPDATE log cũ.
public enum ReviewService {

    /// Đọc dòng cards → CardSnapshot (ảnh chụp TRƯỚC).
    public static func fetchSnapshot(
        on db: SQLiteDatabase, cardID: String
    ) throws -> CardSnapshot? {
        let rows = try db.rows(
            """
            SELECT id, due_at, stability, difficulty, learning_steps,
                   reps, lapses, state, last_review_at, scheduled_days,
                   suspended_at
            FROM cards WHERE id = ?;
            """, [.text(cardID)])
        guard let row = rows.first else { return nil }
        guard row.count >= 11 else {
            throw DatabaseError.failed(
                "fetch cards thiếu cột (\(row.count)/11)", statement: nil)
        }
        guard
            let state = row[7].textValue,
            CardStateCode.toState(state) != nil
        else {
            throw DatabaseError.failed(
                "state lạ: \(row[7].textValue ?? "nil")", statement: nil)
        }
        guard let dueDate = ISOTimestamp.date(from: row[1].textValue ?? "") else {
            throw DatabaseError.failed(
                "due_at sai định dạng ISO", statement: "SELECT cards")
        }
        return CardSnapshot(
            id: row[0].textValue ?? "",
            due: dueDate,
            stability: row[2].doubleValue ?? 0,
            difficulty: row[3].doubleValue ?? 0,
            learningSteps: Int(row[4].intValue ?? 0),
            reps: Int(row[5].intValue ?? 0),
            lapses: Int(row[6].intValue ?? 0),
            state: state,
            lastReview: row[8].textValue.flatMap { ISOTimestamp.date(from: $0) },
            scheduledDays: Int(row[9].intValue ?? 0),
            suspendedAt: row[10].textValue.flatMap { ISOTimestamp.date(from: $0) }
        )
    }

    /// Chấm thẻ và ghi log — một transaction, trả id review_log.
    @discardableResult
    public static func record(
        on db: SQLiteDatabase,
        cardID: String,
        before: CardSnapshot,
        outcome: ReviewOutcome,
        now: Date
    ) throws -> String {
        let logID = Identifier.uuid()
        let reviewedAtIso = ISOTimestamp.string(from: now)
        try db.inTransaction {
            try db.run(
                """
                UPDATE cards
                SET state = ?, stability = ?, difficulty = ?, reps = ?,
                    lapses = ?, learning_steps = ?, scheduled_days = ?,
                    last_review_at = ?, due_at = ?
                WHERE id = ?;
                """,
                [
                    .text(outcome.state),
                    .double(outcome.stability),
                    .double(outcome.difficulty),
                    .int(Int64(outcome.reps)),
                    .int(Int64(outcome.lapses)),
                    .int(Int64(outcome.learningSteps)),
                    .int(Int64(outcome.scheduledDays)),
                    .text(reviewedAtIso),
                    .text(ISOTimestamp.string(from: outcome.due)),
                    .text(cardID),
                ])
            try db.run(
                """
                INSERT INTO review_logs (
                  id, card_id, mode, rating,
                  state_before, stability_before, difficulty_before,
                  learning_steps_before, due_before,
                  elapsed_days, scheduled_days, reviewed_at
                ) VALUES (?, ?, 'srs', ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                [
                    .text(logID),
                    .text(cardID),
                    .int(Int64(outcome.rating)),
                    .text(before.state),
                    .double(before.stability),
                    .double(before.difficulty),
                    .int(Int64(before.learningSteps)),
                    .text(ISOTimestamp.string(from: before.due)),
                    .int(Int64(outcome.elapsedDaysRounded)),
                    .int(Int64(outcome.scheduledDays)),
                    .text(reviewedAtIso),
                ])
        }
        return logID
    }

    /// Undo một bước (FR-12): trả card về snapshot TRƯỚC và XOÁ đúng dòng log
    /// vừa ghi — cùng transaction, không UPDATE log cũ (db.md A.2).
    public static func undo(
        on db: SQLiteDatabase,
        cardID: String,
        logID: String,
        before: CardSnapshot
    ) throws {
        try db.inTransaction {
            try db.run(
                "DELETE FROM review_logs WHERE id = ? AND card_id = ?;",
                [.text(logID), .text(cardID)])
            try db.run(
                """
                UPDATE cards
                SET state = ?, stability = ?, difficulty = ?, reps = ?,
                    lapses = ?, learning_steps = ?, scheduled_days = ?,
                    last_review_at = ?, due_at = ?, suspended_at = ?
                WHERE id = ?;
                """,
                [
                    .text(before.state),
                    .double(before.stability),
                    .double(before.difficulty),
                    .int(Int64(before.reps)),
                    .int(Int64(before.lapses)),
                    .int(Int64(before.learningSteps)),
                    .int(Int64(before.scheduledDays)),
                    before.lastReview.map {
                        .text(ISOTimestamp.string(from: $0))
                    } ?? .null,
                    .text(ISOTimestamp.string(from: before.due)),
                    before.suspendedAt.map {
                        .text(ISOTimestamp.string(from: $0))
                    } ?? .null,
                    .text(cardID),
                ])
        }
    }
}