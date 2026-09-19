import Foundation

/// Repository của tầng vocab/card — nơi walking skeleton printf commit vào DB.
/// Mỗi lần "lưu capture" là một transaction (SD mục 6 khối #4):
/// `INSERT vocab_items[]` + `INSERT cards` (receptive, state=new, due hôm nay).
public enum VocabRepository {

    public struct Collection: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let isDefault: Bool
        public let createdAt: Date
    }

    public struct VocabItem: Equatable, Sendable, Identifiable {
        public let id: String
        public let collectionID: String
        public let term: String
        public let termNormalized: String
        public let pos: String
        public let ipa: String?
        public let meaningVI: String
        public let example: String
        public let cefr: String?
        public let createdAt: Date
    }

    /// Chuẩn hoá term → term_normalized: lower + trim (trim trước, rồi lower).
    public static func normalizedTerm(_ term: String) -> String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Tạo collection mới. Tên trim trước khi insert (db.md A.2.2 — NOCASE
    /// không thay trim). Trả nil nếu trùng tên (index unique).
    public static func createCollection(
        on db: SQLiteDatabase,
        name: String,
        now: Date = Date()
    ) throws -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let id = Identifier.uuid()
        do {
            try db.run(
                """
                INSERT INTO collections (id, name, is_default, created_at)
                VALUES (?, ?, 0, ?);
                """,
                [.text(id), .text(trimmed), .text(ISOTimestamp.string(from: now))])
            return id
        } catch DatabaseError.failed(_, _) {
            // Tên trùng (idx_collections_name) → nil. Báo lỗi khác lên trên.
            return nil
        }
    }

    public static func allCollections(on db: SQLiteDatabase) throws -> [Collection] {
        let rows = try db.rows(
            """
            SELECT id, name, is_default, created_at
            FROM collections
            ORDER BY is_default DESC, name COLLATE NOCASE;
            """)
        return try rows.map { row in
            guard row.count >= 4 else {
                throw DatabaseError.failed("thiếu cột", statement: "collections")
            }
            return Collection(
                id: row[0].textValue ?? "",
                name: row[1].textValue ?? "",
                isDefault: (row[2].intValue ?? 0) != 0,
                createdAt: ISOTimestamp.date(from: row[3].textValue ?? "") ?? Date())
        }
    }

    /// Lưu một trang capture — transaction #4 (SD mục 6).
    /// collectionID nil → kho tạm (is_default, 2.4). Một item lỗi → rollback.
    public static func saveCapture(
        on db: SQLiteDatabase,
        items: [PageAnalysis.VocabularyItemIn],
        collectionID: String?,
        now: Date
    ) throws -> Int {
        guard !items.isEmpty else { return 0 }
        let targetID: String
        if let collectionID {
            // Validate còn tồn tại.
            let exists = try db.scalarInt64(
                "SELECT 1 FROM collections WHERE id = ? LIMIT 1;",
                [.text(collectionID)])
            guard (exists ?? 0) != 0 else {
                throw DatabaseError.failed("collection không tồn tại", statement: nil)
            }
            targetID = collectionID
        } else {
            // 2.4 — chưa chọn → kho tạm (is_default=1).
            guard
                let inboxID = try db.scalarString(
                    "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;")
            else {
                throw DatabaseError.failed("thiếu kho tạm seed", statement: nil)
            }
            targetID = inboxID
        }
        let nowIso = ISOTimestamp.string(from: now)
        var count = 0
        try db.inTransaction {
            for item in items {
                let vocabID = Identifier.uuid()
                try db.run(
                    """
                    INSERT INTO vocab_items (
                      id, collection_id, term, term_normalized, pos,
                      ipa, meaning_vi, example, cefr, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    [
                        .text(vocabID),
                        .text(targetID),
                        .text(item.term),
                        .text(normalizedTerm(item.term)),
                        .text(item.pos),
                        item.ipa.map { .text($0) } ?? .null,
                        .text(item.meaningVI),
                        .text(item.example),
                        item.cefr.map { .text($0) } ?? .null,
                        .text(nowIso),
                    ])
                try db.run(
                    """
                    INSERT INTO cards (
                      id, vocab_item_id, direction, state,
                      stability, difficulty, reps, lapses, learning_steps,
                      scheduled_days, last_review_at, due_at, suspended_at
                    ) VALUES (?, ?, 'receptive', 'new', 0, 0, 0, 0, 0, 0, NULL, ?, NULL);
                    """,
                    [
                        .text(Identifier.uuid()),
                        .text(vocabID),
                        // FR-09: card mới `new`, `due_at` hôm nay.
                        .text(nowIso),
                    ])
                count += 1
            }
        }
        return count
    }
}