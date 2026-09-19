import Foundation

/// Hàng đợi ôn — HAI nhánh (rulebook mục 8):
/// - thẻ MỚI bị chặn bởi `daily_new_limit`;
/// - thẻ ÔN LẠI thì KHÔNG bị giới hạn này.
///
/// > CHƯA CHỐT — hình dạng query cố ý chưa chốt trong research doc; đây là
/// > ĐỀ XUẤT triển khai cho ROADMAP task 1.4, sẽ đối chiếu lại lúc solution
/// > design của FR-11. Điều đã chốt: hai nhánh, `suspended_at IS NULL`, thẻ mới
/// > giới hạn bởi daily_new_limit còn thẻ ôn thì không.
public enum ReviewQueue {

    /// Nhánh 1 — thẻ mới đến hạn, quota = daily_new_limit trừ số thẻ mới đã
    /// giới thiệu hôm nay.
    public static func newCardIDs(
        on db: SQLiteDatabase, quota: Int64
    ) throws -> [String] {
        guard quota > 0 else { return [] }
        return try db.rows(
            """
            SELECT id FROM cards
            WHERE state = 'new' AND suspended_at IS NULL
            ORDER BY due_at, id
            LIMIT ?;
            """, [.int(quota)]
        ).compactMap { $0.first?.textValue }
    }

    /// Nhánh 2 — thẻ ôn lại đã đến hạn tới cuối "hôm nay".
    /// KHÔNG có LIMIT theo daily_new_limit.
    public static func dueCardIDs(
        on db: SQLiteDatabase, dueBeforeIso: String
    ) throws -> [String] {
        try db.rows(
            """
            SELECT id FROM cards
            WHERE state IN ('review', 'relearning')
              AND suspended_at IS NULL
              AND due_at <= ?
            ORDER BY due_at, id;
            """, [.text(dueBeforeIso)]
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
}