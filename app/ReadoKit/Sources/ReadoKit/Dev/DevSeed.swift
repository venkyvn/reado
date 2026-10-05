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
            // Fixture `analysis-demo.json` mở popover của "routine" (match đầu tiên
            // còn trong từ điển), không phải vocab đầu tiên → ưu tiên "routine".
            let demoID = try db.scalarString(
                "SELECT id FROM vocab_items WHERE term_normalized = 'routine' LIMIT 1;")
            try seedDemoContexts(on: db, vocabItemID: demoID ?? vocabIDs[0], now: now)
        }
    }

    /// vocab-identity-r1 T4 — 2 lần `seen` CÓ CÂU cho một vocab (thêm vào lần `seen`
    /// không câu ở trên) để chụp ảnh popover FR-22 + mặt sau thẻ. Câu ghi rõ
    /// "Demo:" — dữ liệu giả, không phải sách thật.
    private static func seedDemoContexts(
        on db: SQLiteDatabase, vocabItemID: String, now: Date
    ) throws {
        guard let row = try db.rows(
            """
            SELECT v.term AS term, v.collection_id AS collection_id
            FROM vocab_items v WHERE v.id = ?;
            """, [.text(vocabItemID)]).first,
            let term = row["term"].textValue
        else { return }
        let collectionID = row["collection_id"].textValue
        let samples = [
            (days: 2.0, sentence: "Demo: \(term) appears again in another chapter."),
            (days: 1.0, sentence: "Demo: the second time we meet \(term), it is in a longer sentence about building habits that last."),
        ]
        for sample in samples {
            _ = try EncounterRepository.insertSeen(
                on: db,
                contexts: [EncounterContext(vocabItemID: vocabItemID, sentence: sample.sentence)],
                collectionID: collectionID,
                now: now.addingTimeInterval(-sample.days * 86_400))
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

    /// home-eevas-r1 T3 — chấm `.again` liên tiếp đủ ngưỡng leech cho vài thẻ để Home/màn
    /// "Từ hay quên" có dữ liệu khi seed `demo-reviewed`. Idempotent: đã có thẻ suspended thì bỏ qua.
    public static func markLeeches(
        on db: SQLiteDatabase, count: Int = 2, now: Date
    ) throws {
        guard try (db.scalarInt64("SELECT COUNT(*) FROM cards WHERE suspended_at IS NOT NULL;") ?? 0) == 0
        else { return }

        let cardIDs = try db.rows(
            "SELECT id FROM cards WHERE suspended_at IS NULL ORDER BY rowid LIMIT ?;",
            [.int(Int64(count))]
        ).compactMap { $0.first?.textValue }
        guard !cardIDs.isEmpty else { return }

        let threshold = try LeechService.readThreshold(on: db) ?? 6
        let scheduler = try ReviewScheduler(settings: ReadoFSRS.readSettings(on: db))

        for cardID in cardIDs {
            var simNow = now
            for _ in 0..<threshold {
                guard let snapshot = try ReviewService.fetchSnapshot(on: db, cardID: cardID)
                else { break }
                let outcome = try scheduler.grade(.again, snapshot: snapshot, now: simNow)
                try ReviewService.record(
                    on: db, cardID: cardID, before: snapshot, outcome: outcome,
                    leechThreshold: threshold, now: simNow)
                simNow = simNow.addingTimeInterval(-300)
            }
        }
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

    /// Tên collection phụ chứa các dòng trùng của `addDuplicates`.
    public static let duplicatesCollectionName = "Bộ trùng (demo)"

    /// engagement-r1 T2 (FR-24) — dựng NHÓM TRÙNG để chụp màn "Gộp từ trùng": với 2 vocab đầu
    /// (theo `rowid`), thêm bản sao cùng `term+pos` vào một collection phụ, nghĩa khác, thẻ `new`
    /// (từ đầu có 2 bản sao → nhóm 3 dòng) và cho thẻ gốc của từ đầu lên `review` để mức khác nhau.
    /// Idempotent: collection phụ đã có thì bỏ qua.
    public static func addDuplicates(on db: SQLiteDatabase, now: Date) throws {
        let existing = try db.scalarInt64(
            "SELECT COUNT(*) FROM collections WHERE name = ?;",
            [.text(duplicatesCollectionName)]) ?? 0
        guard existing == 0 else { return }
        let nowIso = ISOTimestamp.string(from: now)
        let learnedAt = ISOTimestamp.string(from: now.addingTimeInterval(-5 * 86_400))
        let dueAt = ISOTimestamp.string(from: now.addingTimeInterval(20 * 86_400))
        try db.inTransaction {
            let originals = try db.rows(
                """
                SELECT id, term, term_normalized, pos, ipa, example, cefr
                FROM vocab_items ORDER BY rowid LIMIT 2;
                """, [])
            guard !originals.isEmpty else { return }
            let collectionID = Identifier.uuid()
            try db.run(
                "INSERT INTO collections (id, name, is_default, created_at) VALUES (?, ?, 0, ?);",
                [.text(collectionID), .text(duplicatesCollectionName), .text(nowIso)])
            for (index, row) in originals.enumerated() {
                for copy in 0..<(index == 0 ? 2 : 1) {
                    let vocabID = Identifier.uuid()
                    try db.run(
                        """
                        INSERT INTO vocab_items (
                          id, collection_id, term, term_normalized, pos,
                          ipa, meaning_vi, example, cefr, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                        """,
                        [
                            .text(vocabID), .text(collectionID),
                            .text(row["term"].textValue ?? ""),
                            .text(row["term_normalized"].textValue ?? ""),
                            .text(row["pos"].textValue ?? "other"),
                            row["ipa"].textValue.map { .text($0) } ?? .null,
                            .text("nghĩa khác (demo \(copy + 1))"),
                            .text(row["example"].textValue ?? ""),
                            row["cefr"].textValue.map { .text($0) } ?? .null,
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
                        [.text(Identifier.uuid()), .text(vocabID), .text(nowIso)])
                }
            }
            if let firstID = originals[0]["id"].textValue {
                try db.run(
                    """
                    UPDATE cards SET state = 'review', stability = 25, difficulty = 5,
                           reps = 3, scheduled_days = 25, last_review_at = ?, due_at = ?
                    WHERE vocab_item_id = ?;
                    """,
                    [.text(learnedAt), .text(dueAt), .text(firstID)])
            }
        }
    }
}
