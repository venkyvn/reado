import Foundation

// Tổng quan collection cho Home/Kho và lần ôn kế tiếp (FR-17a).
// Tách từ VocabRepository.swift (refactor): logic giữ nguyên.

extension VocabRepository {
    // MARK: — FR-17(a) + Home overview

    /// Tổng quan mọi collection — tên, số từ, thẻ đến hạn (`due_at <= window.end`
    /// — hạn ngày học, chưa suspend), lần thêm từ gần nhất, số từ đã thuộc
    /// (Q-08, ý 4 motivation-r1).
    /// `COUNT(DISTINCT v.id)` chống việc JOIN cards nhân dòng (một vocab tối đa
    /// 2 card theo direction) — áp dụng cả cho `mastered_count`.
    public static func allCollectionSummaries(
        on db: SQLiteDatabase, now: Date
    ) throws -> [CollectionSummary] {
        let windowEndIso = ReviewQueue.currentDayWindow(on: db, now: now).end
        let sevenDaysAgoIso = ISOTimestamp.string(
            from: now.addingTimeInterval(-7 * 86_400))
        // Bảng dẫn xuất `b` gom theo TỪ (1 dòng / từ) rồi theo collection: mỗi từ
        // vào đúng 1 nhóm (m > l > r > active). Thứ tự bind theo vị trí `?` trong
        // SQL: due_now, mastered (ngưỡng), added7, crammable, absorbed (ngưỡng), rồi
        // ngưỡng trong `b`.
        let rows = try db.rows(
            """
            SELECT c.id AS id, c.name AS name, c.is_default AS is_default,
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
                        THEN 1 ELSE 0 END), 0) AS crammable_count,
                   COUNT(DISTINCT CASE
                        WHEN ca.state = 'review' AND ca.stability >= ?
                             AND ca.suspended_at IS NULL
                             AND EXISTS (SELECT 1 FROM encounters e
                                         WHERE e.vocab_item_id = v.id
                                           AND e.kind = 'recognized')
                        THEN v.id END) AS absorbed_count
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
                .text(windowEndIso), .double(Mastery.stabilityThreshold),
                .text(sevenDaysAgoIso), .text(windowEndIso),
                .double(Mastery.stabilityThreshold),
                .double(Mastery.stabilityThreshold),
            ])
        return rows.map { row in
            CollectionSummary(
                id: row["id"].textValue ?? "",
                name: row["name"].textValue ?? "",
                isDefault: (row["is_default"].intValue ?? 0) != 0,
                wordCount: Int(row["word_count"].intValue ?? 0),
                dueNow: Int(row["due_now"].intValue ?? 0),
                lastAddedAt: row["last_added"].textValue.flatMap { ISOTimestamp.date(from: $0) },
                masteredCount: Int(row["mastered_count"].intValue ?? 0),
                learningCount: Int(row["learning_count"].intValue ?? 0),
                reviewingCount: Int(row["reviewing_count"].intValue ?? 0),
                notStartedCount: Int(row["not_started_count"].intValue ?? 0),
                absorbedCount: Int(row["absorbed_count"].intValue ?? 0),
                addedLast7Days: Int(row["added_7d"].intValue ?? 0),
                crammableCount: Int(row["crammable_count"].intValue ?? 0))
        }
    }

    /// Lần ôn kế tiếp của một collection: `MIN(due_at)` của thẻ chưa suspend có
    /// `due_at > window.end` (hạn ngày học hiện tại — không trỏ vào thẻ đã nằm
    /// trong hàng đợi hôm nay), và số thẻ cùng điều kiện rơi trong cùng ngày
    /// học chứa mốc đó (`ReviewQueue.currentDayWindow` — giờ chuyển ngày FR-11).
    /// nil = không còn lịch nào sau cửa sổ hiện tại.
    public static func nextDue(
        on db: SQLiteDatabase, collectionID: String, now: Date
    ) throws -> NextDue? {
        let currentWindowEnd = ReviewQueue.currentDayWindow(on: db, now: now).end
        // `MIN` trả NULL khi không còn thẻ nào → đọc qua `rows` (scalarString ném lỗi).
        let minRows = try db.rows(
            """
            SELECT MIN(ca.due_at) FROM cards ca
            JOIN vocab_items v ON v.id = ca.vocab_item_id
            WHERE v.collection_id = ? AND ca.suspended_at IS NULL
              AND ca.due_at > ?;
            """, [.text(collectionID), .text(currentWindowEnd)])
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
            [.text(collectionID), .text(currentWindowEnd), .text(window.start),
             .text(window.end)]) ?? 0
        return NextDue(date: minDate, count: Int(count))
    }
}
