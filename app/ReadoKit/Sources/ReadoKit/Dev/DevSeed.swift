import Foundation

/// verify-nav-r1 T2 — dựng LỊCH SỬ ÔN giả cho dữ liệu demo (`-ReadoSeed
/// demo-reviewed`, `scripts/sim_screens.sh open --seed demo-reviewed --fresh`)
/// để agent chụp được những màn chỉ hiện khi đã ôn qua: CTA "Ôn thêm", heatmap
/// nhiều mức màu, hàng "Gặp lại N từ". Hàm thuần nghiệp vụ (không `#if DEBUG`
/// — test bằng `scripts/test.sh kit`); call site ở app bọc DEBUG.
///
/// Mọi lần chấm đi qua `ReviewService.record` thật (CÙNG transaction UPDATE
/// cards + INSERT review_logs — luật rulebook mục 5), không tự UPDATE cột.
public enum DevSeed {

    /// Chấm MỌI thẻ `new` ít nhất 1 lần trong QUÁ KHỨ, rải trên `days` ngày
    /// khác nhau (heatmap nhiều mức màu) rồi dọn để **mọi** thẻ kết thúc với
    /// `due_at` ngoài cửa sổ "hôm nay" — Home sẽ thấy `dueToday == 0` (không
    /// còn thẻ `new` lẫn thẻ due) nhưng `extraAvailableCount > 0` (CTA "Ôn
    /// thêm"). Thêm vài dòng `encounters` (kind `seen`) cho "Gặp lại N từ".
    /// Idempotent: đã có `review_logs` thì bỏ qua — gọi lại không nhân đôi.
    public static func gradeHistory(
        on db: SQLiteDatabase, now: Date, days: Int = 20
    ) throws {
        guard try (db.scalarInt64("SELECT COUNT(*) FROM review_logs;") ?? 0) == 0
        else { return }

        let cardIDs = try db.rows("SELECT id FROM cards WHERE state = 'new' ORDER BY rowid;")
            .compactMap { $0.first?.textValue }
        guard !cardIDs.isEmpty else { return }

        let scheduler = try ReviewScheduler(settings: ReadoFSRS.readSettings(on: db))

        for (index, cardID) in cardIDs.enumerated() {
            // Lần ôn ĐẦU rải trên `days` ngày khác nhau (index đi vòng quanh) —
            // heatmap đổi màu theo tứ phân vị (`StreakIntensity`), dồn một ngày
            // thì mọi ô ra cùng một mức.
            let firstOffset = 1 + (index % days)
            var simNow = now.addingTimeInterval(-Double(firstOffset) * 86_400)
            // Xen 3 nhóm 1/2/3 lượt — vài thẻ "mới học" (1 lần), vài thẻ
            // "đã thấm" (3 lần) để Kho/hub có đủ mức Mới/Đang học/Đã nhớ.
            let reviewCount = [1, 2, 3][index % 3]
            for _ in 0..<reviewCount {
                guard let snapshot = try ReviewService.fetchSnapshot(on: db, cardID: cardID)
                else { break }
                let outcome = try scheduler.grade(.good, snapshot: snapshot, now: simNow)
                try ReviewService.record(
                    on: db, cardID: cardID, before: snapshot, outcome: outcome,
                    leechThreshold: nil, now: simNow)
                // Lần kế (nếu có) xảy ra SAU nhưng vẫn phải là quá khứ — kẹp
                // dưới `now` 1 ngày để review_logs không lọt vào "hôm nay" (lịch
                // FSRS tính ra interval dài hơn offset đã rải thì giữ nguyên).
                simNow = min(outcome.due, now.addingTimeInterval(-86_400))
            }
        }

        try pushDueOutsideTodayWindow(on: db, scheduler: scheduler, now: now)

        // FR-22: vài "Gặp lại" gần đây (trong 7 ngày) cho dòng "Gặp lại N từ
        // tuần này" (`EncounterRepository.distinctWordsEncountered`).
        let vocabIDs = try db.rows(
            "SELECT vocab_item_id FROM cards ORDER BY rowid LIMIT 5;"
        ).compactMap { $0.first?.textValue }
        if !vocabIDs.isEmpty {
            _ = try EncounterRepository.insertSeen(
                on: db, vocabItemIDs: vocabIDs, now: now.addingTimeInterval(-3 * 3_600))
        }
    }

    /// q13-sense-filter-r1 T2 — đánh dấu MỘT thẻ demo đã nạp (CSV) "đã thuộc"
    /// (Q-08: `state = 'review'`, `stability >= 21`) để fixture `analysis-fixture`
    /// (`scripts/sim_screens.sh open analysis-fixture`) có từ khớp khoá `term|pos`
    /// cho nhóm gập "Đã thuộc" (Q-13 phương án B, ADR-056) khi mở màn duyệt.
    /// UPDATE thẳng cột — đây là STATE CUỐI của dữ liệu demo tĩnh, không phải một
    /// lượt chấm thật, nên không qua `ReviewScheduler` (luật CLAUDE §4 "FSRS phải
    /// dùng thư viện" áp cho TÍNH lịch chấm; seed demo dùng raw SQL giống
    /// `Seeder`/test `Fixtures.insertCard`). Không khớp `term_normalized`+`pos`
    /// nào → im lặng bỏ qua (dev seed, không phải lỗi người dùng).
    public static func markMature(
        on db: SQLiteDatabase, termNormalized: String, pos: String, now: Date
    ) throws {
        guard
            let cardID = try db.rows(
                """
                SELECT cards.id FROM cards
                JOIN vocab_items ON vocab_items.id = cards.vocab_item_id
                WHERE vocab_items.term_normalized = ? AND vocab_items.pos = ?
                ORDER BY cards.rowid LIMIT 1;
                """,
                [.text(termNormalized), .text(pos)]
            ).first?.first?.textValue
        else { return }

        try db.run(
            """
            UPDATE cards
            SET state = 'review', stability = 30, difficulty = 5,
                reps = 5, lapses = 0, learning_steps = 0, scheduled_days = 30,
                last_review_at = ?, due_at = ?
            WHERE id = ?;
            """,
            [
                .text(ISOTimestamp.string(from: now.addingTimeInterval(-30 * 86_400))),
                .text(ISOTimestamp.string(from: now.addingTimeInterval(30 * 86_400))),
                .text(cardID),
            ])
    }

    /// Dọn nốt: thẻ nào vẫn due trong cửa sổ "hôm nay" (lịch FSRS ngắn hơn
    /// offset đã rải ở `gradeHistory`) → chấm thêm 1 lần Easy ngay trước `now`
    /// để đẩy `due_at` ra sau. Tối đa 3 vòng — không treo nếu interval vẫn
    /// ngắn hơn kỳ vọng.
    private static func pushDueOutsideTodayWindow(
        on db: SQLiteDatabase, scheduler: ReviewScheduler, now: Date
    ) throws {
        let window = ReviewQueue.currentDayWindow(on: db, now: now)
        for _ in 0..<3 {
            let stillDue = try db.rows(
                "SELECT id FROM cards WHERE suspended_at IS NULL AND due_at <= ? ORDER BY rowid;",
                [.text(window.end)]
            ).compactMap { $0.first?.textValue }
            if stillDue.isEmpty { return }
            let pushNow = now.addingTimeInterval(-3_600)
            for cardID in stillDue {
                guard let snapshot = try ReviewService.fetchSnapshot(on: db, cardID: cardID)
                else { continue }
                let outcome = try scheduler.grade(.easy, snapshot: snapshot, now: pushNow)
                try ReviewService.record(
                    on: db, cardID: cardID, before: snapshot, outcome: outcome,
                    leechThreshold: nil, now: pushNow)
            }
        }
    }
}
