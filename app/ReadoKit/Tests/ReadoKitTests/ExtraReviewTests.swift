import ReadoKit
import XCTest

/// FR-18 tiêu chí 4 / extra-review-r1 (đảo ADR-011/043) — Ôn thêm: trộn thẻ
/// mới (LIFO, bỏ qua `daily_new_limit`) + thẻ đã học CHƯA đến hạn ("ôn sớm").
/// Owner chốt 2026-10-01: MỌI lượt chấm ghi lịch thật (không còn đường
/// `mode='cram'` chỉ-log của R1) — chấm/undo dùng chung `ReviewService.record`/
/// `undo`, test ở `ReviewQueueAndServiceTests`. File này chỉ test phần hàng đợi
/// Ôn thêm riêng (nguồn, trộn, bù, "mỗi lượt ra nhóm khác").
final class ExtraReviewTests: XCTestCase {

    private let now = Fixtures.fixedNow  // 2026-09-18T02:00:00Z
    private let future = "2026-09-25T00:00:00Z"
    private let past = "2026-09-10T00:00:00Z"

    @discardableResult
    private func insertLearned(
        _ db: SQLiteDatabase, collectionID: String, term: String,
        state: String = "review", dueIso: String, suspended: String? = nil
    ) throws -> String {
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: term)
        return try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: state, dueIso: dueIso,
            stability: 5, difficulty: 5, reps: 2,
            lastReviewIso: "2026-09-15T00:00:00Z", suspendedIso: suspended,
            scheduledDays: 10)
    }

    @discardableResult
    private func insertNew(
        _ db: SQLiteDatabase, collectionID: String, term: String,
        createdAt: String
    ) throws -> String {
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: term, createdAt: createdAt)
        return try Fixtures.insertCard(in: db, vocabItemID: vocabID, dueIso: createdAt)
    }

    // MARK: — extraReviewCardIDs ("10 từ đến hạn")

    func testExtraReviewOnlyLearnedNotDueNotSuspendedOrdered() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let later = try insertLearned(db, collectionID: col, term: "later", dueIso: "2026-10-30T00:00:00Z")
        let soon = try insertLearned(db, collectionID: col, term: "soon", dueIso: "2026-09-19T00:00:00Z")
        try insertLearned(db, collectionID: col, term: "due", dueIso: past)
        try insertNew(db, collectionID: col, term: "new", createdAt: future)
        try insertLearned(
            db, collectionID: col, term: "susp", dueIso: future,
            suspended: "2026-09-16T00:00:00Z")

        let ids = try ReviewQueue.extraReviewCardIDs(on: db, now: now, limit: 20)
        XCTAssertEqual(ids, [soon, later], "chỉ thẻ đã học, chưa due, chưa suspend; due gần trước")
    }

    /// T1 fsrs-queue-fix-r1 giữ nguyên ở Ôn thêm: thẻ due TỐI NAY (trước giờ
    /// chuyển ngày) đi đường srs, KHÔNG lọt vào Ôn thêm dù `due_at > now`.
    func testExtraReviewExcludesCardsDueLaterTodayBeforeDayCutoff() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let window = ReviewQueue.currentDayWindow(on: db, now: now)
        let windowEndDate = try XCTUnwrap(ISOTimestamp.date(from: window.end))

        let laterToday = try insertLearned(
            db, collectionID: col, term: "later-today",
            dueIso: ISOTimestamp.string(from: windowEndDate.addingTimeInterval(-3600)))
        let afterCutoff = try insertLearned(
            db, collectionID: col, term: "after-cutoff",
            dueIso: ISOTimestamp.string(from: windowEndDate.addingTimeInterval(3600)))

        let ids = try ReviewQueue.extraReviewCardIDs(on: db, now: now, limit: 20)
        XCTAssertEqual(
            ids, [afterCutoff],
            "due trước window.end (kể cả sau now) đi đường srs, không phải Ôn thêm")
        XCTAssertFalse(ids.contains(laterToday))
    }

    /// "Mỗi lượt ra nhóm khác" (owner chốt): thẻ đã có lượt chấm hôm nay (dù
    /// qua đường nào) không bị lôi lại ngay trong lượt Ôn thêm kế tiếp.
    func testExtraReviewExcludesCardsAlreadyReviewedToday() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let reviewedToday = try insertLearned(
            db, collectionID: col, term: "done-today", dueIso: future)
        let untouched = try insertLearned(
            db, collectionID: col, term: "untouched", dueIso: future)
        try Fixtures.insertLog(
            in: db, cardID: reviewedToday, reviewedAtIso: "2026-09-18T01:00:00Z")

        let ids = try ReviewQueue.extraReviewCardIDs(on: db, now: now, limit: 20)
        XCTAssertEqual(ids, [untouched])
    }

    func testExtraReviewRespectsScopeAndLimit() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        for i in 0..<15 {
            try insertLearned(db, collectionID: colA, term: "a\(i)", dueIso: future)
        }
        try insertLearned(db, collectionID: colB, term: "b0", dueIso: future)

        XCTAssertEqual(
            try ReviewQueue.extraReviewCardIDs(on: db, now: now, scope: [colA], limit: 10).count, 10)
        XCTAssertEqual(
            try ReviewQueue.extraReviewCardIDs(on: db, now: now, scope: [colB], limit: 10).count, 1)
    }

    // MARK: — interleave (hàm thuần)

    func testInterleaveAlternatesAndAppendsLeftover() throws {
        XCTAssertEqual(
            ReviewQueue.interleave(old: ["o1", "o2", "o3"], new: ["n1", "n2"]),
            ["o1", "n1", "o2", "n2", "o3"], "cũ trước, dư dồn cuối")
        XCTAssertEqual(
            ReviewQueue.interleave(old: [], new: ["n1", "n2"]), ["n1", "n2"])
        XCTAssertEqual(
            ReviewQueue.interleave(old: ["o1"], new: []), ["o1"])
        XCTAssertEqual(ReviewQueue.interleave(old: [], new: []), [])
    }

    // MARK: — extraCardIDs (trộn 10/10 + bù)

    func testExtraCardIDsMixesNewAndReviewInterleaved() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        // due_at TĂNG DẦN và khác nhau — extraReviewCardIDs sắp "sắp due trước",
        // trùng due_at sẽ tie-break theo uuid ngẫu nhiên (không tất định).
        var reviewIDs: [String] = []
        for i in 0..<3 {
            reviewIDs.append(
                try insertLearned(
                    db, collectionID: col, term: "r\(i)",
                    dueIso: "2026-09-2\(5 + i)T00:00:00Z"))
        }
        var newIDs: [String] = []
        for i in 0..<3 {
            newIDs.append(
                try insertNew(
                    db, collectionID: col, term: "n\(i)",
                    createdAt: "2026-09-0\(i + 1)T00:00:00Z"))
        }

        let ids = try ReviewQueue.extraCardIDs(on: db, now: now, scope: [col], limit: 20)
        // review (due tăng dần → r0,r1,r2) xen với new (LIFO, mới nhất trước → n2,n1,n0).
        XCTAssertEqual(ids, [reviewIDs[0], newIDs[2], reviewIDs[1], newIDs[1], reviewIDs[2], newIDs[0]])
    }

    func testExtraCardIDsReviewShortfallBackfilledByNew() throws {
        // Chỉ 2 thẻ ôn sớm nhưng 18 từ mới, limit 20, newShare 10 → review 2,
        // new bù lên 18 (20 - 2) thay vì dừng ở 10.
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        for i in 0..<2 {
            try insertLearned(db, collectionID: col, term: "r\(i)", dueIso: future)
        }
        for i in 0..<18 {
            try insertNew(
                db, collectionID: col, term: "n\(i)",
                createdAt: ISOTimestamp.string(
                    from: Fixtures.iso("2026-09-01T00:00:00Z").addingTimeInterval(Double(i) * 86_400)))
        }

        let ids = try ReviewQueue.extraCardIDs(on: db, now: now, scope: [col], limit: 20)
        XCTAssertEqual(ids.count, 20, "2 ôn sớm + 18 mới bù đủ 20")
    }

    func testExtraCardIDsNewShortfallBackfilledByReview() throws {
        // Chỉ 3 từ mới nhưng 17 thẻ ôn sớm, limit 20, newShare 10 → new 3,
        // review bù lên 17 (20 - 3) thay vì dừng ở 10.
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        for i in 0..<3 {
            try insertNew(db, collectionID: col, term: "n\(i)", createdAt: future)
        }
        for i in 0..<17 {
            try insertLearned(db, collectionID: col, term: "r\(i)", dueIso: future)
        }

        let ids = try ReviewQueue.extraCardIDs(on: db, now: now, scope: [col], limit: 20)
        XCTAssertEqual(ids.count, 20, "3 mới + 17 ôn sớm bù đủ 20")
    }

    // MARK: — extraAvailableCount (không bị limit của một lượt)

    func testExtraAvailableCountSumsNewAndReviewUncapped() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        for i in 0..<15 {
            try insertNew(db, collectionID: col, term: "n\(i)", createdAt: future)
        }
        for i in 0..<5 {
            try insertLearned(db, collectionID: col, term: "r\(i)", dueIso: future)
        }
        XCTAssertEqual(try ReviewQueue.extraAvailableCount(on: db, now: now, scope: [col]), 20)
    }

    func testExtraAvailableCountExcludesReviewedTodayAndSuspended() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let reviewedToday = try insertLearned(db, collectionID: col, term: "done", dueIso: future)
        try Fixtures.insertLog(
            in: db, cardID: reviewedToday, reviewedAtIso: "2026-09-18T01:00:00Z")
        try insertLearned(
            db, collectionID: col, term: "susp", dueIso: future,
            suspended: "2026-09-16T00:00:00Z")
        XCTAssertEqual(try ReviewQueue.extraAvailableCount(on: db, now: now, scope: [col]), 0)
    }

    // MARK: — loadExtraQueue (hydrate GIỮ thứ tự xen kẽ, không sắp lại theo due_at)

    func testLoadExtraQueueHydratesInInterleavedOrderNotDueAt() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        // due_at của thẻ mới (hôm nay) sớm hơn NHIỀU so với thẻ ôn sớm (tương
        // lai xa) — nếu hydrate sắp theo due_at, mới sẽ đứng hết trước ôn sớm,
        // phá thứ tự xen kẽ.
        let review0 = try insertLearned(db, collectionID: col, term: "r0", dueIso: future)
        let new0 = try insertNew(db, collectionID: col, term: "n0", createdAt: "2026-09-01T00:00:00Z")

        let (items, snaps) = try ReviewQueue.loadExtraQueue(on: db, now: now, scope: [col])
        XCTAssertEqual(items.map(\.cardID), [review0, new0])
        XCTAssertEqual(snaps[review0]?.state, "review")
        XCTAssertEqual(snaps[new0]?.state, "new")

        let empty = try ReviewQueue.loadExtraQueue(on: db, now: now, scope: ["không-tồn-tại"])
        XCTAssertTrue(empty.items.isEmpty)
    }
}
