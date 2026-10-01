import Foundation

/// Loại lần gặp lại một từ đã có trong kho (FR-22).
public enum EncounterKind: String, Equatable, Sendable {
    /// Tự ghi khi lưu một trang có từ đã có trong kho.
    case seen
    /// Người dùng chạm "Nhận ra" khi đọc.
    case recognized
}

/// FR-22 — "gặp lại từ cũ khi đọc" (reencounter-r1, ADR-048). Bảng `encounters`
/// nằm NGOÀI FSRS: không đụng `cards`/`review_logs`, nên "nhận ra khi đọc" không
/// đổi lịch ôn.
public enum EncounterRepository {

    /// Một dòng `seen` cho mỗi vocab trong `vocabItemIDs` (trùng id trong danh
    /// sách chỉ tính một). KHÔNG tự mở transaction — caller (lưu trang) gọi trong
    /// CÙNG transaction với lưu vocab + phiên đọc; `inTransaction` không lồng được.
    /// Trả số dòng đã ghi.
    @discardableResult
    public static func insertSeen(
        on db: SQLiteDatabase, vocabItemIDs: [String], now: Date
    ) throws -> Int {
        let createdAt = ISOTimestamp.string(from: now)
        var written = Set<String>()
        for id in vocabItemIDs where written.insert(id).inserted {
            try insert(on: db, vocabItemID: id, kind: .seen, createdAt: createdAt)
        }
        return written.count
    }

    /// "Nhận ra" khi đọc: tối đa MỘT dòng / vocab / ngày học (`day_cutoff_hour`
    /// FR-11 — cùng cửa sổ với hàng đợi, không nửa đêm hệ thống). Trả `true` nếu
    /// vừa ghi, `false` nếu hôm nay đã nhận ra từ này rồi. Tự mở transaction
    /// (kiểm + ghi nguyên tử) — không gọi trong transaction khác.
    @discardableResult
    public static func recordRecognized(
        on db: SQLiteDatabase, vocabItemID: String, now: Date
    ) throws -> Bool {
        let window = ReviewQueue.currentDayWindow(on: db, now: now)
        return try db.inTransaction { () throws -> Bool in
            let already = try db.scalarInt64(
                """
                SELECT COUNT(*) FROM encounters
                WHERE vocab_item_id = ? AND kind = 'recognized'
                  AND created_at >= ? AND created_at < ?;
                """,
                [.text(vocabItemID), .text(window.start), .text(window.end)]) ?? 0
            guard already == 0 else { return false }
            try insert(
                on: db, vocabItemID: vocabItemID, kind: .recognized,
                createdAt: ISOTimestamp.string(from: now))
            return true
        }
    }

    /// Số dòng `kind` của một vocab.
    public static func count(
        on db: SQLiteDatabase, vocabItemID: String, kind: EncounterKind
    ) throws -> Int {
        Int(try db.scalarInt64(
            "SELECT COUNT(*) FROM encounters WHERE vocab_item_id = ? AND kind = ?;",
            [.text(vocabItemID), .text(kind.rawValue)]) ?? 0)
    }

    /// Số TỪ (vocab, không phải số lần) có ít nhất một lần gặp lại từ `since` —
    /// dòng "Gặp lại N từ tuần này" ở Home.
    public static func distinctWordsEncountered(
        on db: SQLiteDatabase, since: Date
    ) throws -> Int {
        Int(try db.scalarInt64(
            "SELECT COUNT(DISTINCT vocab_item_id) FROM encounters WHERE created_at >= ?;",
            [.text(ISOTimestamp.string(from: since))]) ?? 0)
    }

    /// Từ điển để dò: mọi vocab xuyên collection (kể cả kho tạm) trừ vocab có
    /// thẻ đang suspend (leech — FR-19 đã loại khỏi hàng đợi). Thứ tự ổn định:
    /// `created_at`, `id`.
    public static func loadLexicon(on db: SQLiteDatabase) throws -> [EncounterLexiconEntry] {
        let rows = try db.rows(
            """
            SELECT v.id, v.term, v.pos, v.ipa, v.meaning_vi, v.collection_id, c.name
            FROM vocab_items v
            JOIN collections c ON c.id = v.collection_id
            WHERE NOT EXISTS (
              SELECT 1 FROM cards k
              WHERE k.vocab_item_id = v.id AND k.suspended_at IS NOT NULL)
            ORDER BY v.created_at, v.id;
            """)
        return try rows.map { row in
            guard row.count >= 7 else {
                throw DatabaseError.failed(
                    "loadLexicon thiếu cột (\(row.count)/7)", statement: "loadLexicon")
            }
            return EncounterLexiconEntry(
                vocabItemID: row[0].textValue ?? "",
                term: row[1].textValue ?? "",
                pos: row[2].textValue ?? "",
                ipa: row[3].textValue,
                meaningVI: row[4].textValue ?? "",
                collectionID: row[5].textValue ?? "",
                collectionName: row[6].textValue ?? "")
        }
    }

    // MARK: — private

    private static func insert(
        on db: SQLiteDatabase, vocabItemID: String, kind: EncounterKind, createdAt: String
    ) throws {
        try db.run(
            """
            INSERT INTO encounters (id, vocab_item_id, kind, created_at)
            VALUES (?, ?, ?, ?);
            """,
            [
                .text(Identifier.uuid()), .text(vocabItemID),
                .text(kind.rawValue), .text(createdAt),
            ])
    }
}
