import Foundation

/// Repository của tầng vocab/card — nơi walking skeleton printf commit vào DB.
/// Mỗi lần "lưu capture" là một transaction (SD mục 6 khối #4):
/// `INSERT vocab_items[]` + `INSERT cards` (receptive, state=new, due hôm nay).
/// Lỗi quản lý collection (FR-17).
public enum CollectionError: Error, LocalizedError, Equatable {
    /// id không tồn tại.
    case notFound
    /// Kho tạm (is_default) không xoá được — luôn cần chỗ tiếp nhận từ chưa phân loại.
    case cannotDeleteDefault
    /// Collection còn từ; `associated` = số từ bị ảnh hưởng (UI nói rõ rồi cho chuyển).
    case hasWords(Int)

    public var errorDescription: String? {
        switch self {
        case .notFound: "Collection không tồn tại"
        case .cannotDeleteDefault: "Không thể xoá kho tạm"
        case let .hasWords(count):
            "Collection còn \(count) từ — chuyển chúng đi trước khi xoá"
        }
    }
}

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

    /// Dòng hiển thị danh sách từ (FR-08) — đủ các trường + tên collection chứa nó.
    public struct VocabularyListEntry: Equatable, Sendable, Identifiable {
        public let id: String
        public let collectionID: String
        public let collectionName: String
        public let term: String
        public let termNormalized: String
        public let pos: String
        public let ipa: String?
        public let meaningVI: String
        public let example: String
        public let cefr: String?
        public let createdAt: Date
    }

    /// Tổng quan một collection cho Home (FR-17 a) — tên, số từ, đến hạn, lần thêm gần nhất.
    public struct CollectionSummary: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let isDefault: Bool
        public let wordCount: Int
        public let dueNow: Int
        public let lastAddedAt: Date?
    }

    /// Thứ tự sắp danh sách từ: FR-08 gộp cùng `term` cạnh nhau; J6 kho tạm theo
    /// thời điểm thêm để "chọn nguyên lô chiều hôm qua".
    public enum VocabularyOrder: Sendable {
        case byTerm
        case byDateAdded
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

    // MARK: — FR-08 Vocabulary List

    /// Danh sách từ của một collection với đủ trường hiển thị + tên collection.
    /// `order = .byTerm` (dòng cùng term nằm cạnh nhau, không gộp — FR-08 crit 3;
    /// `term_normalized` đã lower qua `normalizedTerm`); `.byDateAdded` cho kho tạm (J6).
    public static func listVocabulary(
        on db: SQLiteDatabase,
        collectionID: String,
        order: VocabularyOrder = .byTerm
    ) throws -> [VocabularyListEntry] {
        let orderClause: String
        switch order {
        case .byTerm:
            orderClause = "v.term_normalized, v.pos, v.id"
        case .byDateAdded:
            orderClause = "v.created_at, v.id"
        }
        let rows = try db.rows(
            """
            SELECT v.id, v.collection_id, c.name, v.term, v.term_normalized,
                   v.pos, v.ipa, v.meaning_vi, v.example, v.cefr, v.created_at
            FROM vocab_items v
            JOIN collections c ON c.id = v.collection_id
            WHERE v.collection_id = ?
            ORDER BY \(orderClause);
            """,
            [.text(collectionID)])
        return rows.compactMap { row in
            guard row.count >= 11 else { return nil }
            return VocabularyListEntry(
                id: row[0].textValue ?? "",
                collectionID: row[1].textValue ?? "",
                collectionName: row[2].textValue ?? "",
                term: row[3].textValue ?? "",
                termNormalized: row[4].textValue ?? "",
                pos: row[5].textValue ?? "other",
                ipa: row[6].textValue,
                meaningVI: row[7].textValue ?? "",
                example: row[8].textValue ?? "",
                cefr: row[9].textValue,
                createdAt: ISOTimestamp.date(from: row[10].textValue ?? "") ?? Date())
        }
    }

    // MARK: — FR-17(a) + Home overview

    /// Tổng quan mọi collection — tên, số từ, thẻ đến hạn (`due_at <= now`, chưa
    /// suspend), lần thêm từ gần nhất. `COUNT(DISTINCT v.id)` chống việc JOIN
    /// cards nhân dòng (một vocab tối đa 2 card theo direction).
    public static func allCollectionSummaries(
        on db: SQLiteDatabase, now: Date
    ) throws -> [CollectionSummary] {
        let nowIso = ISOTimestamp.string(from: now)
        let rows = try db.rows(
            """
            SELECT c.id, c.name, c.is_default,
                   COUNT(DISTINCT v.id) AS word_count,
                   SUM(CASE WHEN ca.suspended_at IS NULL AND ca.due_at <= ?
                        THEN 1 ELSE 0 END) AS due_now,
                   MAX(v.created_at) AS last_added
            FROM collections c
            LEFT JOIN vocab_items v ON v.collection_id = c.id
            LEFT JOIN cards ca ON ca.vocab_item_id = v.id
            GROUP BY c.id
            ORDER BY c.is_default DESC, c.name COLLATE NOCASE;
            """,
            [.text(nowIso)])
        return try rows.map { row in
            guard row.count >= 6 else {
                throw DatabaseError.failed(
                    "thiếu cột summary", statement: "collection_summaries")
            }
            return CollectionSummary(
                id: row[0].textValue ?? "",
                name: row[1].textValue ?? "",
                isDefault: (row[2].intValue ?? 0) != 0,
                wordCount: Int(row[3].intValue ?? 0),
                dueNow: Int(row[4].intValue ?? 0),
                lastAddedAt: row[5].textValue.flatMap { ISOTimestamp.date(from: $0) })
        }
    }

    // MARK: — FR-17(b)(c) Collection Management

    /// Chuyển một lô từ sang collection khác — CHỈ đổi `vocab_items.collection_id`,
    /// KHÔNG chạm `cards` → thẻ giữ nguyên toàn bộ lịch FSRS (FR-17: collection
    /// là nhãn ngữ cảnh, không phải danh tính của thẻ). Trả số item được chỉ định.
    @discardableResult
    public static func moveVocabularyItems(
        on db: SQLiteDatabase,
        fromCollectionID: String,
        itemIDs: [String],
        toCollectionID: String
    ) throws -> Int {
        guard !itemIDs.isEmpty else { return 0 }
        let targetExists = try db.scalarInt64(
            "SELECT 1 FROM collections WHERE id = ? LIMIT 1;",
            [.text(toCollectionID)])
        guard (targetExists ?? 0) != 0 else {
            throw CollectionError.notFound
        }
        let placeholders = itemIDs.map { _ in "?" }.joined(separator: ",")
        let params: [SQLValue] = [.text(toCollectionID), .text(fromCollectionID)]
            + itemIDs.map { .text($0) }
        try db.run(
            """
            UPDATE vocab_items
               SET collection_id = ?
             WHERE collection_id = ?
               AND id IN (\(placeholders));
            """,
            params)
        return itemIDs.count
    }

    /// Đổi tên collection — kho tạm vẫn đổi được (FR-17). Trả `false` khi tên rỗng
    /// hoặc trùng tên collection khác (idx_collections_name unique — NOCASE ASCII).
    @discardableResult
    public static func renameCollection(
        on db: SQLiteDatabase, id: String, name: String
    ) throws -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            try db.run(
                """
                UPDATE collections SET name = ? WHERE id = ?;
                """,
                [.text(trimmed), .text(id)])
            return true
        } catch DatabaseError.failed(_, _) {
            // Trùng tên (idx_collections_name) → false.
            return false
        }
    }

    /// Xoá collection (chỉ named). Kho tạm → `.cannotDeleteDefault`. Còn từ mà
    /// không chỉ đích chuyển → `.hasWords(n)`. Có đích → chuyển toàn bộ từ sang
    /// rồi xoá trong 1 transaction, trả số từ đã chuyển (0 khi collection rỗng).
    @discardableResult
    public static func deleteCollection(
        on db: SQLiteDatabase, id: String, moveWordsTo targetID: String? = nil
    ) throws -> Int {
        guard let isDefault = try db.scalarInt64(
            "SELECT is_default FROM collections WHERE id = ? LIMIT 1;",
            [.text(id)])
        else {
            throw CollectionError.notFound
        }
        guard isDefault == 0 else { throw CollectionError.cannotDeleteDefault }

        let wordCount = try db.scalarInt64(
            "SELECT COUNT(*) FROM vocab_items WHERE collection_id = ?;",
            [.text(id)]) ?? 0

        if wordCount == 0 {
            try db.run("DELETE FROM collections WHERE id = ?;", [.text(id)])
            return 0
        }
        // FR-17: còn từ → bắt buộc chỉ đích chuyển (nói rõ số từ bị ảnh hưởng).
        guard let targetID else { throw CollectionError.hasWords(Int(wordCount)) }
        let targetExists = try db.scalarInt64(
            "SELECT 1 FROM collections WHERE id = ? LIMIT 1;",
            [.text(targetID)])
        guard (targetExists ?? 0) != 0 else { throw CollectionError.notFound }

        try db.inTransaction {
            try db.run(
                "UPDATE vocab_items SET collection_id = ? WHERE collection_id = ?;",
                [.text(targetID), .text(id)])
            try db.run("DELETE FROM collections WHERE id = ?;", [.text(id)])
        }
        return Int(wordCount)
    }
}