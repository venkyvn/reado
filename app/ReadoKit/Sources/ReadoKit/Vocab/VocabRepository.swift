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
        /// Q-08 "đã thuộc" (`Mastery.stabilityThreshold`) — số VOCAB ITEM (không
        /// phải card) có ≥1 card `state='review'`, `stability >= ngưỡng`, chưa
        /// suspend. Ý 4 (motivation-r1) — "Đã thuộc X/Y" ở hub + dòng bộ Kho.
        public let masteredCount: Int
        /// Thanh 4 màu ở header collection (cram-collection-r1 T3) — đếm theo TỪ,
        /// mỗi từ đúng 1 nhóm theo ưu tiên Đã thuộc (`masteredCount`) › Đang học ›
        /// Đang nhớ › Chưa học; từ chỉ còn thẻ suspended không thuộc nhóm nào.
        /// "Đang học": có thẻ `learning`/`relearning`, chưa thuộc.
        public let learningCount: Int
        /// "Đang nhớ": có thẻ `review`, không có thẻ learning/relearning, chưa thuộc.
        public let reviewingCount: Int
        /// "Chưa học": còn lại (chỉ thẻ `new`, hoặc chưa có thẻ nào).
        public let notStartedCount: Int
        /// Số từ có `created_at` trong 7 ngày gần nhất tính tới `now`.
        public let addedLast7Days: Int
        /// Số THẻ Cram được — điều kiện y hệt `ReviewQueue.crammableCount`
        /// (state ≠ new, chưa suspend, `due_at > now`).
        public let crammableCount: Int
    }

    /// Lần ôn kế tiếp của một collection — mốc sớm nhất sau `now` và số thẻ đến
    /// hạn trong cùng ngày học (FR-11, giờ chuyển ngày — không nửa đêm).
    public struct NextDue: Equatable, Sendable {
        public let date: Date
        public let count: Int
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

    /// Q-08: stability từ mức này trở lên, state `review`, là "đã thuộc".
    /// `known_stability` NULL trong settings cũng dùng số này — NULL không tắt lọc.
    /// Cùng hằng số với `Mastery.stabilityThreshold` (toast ăn mừng ADR-038) —
    /// không chép số 21 hai nơi.
    public static let defaultMatureStability = Mastery.stabilityThreshold

    /// Khoá so khớp FR-10: form từ (không lemmatize) + loại từ, trong một collection.
    public static func matureKey(term: String, pos: String) -> String {
        let posKey = pos.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedTerm(term))|\(posKey)"
    }

    /// Term+pos đã thuộc trong đúng collection (Q-09). Không tính leech
    /// (`suspended_at`) và không tính collection khác.
    public static func matureKeys(
        on db: SQLiteDatabase, collectionID: String
    ) throws -> Set<String> {
        let setting = try db.rows(
            "SELECT known_stability FROM settings WHERE id = 1 LIMIT 1;")
        let threshold = setting.first?.first?.doubleValue ?? defaultMatureStability
        let rows = try db.rows(
            """
            SELECT v.term_normalized, v.pos
            FROM vocab_items v
            JOIN cards c ON c.vocab_item_id = v.id
            WHERE v.collection_id = ?
              AND c.state = 'review'
              AND c.stability >= ?
              AND c.suspended_at IS NULL;
            """,
            [.text(collectionID), .double(threshold)])
        return Set(rows.compactMap { row in
            guard row.count >= 2,
                  let term = row[0].textValue,
                  let pos = row[1].textValue
            else { return nil }
            return "\(term)|\(pos.lowercased())"
        })
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
    /// `segments`/`summaryVI` (FR-05/06) chỉ ghi thành phiên đọc khi đích là
    /// collection có tên — kho tạm KHÔNG lưu phiên (Q-10/ADR-029).
    public static func saveCapture(
        on db: SQLiteDatabase,
        items: [PageAnalysis.VocabularyItemIn],
        collectionID: String?,
        segments: [PageAnalysis.Segment] = [],
        summaryVI: String = "",
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
        // Q-10/ADR-029: phiên đọc chỉ tồn tại với collection có tên (kho tạm thì
        // không). Đọc cờ một lần để khỏi kiểm lại trong vòng lặp.
        let isNamed: Bool = (try db.scalarInt64(
            "SELECT is_default FROM collections WHERE id = ? LIMIT 1;",
            [.text(targetID)]) ?? 1) == 0
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
            // SD §6 khối #5 — ghi phiên đọc CÙNG transaction (inTransaction không
            // nest được). Chỉ khi đích là collection có tên + có nội dung.
            if isNamed && (!segments.isEmpty || !summaryVI.isEmpty) {
                try ReadingSessionRepository.insertInsideTransaction(
                    on: db,
                    collectionID: targetID,
                    createdAt: now,
                    segments: segments,
                    summary: summaryVI.isEmpty ? nil : summaryVI)
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
    /// suspend), lần thêm từ gần nhất, số từ đã thuộc (Q-08, ý 4 motivation-r1).
    /// `COUNT(DISTINCT v.id)` chống việc JOIN cards nhân dòng (một vocab tối đa
    /// 2 card theo direction) — áp dụng cả cho `mastered_count`.
    public static func allCollectionSummaries(
        on db: SQLiteDatabase, now: Date
    ) throws -> [CollectionSummary] {
        let nowIso = ISOTimestamp.string(from: now)
        let sevenDaysAgoIso = ISOTimestamp.string(
            from: now.addingTimeInterval(-7 * 86_400))
        // Bảng dẫn xuất `b` gom theo TỪ (1 dòng / từ) rồi theo collection: mỗi từ
        // vào đúng 1 nhóm (m > l > r > active). Thứ tự bind theo vị trí `?` trong
        // SQL: due_now, mastered (ngưỡng), added7, crammable, rồi ngưỡng trong `b`.
        let rows = try db.rows(
            """
            SELECT c.id, c.name, c.is_default,
                   COUNT(DISTINCT v.id) AS word_count,
                   SUM(CASE WHEN ca.suspended_at IS NULL AND ca.due_at <= ?
                        THEN 1 ELSE 0 END) AS due_now,
                   MAX(v.created_at) AS last_added,
                   COUNT(DISTINCT CASE
                        WHEN ca.state = 'review' AND ca.stability >= ?
                             AND ca.suspended_at IS NULL
                        THEN v.id END) AS mastered_count,
                   COALESCE(MAX(b.learning_count), 0) AS learning_count,
                   COALESCE(MAX(b.reviewing_count), 0) AS reviewing_count,
                   COALESCE(MAX(b.not_started_count), 0) AS not_started_count,
                   COUNT(DISTINCT CASE WHEN v.created_at >= ? THEN v.id END)
                        AS added_7d,
                   COALESCE(SUM(CASE
                        WHEN ca.state != 'new' AND ca.suspended_at IS NULL
                             AND ca.due_at > ?
                        THEN 1 ELSE 0 END), 0) AS crammable_count
            FROM collections c
            LEFT JOIN vocab_items v ON v.collection_id = c.id
            LEFT JOIN cards ca ON ca.vocab_item_id = v.id
            LEFT JOIN (
                SELECT cid,
                    SUM(CASE WHEN m = 0 AND l = 1 THEN 1 ELSE 0 END)
                        AS learning_count,
                    SUM(CASE WHEN m = 0 AND l = 0 AND r = 1 THEN 1 ELSE 0 END)
                        AS reviewing_count,
                    SUM(CASE WHEN m = 0 AND l = 0 AND r = 0 AND active = 1
                        THEN 1 ELSE 0 END) AS not_started_count
                FROM (
                    SELECT v2.collection_id AS cid, v2.id,
                        MAX(CASE WHEN ca2.suspended_at IS NULL
                                  AND ca2.state = 'review' AND ca2.stability >= ?
                            THEN 1 ELSE 0 END) AS m,
                        MAX(CASE WHEN ca2.suspended_at IS NULL
                                  AND ca2.state IN ('learning', 'relearning')
                            THEN 1 ELSE 0 END) AS l,
                        MAX(CASE WHEN ca2.suspended_at IS NULL
                                  AND ca2.state = 'review'
                            THEN 1 ELSE 0 END) AS r,
                        MAX(CASE WHEN ca2.id IS NULL OR ca2.suspended_at IS NULL
                            THEN 1 ELSE 0 END) AS active
                    FROM vocab_items v2
                    LEFT JOIN cards ca2 ON ca2.vocab_item_id = v2.id
                    GROUP BY v2.id
                )
                GROUP BY cid
            ) b ON b.cid = c.id
            GROUP BY c.id
            ORDER BY c.is_default DESC, c.name COLLATE NOCASE;
            """,
            [
                .text(nowIso), .double(Mastery.stabilityThreshold),
                .text(sevenDaysAgoIso), .text(nowIso),
                .double(Mastery.stabilityThreshold),
            ])
        return try rows.map { row in
            guard row.count >= 12 else {
                throw DatabaseError.failed(
                    "thiếu cột summary", statement: "collection_summaries")
            }
            return CollectionSummary(
                id: row[0].textValue ?? "",
                name: row[1].textValue ?? "",
                isDefault: (row[2].intValue ?? 0) != 0,
                wordCount: Int(row[3].intValue ?? 0),
                dueNow: Int(row[4].intValue ?? 0),
                lastAddedAt: row[5].textValue.flatMap { ISOTimestamp.date(from: $0) },
                masteredCount: Int(row[6].intValue ?? 0),
                learningCount: Int(row[7].intValue ?? 0),
                reviewingCount: Int(row[8].intValue ?? 0),
                notStartedCount: Int(row[9].intValue ?? 0),
                addedLast7Days: Int(row[10].intValue ?? 0),
                crammableCount: Int(row[11].intValue ?? 0))
        }
    }

    /// Lần ôn kế tiếp của một collection: `MIN(due_at)` của thẻ chưa suspend có
    /// `due_at > now`, và số thẻ (chưa suspend, `due_at > now`) rơi trong cùng ngày
    /// học chứa mốc đó (`ReviewQueue.currentDayWindow` — giờ chuyển ngày FR-11).
    /// nil = không còn lịch nào sau `now`.
    public static func nextDue(
        on db: SQLiteDatabase, collectionID: String, now: Date
    ) throws -> NextDue? {
        let nowIso = ISOTimestamp.string(from: now)
        // `MIN` trả NULL khi không còn thẻ nào → đọc qua `rows` (scalarString ném lỗi).
        let minRows = try db.rows(
            """
            SELECT MIN(ca.due_at) FROM cards ca
            JOIN vocab_items v ON v.id = ca.vocab_item_id
            WHERE v.collection_id = ? AND ca.suspended_at IS NULL
              AND ca.due_at > ?;
            """, [.text(collectionID), .text(nowIso)])
        guard
            let minIso = minRows.first?.first?.textValue,
            let minDate = ISOTimestamp.date(from: minIso)
        else { return nil }
        let window = ReviewQueue.currentDayWindow(on: db, now: minDate)
        let count = try db.scalarInt64(
            """
            SELECT COUNT(*) FROM cards ca
            JOIN vocab_items v ON v.id = ca.vocab_item_id
            WHERE v.collection_id = ? AND ca.suspended_at IS NULL
              AND ca.due_at > ? AND ca.due_at >= ? AND ca.due_at < ?;
            """,
            [.text(collectionID), .text(nowIso), .text(window.start),
             .text(window.end)]) ?? 0
        return NextDue(date: minDate, count: Int(count))
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