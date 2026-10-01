import Foundation

// Tạo/liệt kê/đổi tên/chuyển từ/xoá collection (FR-17).
// Tách từ VocabRepository.swift (refactor): logic giữ nguyên.

extension VocabRepository {
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
        return rows.map { row in
            Collection(
                id: row["id"].textValue ?? "",
                name: row["name"].textValue ?? "",
                isDefault: (row["is_default"].intValue ?? 0) != 0,
                createdAt: ISOTimestamp.date(from: row["created_at"].textValue ?? "") ?? Date())
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
