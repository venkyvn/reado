import Foundation

/// Hàng đợi ôn — HAI nhánh (rulebook mục 8). Shape đã chốt lúc task 2.5 ship:
/// - thẻ MỚI bị chặn bởi `daily_new_limit` (toàn cục, trước khi lọc scope);
/// - thẻ ÔN LẠI thì KHÔNG bị giới hạn này.
/// `suspended_at IS NULL`. FR-18 thêm `scope`: nil = tất cả collection.
public enum ReviewQueue {

    /// Nhánh 1 — thẻ mới đến hạn, quota = daily_new_limit trừ số thẻ mới đã
    /// giới thiệu hôm nay. `scope` (FR-18): nil = tất cả, ngược lại chỉ chọn
    /// card thuộc đúng các collection — hạn mức vẫn áp TOÀN CỤC trước (không nới).
    /// Thứ tự (new-order-r1, ADR-047): bộ vừa thêm từ gần nhất trước (kể cả kho
    /// tạm) → trong bộ, từ gặp lại (cùng `term_normalized` ở ≥2 dòng) trước →
    /// thứ tự trang (`created_at`, rồi `due_at`).
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
            ORDER BY
              (SELECT MAX(v2.created_at) FROM vocab_items v2
                WHERE v2.collection_id = v.collection_id) DESC,
              (SELECT COUNT(*) FROM vocab_items v3
                WHERE v3.term_normalized = v.term_normalized) DESC,
              v.created_at, c.due_at, c.id
            LIMIT ?;
            """, params
        ).compactMap { $0.first?.textValue }
    }

    /// Nhánh 2 — thẻ ôn lại đã đến hạn tới cuối "hôm nay" (`dueBeforeIso` PHẢI
    /// là `currentDayWindow(...).end` — hạn ôn theo NGÀY HỌC, không phải `now`
    /// thời điểm bấm; T1 fsrs-queue-fix-r1: thẻ hẹn 21h hôm nay hiện từ sáng).
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

    /// Số thẻ tối đa mỗi lượt Cram (owner chốt 2026-09-28, ADR-043).
    public static let cramBatchSize = 20

    /// Cram (FR-18 tiêu chí 4, ADR-011/043) — thẻ ĐÃ HỌC (state ≠ new), chưa
    /// suspend, CHƯA đến hạn ngày học (`due_at > window.end`; thẻ đến hạn tối
    /// nay đi đường srs dù chưa qua `now`), sắp đến hạn trước. `scope` nil =
    /// tất cả. Thẻ new KHÔNG vào đây — đường "Học thêm".
    public static func cramCardIDs(
        on db: SQLiteDatabase,
        now: Date,
        scope: Set<String>? = nil,
        limit: Int = cramBatchSize
    ) throws -> [String] {
        guard limit > 0 else { return [] }
        let windowEnd = currentDayWindow(on: db, now: now).end
        let (clause, binds) = inScopeClause(scope)
        var params: [SQLValue] = [.text(windowEnd)]
        params.append(contentsOf: binds)
        params.append(.int(Int64(limit)))
        return try db.rows(
            """
            SELECT c.id FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state != 'new'
              AND c.suspended_at IS NULL
              AND c.due_at > ?
              AND \(clause)
            ORDER BY c.due_at, c.id
            LIMIT ?;
            """, params
        ).compactMap { $0.first?.textValue }
    }

    /// Số thẻ Cram được trong phạm vi (không bị `limit`) — quyết định hiện nút
    /// "Ôn thêm" hay không.
    public static func crammableCount(
        on db: SQLiteDatabase, now: Date, scope: Set<String>? = nil
    ) throws -> Int64 {
        let windowEnd = currentDayWindow(on: db, now: now).end
        let (clause, binds) = inScopeClause(scope)
        var params: [SQLValue] = [.text(windowEnd)]
        params.append(contentsOf: binds)
        return try db.scalarInt64(
            """
            SELECT COUNT(*) FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state != 'new'
              AND c.suspended_at IS NULL
              AND c.due_at > ?
              AND \(clause);
            """, params) ?? 0
    }

    /// Số thẻ có review ĐẦU TIÊN nằm trong ngày hôm nay (thẻ "mới giới thiệu
    /// hôm nay") — dùng để trừ vào quota nhánh 1. Chỉ đếm log `mode='srs'`:
    /// log cram không ăn hạn mức FR-11 (ADR-011).
    public static func newIntroducedCount(
        on db: SQLiteDatabase, dayStartIso: String
    ) throws -> Int64 {
        let value = try db.scalarInt64(
            """
            SELECT COUNT(*) FROM cards c
            WHERE EXISTS (
                    SELECT 1 FROM review_logs l
                    WHERE l.card_id = c.id AND l.mode = 'srs' AND l.reviewed_at >= ?
                  )
              AND NOT EXISTS (
                    SELECT 1 FROM review_logs l2
                    WHERE l2.card_id = c.id AND l2.mode = 'srs' AND l2.reviewed_at < ?
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

    /// `dayStart` (ISO) hiện tại theo `settings.timezone` + `day_cutoff_hour` —
    /// cùng cửa sổ "hôm nay" mà `loadFullQueue`/`DailyProgressService` dùng.
    /// `AppModel` (ý 3 "Học thêm") gọi hàm này để gắn phần nới hạn mức đúng ngày
    /// học hiện tại, KHÔNG dùng `Calendar.current` nửa đêm hệ thống.
    public static func currentDayStartIso(on db: SQLiteDatabase, now: Date) -> String {
        currentDayWindow(on: db, now: now).start
    }

    /// Cửa sổ ngày học [start, end) chứa `now` theo `settings.timezone` +
    /// `day_cutoff_hour` (FR-11) — `nextDue` dùng để đếm thẻ "cùng ngày".
    public static func currentDayWindow(
        on db: SQLiteDatabase, now: Date
    ) -> DayBoundary.DayWindow {
        let (timezone, cutoffHour) = DayContext.read(on: db)
        return DayBoundary.window(
            now: now, timezone: timezone, dayCutoffHour: cutoffHour)
    }

    /// Hàm THUẦN (không DB) — phần nới "Học thêm" chỉ còn hiệu lực trong đúng
    /// `dayStart` đã lưu; qua ngày mới (giờ chuyển ngày FR-11, không nửa đêm hệ
    /// thống) thì mất, không cộng dồn (Q-A đã chốt 2026-09-26).
    public static func effectiveExtra(
        stored: (dayStart: String, count: Int)?,
        currentDayStart: String
    ) -> Int {
        guard let stored, stored.dayStart == currentDayStart else { return 0 }
        return stored.count
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
    /// `extraNew` (ý 3 motivation-r1, "Học thêm 10 từ"): phần nới hạn mức new
    /// RIÊNG ngày hiện tại, giữ trong bộ nhớ app (`AppModel`, không schema) —
    /// mặc định 0 = hành vi cũ. Vẫn áp TOÀN CỤC trước khi lọc phạm vi (FR-11).
    public static func loadFullQueue(
        on db: SQLiteDatabase,
        dailyNewLimit: Int,
        now: Date,
        scope: Set<String>? = nil,
        extraNew: Int = 0
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot]) {
        let window = currentDayWindow(on: db, now: now)

        // Nhánh 1 — new (quota).
        let introduced = try newIntroducedCount(on: db, dayStartIso: window.start)
        let remainingQuota = max(0, Int64(dailyNewLimit) + Int64(extraNew) - introduced)
        let newIDs = try newCardIDs(on: db, quota: remainingQuota, scope: scope)
        // Nhánh 2 — due (review/relearning, đến cuối ngày học — window.end).
        let dueIDs = try dueCardIDs(on: db, dueBeforeIso: window.end, scope: scope)
        let allCardIDs = newIDs + dueIDs
        guard !allCardIDs.isEmpty else { return ([], [:]) }

        return try hydrate(on: db, cardIDs: allCardIDs)
    }

    /// Cram: hàng đợi ôn thêm (không đụng lịch) — cùng shape với `loadFullQueue`.
    public static func loadCramQueue(
        on db: SQLiteDatabase,
        now: Date,
        scope: Set<String>? = nil,
        limit: Int = cramBatchSize
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot]) {
        let ids = try cramCardIDs(on: db, now: now, scope: scope, limit: limit)
        guard !ids.isEmpty else { return ([], [:]) }
        return try hydrate(on: db, cardIDs: ids)
    }

    /// cardIDs → `ReviewItem` (kèm vocab + collection) + snapshot TRƯỚC, sắp theo
    /// `due_at` — dùng chung cho hàng đợi srs và Cram.
    private static func hydrate(
        on db: SQLiteDatabase, cardIDs: [String]
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot]) {
        let placeholders = cardIDs.map { _ in "?" }.joined(separator: ",")
        let params: [SQLValue] = cardIDs.map { .text($0) }
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
