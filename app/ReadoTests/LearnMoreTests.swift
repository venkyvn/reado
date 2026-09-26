import ReadoKit
import XCTest

/// motivation-r1 T2 (ý 3) — "Học thêm 10 từ": nới `daily_new_limit` RIÊNG ngày
/// học hiện tại, giữ trong bộ nhớ app (Q-A), N=10 cố định (Q-B). Hạn mức vẫn
/// áp TOÀN CỤC trước khi lọc phạm vi (FR-11) — `extraNew` chỉ đổi TRẦN, không
/// đổi cách đếm `newIntroducedCount`.
final class LearnMoreTests: XCTestCase {

    private func defaultCollectionID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(
            db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))
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

    // MARK: — loadFullQueue extraNew

    /// `extraNew = 0` (mặc định) → kết quả y hệt test FR-11 hiện có
    /// (`ScopedReviewTests.testGlobalDailyNewLimitAppliedBeforeScope`).
    func testExtraNewZeroMatchesExistingFR11Behavior() throws {
        let db = try Fixtures.seededDB()
        let inbox = try defaultCollectionID(db)
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        for i in 1...3 {
            try insertNew(
                db, collectionID: colA, term: "new\(i)",
                dueIso: "2026-09-18T00:00:0\(i)Z")
        }
        let inboxVocab = try Fixtures.insertVocab(
            in: db, collectionID: inbox, term: "introduced")
        let inboxCard = try Fixtures.insertCard(
            in: db, vocabItemID: inboxVocab, state: "new",
            dueIso: "2026-09-18T00:00:00Z")
        try Fixtures.insertLog(
            in: db, cardID: inboxCard, reviewedAtIso: "2026-09-18T01:00:00Z")

        let (items, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 2, now: Fixtures.fixedNow, scope: [colA], extraNew: 0)
        XCTAssertEqual(items.map(\.term), ["new1"],
                       "extraNew=0 phải giống hành vi cũ (chưa nới)")
    }

    /// limit 10, đã giới thiệu 10 (quota hết), `extraNew = 10` → đúng 10 thẻ
    /// new mới được đưa vào hàng đợi (không phải 0, không phải 20).
    func testExtraNewAddsExactlyTenWhenQuotaFullyConsumed() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")

        // 10 thẻ đã giới thiệu hôm nay (đã có log) — quota gốc hết. State
        // "learning" vì đã rời 'new' sau lượt chấm đầu — nếu không đổi state,
        // chúng vẫn đủ điều kiện `newCardIDs` chọn lại và giả vờ "10 thẻ mới"
        // trong khi thực ra là thẻ đã ôn (cũng tránh lẫn vào nhánh `dueCardIDs`
        // nếu đặt "review" với `due_at` trong quá khứ).
        for i in 1...10 {
            let v = try Fixtures.insertVocab(in: db, collectionID: col, term: "introduced\(i)")
            let card = try Fixtures.insertCard(
                in: db, vocabItemID: v, state: "learning",
                dueIso: "2026-09-18T00:00:0\(i % 10)Z")
            try Fixtures.insertLog(
                in: db, cardID: card, reviewedAtIso: "2026-09-18T01:00:00Z")
        }
        // 15 thẻ new khác chưa từng giới thiệu.
        for i in 1...15 {
            try insertNew(
                db, collectionID: col, term: "fresh\(i)",
                dueIso: "2026-09-18T02:00:\(String(format: "%02d", i))Z")
        }

        let (noExtra, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow, extraNew: 0)
        XCTAssertEqual(noExtra.count, 0, "quota gốc đã hết, chưa nới thì 0 thẻ mới")

        let (withExtra, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow, extraNew: 10)
        XCTAssertEqual(withExtra.count, 10, "nới 10 → đúng 10 thẻ, không phải 0 hay 20")
    }

    /// Scope 1 collection + `extraNew` — hạn mức vẫn áp TOÀN CỤC trước khi lọc
    /// phạm vi: tổng new lấy ra across scope filter đúng ≤ limit + extraNew,
    /// không nhân theo số collection.
    func testExtraNewStillGlobalAcrossScopeFilter() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")

        // colB đã ăn 3 thẻ new hôm nay (giới thiệu rồi) → trừ vào quota toàn cục.
        for i in 1...3 {
            let v = try Fixtures.insertVocab(in: db, collectionID: colB, term: "b-introduced\(i)")
            let card = try Fixtures.insertCard(
                in: db, vocabItemID: v, state: "new",
                dueIso: "2026-09-18T00:00:0\(i)Z")
            try Fixtures.insertLog(
                in: db, cardID: card, reviewedAtIso: "2026-09-18T01:00:00Z")
        }
        // colA có 10 thẻ new chưa giới thiệu — nhiều hơn cả limit+extraNew.
        for i in 1...10 {
            try insertNew(
                db, collectionID: colA, term: "a\(i)",
                dueIso: "2026-09-18T02:00:\(String(format: "%02d", i))Z")
        }

        // limit=5, extraNew=2 → trần toàn cục = 7, đã giới thiệu 3 → còn 4 cho
        // scope colA (không phải 5+2=7 riêng cho colA).
        let (items, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 5, now: Fixtures.fixedNow, scope: [colA], extraNew: 2)
        XCTAssertEqual(items.count, 4,
                       "trần toàn cục (5+2) trừ 3 đã giới thiệu ở bộ khác = 4, không nhân theo scope")
    }

    // MARK: — DailyProgressService.load extraNew

    func testDailyProgressLoadExtraNewIncreasesDueTodayAndShrinksBacklog() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        for i in 1...15 {
            try insertNew(
                db, collectionID: col, term: "term\(i)",
                dueIso: "2026-09-01T00:00:\(String(format: "%02d", i))Z")
        }

        let base = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(base.dueToday, 10)
        XCTAssertEqual(base.backlog, 5)
        XCTAssertEqual(base.totalNewRemaining, 15)

        let extended = try DailyProgressService.load(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow, extraNew: 10)
        XCTAssertEqual(extended.dueToday, 15, "nới 10 → cả 15 thẻ new còn lại vào hàng đợi")
        XCTAssertEqual(extended.backlog, 0)
        XCTAssertEqual(extended.totalNewRemaining, 15, "tổng tồn kho không đổi theo extraNew")
    }

    // MARK: — effectiveExtra (hàm thuần, không DB)

    func testEffectiveExtraReturnsStoredCountWhenSameDayStart() {
        let stored = (dayStart: "2026-09-18T04:00:00Z", count: 10)
        XCTAssertEqual(
            ReviewQueue.effectiveExtra(stored: stored, currentDayStart: "2026-09-18T04:00:00Z"),
            10)
    }

    func testEffectiveExtraResetsToZeroWhenDayStartDiffers() {
        let stored = (dayStart: "2026-09-18T04:00:00Z", count: 10)
        XCTAssertEqual(
            ReviewQueue.effectiveExtra(stored: stored, currentDayStart: "2026-09-19T04:00:00Z"),
            0, "qua ngày mới mất phần nới cũ, không cộng dồn")
    }

    func testEffectiveExtraReturnsZeroWhenNilStored() {
        XCTAssertEqual(
            ReviewQueue.effectiveExtra(stored: nil, currentDayStart: "2026-09-18T04:00:00Z"),
            0)
    }
}
