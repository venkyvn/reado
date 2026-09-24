import Foundation

/// Hàng đợi ôn — HAI nhánh (rulebook mục 8). Shape đã chốt lúc task 2.5 ship:
/// - thẻ MỚI bị chặn bởi `daily_new_limit` (toàn cục, trước khi lọc scope);
/// - thẻ ÔN LẠI thì KHÔNG bị giới hạn này.
/// `suspended_at IS NULL`. FR-18 thêm `scope`: nil = tất cả collection.
public enum ReviewQueue {

    /// Nhánh 1 — thẻ mới đến hạn, quota = daily_new_limit trừ số thẻ mới đã
    /// giới thiệu hôm nay. `scope` (FR-18): nil = tất cả, ngược lại chỉ chọn
    /// card thuộc đúng các collection — hạn mức vẫn áp TOÀN CỤC trước (không nới).
    public static func newCardIDs(
        on db: SQLiteDatabase, quota: Int64, scope: Set<String>? = nil
    ) throws -> [String] {
        guard quota > 0 else { return [] }
        let (clause, binds) = inScopeClause(scope)
        var params = binds
        params.append(.int(quota))
        return try db.rows(
            """
            SELECT c.id FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state = 'new' AND c.suspended_at IS NULL
              AND \(clause)
            ORDER BY c.due_at, c.id
            LIMIT ?;
            """, params
        ).compactMap { $0.first?.textValue }
    }

    /// Nhánh 2 — thẻ ôn lại đã đến hạn tới cuối "hôm nay".
    /// KHÔNG có LIMIT theo daily_new_limit. `scope` (FR-18): nil = tất cả.
    public static func dueCardIDs(
        on db: SQLiteDatabase, dueBeforeIso: String, scope: Set<String>? = nil
    ) throws -> [String] {
        let (clause, binds) = inScopeClause(scope)
        var params: [SQLValue] = [.text(dueBeforeIso)]
        params.append(contentsOf: binds)
        return try db.rows(
            """
            SELECT c.id FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state IN ('review', 'relearning')
              AND c.suspended_at IS NULL
              AND c.due_at <= ?
              AND \(clause)
            ORDER BY c.due_at, c.id;
            """, params
        ).compactMap { $0.first?.textValue }
    }

    /// Số thẻ có review ĐẦU TIÊN nằm trong ngày hôm nay (thẻ "mới giới thiệu
    /// hôm nay") — dùng để trừ vào quota nhánh 1.
    public static func newIntroducedCount(
        on db: SQLiteDatabase, dayStartIso: String
    ) throws -> Int64 {
        let value = try db.scalarInt64(
            """
            SELECT COUNT(*) FROM cards c
            WHERE EXISTS (
                    SELECT 1 FROM review_logs l
                    WHERE l.card_id = c.id AND l.reviewed_at >= ?
                  )
              AND NOT EXISTS (
                    SELECT 1 FROM review_logs l2
                    WHERE l2.card_id = c.id AND l2.reviewed_at < ?
                  );
            """,
            [.text(dayStartIso), .text(dayStartIso)])
        return value ?? 0
    }

    /// FR-18: số thẻ ôn lại đã đến hạn nằm NGOÀI phạm vi đang chọn (nợ phải nhìn
    /// thấy — nếu scope nil / rỗng thì không có gì ngoài phạm vi, trả 0).
    public static func dueOutsideScopeCount(
        on db: SQLiteDatabase, dueBeforeIso: String, scope: Set<String>?
    ) throws -> Int64 {
        let (clause, binds) = outOfScopeClause(scope)
        guard !clause.isEmpty else { return 0 }
        var params: [SQLValue] = [.text(dueBeforeIso)]
        params.append(contentsOf: binds)
        let value = try db.scalarInt64(
            """
            SELECT COUNT(*) FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state IN ('review', 'relearning')
              AND c.suspended_at IS NULL
              AND c.due_at <= ?
              AND \(clause)
            """, params)
        return value ?? 0
    }

    /// Mệnh đề `v.collection_id IN (...)` cho card THUỘC phạm vi. nil / rỗng =
    /// tất cả (TRUE).
    private static func inScopeClause(
        _ scope: Set<String>?
    ) -> (sql: String, binds: [SQLValue]) {
        guard let scope, !scope.isEmpty else { return ("TRUE", []) }
        let placeholders = scope.map { _ in "?" }.joined(separator: ",")
        return (
            "v.collection_id IN (\(placeholders))",
            scope.map { .text($0) }
        )
    }

    /// Mệnh đề `v.collection_id NOT IN (...)` cho card NẰM NGOÀI phạm vi. nil /
    /// rỗng = không có gì ngoài (trả sql rỗng → caller trả 0).
    private static func outOfScopeClause(
        _ scope: Set<String>?
    ) -> (sql: String, binds: [SQLValue]) {
        guard let scope, !scope.isEmpty else { return ("", []) }
        let placeholders = scope.map { _ in "?" }.joined(separator: ",")
        return (
            "v.collection_id NOT IN (\(placeholders))",
            scope.map { .text($0) }
        )
    }

    // MARK: — FR-11 full queue façade (cards → [ReviewItem] + snapshot map)

    /// Một item hiển thị trên hàng đợi — FR-12 cần term/pos/meaning_vi/ipa/example/
    /// collectionName, FR-11 cần cardID做 key.
    public struct ReviewItem: Equatable, Identifiable, Sendable {
        public var id: String { cardID }
        public let cardID: String
        public let term: String
        public let pos: String
        public let meaningVI: String
        public let ipa: String?
        public let example: String
        public let collectionName: String

        public init(
            cardID: String,
            term: String,
            pos: String,
            meaningVI: String,
            ipa: String?,
            example: String,
            collectionName: String
        ) {
            self.cardID = cardID
            self.term = term
            self.pos = pos
            self.meaningVI = meaningVI
            self.ipa = ipa
            self.example = example
            self.collectionName = collectionName
        }
    }

    /// Đọc toàn bộ hàng đợi hiện tại (hai nhánh gộp) kèm chi tiết vocab
    /// + collection cho UI + map cardID→snapshot TRƯỚC (FR-12 undo cần).
    /// `dailyNewLimit` / `now` caller truyền vào để tính quota chính xác.
    public static func loadFullQueue(
        on db: SQLiteDatabase,
        dailyNewLimit: Int,
        now: Date,
        scope: Set<String>? = nil
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot]) {
        let nowIso = ISOTimestamp.string(from: now)
        // Tính dayStartIso theo settings.timezone + cutoff_hour.
        let timezoneID: String = (try? db.scalarString(
            "SELECT timezone FROM settings WHERE id = 1;")) ?? "UTC"
        let cutoffHour: Int = {
            if let v = try? db.scalarInt64(
                "SELECT day_cutoff_hour FROM settings WHERE id = 1;") {
                return Int(v)
            }
            return 4
        }()
        let tz = TimeZone(identifier: timezoneID) ?? .current
        let dayStartIso = DayBoundary.window(
            now: now, timezone: tz, dayCutoffHour: cutoffHour).start

        // Nhánh 1 — new (quota).
        let introduced = try newIntroducedCount(on: db, dayStartIso: dayStartIso)
        let remainingQuota = max(0, Int64(dailyNewLimit) - introduced)
        let newIDs = try newCardIDs(on: db, quota: remainingQuota, scope: scope)
        // Nhánh 2 — due (review/relearning, đến cuối ngày cutoff).
        let dueIDs = try dueCardIDs(on: db, dueBeforeIso: nowIso, scope: scope)
        let allCardIDs = newIDs + dueIDs
        guard !allCardIDs.isEmpty else { return ([], [:]) }

        let placeholders = allCardIDs.map { _ in "?" }.joined(separator: ",")
        let params: [SQLValue] = allCardIDs.map { .text($0) }
        let rows = try db.rows(
            """
            SELECT c.id AS card_id,
                   v.term, v.pos, v.ipa, v.meaning_vi, v.example,
                   col.name AS collection_name
            FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            JOIN collections col ON col.id = v.collection_id
            WHERE c.id IN (\(placeholders))
            ORDER BY c.due_at, c.id;
            """, params)

        var items: [ReviewItem] = []
        var snapshots: [String: CardSnapshot] = [:]
        for row in rows {
            let cardID = row[0].textValue ?? ""
            let item = ReviewItem(
                cardID: cardID,
                term: row[1].textValue ?? "",
                pos: row[2].textValue ?? "other",
                meaningVI: row[4].textValue ?? "",
                ipa: row[3].textValue,
                example: row[5].textValue ?? "",
                collectionName: row[6].textValue ?? "")
            items.append(item)
            if let snap = try ReviewService.fetchSnapshot(on: db, cardID: cardID) {
                snapshots[cardID] = snap
            }
        }
        return (items, snapshots)
    }
}