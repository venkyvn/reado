import ReadoKit
import XCTest

/// engagement-r1 — `DevSeed.addStreakHistory` dựng đúng trạng thái để chụp dòng N/7 và "Gặp lần đầu".
final class DevSeedStreakTests: XCTestCase {

    private func seeded() throws -> SQLiteDatabase {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        for term in ["one", "two", "three"] {
            let vocab = try Fixtures.insertVocab(in: db, collectionID: col, term: term)
            _ = try Fixtures.insertCard(in: db, vocabItemID: vocab)
        }
        return db
    }

    func testStreakWithoutTodayAndStillDue() throws {
        let db = try seeded()
        try DevSeed.addStreakHistory(on: db, now: Fixtures.fixedNow)

        let progress = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)

        XCTAssertEqual(progress.streak, 3, "1, 2, 3 ngày trước liên tiếp")
        XCTAssertFalse(progress.reviewedToday)
        XCTAssertEqual(progress.weekReviewDays, 4)
        XCTAssertEqual(progress.weekReminder, "Tuần này ôn 4/7 ngày")
        XCTAssertGreaterThan(progress.dueToday, 0, "thẻ vẫn `new` nên còn đến hạn → hero ở trạng thái .review")
    }

    func testVocabIsOldEnoughForFirstSeenLine() throws {
        let db = try seeded()
        try DevSeed.addStreakHistory(on: db, now: Fixtures.fixedNow)

        let (items, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        let created = try XCTUnwrap(items.first?.createdAt)
        let days = DayBoundary.daysBetween(
            Fixtures.iso(created), Fixtures.fixedNow,
            timezone: TimeZone(identifier: Fixtures.timezoneID)!)

        XCTAssertGreaterThanOrEqual(days, DaysAgo.firstSeenMinDays)
        XCTAssertNotNil(DaysAgo.firstSeenLabel(days: days))
    }

    func testIdempotentAndNoopWithoutCards() throws {
        let db = try seeded()
        try DevSeed.addStreakHistory(on: db, now: Fixtures.fixedNow)
        try DevSeed.addStreakHistory(on: db, now: Fixtures.fixedNow)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM review_logs;"), 4)

        let empty = try Fixtures.seededDB()
        try DevSeed.addStreakHistory(on: empty, now: Fixtures.fixedNow)
        XCTAssertEqual(try empty.scalarInt64("SELECT COUNT(*) FROM review_logs;"), 0)
    }
}
