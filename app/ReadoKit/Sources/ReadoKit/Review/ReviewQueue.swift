import Foundation

/// Hàng đợi ôn — HAI nhánh (rulebook mục 8). Shape đã chốt lúc task 2.5 ship:
/// - thẻ MỚI bị chặn bởi `daily_new_limit` (toàn cục, trước khi lọc scope);
/// - thẻ ÔN LẠI thì KHÔNG bị giới hạn này.
/// `suspended_at IS NULL`. FR-18 thêm `scope`: nil = tất cả collection.
/// Ôn thêm (B1 extra-review-r1, đảo ADR-011/043 cho R1): `extraCardIDs`/
/// `loadExtraQueue` bên dưới — trộn thẻ mới + ôn sớm, MỌI lượt chấm ghi lịch
/// thật (không còn đường `mode='cram'` chỉ-log).
public enum ReviewQueue {

    /// Nhánh 1 — thẻ mới đến hạn, quota = daily_new_limit trừ số thẻ mới đã
    /// giới thiệu hôm nay. `scope` (FR-18): nil = tất cả, ngược lại chỉ chọn
    /// card thuộc đúng các collection — hạn mức vẫn áp TOÀN CỤC trước (không nới).
    /// Thứ tự (new-order-r1 ADR-047, đảo LIFO ở extra-review-r1 B3): bộ vừa
    /// thêm từ gần nhất trước (kể cả kho tạm) → trong bộ, từ gặp lại trước — số
    /// dòng cùng `term_normalized` CỘNG số lần `seen` (FR-22) → **LIFO**: trang/
    /// lần chụp gần đây nhất trước (`v.created_at DESC`), cùng một lần chụp thì
    /// giữ thứ tự trang (`v.rowid ASC`, không `WITHOUT ROWID`). Owner chốt
    /// 2026-10-01: "cuốn chiếu" — từ vừa thêm học trước, chấp nhận từ cũ đợi lâu
    /// hơn (không trần, Ôn thêm vẫn kéo được qua `extraCardIDs`).
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
                WHERE v3.term_normalized = v.term_normalized)
              + (SELECT COUNT(*) FROM encounters e
                  WHERE e.vocab_item_id = v.id AND e.kind = 'seen') DESC,
              v.created_at DESC, v.rowid ASC
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

    // MARK: — Ôn thêm (extra-review-r1, đảo ADR-011/043 cho R1)

    /// Số thẻ tối đa mỗi lượt Ôn thêm (owner chốt 2026-10-01).
    public static let extraBatchSize = 20
    /// Phần dành cho thẻ MỚI trong một lượt — nửa kia dành cho ôn sớm. Bên nào
    /// thiếu thì bên kia bù đủ `extraBatchSize` (owner chốt).
    public static let extraNewShare = 10

    /// Thẻ ĐÃ HỌC (state ≠ new), chưa suspend, CHƯA đến hạn ngày học
    /// (`due_at > window.end`), và CHƯA có lượt chấm nào hôm nay (tránh lôi lại
    /// ngay thẻ vừa Ôn thêm xong — "mỗi lượt ra nhóm khác", owner chốt). Sắp
    /// due trước lên trước — "10 từ đến hạn" (owner chốt 2026-10-01).
    public static func extraReviewCardIDs(
        on db: SQLiteDatabase,
        now: Date,
        scope: Set<String>? = nil,
        limit: Int = extraNewShare
    ) throws -> [String] {
        guard limit > 0 else { return [] }
        let window = currentDayWindow(on: db, now: now)
        let (clause, binds) = inScopeClause(scope)
        var params: [SQLValue] = [.text(window.end), .text(window.start)]
        params.append(contentsOf: binds)
        params.append(.int(Int64(limit)))
        return try db.rows(
            """
            SELECT c.id FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state != 'new'
              AND c.suspended_at IS NULL
              AND c.due_at > ?
              AND NOT EXISTS (
                    SELECT 1 FROM review_logs l
                    WHERE l.card_id = c.id AND l.reviewed_at >= ?
                  )
              AND \(clause)
            ORDER BY c.due_at, c.id
            LIMIT ?;
            """, params
        ).compactMap { $0.first?.textValue }
    }

    /// Xen kẽ hai danh sách (cũ, mới, cũ, mới…; phần dư dồn cuối) — owner chốt
    /// 2026-10-01: lượt Ôn thêm phải MIX từ cũ với từ mới, không xếp hết bên
    /// này rồi mới tới bên kia. Hàm thuần — test không cần DB.
    public static func interleave(old: [String], new: [String]) -> [String] {
        var result: [String] = []
        result.reserveCapacity(old.count + new.count)
        var i = 0, j = 0
        while i < old.count || j < new.count {
            if i < old.count { result.append(old[i]); i += 1 }
            if j < new.count { result.append(new[j]); j += 1 }
        }
        return result
    }

    /// Lượt Ôn thêm — tối đa `limit` thẻ, tối đa `newShare` thẻ mới ("10 từ gần
    /// nhất" LIFO, bỏ qua `daily_new_limit`) + phần còn lại là ôn sớm ("10 từ
    /// đến hạn"). Bên nào thiếu thì bên kia bù đủ `limit` (owner chốt). Chấm mọi
    /// thẻ ở đây = `ReviewService.record` bình thường — không còn đường
    /// `mode='cram'` chỉ-ghi-log của R1.
    public static func extraCardIDs(
        on db: SQLiteDatabase,
        now: Date,
        scope: Set<String>? = nil,
        limit: Int = extraBatchSize,
        newShare: Int = extraNewShare
    ) throws -> [String] {
        guard limit > 0 else { return [] }
        let newCap = min(newShare, limit)
        var newIDs = try newCardIDs(on: db, quota: Int64(newCap), scope: scope)
        let reviewCap = limit - newIDs.count
        let reviewIDs = try extraReviewCardIDs(
            on: db, now: now, scope: scope, limit: reviewCap)
        // Bù chiều ngược lại: ôn sớm thiếu mà kho còn từ mới ngoài `newCap` thì
        // kéo thêm cho đủ `limit`. `newCardIDs` xác định (ORDER BY có c.id) nên
        // phần đầu của lần gọi lại với quota lớn hơn giữ nguyên.
        let stillOpen = limit - newIDs.count - reviewIDs.count
        if stillOpen > 0 {
            newIDs = try newCardIDs(
                on: db, quota: Int64(newIDs.count + stillOpen), scope: scope)
        }
        return interleave(old: reviewIDs, new: newIDs)
    }

    /// Số thẻ Ôn thêm có thể lấy trong phạm vi — KHÔNG bị `limit` của một lượt —
    /// quyết định hiện CTA "Ôn thêm N thẻ" hay không, N hiển thị kẹp ở
    /// `extraBatchSize` (caller).
    public static func extraAvailableCount(
        on db: SQLiteDatabase, now: Date, scope: Set<String>? = nil
    ) throws -> Int64 {
        let window = currentDayWindow(on: db, now: now)
        let (clause, binds) = inScopeClause(scope)
        let newCount = try db.scalarInt64(
            """
            SELECT COUNT(*) FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state = 'new' AND c.suspended_at IS NULL AND \(clause);
            """, binds) ?? 0
        var reviewParams: [SQLValue] = [.text(window.end), .text(window.start)]
        reviewParams.append(contentsOf: binds)
        let reviewCount = try db.scalarInt64(
            """
            SELECT COUNT(*) FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            WHERE c.state != 'new' AND c.suspended_at IS NULL AND c.due_at > ?
              AND NOT EXISTS (
                    SELECT 1 FROM review_logs l
                    WHERE l.card_id = c.id AND l.reviewed_at >= ?
                  )
              AND \(clause);
            """, reviewParams) ?? 0
        return newCount + reviewCount
    }

    /// Số thẻ có review ĐẦU TIÊN nằm trong ngày hôm nay (thẻ "mới giới thiệu
    /// hôm nay") — dùng để trừ vào quota nhánh 1. Mọi lượt chấm (kể cả qua
    /// Ôn thêm) đều ghi `mode='srs'` (extra-review-r1 đảo ADR-011) nên đếm qua
    /// đây là đủ, không cần lọc mode nữa — giữ điều kiện cho rõ ý.
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

    // MARK: — FR-11 full queue façade (cards → [ReviewItem] + snapshot map)

    /// Một item hiển thị trên hàng đợi — FR-12 cần term/pos/meaning_vi/ipa/example/
    /// collectionName, FR-11 cần cardID làm key.
    public struct ReviewItem: Equatable, Identifiable, Sendable {
        public var id: String { cardID }
        public let cardID: String
        public let term: String
        public let pos: String
        public let meaningVI: String
        public let ipa: String?
        public let example: String
        public let collectionName: String
        /// Id vocab của thẻ (vocab-identity-r1 T4) — rỗng khi chỗ dựng không cần.
        public let vocabItemID: String
        /// Tối đa 3 câu gặp lại gần nhất (không trùng `example`), mới nhất trước.
        public let contexts: [EncounterRepository.EncounterContextRow]
        /// Lúc lưu từ (`vocab_items.created_at`, ISO `Z`) — "Gặp lần đầu N ngày trước" ở mặt sau thẻ
        /// (engagement-r1 T4). nil khi chỗ dựng không cần.
        public let createdAt: String?

        public init(
            cardID: String,
            term: String,
            pos: String,
            meaningVI: String,
            ipa: String?,
            example: String,
            collectionName: String,
            vocabItemID: String = "",
            contexts: [EncounterRepository.EncounterContextRow] = [],
            createdAt: String? = nil
        ) {
            self.cardID = cardID
            self.term = term
            self.pos = pos
            self.meaningVI = meaningVI
            self.ipa = ipa
            self.example = example
            self.collectionName = collectionName
            self.vocabItemID = vocabItemID
            self.contexts = contexts
            self.createdAt = createdAt
        }
    }

    /// Số câu gặp lại tối đa trên mặt sau thẻ.
    static let maxCardContexts = 3

    /// Đọc toàn bộ hàng đợi hiện tại (hai nhánh gộp) kèm chi tiết vocab
    /// + collection cho UI + map cardID→snapshot TRƯỚC (FR-12 undo cần).
    /// `dailyNewLimit` / `now` caller truyền vào để tính quota chính xác.
    public static func loadFullQueue(
        on db: SQLiteDatabase,
        dailyNewLimit: Int,
        now: Date,
        scope: Set<String>? = nil
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot]) {
        let window = currentDayWindow(on: db, now: now)

        // Nhánh 1 — new (quota). Có thể âm khi Ôn thêm đã giới thiệu vượt trần
        // hôm đó (owner chốt: chấp nhận, không trần qua Ôn thêm) — `max(0, …)`
        // kẹp về 0, không cấp thêm chứ không lỗi.
        let introduced = try newIntroducedCount(on: db, dayStartIso: window.start)
        let remainingQuota = max(0, Int64(dailyNewLimit) - introduced)
        let newIDs = try newCardIDs(on: db, quota: remainingQuota, scope: scope)
        // Nhánh 2 — due (review/relearning, đến cuối ngày học — window.end).
        let dueIDs = try dueCardIDs(on: db, dueBeforeIso: window.end, scope: scope)
        let allCardIDs = newIDs + dueIDs
        guard !allCardIDs.isEmpty else { return ([], [:]) }

        return try hydrate(on: db, cardIDs: allCardIDs)
    }

    /// Số thẻ của một phiên ôn nhanh (engagement-r1 T5, ADR-068) — "xong 3 thẻ là được dừng".
    public static let quickSessionSize = 3

    /// Phiên ôn nhanh: `size` thẻ ĐẦU của `loadFullQueue` (giữ đúng thứ tự ưu tiên) + snapshot của
    /// chúng + số thẻ còn lại của hàng đợi hôm nay. Chấm vẫn qua `ReviewService.record` như phiên
    /// thường nên lịch FSRS và streak không khác.
    public static func loadQuickQueue(
        on db: SQLiteDatabase,
        dailyNewLimit: Int,
        now: Date,
        scope: Set<String>? = nil,
        size: Int = quickSessionSize
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot], remaining: Int) {
        let full = try loadFullQueue(
            on: db, dailyNewLimit: dailyNewLimit, now: now, scope: scope)
        let items = Array(full.items.prefix(max(0, size)))
        var snapshots: [String: CardSnapshot] = [:]
        for item in items { snapshots[item.cardID] = full.snapshots[item.cardID] }
        return (items, snapshots, max(0, full.items.count - items.count))
    }

    /// Ôn thêm (extra-review-r1): hàng đợi trộn mới + ôn sớm — cùng shape với
    /// `loadFullQueue`. Giữ đúng thứ tự xen kẽ của `extraCardIDs` (KHÔNG sắp lại
    /// theo `due_at` — thẻ mới và thẻ ôn sớm có `due_at` khác hẳn nhau, sắp lại
    /// sẽ tách rời phần đã xen kẽ).
    public static func loadExtraQueue(
        on db: SQLiteDatabase,
        now: Date,
        scope: Set<String>? = nil,
        limit: Int = extraBatchSize
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot]) {
        let ids = try extraCardIDs(on: db, now: now, scope: scope, limit: limit)
        guard !ids.isEmpty else { return ([], [:]) }
        return try hydrate(on: db, cardIDs: ids, preserveOrder: true)
    }

    /// cardIDs → `ReviewItem` (kèm vocab + collection) + snapshot TRƯỚC —
    /// `preserveOrder` false (mặc định, `loadFullQueue`): sắp theo `due_at`.
    /// true (`loadExtraQueue`): giữ đúng thứ tự `cardIDs` truyền vào (xen kẽ đã
    /// tính trước đó) — sắp theo `due_at` ở đây sẽ phá thứ tự xen kẽ.
    private static func hydrate(
        on db: SQLiteDatabase, cardIDs: [String], preserveOrder: Bool = false
    ) throws -> (items: [ReviewItem], snapshots: [String: CardSnapshot]) {
        let placeholders = cardIDs.map { _ in "?" }.joined(separator: ",")
        let params: [SQLValue] = cardIDs.map { .text($0) }
        let orderClause = preserveOrder ? "" : "ORDER BY c.due_at, c.id"
        let rows = try db.rows(
            """
            SELECT c.id AS card_id, v.id AS vocab_item_id,
                   v.term AS term, v.pos AS pos, v.ipa AS ipa,
                   v.meaning_vi AS meaning_vi, v.example AS example,
                   col.name AS collection_name, v.created_at AS vocab_created_at
            FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id
            JOIN collections col ON col.id = v.collection_id
            WHERE c.id IN (\(placeholders))
            \(orderClause);
            """, params)

        var byID: [String: ReviewItem] = [:]
        var dueOrder: [ReviewItem] = []
        for row in rows {
            let vocabItemID = row["vocab_item_id"].textValue ?? ""
            let example = row["example"].textValue ?? ""
            let item = ReviewItem(
                cardID: row["card_id"].textValue ?? "",
                term: row["term"].textValue ?? "",
                pos: row["pos"].textValue ?? "other",
                meaningVI: row["meaning_vi"].textValue ?? "",
                ipa: row["ipa"].textValue,
                example: example,
                collectionName: row["collection_name"].textValue ?? "",
                vocabItemID: vocabItemID,
                contexts: try cardContexts(on: db, vocabItemID: vocabItemID, example: example),
                createdAt: row["vocab_created_at"].textValue)
            byID[item.cardID] = item
            dueOrder.append(item)
        }
        let items = preserveOrder ? cardIDs.compactMap { byID[$0] } : dueOrder
        // 1 query thêm cho snapshot cả lô — tránh N+1 (trước: 1 fetchSnapshot/card).
        let snapshots = try ReviewService.fetchSnapshots(on: db, cardIDs: cardIDs)
        return (items, snapshots)
    }

    /// Câu gặp lại cho mặt sau thẻ: bỏ câu trùng `example` (trim, không phân biệt
    /// hoa thường) — câu gốc đã hiện ngay phía trên. Lấy dư để vẫn đủ 3 sau khi lọc.
    private static func cardContexts(
        on db: SQLiteDatabase, vocabItemID: String, example: String
    ) throws -> [EncounterRepository.EncounterContextRow] {
        let key = example.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rows = try EncounterRepository.recentContexts(
            on: db, vocabItemID: vocabItemID, limit: maxCardContexts + 1)
        return Array(
            rows.filter {
                $0.sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != key
            }.prefix(maxCardContexts))
    }
}
