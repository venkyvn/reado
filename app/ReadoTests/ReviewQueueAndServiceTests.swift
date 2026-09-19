import ReadoKit
import XCTest

/// ROADMAP 1.4 — queue hai nhánh (mới bị hạn mức / ôn lại không) +
/// transaction chấm thẻ + undo xoá đúng log (db.md A.2).
final class ReviewQueueAndServiceTests: XCTestCase {

    // MARK: Queue

    private func defaultCollectionID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(
            db.scalarString(
                "SELECT id FROM collections WHERE is_default = 1;"))
    }

    func testNewBranchLimitedByQuotaAndOrderedByDue() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        var inserted: [String] = []
        for i in 1...5 {
            let vocabID = try Fixtures.insertVocab(
                in: db, collectionID: collectionID, term: "term\(i)")
            let cardID = try Fixtures.insertCard(
                in: db, vocabItemID: vocabID,
                dueIso: "2026-09-01T00:00:0\(i)Z")
            inserted.append(cardID)
        }
        let result = try ReviewQueue.newCardIDs(on: db, quota: 2)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Array(result.prefix(2)), Array(inserted.prefix(2)),
                       "thứ tự due_at tăng dần, chặn quota")
    }

    func testNewBranchQuotaZeroReturnsEmpty() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "term")
        _ = try Fixtures.insertCard(in: db, vocabItemID: vocabID)
        XCTAssertEqual(Array(try ReviewQueue.newCardIDs(on: db, quota: 0)), [])
    }

    func testDueBranchNotLimitedAndOrdered() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        // Chèn ngược thứ tự, cutoff xa tương lai → đủ cả ba, sắp theo due_at.
        let vocab1 = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "one")
        let card1 = try Fixtures.insertCard(
            in: db, vocabItemID: vocab1, state: "review",
            dueIso: "2026-09-05T00:00:00Z")
        let vocab2 = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "two")
        let card2 = try Fixtures.insertCard(
            in: db, vocabItemID: vocab2, state: "review",
            dueIso: "2026-09-02T00:00:00Z")
        let vocab3 = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "three")
        let card3 = try Fixtures.insertCard(
            in: db, vocabItemID: vocab3, state: "relearning",
            dueIso: "2026-09-03T00:00:00Z")

        let result = try ReviewQueue.dueCardIDs(
            on: db, dueBeforeIso: "2026-12-31T23:59:59Z")
        XCTAssertEqual(result, [card2, card3, card1])
    }

    func testDueCutoffExcludesFuture() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "future")
        _ = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review",
            dueIso: "2026-10-01T00:00:00Z")
        XCTAssertEqual(
            Array(
                try ReviewQueue.dueCardIDs(
                    on: db, dueBeforeIso: "2026-09-30T23:59:59Z")),
            [])
    }

    func testSuspendedExcludedFromBothBranches() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabNew = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "s-new")
        let suspendedNew = try Fixtures.insertCard(
            in: db, vocabItemID: vocabNew, state: "new",
            suspendedIso: "2026-09-01T00:00:00Z")
        let vocabDue = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "s-due")
        let suspendedDue = try Fixtures.insertCard(
            in: db, vocabItemID: vocabDue, state: "review",
            dueIso: "2026-09-01T00:00:00Z",
            suspendedIso: "2026-09-01T00:00:00Z")

        let newIDs = try ReviewQueue.newCardIDs(on: db, quota: 100)
        XCTAssertFalse(newIDs.contains(suspendedNew))
        let dueIDs = try ReviewQueue.dueCardIDs(
            on: db, dueBeforeIso: "2026-12-31T23:59:59Z")
        XCTAssertFalse(dueIDs.contains(suspendedDue))
    }

    func testNewIntroducedCountUsesDayWindowStart() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        // Thẻ A: review đầu tiên trong ngày hôm nay → tính.
        let vocabA = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "a")
        let cardA = try Fixtures.insertCard(
            in: db, vocabItemID: vocabA, state: "review",
            dueIso: "2026-09-18T00:00:00Z")
        try Fixtures.insertLog(
            in: db, cardID: cardA, reviewedAtIso: "2026-09-18T01:00:00Z")
        // Thẻ B: review từ tuần trước → không tính.
        let vocabB = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "b")
        let cardB = try Fixtures.insertCard(
            in: db, vocabItemID: vocabB, state: "review",
            dueIso: "2026-09-18T00:00:00Z")
        try Fixtures.insertLog(
            in: db, cardID: cardB, reviewedAtIso: "2026-09-10T01:00:00Z")

        // dayStart VN 2026-09-18 (cutoff 4h +07) = 2026-09-17T21:00:00Z.
        let count = try ReviewQueue.newIntroducedCount(
            on: db, dayStartIso: "2026-09-17T21:00:00Z")
        XCTAssertEqual(count, 1)
    }

    // MARK: ReviewService — chấm thẻ

    func testRecordUpdatesCardAndInsertsLogInOneTransaction() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "record")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, dueIso: "2026-09-15T00:00:00Z")

        let before = try XCTUnwrap(
            ReviewService.fetchSnapshot(on: db, cardID: cardID))
        XCTAssertEqual(before.state, "new")
        XCTAssertEqual(before.stability, 0)

        let scheduler = try ReviewScheduler(
            settings: ReadoFSRS.readSettings(on: db))
        let now = Fixtures.fixedNow
        let outcome = try scheduler.grade(.good, snapshot: before, now: now)
        let logID = try ReviewService.record(
            on: db, cardID: cardID, before: before, outcome: outcome, now: now)

        // cards đã cập nhật.
        let cardRow = try XCTUnwrap(
            db.rows(
                """
                SELECT state, stability, difficulty, reps, lapses,
                       last_review_at, due_at, scheduled_days
                FROM cards WHERE id = ?;
                """, [.text(cardID)]).first)
        XCTAssertEqual(cardRow[0].textValue, "review")
        XCTAssertGreaterThan(cardRow[1].doubleValue ?? 0, 0)
        XCTAssertEqual(cardRow[3].intValue, 1)
        XCTAssertEqual(cardRow[5].textValue, "2026-09-18T02:00:00Z")
        XCTAssertEqual(cardRow[7].intValue, Int64(outcome.scheduledDays))

        // review_logs: ảnh chụp TRƯỚC khi chấm.
        let logRow = try XCTUnwrap(
            db.rows(
                """
                SELECT id, card_id, mode, rating, state_before,
                       stability_before, difficulty_before,
                       learning_steps_before, due_before, reviewed_at
                FROM review_logs WHERE id = ?;
                """, [.text(logID)]).first)
        XCTAssertEqual(logRow[0].textValue, logID)
        XCTAssertEqual(logRow[1].textValue, cardID)
        XCTAssertEqual(logRow[2].textValue, "srs")
        XCTAssertEqual(logRow[3].intValue, 3, "good = 3")
        XCTAssertEqual(logRow[4].textValue, "new", "state_before = TRƯỚC")
        XCTAssertEqual(logRow[5].doubleValue ?? -1, 0, "stability_before = 0")
        XCTAssertEqual(logRow[8].textValue, "2026-09-15T00:00:00Z")
        XCTAssertEqual(logRow[9].textValue, "2026-09-18T02:00:00Z")
    }

    func testUndoRestoresSnapshotAndDeletesExactLog() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "undo")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, dueIso: "2026-09-15T00:00:00Z")

        let before = try XCTUnwrap(
            ReviewService.fetchSnapshot(on: db, cardID: cardID))
        let scheduler = try ReviewScheduler(
            settings: ReadoFSRS.readSettings(on: db))
        let now = Fixtures.fixedNow
        let outcome = try scheduler.grade(.again, snapshot: before, now: now)
        let logID = try ReviewService.record(
            on: db, cardID: cardID, before: before, outcome: outcome, now: now)

        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM review_logs WHERE card_id = ?;",
                [.text(cardID)]),
            1)

        try ReviewService.undo(
            on: db, cardID: cardID, logID: logID, before: before)

        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM review_logs WHERE card_id = ?;",
                [.text(cardID)]),
            0, "undo phải XOÁ đúng log vừa ghi, không UPDATE")
        let restored = try XCTUnwrap(
            ReviewService.fetchSnapshot(on: db, cardID: cardID))
        XCTAssertEqual(restored.state, "new")
        XCTAssertEqual(restored.reps, 0)
        XCTAssertEqual(
            ISOTimestamp.string(from: restored.due), "2026-09-15T00:00:00Z")
        XCTAssertNil(restored.lastReview)
    }

    func testRecordRollsBackWhenLogInsertFails() throws {
        // Atomic proof: UPDATE chạy trước trong transaction, INSERT log sau
        // vi phạm CHECK (rating = 0 ngoài 1–4) → toàn bộ phải rollback.
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "atomic")
        let cardID = try Fixtures.insertCard(in: db, vocabItemID: vocabID)
        let before = try XCTUnwrap(
            ReviewService.fetchSnapshot(on: db, cardID: cardID))

        let now = Fixtures.fixedNow
        let bogusOutcome = ReviewOutcome(
            state: "review", due: now, stability: 1, difficulty: 5,
            reps: 1, lapses: 0, learningSteps: 0, scheduledDays: 0,
            rating: 0, elapsedDaysRounded: 0)

        XCTAssertThrowsError(
            try ReviewService.record(
                on: db, cardID: cardID, before: before,
                outcome: bogusOutcome, now: now),
            "rating 0 phải ném CHECK violation")

        let after = try XCTUnwrap(
            ReviewService.fetchSnapshot(on: db, cardID: cardID))
        XCTAssertEqual(after, before, "cards phải nguyên vẹn sau rollback")
        XCTAssertEqual(
            try db.scalarInt64("SELECT COUNT(*) FROM review_logs;"), 0,
            "log không được rơi rớt sau rollback")
    }
}