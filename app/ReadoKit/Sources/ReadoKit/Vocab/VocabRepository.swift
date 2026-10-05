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

/// ADR-066: một nghĩa đã có trong kho (bất kể collection, bất kể trạng thái thẻ).
public struct KnownSense: Equatable, Sendable {
    public let vocabItemID: String
    public let meaningVI: String
    public let collectionName: String
    public let isMature: Bool
    public let isLeech: Bool

    public init(
        vocabItemID: String, meaningVI: String, collectionName: String,
        isMature: Bool, isLeech: Bool
    ) {
        self.vocabItemID = vocabItemID
        self.meaningVI = meaningVI
        self.collectionName = collectionName
        self.isMature = isMature
        self.isLeech = isLeech
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
        /// "Đã thấm" (reencounter-r1 T3): số TỪ đạt Q-08 (thuộc `masteredCount`)
        /// VÀ có ≥ 1 lần `recognized` — tập con của `masteredCount`. "Đã nhớ" =
        /// `masteredCount − absorbedCount`.
        public let absorbedCount: Int
        /// Số từ có `created_at` trong 7 ngày gần nhất tính tới `now`.
        public let addedLast7Days: Int
        /// Số thẻ đã học, chưa suspend, chưa đến hạn (`due_at > window.end`) —
        /// phần "ôn sớm" của Ôn thêm (extra-review-r1), KHÔNG gồm từ mới. Dùng
        /// cho CTA header; hàng đợi Ôn thêm thật sự tính qua
        /// `ReviewQueue.extraAvailableCount` (có thêm bộ lọc "chưa ôn hôm nay").
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
    /// (`suspended_at`) và không tính collection khác. Wrapper của
    /// `matureSenses` (chỉ lấy khoá) — giữ cho call site chỉ cần tập khoá.
    public static func matureKeys(
        on db: SQLiteDatabase, collectionID: String
    ) throws -> Set<String> {
        Set(try matureSenses(on: db, collectionID: collectionID).keys)
    }

    /// Q-13 phương án B (ADR-056): khoá `term|pos` → `meaning_vi` của MỌI dòng
    /// đã thuộc cùng khoá, trong đúng collection (Q-09). Cùng điều kiện
    /// `matureKeys` (`state='review'`, `stability >= known_stability ?? 21`,
    /// `suspended_at IS NULL`). Dùng để gập (không xoá) item khớp khoá trên màn
    /// duyệt, kèm nghĩa trong kho cho người dùng tự so — không còn im lặng loại
    /// nghĩa mới cùng khoá (Context — lệch spec cũ).
    public static func matureSenses(
        on db: SQLiteDatabase, collectionID: String
    ) throws -> [String: [String]] {
        let setting = try db.rows(
            "SELECT known_stability FROM settings WHERE id = 1 LIMIT 1;")
        let threshold = setting.first?.first?.doubleValue ?? defaultMatureStability
        let rows = try db.rows(
            """
            SELECT v.term_normalized AS term_normalized, v.pos AS pos,
                   v.meaning_vi AS meaning_vi
            FROM vocab_items v
            JOIN cards c ON c.vocab_item_id = v.id
            WHERE v.collection_id = ?
              AND c.state = 'review'
              AND c.stability >= ?
              AND c.suspended_at IS NULL;
            """,
            [.text(collectionID), .double(threshold)])
        var result: [String: [String]] = [:]
        for row in rows {
            guard let term = row["term_normalized"].textValue,
                  let pos = row["pos"].textValue
            else { continue }
            let key = "\(term)|\(pos.lowercased())"
            result[key, default: []].append(row["meaning_vi"].textValue ?? "")
        }
        return result
    }

    /// ADR-066 (đảo Q-09 cho FR-10): khoá `matureKey` -> mọi nghĩa đã có, MỌI collection,
    /// mọi trạng thái (D2). Một phần tử mỗi vocab_item. Ngưỡng "đã thuộc" như `matureSenses`.
    public static func knownSenses(on db: SQLiteDatabase) throws -> [String: [KnownSense]] {
        let setting = try db.rows(
            "SELECT known_stability FROM settings WHERE id = 1 LIMIT 1;")
        let threshold = setting.first?.first?.doubleValue ?? defaultMatureStability
        let rows = try db.rows(
            """
            SELECT v.id AS id, v.term_normalized AS term_normalized, v.pos AS pos,
                   v.meaning_vi AS meaning_vi, col.name AS collection_name,
                   MAX(CASE WHEN c.state = 'review' AND c.stability >= ?
                            AND c.suspended_at IS NULL THEN 1 ELSE 0 END) AS is_mature,
                   MAX(CASE WHEN c.suspended_at IS NOT NULL THEN 1 ELSE 0 END) AS is_leech
            FROM vocab_items v
            JOIN collections col ON col.id = v.collection_id
            LEFT JOIN cards c ON c.vocab_item_id = v.id
            GROUP BY v.id
            ORDER BY v.created_at, v.id;
            """,
            [.double(threshold)])
        var result: [String: [KnownSense]] = [:]
        for row in rows {
            guard let term = row["term_normalized"].textValue,
                  let pos = row["pos"].textValue
            else { continue }
            let key = matureKey(term: term, pos: pos)
            result[key, default: []].append(
                KnownSense(
                    vocabItemID: row["id"].textValue ?? "",
                    meaningVI: row["meaning_vi"].textValue ?? "",
                    collectionName: row["collection_name"].textValue ?? "",
                    isMature: (row["is_mature"].intValue ?? 0) != 0,
                    isLeech: (row["is_leech"].intValue ?? 0) != 0))
        }
        return result
    }

    /// FR-09 / ADR-066 D1: số từ đã lưu trong NGÀY HỌC hiện tại (giờ chuyển ngày FR-11).
    /// Tính cả từ nhập CSV (Q3 — không phân biệt được nguồn).
    public static func newSavedToday(on db: SQLiteDatabase, now: Date) throws -> Int {
        let window = ReviewQueue.currentDayWindow(on: db, now: now)
        return Int(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM vocab_items WHERE created_at >= ? AND created_at < ?;",
                [.text(window.start), .text(window.end)]) ?? 0)
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
        contextOnly: [ContextOnlyItem] = [],
        now: Date
    ) throws -> Int {
        guard !items.isEmpty || !contextOnly.isEmpty else { return 0 }
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
            guard let inboxID = try defaultCollectionID(on: db) else {
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
            // FR-22: dựng matcher TRƯỚC khi chèn item mới — từ vừa lưu ở trang này
            // không phải "gặp lại". Không có đoạn gốc thì không có gì để dò.
            var seenMatcher: EncounterMatcher?
            if !segments.isEmpty {
                seenMatcher = EncounterMatcher(
                    lexicon: try EncounterRepository.loadLexicon(on: db))
            }
            // ADR-066 Q8: từ để lại trong nhóm "Đã có" — tra id TRƯỚC khi chèn item mới
            // (khỏi nhầm với dòng vừa lưu); leech bị loại (không ghi `seen`).
            var contextOnlyIDs: [(id: String, example: String?)] = []
            for item in contextOnly {
                let posKey = item.pos.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let rows = try db.rows(
                    """
                    SELECT v.id AS id FROM vocab_items v
                    WHERE v.term_normalized = ? AND lower(trim(v.pos)) = ?
                      AND NOT EXISTS (
                        SELECT 1 FROM cards k
                        WHERE k.vocab_item_id = v.id AND k.suspended_at IS NOT NULL)
                    ORDER BY v.created_at, v.id;
                    """,
                    [.text(normalizedTerm(item.term)), .text(posKey)])
                for row in rows {
                    if let id = row["id"].textValue {
                        contextOnlyIDs.append((id, item.example))
                    }
                }
            }
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
            // FR-22 / SD §6 khối #8 — `seen` CÙNG transaction (kể cả kho tạm: trang vẫn
            // được đọc dù không lưu phiên).
            if seenMatcher != nil || !contextOnlyIDs.isEmpty {
                var contexts = seenMatcher?.contexts(in: segments.map(\.sourceEN)) ?? []
                let have = Set(contexts.map(\.vocabItemID))
                for entry in contextOnlyIDs where !have.contains(entry.id) {
                    contexts.append(EncounterContext(vocabItemID: entry.id, sentence: entry.example))
                }
                try EncounterRepository.insertSeen(
                    on: db, contexts: contexts, collectionID: targetID, now: now)
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
            SELECT v.id AS id, v.collection_id AS collection_id,
                   c.name AS collection_name, v.term AS term,
                   v.term_normalized AS term_normalized, v.pos AS pos,
                   v.ipa AS ipa, v.meaning_vi AS meaning_vi, v.example AS example,
                   v.cefr AS cefr, v.created_at AS created_at
            FROM vocab_items v
            JOIN collections c ON c.id = v.collection_id
            WHERE v.collection_id = ?
            ORDER BY \(orderClause);
            """,
            [.text(collectionID)])
        return rows.map(entry(from:))
    }

    private static func entry(from row: SQLRow) -> VocabularyListEntry {
        VocabularyListEntry(
            id: row["id"].textValue ?? "",
            collectionID: row["collection_id"].textValue ?? "",
            collectionName: row["collection_name"].textValue ?? "",
            term: row["term"].textValue ?? "",
            termNormalized: row["term_normalized"].textValue ?? "",
            pos: row["pos"].textValue ?? "other",
            ipa: row["ipa"].textValue,
            meaningVI: row["meaning_vi"].textValue ?? "",
            example: row["example"].textValue ?? "",
            cefr: row["cefr"].textValue,
            createdAt: ISOTimestamp.date(from: row["created_at"].textValue ?? "") ?? Date())
    }

    /// Gập cho tìm kiếm (khác `normalizedTerm` — khoá so khớp FR-10 giữ dấu). Bỏ dấu + lower +
    /// đ→d. SQLite NOCASE chỉ gập ASCII (CLAUDE.md §7) nên lọc ở tầng Swift.
    public static func searchFold(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
        return folded.replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// FR-08: tìm từ xuyên mọi collection theo term hoặc nghĩa, không phân biệt hoa/thường/dấu.
    public static func searchVocabulary(
        on db: SQLiteDatabase, query: String, limit: Int = 100
    ) throws -> [VocabularyListEntry] {
        let q = searchFold(query)
        guard !q.isEmpty else { return [] }
        let rows = try db.rows(
            """
            SELECT v.id AS id, v.collection_id AS collection_id,
                   c.name AS collection_name, v.term AS term,
                   v.term_normalized AS term_normalized, v.pos AS pos,
                   v.ipa AS ipa, v.meaning_vi AS meaning_vi, v.example AS example,
                   v.cefr AS cefr, v.created_at AS created_at
            FROM vocab_items v
            JOIN collections c ON c.id = v.collection_id
            ORDER BY v.term_normalized, v.pos, v.id;
            """, [])
        let entries = rows.map(entry(from:))
        let scored = entries.compactMap { entry -> (Int, VocabularyListEntry)? in
            let termFold = searchFold(entry.term)
            let meaningFold = searchFold(entry.meaningVI)
            if termFold.hasPrefix(q) { return (0, entry) }
            if termFold.contains(q) { return (1, entry) }
            if meaningFold.contains(q) { return (2, entry) }
            return nil
        }
        return scored.sorted { $0.0 < $1.0 }.prefix(limit).map(\.1)
    }
}
