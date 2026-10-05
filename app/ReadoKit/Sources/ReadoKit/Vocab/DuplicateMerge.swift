import Foundation

/// FR-24 / ADR-067 — gộp các dòng `vocab_items` trùng khoá `VocabRepository.matureKey`
/// (`term_normalized + pos`) có từ trước ADR-066. Fen duyệt từng nhóm (UI chọn dòng nào gộp);
/// ReadoKit chỉ lo chọn thẻ giữ lại và gộp trong MỘT transaction. Không có `unique` trên
/// `vocab_items` (luật cứng) — gộp là thao tác có người duyệt, không phải ràng buộc DB.
///
/// Không đụng FSRS: thẻ giữ lại không đổi một cột nào; chỉ `review_logs`/`encounters` của dòng
/// bị gộp được chuyển sang, câu gốc của nó thành một `encounters.seen` (vision #4).
public enum DuplicateMerge {

    public struct Member: Equatable, Identifiable, Sendable {
        public var id: String { vocabItemID }
        public let vocabItemID: String
        public let term: String
        public let pos: String
        public let meaningVI: String
        public let example: String
        public let collectionID: String
        public let collectionName: String
        /// ISO-8601 UTC `Z`.
        public let createdAt: String
        /// Thẻ `receptive`; nil nếu dòng không còn thẻ (vd `LeechService.deleteCard`).
        public let cardID: String?
        /// `new` khi không có thẻ.
        public let state: String
        public let stability: Double
        public let lastReviewAt: String?
        public let isSuspended: Bool
        public let recognizedCount: Int

        public var level: Mastery.Level {
            Mastery.level(state: state, stability: stability, recognizedCount: recognizedCount)
        }

        public init(
            vocabItemID: String,
            term: String = "",
            pos: String = "noun",
            meaningVI: String = "",
            example: String = "",
            collectionID: String = "",
            collectionName: String = "",
            createdAt: String = "2026-09-01T00:00:00Z",
            cardID: String? = nil,
            state: String = "new",
            stability: Double = 0,
            lastReviewAt: String? = nil,
            isSuspended: Bool = false,
            recognizedCount: Int = 0
        ) {
            self.vocabItemID = vocabItemID
            self.term = term
            self.pos = pos
            self.meaningVI = meaningVI
            self.example = example
            self.collectionID = collectionID
            self.collectionName = collectionName
            self.createdAt = createdAt
            self.cardID = cardID
            self.state = state
            self.stability = stability
            self.lastReviewAt = lastReviewAt
            self.isSuspended = isSuspended
            self.recognizedCount = recognizedCount
        }
    }

    public struct Group: Equatable, Identifiable, Sendable {
        public var id: String { key }
        /// `VocabRepository.matureKey`.
        public let key: String
        /// Dòng `keeper(of:)` đứng đầu, còn lại theo `created_at, id`.
        public let members: [Member]
    }

    /// Một nhóm đã duyệt: giữ `keeperID`, gộp các `mergedIDs` vào đó.
    public struct Selection: Equatable, Sendable {
        public let keeperID: String
        public let mergedIDs: [String]

        public init(keeperID: String, mergedIDs: [String]) {
            self.keeperID = keeperID
            self.mergedIDs = mergedIDs
        }
    }

    public struct Summary: Equatable, Sendable {
        public let groupsMerged: Int
        public let rowsMerged: Int

        public init(groupsMerged: Int, rowsMerged: Int) {
            self.groupsMerged = groupsMerged
            self.rowsMerged = rowsMerged
        }
    }

    public enum MergeError: Error, Equatable {
        /// Dòng gộp khác khoá `term|pos` với dòng giữ (màn duyệt đã cũ).
        case keyMismatch(keeperID: String, mergedID: String)
        /// Không còn dòng này trong kho.
        case missingRow(String)
    }

    // MARK: — Nhóm trùng

    /// Mọi khoá có ≥ 2 dòng trong kho (toàn app, mọi collection), sắp theo khoá.
    public static func groups(on db: SQLiteDatabase) throws -> [Group] {
        let rows = try db.rows(
            """
            SELECT v.id AS id, v.term AS term, v.term_normalized AS term_normalized,
                   v.pos AS pos, v.meaning_vi AS meaning_vi, v.example AS example,
                   v.collection_id AS collection_id, col.name AS collection_name,
                   v.created_at AS created_at,
                   c.id AS card_id, c.state AS state, c.stability AS stability,
                   c.last_review_at AS last_review_at, c.suspended_at AS suspended_at,
                   (SELECT COUNT(*) FROM encounters e
                     WHERE e.vocab_item_id = v.id AND e.kind = 'recognized') AS recognized_count
            FROM vocab_items v
            JOIN collections col ON col.id = v.collection_id
            LEFT JOIN cards c ON c.vocab_item_id = v.id AND c.direction = 'receptive'
            ORDER BY v.created_at, v.id;
            """,
            [])
        var byKey: [String: [Member]] = [:]
        for row in rows {
            guard let id = row["id"].textValue,
                  let termNormalized = row["term_normalized"].textValue,
                  let pos = row["pos"].textValue
            else { continue }
            let key = VocabRepository.matureKey(term: termNormalized, pos: pos)
            byKey[key, default: []].append(
                Member(
                    vocabItemID: id,
                    term: row["term"].textValue ?? termNormalized,
                    pos: pos,
                    meaningVI: row["meaning_vi"].textValue ?? "",
                    example: row["example"].textValue ?? "",
                    collectionID: row["collection_id"].textValue ?? "",
                    collectionName: row["collection_name"].textValue ?? "",
                    createdAt: row["created_at"].textValue ?? "",
                    cardID: row["card_id"].textValue,
                    state: row["state"].textValue ?? "new",
                    stability: number(row["stability"]),
                    lastReviewAt: row["last_review_at"].textValue,
                    isSuspended: !row["suspended_at"].isNull,
                    recognizedCount: Int(row["recognized_count"].intValue ?? 0)))
        }
        return byKey
            .filter { $0.value.count >= 2 }
            .sorted { $0.key < $1.key }
            .map { key, members in
                let first = keeper(of: members)
                let rest = members.filter { $0.vocabItemID != first?.vocabItemID }
                return Group(key: key, members: (first.map { [$0] } ?? []) + rest)
            }
    }

    /// Dòng/thẻ được giữ lại: không leech trước → `stability` cao nhất → `last_review_at` mới nhất
    /// (nil xếp cuối) → `created_at` cũ nhất → `id` nhỏ nhất. Hàm THUẦN — UI gọi lại trên các dòng
    /// ĐANG CHỌN để nhãn "Giữ thẻ này" đúng khi fen bỏ chọn dòng giữ.
    public static func keeper(of members: [Member]) -> Member? {
        members.min(by: isBetterKeeper)
    }

    private static func isBetterKeeper(_ a: Member, _ b: Member) -> Bool {
        if a.isSuspended != b.isSuspended { return !a.isSuspended }
        if a.stability != b.stability { return a.stability > b.stability }
        if a.lastReviewAt != b.lastReviewAt {
            guard let x = a.lastReviewAt else { return false }
            guard let y = b.lastReviewAt else { return true }
            return x > y
        }
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.vocabItemID < b.vocabItemID
    }

    // MARK: — Gộp

    /// Gộp mọi `selections` trong MỘT transaction (lỗi bất kỳ → rollback toàn bộ). Selection có
    /// `mergedIDs` rỗng thì bỏ qua. Mỗi dòng gộp L vào dòng giữ K:
    /// 1. `review_logs` của thẻ L chuyển sang thẻ K (K chưa có thẻ thì thẻ L chuyển sang K).
    /// 2. `encounters` của L chuyển sang K; `recognized` trùng ngày học (FR-11) với một `recognized`
    ///    đã có của K thì bỏ (giữ luật một lần/ngày của FR-22).
    /// 3. Thêm một `seen` mang `example`/`collection_id`/`created_at` của L.
    /// 4. Xoá dòng L (thẻ còn lại của L đi theo cascade).
    /// Không gọi `ReviewService`, không ghi gì vào `cards` của K.
    @discardableResult
    public static func merge(
        on db: SQLiteDatabase, selections: [Selection]
    ) throws -> Summary {
        let active = selections.filter { selection in
            selection.mergedIDs.contains { $0 != selection.keeperID }
        }
        guard !active.isEmpty else { return Summary(groupsMerged: 0, rowsMerged: 0) }
        let (timezone, cutoffHour) = DayContext.read(on: db)
        return try db.inTransaction { () throws -> Summary in
            var rowsMerged = 0
            for selection in active {
                guard let keeper = try loadRow(on: db, id: selection.keeperID) else {
                    throw MergeError.missingRow(selection.keeperID)
                }
                var keeperCardID = keeper.cardID
                var recognizedDays = try learningDays(
                    on: db, vocabItemID: keeper.id, timezone: timezone, cutoffHour: cutoffHour)
                var seen = Set<String>()
                for mergedID in selection.mergedIDs
                where mergedID != selection.keeperID && seen.insert(mergedID).inserted {
                    guard let row = try loadRow(on: db, id: mergedID) else {
                        throw MergeError.missingRow(mergedID)
                    }
                    guard row.key == keeper.key else {
                        throw MergeError.keyMismatch(keeperID: keeper.id, mergedID: mergedID)
                    }
                    if let mergedCard = row.cardID {
                        if let keeperCard = keeperCardID {
                            try db.run(
                                "UPDATE review_logs SET card_id = ? WHERE card_id = ?;",
                                [.text(keeperCard), .text(mergedCard)])
                        } else {
                            try db.run(
                                "UPDATE cards SET vocab_item_id = ? WHERE id = ?;",
                                [.text(keeper.id), .text(mergedCard)])
                            keeperCardID = mergedCard
                        }
                    }
                    try moveEncounters(
                        on: db, from: row.id, to: keeper.id, recognizedDays: &recognizedDays,
                        timezone: timezone, cutoffHour: cutoffHour)
                    let sentence = row.example.trimmingCharacters(in: .whitespacesAndNewlines)
                    try EncounterRepository.insert(
                        on: db, vocabItemID: keeper.id, kind: .seen, createdAt: row.createdAt,
                        sentence: sentence.isEmpty ? nil : sentence,
                        collectionID: row.collectionID)
                    try db.run("DELETE FROM vocab_items WHERE id = ?;", [.text(row.id)])
                    rowsMerged += 1
                }
            }
            return Summary(groupsMerged: active.count, rowsMerged: rowsMerged)
        }
    }

    // MARK: — Nội bộ

    private struct Row {
        let id: String
        let key: String
        let example: String
        let collectionID: String
        let createdAt: String
        let cardID: String?
    }

    private static func loadRow(on db: SQLiteDatabase, id: String) throws -> Row? {
        let rows = try db.rows(
            """
            SELECT v.id AS id, v.term_normalized AS term_normalized, v.pos AS pos,
                   v.example AS example, v.collection_id AS collection_id,
                   v.created_at AS created_at, c.id AS card_id
            FROM vocab_items v
            LEFT JOIN cards c ON c.vocab_item_id = v.id AND c.direction = 'receptive'
            WHERE v.id = ?;
            """,
            [.text(id)])
        guard let row = rows.first,
              let rowID = row["id"].textValue,
              let term = row["term_normalized"].textValue,
              let pos = row["pos"].textValue
        else { return nil }
        return Row(
            id: rowID,
            key: VocabRepository.matureKey(term: term, pos: pos),
            example: row["example"].textValue ?? "",
            collectionID: row["collection_id"].textValue ?? "",
            createdAt: row["created_at"].textValue ?? "",
            cardID: row["card_id"].textValue)
    }

    /// Đầu cửa sổ ngày học (FR-11) của mỗi lần `recognized` của một vocab.
    private static func learningDays(
        on db: SQLiteDatabase, vocabItemID: String, timezone: TimeZone, cutoffHour: Int
    ) throws -> Set<String> {
        let rows = try db.rows(
            "SELECT created_at FROM encounters WHERE vocab_item_id = ? AND kind = 'recognized';",
            [.text(vocabItemID)])
        return Set(rows.compactMap { row in
            dayStart(row.first?.textValue, timezone: timezone, cutoffHour: cutoffHour)
        })
    }

    private static func moveEncounters(
        on db: SQLiteDatabase, from sourceID: String, to targetID: String,
        recognizedDays: inout Set<String>, timezone: TimeZone, cutoffHour: Int
    ) throws {
        let recognized = try db.rows(
            """
            SELECT id, created_at FROM encounters
            WHERE vocab_item_id = ? AND kind = 'recognized'
            ORDER BY created_at, id;
            """,
            [.text(sourceID)])
        for row in recognized {
            guard let encounterID = row[0].textValue else { continue }
            let day = dayStart(row[1].textValue, timezone: timezone, cutoffHour: cutoffHour)
            if let day, !recognizedDays.insert(day).inserted {
                try db.run("DELETE FROM encounters WHERE id = ?;", [.text(encounterID)])
            }
        }
        try db.run(
            "UPDATE encounters SET vocab_item_id = ? WHERE vocab_item_id = ?;",
            [.text(targetID), .text(sourceID)])
    }

    private static func dayStart(
        _ iso: String?, timezone: TimeZone, cutoffHour: Int
    ) -> String? {
        guard let iso, let date = ISOTimestamp.date(from: iso) else { return nil }
        return DayBoundary.window(
            now: date, timezone: timezone, dayCutoffHour: cutoffHour).start
    }

    private static func number(_ value: SQLValue) -> Double {
        value.doubleValue ?? value.intValue.map(Double.init) ?? 0
    }
}
