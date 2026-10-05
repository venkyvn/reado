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
        try insertSeen(
            on: db,
            contexts: vocabItemIDs.map { EncounterContext(vocabItemID: $0, sentence: nil) },
            collectionID: nil, now: now)
    }

    /// Như trên nhưng kèm câu chứa từ + collection đang lưu (vocab-identity-r1 T2).
    /// Khử trùng theo `vocabItemID` (lần đầu thắng). KHÔNG tự mở transaction.
    @discardableResult
    public static func insertSeen(
        on db: SQLiteDatabase, contexts: [EncounterContext], collectionID: String?, now: Date
    ) throws -> Int {
        let createdAt = ISOTimestamp.string(from: now)
        var written = Set<String>()
        for context in contexts where written.insert(context.vocabItemID).inserted {
            try insert(
                on: db, vocabItemID: context.vocabItemID, kind: .seen, createdAt: createdAt,
                sentence: context.sentence, collectionID: collectionID)
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
            guard try !recognized(on: db, vocabItemID: vocabItemID, in: window) else {
                return false
            }
            try insert(
                on: db, vocabItemID: vocabItemID, kind: .recognized,
                createdAt: ISOTimestamp.string(from: now))
            return true
        }
    }

    /// Hôm nay (ngày học hiện tại) đã "nhận ra" từ này chưa — popover dùng để
    /// tắt nút "Nhận ra ✓".
    public static func recognizedToday(
        on db: SQLiteDatabase, vocabItemID: String, now: Date
    ) throws -> Bool {
        try recognized(
            on: db, vocabItemID: vocabItemID,
            in: ReviewQueue.currentDayWindow(on: db, now: now))
    }

    /// Số dòng `kind` của một vocab.
    public static func count(
        on db: SQLiteDatabase, vocabItemID: String, kind: EncounterKind
    ) throws -> Int {
        Int(try db.scalarInt64(
            "SELECT COUNT(*) FROM encounters WHERE vocab_item_id = ? AND kind = ?;",
            [.text(vocabItemID), .text(kind.rawValue)]) ?? 0)
    }

    /// Một lần gặp lại có câu (vocab-identity-r1 T4).
    public struct EncounterContextRow: Equatable, Sendable {
        public let sentence: String
        /// nil = bộ đã xoá (`collection_id` SET NULL) hoặc dòng cũ không ghi bộ.
        public let collectionName: String?
        public let createdAt: Date

        public init(sentence: String, collectionName: String?, createdAt: Date) {
            self.sentence = sentence
            self.collectionName = collectionName
            self.createdAt = createdAt
        }
    }

    /// Các lần `seen` có câu của một vocab, mới nhất trước.
    public static func recentContexts(
        on db: SQLiteDatabase, vocabItemID: String, limit: Int
    ) throws -> [EncounterContextRow] {
        guard limit > 0 else { return [] }
        let rows = try db.rows(
            """
            SELECT e.sentence AS sentence, col.name AS collection_name, e.created_at AS created_at
            FROM encounters e
            LEFT JOIN collections col ON col.id = e.collection_id
            WHERE e.vocab_item_id = ? AND e.kind = 'seen' AND e.sentence IS NOT NULL
            ORDER BY e.created_at DESC, e.id DESC
            LIMIT ?;
            """,
            [.text(vocabItemID), .int(Int64(limit))])
        return rows.compactMap { row in
            guard let sentence = row["sentence"].textValue,
                  let iso = row["created_at"].textValue,
                  let date = ISOTimestamp.date(from: iso) else { return nil }
            return EncounterContextRow(
                sentence: sentence, collectionName: row["collection_name"].textValue,
                createdAt: date)
        }
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
            SELECT v.id AS id, v.term AS term, v.pos AS pos, v.ipa AS ipa,
                   v.meaning_vi AS meaning_vi, v.collection_id AS collection_id,
                   c.name AS collection_name
            FROM vocab_items v
            JOIN collections c ON c.id = v.collection_id
            WHERE NOT EXISTS (
              SELECT 1 FROM cards k
              WHERE k.vocab_item_id = v.id AND k.suspended_at IS NOT NULL)
            ORDER BY v.created_at, v.id;
            """)
        return rows.map { row in
            EncounterLexiconEntry(
                vocabItemID: row["id"].textValue ?? "",
                term: row["term"].textValue ?? "",
                pos: row["pos"].textValue ?? "",
                ipa: row["ipa"].textValue,
                meaningVI: row["meaning_vi"].textValue ?? "",
                collectionID: row["collection_id"].textValue ?? "",
                collectionName: row["collection_name"].textValue ?? "")
        }
    }

    // MARK: — private

    private static func recognized(
        on db: SQLiteDatabase, vocabItemID: String, in window: DayBoundary.DayWindow
    ) throws -> Bool {
        let count = try db.scalarInt64(
            """
            SELECT COUNT(*) FROM encounters
            WHERE vocab_item_id = ? AND kind = 'recognized'
              AND created_at >= ? AND created_at < ?;
            """,
            [.text(vocabItemID), .text(window.start), .text(window.end)]) ?? 0
        return count > 0
    }

    /// Internal: `DuplicateMerge` (FR-24) ghi `seen` với `createdAt`/câu/bộ của dòng bị gộp.
    static func insert(
        on db: SQLiteDatabase, vocabItemID: String, kind: EncounterKind, createdAt: String,
        sentence: String? = nil, collectionID: String? = nil
    ) throws {
        try db.run(
            """
            INSERT INTO encounters (id, vocab_item_id, kind, created_at, sentence, collection_id)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            [
                .text(Identifier.uuid()), .text(vocabItemID),
                .text(kind.rawValue), .text(createdAt),
                sentence.map { .text($0) } ?? .null,
                collectionID.map { .text($0) } ?? .null,
            ])
    }
}
