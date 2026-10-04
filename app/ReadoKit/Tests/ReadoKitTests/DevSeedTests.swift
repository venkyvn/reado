import ReadoKit
import XCTest

/// verify-nav-r1 T2 — `DevSeed.gradeHistory` dựng lịch sử ôn giả cho demo.
/// Chạy bằng `scripts/test.sh kit`.
final class DevSeedTests: XCTestCase {

    private let now = Fixtures.fixedNow  // 2026-09-18T02:00:00Z

    private func seedNewCards(_ db: SQLiteDatabase, count: Int = 12) throws {
        let col = try Fixtures.insertCollection(in: db, name: "Demo")
        for index in 0..<count {
            let vocabID = try Fixtures.insertVocab(
                in: db, collectionID: col, term: "word\(index)")
            try Fixtures.insertCard(in: db, vocabItemID: vocabID, state: "new")
        }
    }

    func testGradeHistoryClearsDueTodayAndFillsExtraAvailable() throws {
        let db = try Fixtures.seededDB()
        try seedNewCards(db)

        try DevSeed.gradeHistory(on: db, now: now, days: 20)

        let progress = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: now)
        XCTAssertEqual(progress.dueToday, 0)
        let extra = try ReviewQueue.extraAvailableCount(on: db, now: now)
        XCTAssertGreaterThan(extra, 0)
    }

    func testGradeHistorySpreadsAcrossManyDistinctDays() throws {
        let db = try Fixtures.seededDB()
        try seedNewCards(db, count: 20)

        try DevSeed.gradeHistory(on: db, now: now, days: 20)

        let days = Set(
            try db.rows("SELECT reviewed_at FROM review_logs;")
                .compactMap { $0.first?.textValue }
                .map { String($0.prefix(10)) }  // yyyy-MM-dd
        )
        XCTAssertGreaterThanOrEqual(days.count, 10, "heatmap cần nhiều mức màu, không dồn 1-2 ngày")
    }

    func testGradeHistoryOnlyProducesKnownCardStates() throws {
        let db = try Fixtures.seededDB()
        try seedNewCards(db)

        try DevSeed.gradeHistory(on: db, now: now, days: 20)

        let states = Set(
            try db.rows("SELECT state FROM cards;").compactMap { $0.first?.textValue })
        let known: Set<String> = ["new", "learning", "review", "relearning"]
        XCTAssertTrue(states.isSubset(of: known), "cards.state lạ: \(states)")
        XCTAssertFalse(states.contains("new"), "mọi thẻ phải rời 'new' để dueToday == 0")
    }

    func testGradeHistoryInsertsRecentSeenEncounters() throws {
        let db = try Fixtures.seededDB()
        try seedNewCards(db)

        try DevSeed.gradeHistory(on: db, now: now, days: 20)

        let recent = try EncounterRepository.distinctWordsEncountered(
            on: db, since: now.addingTimeInterval(-7 * 86_400))
        XCTAssertGreaterThan(recent, 0)
    }

    func testGradeHistoryIsIdempotent() throws {
        let db = try Fixtures.seededDB()
        try seedNewCards(db)

        try DevSeed.gradeHistory(on: db, now: now, days: 20)
        let firstCount = try db.scalarInt64("SELECT COUNT(*) FROM review_logs;") ?? 0

        try DevSeed.gradeHistory(on: db, now: now, days: 20)
        let secondCount = try db.scalarInt64("SELECT COUNT(*) FROM review_logs;") ?? 0

        XCTAssertEqual(firstCount, secondCount)
        XCTAssertGreaterThan(firstCount, 0)
    }

    func testGradeHistoryNoOpWhenNoNewCards() throws {
        let db = try Fixtures.seededDB()
        // Không thẻ nào — không được crash, không ghi gì.
        try DevSeed.gradeHistory(on: db, now: now, days: 20)
        let count = try db.scalarInt64("SELECT COUNT(*) FROM review_logs;") ?? 0
        XCTAssertEqual(count, 0)
    }

    // MARK: - markMature (q13-sense-filter-r1 T2)

    func testMarkMatureSetsStabilityAboveThreshold() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Demo")
        let item = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "setback", pos: "noun")
        try Fixtures.insertCard(in: db, vocabItemID: item, state: "new")

        try DevSeed.markMature(on: db, termNormalized: "setback", pos: "noun", now: now)

        let rows = try db.rows("SELECT state, stability FROM cards;")
        XCTAssertEqual(rows.first?["state"].textValue, "review")
        XCTAssertGreaterThanOrEqual(rows.first?["stability"].doubleValue ?? 0, 21)
    }

    func testMarkMatureNoOpWhenTermNotFound() throws {
        let db = try Fixtures.seededDB()
        // Không khớp term+pos nào — không crash, không đổi gì.
        try DevSeed.markMature(on: db, termNormalized: "ghost", pos: "noun", now: now)
        let count = try db.scalarInt64("SELECT COUNT(*) FROM cards;") ?? 0
        XCTAssertEqual(count, 0)
    }

    // MARK: - markLeeches (home-eevas-r1 T3)

    func testMarkLeechesSuspendsCountCardsAtThreshold() throws {
        let db = try Fixtures.seededDB()
        try seedNewCards(db, count: 5)
        try DevSeed.gradeHistory(on: db, now: now, days: 20)
        let threshold = try XCTUnwrap(LeechService.readThreshold(on: db))

        try DevSeed.markLeeches(on: db, count: 2, now: now)

        let suspended = try db.rows(
            "SELECT lapses FROM cards WHERE suspended_at IS NOT NULL;")
        XCTAssertEqual(suspended.count, 2)
        for row in suspended {
            XCTAssertGreaterThanOrEqual(row["lapses"].intValue ?? 0, Int64(threshold))
        }
    }

    func testMarkLeechesIsIdempotent() throws {
        let db = try Fixtures.seededDB()
        try seedNewCards(db, count: 5)
        try DevSeed.gradeHistory(on: db, now: now, days: 20)

        try DevSeed.markLeeches(on: db, count: 2, now: now)
        let firstCount = try db.scalarInt64(
            "SELECT COUNT(*) FROM cards WHERE suspended_at IS NOT NULL;") ?? 0

        try DevSeed.markLeeches(on: db, count: 2, now: now)
        let secondCount = try db.scalarInt64(
            "SELECT COUNT(*) FROM cards WHERE suspended_at IS NOT NULL;") ?? 0

        XCTAssertEqual(firstCount, 2)
        XCTAssertEqual(firstCount, secondCount, "gọi lại không nhân đôi leech")
    }

    func testMarkLeechesNoOpWhenNoCards() throws {
        let db = try Fixtures.seededDB()
        // Không crash khi kho trống.
        try DevSeed.markLeeches(on: db, count: 2, now: now)
        let count = try db.scalarInt64(
            "SELECT COUNT(*) FROM cards WHERE suspended_at IS NOT NULL;") ?? 0
        XCTAssertEqual(count, 0)
    }
}
