import ReadoKit
import XCTest

/// FR-14 — Daily Progress: đến hạn quota-aware, tồn đọng riêng, leech loại,
/// streak theo giờ chuyển ngày (không nửa đêm hệ thống).
final class DailyProgressTests: XCTestCase {

    /// FR-14 crit 2: số "đến hạn hôm nay" đã áp hạn mức thẻ mới — KHÔNG phải
    /// tổng due_at quá khứ. 15 new + 3 due, limit 10 → dueToday = 13, backlog = 5.
    func testDueTodayIsQuotaAwareAndBacklogSeparate() throws {
        let db = try Fixtures.seededDB() // daily_new_limit = 10, cutoff 04:00 VN
        let col = try Fixtures.insertCollection(in: db, name: "A")

        for _ in 0..<3 {
            let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
            try Fixtures.insertCard(
                in: db, vocabItemID: v, state: "review",
                dueIso: "2026-09-17T00:00:00Z")
        }
        for _ in 0..<15 {
            let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
            try Fixtures.insertCard(in: db, vocabItemID: v, state: "new")
        }

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)

        XCTAssertEqual(p.dueToday, 13, "3 due + 10 new (hạn mức), không phải 18")
        XCTAssertEqual(p.backlog, 5, "15 new - 10 đã vào hôm nay")
    }

    /// FR-14 crit 4: card leech (suspended) không tính vào con số đến hạn.
    func testLeechExcludedFromDueToday() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")

        let active = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        try Fixtures.insertCard(
            in: db, vocabItemID: active, state: "review",
            dueIso: "2026-09-17T00:00:00Z")
        let leech = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        try Fixtures.insertCard(
            in: db, vocabItemID: leech, state: "review",
            dueIso: "2026-09-17T00:00:00Z",
            suspendedIso: "2026-09-18T01:00:00Z")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)

        XCTAssertEqual(p.dueToday, 1, "chỉ card hoạt động được tính")
    }

    /// FR-14 crit 1: streak đếm ngày ôn liên tục (03:00 UTC hôm sau vẫn là VN).
    func testStreakConsecutive() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")

        // 09:00 VN mỗi ngày = 02:00 UTC — vào đúng ngày cutoff tương ứng.
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-18T02:00:00Z")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T02:00:00Z")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-16T02:00:00Z")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(p.streak, 3)
    }

    /// FR-14 crit 1: một ngày trống giữa chuỗi → streak đứt.
    func testStreakGapResets() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")

        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-18T02:00:00Z")
        // Thiếu 09-17 → streak chỉ tính hôm nay.
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-16T02:00:00Z")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(p.streak, 1)
    }

    /// FR-14 crit 1: hôm nay chưa ôn → streak tính từ hôm qua (chưa đứt).
    func testStreakWhenTodayNotYetReviewed() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")

        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T02:00:00Z")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-16T02:00:00Z")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(p.streak, 2)
    }

    /// FR-14 crit 5: streak dùng giờ chuyển ngày, không nửa đêm hệ thống.
    /// 03:30 VN (trước cutoff 04:00) thuộc hôm QUA → cùng 09:30 VN hôm nay = 2
    /// ngày liên tiếp; nếu tính nửa đêm thì cả hai cùng một ngày → chỉ = 1.
    func testStreakUsesDayCutoffNotMidnight() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")

        // 09:30 VN 18/09 = 02:30 UTC (sau cutoff → thuộc hôm nay).
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-18T02:30:00Z")
        // 03:30 VN 18/09 = 20:30 UTC 17/09 (trước cutoff → thuộc hôm qua).
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T20:30:00Z")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(p.streak, 2, "theo cutoff 04:00 VN, hai log là hai ngày liên tiếp")
    }

    // MARK: — Ý 7 motivation-r1: reviewedToday (streak-nudge)

    /// Chưa có log nào → `reviewedToday == false`.
    func testReviewedTodayFalseWhenNoLogs() throws {
        let db = try Fixtures.seededDB()
        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertFalse(p.reviewedToday)
    }

    /// `fixedNow` = 09:00 VN 18/09, cutoff 04:00 VN → cửa sổ "hôm nay" bắt đầu
    /// 04:00 VN 18/09 = 21:00 UTC 17/09. Log 03:59 VN 18/09 (= 20:59 UTC 17/09)
    /// nằm TRƯỚC cutoff → vẫn thuộc phiên hôm QUA → `reviewedToday == false`.
    func testReviewedTodayFalseWhenLogBeforeCutoff() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T20:59:00Z")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertFalse(p.reviewedToday)
    }

    /// Log ngay tại/khi qua cutoff (04:00 VN 18/09 = 21:00 UTC 17/09) → cùng
    /// "ngày học" hiện tại → `reviewedToday == true`.
    func testReviewedTodayTrueWhenLogAtOrAfterCutoff() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T21:00:00Z")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertTrue(p.reviewedToday)
    }

    /// ADR-068: `reviewedToday` cùng luật với streak — MỌI mode đều tính (trước đây chỉ `srs`, hai con số
    /// trên cùng màn hình có thể nói hai điều khác nhau về cùng một ngày).
    func testReviewedTodayCountsAnyMode() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")
        try Fixtures.insertLog(
            in: db, cardID: card, reviewedAtIso: "2026-09-18T02:00:00Z", mode: "cram")

        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertTrue(p.reviewedToday)
    }

    /// engagement-r1 T4: N/7 = số ngày học có ôn trong 7 ngày gần nhất (tính cả hôm nay);
    /// dòng nhắc chỉ hiện khi có streak mà hôm nay chưa ôn.
    func testWeekReviewDaysAndReminder() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")
        // Hôm nay = ngày học 18/09 (VN). Có ôn: 17 và 16 (chuỗi 2 ngày); 10/09 nằm ngoài 7 ngày.
        for iso in ["2026-09-17T02:00:00Z", "2026-09-16T02:00:00Z", "2026-09-10T02:00:00Z"] {
            try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: iso)
        }

        let before = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(before.streak, 2)
        XCTAssertFalse(before.reviewedToday)
        XCTAssertEqual(before.weekReviewDays, 2)
        XCTAssertEqual(before.weekReminder, "Tuần này ôn 2/7 ngày")

        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-18T02:00:00Z")
        let after = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(after.weekReviewDays, 3, "tính cả hôm nay")
        XCTAssertNil(after.weekReminder, "đã ôn hôm nay thì không nhắc")
    }

    func testWeekReminderNeedsAnActiveStreak() throws {
        let db = try Fixtures.seededDB()
        let p = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(p.weekReviewDays, 0)
        XCTAssertNil(p.weekReminder, "chưa có streak thì không nhắc")
    }

    /// FR-14 crit 1: số trang đã phân tích đếm `reading_sessions` (0 khi FR-05/06
    /// chưa ghi, tự đúng sau này).
    func testPagesAnalyzedCountsReadingSessions() throws {
        let db = try Fixtures.seededDB()
        let initial = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(initial.pagesAnalyzed, 0)

        let col = try Fixtures.insertCollection(in: db, name: "A")
        try db.run(
            """
            INSERT INTO reading_sessions (id, collection_id, created_at, segments, summary)
            VALUES (?, ?, '2026-09-18T02:00:00Z', '[]', NULL);
            """,
            [.text(Identifier.uuid()), .text(col)])

        let after = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(after.pagesAnalyzed, 1)
    }
}