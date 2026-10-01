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
        guard
            let state = row["state"].textValue,
            CardStateCode.toState(state) != nil
        else {
            throw DatabaseError.failed(
                "state lạ: \(row["state"].textValue ?? "nil")", statement: nil)
        }
        guard let dueDate = ISOTimestamp.date(from: row["due_at"].textValue ?? "") else {
            throw DatabaseError.failed(
                "due_at sai định dạng ISO", statement: "SELECT cards")
        }
        return CardSnapshot(
            id: row["id"].textValue ?? "",
            due: dueDate,
            stability: row["stability"].doubleValue ?? 0,
            difficulty: row["difficulty"].doubleValue ?? 0,
            learningSteps: Int(row["learning_steps"].intValue ?? 0),
            reps: Int(row["reps"].intValue ?? 0),
            lapses: Int(row["lapses"].intValue ?? 0),
            state: state,
            lastReview: row["last_review_at"].textValue.flatMap { ISOTimestamp.date(from: $0) },
            scheduledDays: Int(row["scheduled_days"].intValue ?? 0),
            suspendedAt: row["suspended_at"].textValue.flatMap { ISOTimestamp.date(from: $0) }
        )
    }

    /// Kết quả một lần `record`: id log (cho undo) + thẻ có vừa thành leech không.
    public struct RecordResult: Equatable, Sendable {
        public let logID: String
        /// true khi CHÍNH lần chấm này đẩy `lapses` qua ngưỡng và `suspended_at`
        /// đã được ghi (cùng transaction). Luôn false khi `leechThreshold == nil`.
        public let becameLeech: Bool
    }

    /// Chấm thẻ và ghi log — một transaction: `UPDATE cards` + `INSERT
    /// review_logs` + (FR-19) suspend leech. `leechThreshold` nil = không kiểm
    /// leech (tắt, hoặc caller tự xử lý). Leech chạy TRONG thân transaction nên
    /// lỗi ở đó rollback cả lần chấm; undo khôi phục `suspended_at` từ snapshot.
    /// `suspended_at` dùng cùng `now` với `reviewed_at`.
    @discardableResult
    public static func record(
        on db: SQLiteDatabase,
        cardID: String,
        before: CardSnapshot,
        outcome: ReviewOutcome,
        leechThreshold: Int? = nil,
        now: Date
    ) throws -> RecordResult {
        let logID = Identifier.uuid()
        let reviewedAtIso = ISOTimestamp.string(from: now)
        let becameLeech = try db.inTransaction { () throws -> Bool in
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
            try insertLog(
                on: db, logID: logID, cardID: cardID, mode: "srs",
                rating: outcome.rating, before: before,
                elapsedDays: outcome.elapsedDaysRounded,
                scheduledDays: outcome.scheduledDays, reviewedAtIso: reviewedAtIso)
            guard let leechThreshold else { return false }
            return try LeechService.suspendIfNeeded(
                on: db, cardID: cardID, threshold: leechThreshold, now: now
            ).becameLeech
        }
        return RecordResult(logID: logID, becameLeech: becameLeech)
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

    /// Cram (ADR-011/043): chấm thẻ CHƯA đến hạn mà KHÔNG đổi lịch — chỉ INSERT
    /// một dòng `review_logs` `mode='cram'` (snapshot TRƯỚC = trạng thái hiện tại
    /// của thẻ, `scheduled_days` không đổi). KHÔNG `UPDATE cards`. Trả id log.
    @discardableResult
    public static func recordCram(
        on db: SQLiteDatabase,
        cardID: String,
        before: CardSnapshot,
        rating: ReadoRating,
        now: Date
    ) throws -> String {
        let logID = Identifier.uuid()
        let elapsed = max(
            0,
            Int(((now.timeIntervalSince(before.lastReview ?? now)) / 86_400).rounded()))
        try insertLog(
            on: db, logID: logID, cardID: cardID, mode: "cram",
            rating: rating.rawValue, before: before, elapsedDays: elapsed,
            scheduledDays: before.scheduledDays,
            reviewedAtIso: ISOTimestamp.string(from: now))
        return logID
    }

    /// Undo Cram: chỉ xoá đúng dòng log cram vừa ghi — `cards` chưa từng bị đổi
    /// nên không cần khôi phục gì. Không xoá được log srs qua đường này.
    public static func undoCram(
        on db: SQLiteDatabase, cardID: String, logID: String
    ) throws {
        try db.run(
            "DELETE FROM review_logs WHERE id = ? AND card_id = ? AND mode = 'cram';",
            [.text(logID), .text(cardID)])
    }

    /// Snapshot TRƯỚC → một dòng `review_logs` (dùng chung srs + cram; `mode`
    /// chỉ nhận 'srs'/'cram' theo CHECK của bảng).
    private static func insertLog(
        on db: SQLiteDatabase,
        logID: String,
        cardID: String,
        mode: String,
        rating: Int,
        before: CardSnapshot,
        elapsedDays: Int,
        scheduledDays: Int,
        reviewedAtIso: String
    ) throws {
        try db.run(
            """
            INSERT INTO review_logs (
              id, card_id, mode, rating,
              state_before, stability_before, difficulty_before,
              learning_steps_before, due_before,
              elapsed_days, scheduled_days, reviewed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            [
                .text(logID),
                .text(cardID),
                .text(mode),
                .int(Int64(rating)),
                .text(before.state),
                .double(before.stability),
                .double(before.difficulty),
                .int(Int64(before.learningSteps)),
                .text(ISOTimestamp.string(from: before.due)),
                .int(Int64(elapsedDays)),
                .int(Int64(scheduledDays)),
                .text(reviewedAtIso),
            ])
    }
}
