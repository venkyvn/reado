import ReadoKit
import XCTest

/// engagement-r1 T8 — "Tuần qua": mốc tuần theo ngày học + số đo tuần trước.
/// Now = thứ Sáu 18/09/2026 09:00 VN → tuần hiện tại từ thứ Hai 14/09 04:00 VN (13/09 21:00Z);
/// tuần trước = [06/09 21:00Z, 13/09 21:00Z).
final class WeekStoryTests: XCTestCase {

    private var timezone: TimeZone { TimeZone(identifier: Fixtures.timezoneID)! }

    // MARK: weekStart

    func testWeekStartIsMondayOfTheLearningDay() {
        XCTAssertEqual(
            DayBoundary.weekStart(now: Fixtures.fixedNow, timezone: timezone),
            "2026-09-13T21:00:00Z", "thứ Sáu 18/09 → thứ Hai 14/09 04:00 VN")
        XCTAssertEqual(
            DayBoundary.weekStart(now: Fixtures.iso("2026-09-20T16:00:00Z"), timezone: timezone),
            "2026-09-13T21:00:00Z", "Chủ nhật 23:00 VN vẫn trong tuần đó")
        XCTAssertEqual(
            DayBoundary.weekStart(now: Fixtures.iso("2026-09-13T21:00:00Z"), timezone: timezone),
            "2026-09-13T21:00:00Z", "đúng thứ Hai 04:00 VN là tuần mới")
    }

    func testMondayBeforeCutoffStillBelongsToPreviousWeek() {
        // Thứ Hai 03:30 VN (13/09 20:30Z) còn là ngày học Chủ nhật 13/09 → tuần bắt đầu thứ Hai 07/09.
        XCTAssertEqual(
            DayBoundary.weekStart(now: Fixtures.iso("2026-09-13T20:30:00Z"), timezone: timezone),
            "2026-09-06T21:00:00Z")
    }

    // MARK: load

    private func vocab(_ db: SQLiteDatabase, _ col: String, _ term: String, createdAt: String) throws -> String {
        try Fixtures.insertVocab(in: db, collectionID: col, term: term, createdAt: createdAt)
    }

    private func encounter(
        _ db: SQLiteDatabase, _ vocab: String, _ kind: String, _ iso: String
    ) throws {
        try db.run(
            "INSERT INTO encounters (id, vocab_item_id, kind, created_at) VALUES (?, ?, ?, ?);",
            [.text(Identifier.uuid()), .text(vocab), .text(kind), .text(iso)])
    }

    func testLoadCountsOnlyLastWeekWithInclusiveStartExclusiveEnd() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let a = try vocab(db, col, "alpha", createdAt: "2026-09-08T00:00:00Z")
        let b = try vocab(db, col, "beta", createdAt: "2026-09-08T01:00:00Z")
        _ = try vocab(db, col, "edgeStart", createdAt: "2026-09-06T21:00:00Z")  // biên đầu: tính
        _ = try vocab(db, col, "edgeEnd", createdAt: "2026-09-13T21:00:00Z")    // biên cuối: không
        _ = try vocab(db, col, "old", createdAt: "2026-09-01T00:00:00Z")        // ngoài
        try encounter(db, a, "seen", "2026-09-08T02:00:00Z")
        try encounter(db, a, "seen", "2026-09-09T02:00:00Z")
        try encounter(db, a, "recognized", "2026-09-10T02:00:00Z")
        try encounter(db, b, "seen", "2026-09-07T02:00:00Z")
        try encounter(db, b, "recognized", "2026-09-14T02:00:00Z")              // tuần này: không

        let story = try WeekStoryService.load(on: db, now: Fixtures.fixedNow)

        XCTAssertEqual(story.weekStart, "2026-09-13T21:00:00Z")
        XCTAssertEqual(story.wordsSaved, 3, "alpha, beta, edgeStart")
        XCTAssertEqual(story.wordsReencountered, 2, "alpha và beta có seen")
        XCTAssertEqual(story.recognizedCount, 1)
        XCTAssertEqual(story.topTerm, "alpha", "3 lần trong tuần (2 seen + 1 recognized)")
    }

    func testReviewDaysUseLearningDays() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "term")
        let card = try Fixtures.insertCard(in: db, vocabItemID: v, state: "review")
        for iso in [
            "2026-09-07T02:00:00Z",  // T2 07/09
            "2026-09-08T02:00:00Z",  // T3 08/09
            "2026-09-08T09:00:00Z",  // cùng ngày học: không đếm đôi
            "2026-09-13T20:30:00Z",  // 03:30 VN thứ Hai 14/09 → còn là Chủ nhật 13/09: tuần trước
            "2026-09-15T02:00:00Z",  // tuần này: không
        ] {
            try Fixtures.insertLog(in: db, cardID: card, reviewedAtIso: iso)
        }
        let story = try WeekStoryService.load(on: db, now: Fixtures.fixedNow)
        XCTAssertEqual(story.reviewDays, 3)
    }

    func testTopTermNeedsTwoMeetingsAndTieGoesToEarlierSavedWord() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let early = try vocab(db, col, "early", createdAt: "2026-08-01T00:00:00Z")
        let late = try vocab(db, col, "late", createdAt: "2026-08-02T00:00:00Z")
        let once = try vocab(db, col, "once", createdAt: "2026-08-03T00:00:00Z")
        for id in [early, late] {
            try encounter(db, id, "seen", "2026-09-08T02:00:00Z")
            try encounter(db, id, "seen", "2026-09-09T02:00:00Z")
        }
        try encounter(db, once, "seen", "2026-09-08T02:00:00Z")

        XCTAssertEqual(
            try WeekStoryService.load(on: db, now: Fixtures.fixedNow).topTerm, "early")

        let lonely = try Fixtures.seededDB()
        let c2 = try Fixtures.insertCollection(in: lonely, name: "B")
        let single = try vocab(lonely, c2, "single", createdAt: "2026-08-01T00:00:00Z")
        try encounter(lonely, single, "seen", "2026-09-08T02:00:00Z")
        XCTAssertNil(
            try WeekStoryService.load(on: lonely, now: Fixtures.fixedNow).topTerm,
            "một lần gặp thì chưa gọi là \"nhiều nhất\"")
    }

    func testEmptyWeekIsEmpty() throws {
        let db = try Fixtures.seededDB()
        let story = try WeekStoryService.load(on: db, now: Fixtures.fixedNow)
        XCTAssertTrue(story.isEmpty)
        XCTAssertTrue(story.lines.isEmpty)
    }

    func testLinesSkipZeroCounts() {
        let story = WeekStory(
            weekStart: "x", wordsSaved: 12, wordsReencountered: 0, recognizedCount: 3,
            reviewDays: 5, topTerm: "routine")
        XCTAssertEqual(
            story.lines,
            ["Giữ lại 12 từ mới.", "Nhận ra 3 lần.", "Ôn 5/7 ngày.", "Gặp nhiều nhất: routine."])
        XCTAssertFalse(story.isEmpty)
    }
}
