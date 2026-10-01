import ReadoKit
import XCTest

/// J-R1-P — lịch streak (lens FR-14): heatmap 18 tuần 7×18, streak dài nhất,
/// số thẻ ôn + số trang mỗi ngày theo GIỜ CHUYỂN NGÀY (không nửa đêm hệ thống).
final class StreakCalendarTests: XCTestCase {

    private var timezone: TimeZone { TimeZone(identifier: Fixtures.timezoneID)! }
    private var cutoffHour: Int { 4 }

    /// Helper: tìm ô theo key đầu-cửa-sổ ngày.
    private func find(_ heatmap: StreakHeatmap, dayStart: String) -> StreakDay? {
        heatmap.weeks.flatMap { $0 }.compactMap { $0 }
            .first { $0.dayStartISO == dayStart }
    }

    private func dayStart(iso: String) -> String {
        DayBoundary.window(
            now: Fixtures.iso(iso), timezone: timezone, dayCutoffHour: cutoffHour).start
    }

    /// Current streak của heatmap == DailyProgressService.streak (cùng dữ liệu —
    /// refraction nội bộ không được tách đôi hai con số streak).
    func testCurrentStreakMatchesDailyProgress() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")
        for iso in [
            "2026-09-18T02:00:00Z", "2026-09-17T02:00:00Z", "2026-09-16T02:00:00Z",
        ] {
            try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: iso)
        }

        let progress = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        let heatmap = try StreakCalendarService.load(on: db, now: Fixtures.fixedNow)

        XCTAssertEqual(heatmap.currentStreak, progress.streak)
        XCTAssertEqual(heatmap.currentStreak, 3)
    }

    /// Chuỗi dài nhất xuyên qua lỗ hổng: chuỗi 2 ngày ở hiện tại, chuỗi 4 ngày
    /// trong quá khứ → dài nhất = 4, hiện tại = 2.
    func testLongestStreakAcrossGap() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")

        for iso in ["2026-09-18T02:00:00Z", "2026-09-17T02:00:00Z"] {
            try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: iso)
        }
        for iso in [
            "2026-09-13T02:00:00Z", "2026-09-12T02:00:00Z",
            "2026-09-11T02:00:00Z", "2026-09-10T02:00:00Z",
        ] {
            try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: iso)
        }

        let heatmap = try StreakCalendarService.load(on: db, now: Fixtures.fixedNow)
        XCTAssertEqual(heatmap.currentStreak, 2)
        XCTAssertEqual(heatmap.longestStreak, 4)
    }

    /// Hình dạng lưới: đúng 18 cột × 7 dòng; hôm nay là ô non-nil CUỐI cùng;
    /// mọi ô trước hôm nay non-nil, mọi ô sau hôm nay nil.
    func testHeatmapShape18x7AndFutureNil() throws {
        let db = try Fixtures.seededDB()
        let heatmap = try StreakCalendarService.load(on: db, now: Fixtures.fixedNow)

        XCTAssertEqual(heatmap.weeks.count, 18)
        for column in heatmap.weeks {
            XCTAssertEqual(column.count, 7)
        }

        let flat = heatmap.weeks.flatMap { $0 }
        XCTAssertEqual(flat.count, 18 * 7)

        let todayStart = DayBoundary.window(
            now: Fixtures.fixedNow, timezone: timezone, dayCutoffHour: cutoffHour).start
        guard let todayIndex = flat.firstIndex(where: { $0?.dayStartISO == todayStart }) else {
            return XCTFail("hôm nay phải nằm trong lưới")
        }
        for (index, cell) in flat.enumerated() {
            if index <= todayIndex {
                XCTAssertNotNil(cell, "ô quá khứ/today phải non-nil tại \(index)")
            } else {
                XCTAssertNil(cell, "ô tương lai phải nil tại \(index)")
            }
        }
    }

    /// Số thẻ ôn mỗi ngày gộp đúng: 2 log cùng ngày + 1 log ngày khác.
    func testReviewCountPerDay() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")

        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T02:00:00Z")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T03:00:00Z")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-16T02:00:00Z")

        let heatmap = try StreakCalendarService.load(on: db, now: Fixtures.fixedNow)
        XCTAssertEqual(
            find(heatmap, dayStart: dayStart(iso: "2026-09-17T02:00:00Z"))?.reviewCount, 2)
        XCTAssertEqual(
            find(heatmap, dayStart: dayStart(iso: "2026-09-16T02:00:00Z"))?.reviewCount, 1)
    }

    /// Số trang mỗi ngày từ reading_sessions — ngày chỉ chụp KHÔNG ôn vẫn có
    /// pageCount, reviewCount = 0 (ông xám, nhưng dòng chi tiết hiện số trang).
    func testPageCountPerDay() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        for iso in ["2026-09-17T02:00:00Z", "2026-09-17T05:00:00Z", "2026-09-16T02:00:00Z"] {
            try db.run(
                """
                INSERT INTO reading_sessions (id, collection_id, created_at, segments, summary)
                VALUES (?, ?, ?, '[]', NULL);
                """,
                [.text(Identifier.uuid()), .text(col), .text(iso)])
        }

        let heatmap = try StreakCalendarService.load(on: db, now: Fixtures.fixedNow)
        let day17 = find(heatmap, dayStart: dayStart(iso: "2026-09-17T02:00:00Z"))
        let day16 = find(heatmap, dayStart: dayStart(iso: "2026-09-16T02:00:00Z"))
        XCTAssertEqual(day17?.pageCount, 2)
        XCTAssertEqual(day17?.reviewCount, 0, "ngày chỉ chụp không tô màu")
        XCTAssertEqual(day16?.pageCount, 1)
    }

    /// Giờ chuyển ngày FR-11: hai log cùng ngày dương lịch nhưng khác bên cutoff
    /// 04:00 → hai ô khác nhau (03:30 VN thuộc hôm trước).
    func testCutoffHourSplitsRealDay() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")

        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-18T02:30:00Z")
        try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: "2026-09-17T20:30:00Z")

        let heatmap = try StreakCalendarService.load(on: db, now: Fixtures.fixedNow)
        let today = dayStart(iso: "2026-09-18T02:30:00Z")
        let yesterday = dayStart(iso: "2026-09-17T20:30:00Z")
        XCTAssertNotEqual(today, yesterday)
        XCTAssertEqual(find(heatmap, dayStart: today)?.reviewCount, 1)
        XCTAssertEqual(find(heatmap, dayStart: yesterday)?.reviewCount, 1)
        XCTAssertEqual(heatmap.currentStreak, 2, "hai log là hai ngày liên tiếp theo cutoff")
    }
}