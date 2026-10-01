import Foundation

/// FR-19 — Leech Handling.
///
/// Phát hiện card bị chấm *Again* vượt ngưỡng (`settings.leech_lapses`) và đưa ra khỏi hàng đợi ôn tập
/// bằng cách set `cards.suspended_at`. Ngưỡng NULL = tắt. Owner chốt 2026-09-24: seed = 6. Không phải Q-08.
public enum LeechService {

    /// Kết quả một lần kiểm tra leech sau khi chấm.
    public struct Outcome: Equatable {
        /// Có đúng là card vừa bị đánh dấu leech trong lần này không?
        public let becameLeech: Bool
        /// Số lapses hiện tại của card (sau khi chấm).
        public let lapses: Int
        /// Ngưỡng đã dùng để so sánh; nil nếu tính năng tắt.
        public let threshold: Int?
    }

    /// Đọc ngưỡng leech từ settings (id = 1); nil = tính năng tắt.
    public static func readThreshold(on db: SQLiteDatabase) throws -> Int? {
        // leech_lapses nullable (NULL = tắt) → dùng scalar + intValue,
        // KHÔNG dùng scalarInt64 (ném khi gặp NULL).
        guard let v = try db.scalar(
            "SELECT leech_lapses FROM settings WHERE id = 1;")?.intValue else {
            return nil
        }
        // Giá trị <= 0 coi như tắt — tránh mọi card đều thành leech do lỗi config.
        return v > 0 ? Int(v) : nil
    }

    /// Sau một lần chấm: đọc ngưỡng từ settings rồi `suspendIfNeeded`. Đường
    /// tách rời (ngoài transaction chấm) — production đi qua
    /// `ReviewService.record(leechThreshold:)` để leech cùng transaction với
    /// UPDATE cards + INSERT review_logs. Trả về outcome để caller báo UI
    /// ("Card này đã bị đánh dấu leech").
    @discardableResult
    public static func evaluateAfterGrade(
        on db: SQLiteDatabase,
        cardID: String,
        now: Date = SystemClock().now
    ) throws -> Outcome {
        guard let threshold = try readThreshold(on: db) else {
            // Tính năng tắt — vẫn trả lapses hiện tại để caller ghi log/debug.
            let lapses = try currentLapses(on: db, cardID: cardID)
            return Outcome(becameLeech: false, lapses: lapses, threshold: nil)
        }
        return try suspendIfNeeded(on: db, cardID: cardID, threshold: threshold, now: now)
    }

    /// Nếu `lapses` hiện tại của card đạt/vượt `threshold` thì suspend (set
    /// `suspended_at = now`, chỉ khi chưa suspend). KHÔNG tự mở transaction —
    /// `inTransaction` không lồng được (BEGIN trong BEGIN lỗi), nên hàm này chạy
    /// được trong thân transaction của caller (`ReviewService.record`) và thấy
    /// `lapses` vừa UPDATE trên cùng kết nối.
    @discardableResult
    public static func suspendIfNeeded(
        on db: SQLiteDatabase,
        cardID: String,
        threshold: Int,
        now: Date
    ) throws -> Outcome {
        let lapses = try currentLapses(on: db, cardID: cardID)
        guard lapses >= threshold else {
            return Outcome(becameLeech: false, lapses: lapses, threshold: threshold)
        }
        // Đã vượt ngưỡng → suspend nếu chưa suspend.
        let alreadySuspended = try isSuspended(on: db, cardID: cardID)
        if !alreadySuspended {
            try db.run(
                "UPDATE cards SET suspended_at = ? WHERE id = ?;",
                [
                    .text(ISOTimestamp.string(from: now)),
                    .text(cardID),
                ])
        }
        return Outcome(
            becameLeech: !alreadySuspended,
            lapses: lapses,
            threshold: threshold)
    }

    /// Đưa card trở lại hàng đợi ôn tập (FR-19: "đưa trở lại hàng đợi").
    /// Reset `suspended_at = NULL`. Không đổi FSRS state — card tiếp tục theo lịch cũ.
    public static func unsuspend(
        on db: SQLiteDatabase, cardID: String
    ) throws {
        try db.run(
            "UPDATE cards SET suspended_at = NULL WHERE id = ?;",
            [.text(cardID)])
    }

    /// Xoá hẳn card (FR-19: "xoá hẳn"). CASCADE qua vocab_item_id nếu cần xoá cả từ.
    public static func deleteCard(
        on db: SQLiteDatabase, cardID: String
    ) throws {
        try db.run("DELETE FROM cards WHERE id = ?;", [.text(cardID)])
    }

    /// Danh sách card đang bị suspend (leech) kèm thông tin từ vựng để hiển thị.
    /// ORDER BY suspended_at DESC — mới nhất trước.
    public static func fetchLeeches(on db: SQLiteDatabase) throws -> [LeechCard] {
        let rows = try db.rows(
            """
            SELECT ca.id AS id, ca.vocab_item_id AS vocab_item_id,
                   ca.lapses AS lapses, ca.suspended_at AS suspended_at,
                   ca.state AS state, v.term AS term,
                   v.meaning_vi AS meaning_vi, v.example AS example
            FROM cards ca
            JOIN vocab_items v ON v.id = ca.vocab_item_id
            WHERE ca.suspended_at IS NOT NULL
            ORDER BY ca.suspended_at DESC, ca.id;
            """, [])
        return try rows.map { row in
            guard let suspendedIso = row["suspended_at"].textValue,
                  let suspendedAt = ISOTimestamp.date(from: suspendedIso) else {
                throw DatabaseError.failed(
                    "suspended_at sai định dạng ISO", statement: "fetchLeeches")
            }
            return LeechCard(
                cardID: row["id"].textValue ?? "",
                vocabItemID: row["vocab_item_id"].textValue ?? "",
                lapses: Int(row["lapses"].intValue ?? 0),
                suspendedAt: suspendedAt,
                state: row["state"].textValue ?? "",
                term: row["term"].textValue ?? "",
                meaningVI: row["meaning_vi"].textValue ?? "",
                example: row["example"].textValue ?? "")
        }
    }

    // MARK: — Helpers

    private static func currentLapses(
        on db: SQLiteDatabase, cardID: String
    ) throws -> Int {
        guard let v = try db.scalarInt64(
            "SELECT lapses FROM cards WHERE id = ?;", [.text(cardID)]) else {
            throw DatabaseError.failed(
                "card không tồn tại: \(cardID)", statement: "currentLapses")
        }
        return Int(v)
    }

    private static func isSuspended(
        on db: SQLiteDatabase, cardID: String
    ) throws -> Bool {
        guard let value = try db.scalar(
            "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)]) else {
            throw DatabaseError.failed(
                "card không tồn tại: \(cardID)", statement: "isSuspended")
        }
        // suspended_at NULL → chưa suspend; TEXT → đã suspend.
        return !value.isNull
    }
}

/// Một card leech kèm ngữ cảnh từ vựng — đủ để render danh sách + chi tiết.
public struct LeechCard: Identifiable, Equatable {
    public let cardID: String
    public let vocabItemID: String
    public let lapses: Int
    public let suspendedAt: Date
    public let state: String
    public let term: String
    public let meaningVI: String
    public let example: String

    public var id: String { cardID }
}