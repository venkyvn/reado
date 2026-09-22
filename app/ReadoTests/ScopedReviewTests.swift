import ReadoKit
import XCTest

/// FR-18 — ba chế độ phạm vi ôn (một / vài / tất cả) + nợ ngoài phạm vi nhìn thấy.
/// Cram (ôn chưa đến hạn, mode != srs) = R2, không test ở đây.
final class ScopedReviewTests: XCTestCase {

    private func defaultCollectionID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(
            db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))
    }

    @discardableResult
    private func insertDue(
        _ db: SQLiteDatabase,
        collectionID: String,
        term: String,
        dueIso: String,
        state: String = "review"
    ) throws -> String {
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: term)
        return try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: state, dueIso: dueIso)
    }

    @discardableResult
    private func insertNew(
        _ db: SQLiteDatabase,
        collectionID: String,
        term: String,
        dueIso: String
    ) throws -> String {
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: term)
        return try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "new", dueIso: dueIso)
    }

    // MARK: — dueCardIDs theo scope

    func testScopedDueBranchFiltersByCollection() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        try insertDue(db, collectionID: colA, term: "a-due", dueIso: "2026-01-01T00:00:00Z")
        try insertDue(db, collectionID: colB, term: "b-due", dueIso: "2026-02-01T00:00:00Z")

        let all = try ReviewQueue.dueCardIDs(
            on: db, dueBeforeIso: "2026-12-31T23:59:59Z")
        XCTAssertEqual(all.count, 2, "scope nil = tất cả")

        let aOnly = try ReviewQueue.dueCardIDs(
            on: db, dueBeforeIso: "2026-12-31T23:59:59Z", scope: [colA])
        XCTAssertEqual(aOnly.count, 1, "scope một collection chỉ lọc đúng nó")
    }

    func testScopedNewBranchQuotaStillApplies() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        for i in 1...3 {
            try insertNew(
                db, collectionID: colA, term: "new\(i)",
                dueIso: "2026-09-01T00:00:0\(i)Z")
        }
        let ids = try ReviewQueue.newCardIDs(on: db, quota: 2, scope: [colA])
        XCTAssertEqual(ids.count, 2, "quota vẫn chặn trong phạm vi hẹp")
    }

    // MARK: — loadFullQueue theo scope

    func testLoadFullQueueScopeFiltersAndKeepsCollectionName() throws {
        let db = try Fixtures.seededDB()
        let inbox = try defaultCollectionID(db)
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        try insertDue(db, collectionID: colA, term: "a", dueIso: "2026-09-17T00:00:00Z")
        try insertDue(db, collectionID: colB, term: "b", dueIso: "2026-09-17T00:00:00Z")
        try insertDue(db, collectionID: inbox, term: "c", dueIso: "2026-09-17T00:00:00Z")

        let (all, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 0, now: Fixtures.fixedNow)
        XCTAssertEqual(all.count, 3)

        let (onlyA, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 0, now: Fixtures.fixedNow, scope: [colA])
        XCTAssertEqual(onlyA.map(\.term), ["a"])
        XCTAssertEqual(onlyA.first?.collectionName, "A")
    }

    func testLoadFullQueueMixScopeIncludesSelectedCollections() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        let colC = try Fixtures.insertCollection(in: db, name: "C")
        try insertDue(db, collectionID: colA, term: "a", dueIso: "2026-09-17T00:00:00Z")
        try insertDue(db, collectionID: colB, term: "b", dueIso: "2026-09-17T00:00:00Z")
        try insertDue(db, collectionID: colC, term: "c", dueIso: "2026-09-17T00:00:00Z")

        let (mix, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 0, now: Fixtures.fixedNow, scope: [colA, colB])
        XCTAssertEqual(Set(mix.map(\.term)), ["a", "b"])
    }

    /// FR-11 crit: `daily_new_limit` áp TOÀN CỤC trước khi lọc phạm vi — thẻ new
    /// đã giới thiệu hôm nay ngoài scope vẫn trừ vào quota.
    func testGlobalDailyNewLimitAppliedBeforeScope() throws {
        let db = try Fixtures.seededDB()
        let inbox = try defaultCollectionID(db)
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        for i in 1...3 {
            try insertNew(
                db, collectionID: colA, term: "new\(i)",
                dueIso: "2026-09-18T00:00:0\(i)Z")
        }
        // 1 thẻ new ở inbox đã giới thiệu hôm nay → trừ vào quota TOÀN CỤC.
        let inboxVocab = try Fixtures.insertVocab(
            in: db, collectionID: inbox, term: "introduced")
        let inboxCard = try Fixtures.insertCard(
            in: db, vocabItemID: inboxVocab, state: "new",
            dueIso: "2026-09-18T00:00:00Z")
        try Fixtures.insertLog(
            in: db, cardID: inboxCard, reviewedAtIso: "2026-09-18T01:00:00Z")

        // dailyNewLimit=2, introduced toàn cục = 1 → remaining = 1 cho cả app.
        // Scope colA chỉ được chọn 1 thẻ new (không nới thành 2).
        let (items, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 2, now: Fixtures.fixedNow, scope: [colA])
        XCTAssertEqual(items.map(\.term), ["new1"],
                       "quota toàn cục áp TRƯỚC khi lọc phạm vi")
    }

    // MARK: — nợ ngoài phạm vi

    func testDueOutsideScopeCount() throws {
        let db = try Fixtures.seededDB()
        let inbox = try defaultCollectionID(db)
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        try insertDue(db, collectionID: colA, term: "a", dueIso: "2026-09-17T00:00:00Z")
        try insertDue(db, collectionID: colB, term: "b", dueIso: "2026-09-17T00:00:00Z")
        try insertDue(db, collectionID: inbox, term: "c", dueIso: "2026-09-17T00:00:00Z")

        let nowIso = "2026-09-18T02:00:00Z"
        XCTAssertEqual(
            try ReviewQueue.dueOutsideScopeCount(
                on: db, dueBeforeIso: nowIso, scope: [colA]),
            2, "B + inbox đều ngoài scope A")
        XCTAssertEqual(
            try ReviewQueue.dueOutsideScopeCount(
                on: db, dueBeforeIso: nowIso, scope: [colA, colB, inbox]),
            0)
        XCTAssertEqual(
            try ReviewQueue.dueOutsideScopeCount(
                on: db, dueBeforeIso: nowIso, scope: nil),
            0, "scope tất cả → không có nợ ngoài")
    }

    func testDueOutsideScopeExcludesFutureAndSuspended() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let inbox = try defaultCollectionID(db)
        // Due hôm nay ngoài scope → tính.
        try insertDue(db, collectionID: inbox, term: "due-now", dueIso: "2026-09-17T00:00:00Z")
        // Due tương lai ngoài scope → không tính.
        try insertDue(db, collectionID: inbox, term: "due-future", dueIso: "2026-10-01T00:00:00Z")
        // Suspended ngoài scope → không tính.
        let sv = try Fixtures.insertVocab(in: db, collectionID: inbox, term: "suspended")
        _ = try Fixtures.insertCard(
            in: db, vocabItemID: sv, state: "review",
            dueIso: "2026-09-17T00:00:00Z", suspendedIso: "2026-09-01T00:00:00Z")

        XCTAssertEqual(
            try ReviewQueue.dueOutsideScopeCount(
                on: db, dueBeforeIso: "2026-09-18T02:00:00Z", scope: [colA]),
            1, "chỉ đếm due quá khứ + không suspended")
    }
}