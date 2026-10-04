import ReadoKit
import XCTest

/// ROADMAP 3.2 — FR-19 Leech Handling (logic + test, UI để task sau).
/// Ngưỡng mặc định R1 = 6 🔶 TẠM, chưa chốt (nhóm Q-08) — xem Seeder.defaultLeechLapses.
final class LeechTests: XCTestCase {

    private func defaultCollectionID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(
            db.scalarString(
                "SELECT id FROM collections WHERE is_default = 1;"))
    }

    // MARK: — readThreshold

    func testReadThresholdReturnsSeededDefault() throws {
        let db = try Fixtures.seededDB()
        XCTAssertEqual(try LeechService.readThreshold(on: db), 6,
                       "Seeder phải ghi ngưỡng mặc định 6")
    }

    func testReadThresholdNullDisablesFeature() throws {
        let db = try Fixtures.seededDB()
        try db.run("UPDATE settings SET leech_lapses = NULL WHERE id = 1;")
        XCTAssertNil(try LeechService.readThreshold(on: db))
    }

    func testReadThresholdNonPositiveDisablesFeature() throws {
        // Cấu hình lỗi (<= 0) coi như tắt — tránh mọi card đều thành leech.
        let db = try Fixtures.seededDB()
        for bogus in [0, -5] {
            try db.run(
                "UPDATE settings SET leech_lapses = ? WHERE id = 1;",
                [.int(Int64(bogus))])
            XCTAssertNil(try LeechService.readThreshold(on: db),
                         "leech_lapses = \(bogus) phải tắt tính năng")
        }
    }

    // MARK: — evaluateAfterGrade: trigger / không trigger

    func testEvaluateSuspendsWhenLapsesReachThreshold() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "leech-hit")
        // lapses == ngưỡng (6) → boundary inclusive.
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review", lapses: 6)

        let outcome = try LeechService.evaluateAfterGrade(
            on: db, cardID: cardID, now: Fixtures.fixedNow)

        XCTAssertTrue(outcome.becameLeech)
        XCTAssertEqual(outcome.lapses, 6)
        XCTAssertEqual(outcome.threshold, 6)
        // suspended_at phải được set đúng thời điểm chấm.
        let suspended = try XCTUnwrap(
            db.scalarString(
                "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)]))
        XCTAssertEqual(suspended, ISOTimestamp.string(from: Fixtures.fixedNow))
    }

    func testEvaluateDoesNotSuspendBelowThreshold() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "leech-miss")
        // lapses < ngưỡng (5 < 6) → không suspend.
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review", lapses: 5)

        let outcome = try LeechService.evaluateAfterGrade(
            on: db, cardID: cardID, now: Fixtures.fixedNow)

        XCTAssertFalse(outcome.becameLeech)
        XCTAssertEqual(outcome.lapses, 5)
        let suspended = try db.scalar(
            "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)])
        XCTAssertTrue(suspended?.isNull ?? true,
                      "dưới ngưỡng thì suspended_at phải giữ NULL")
    }

    func testEvaluateAboveThresholdAlsoSuspends() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "leech-over")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review", lapses: 9)

        let outcome = try LeechService.evaluateAfterGrade(
            on: db, cardID: cardID, now: Fixtures.fixedNow)
        XCTAssertTrue(outcome.becameLeech)
        XCTAssertEqual(outcome.lapses, 9)
    }

    func testEvaluateWithDisabledThresholdNeverSuspends() throws {
        // leech_lapses = NULL → tính năng tắt, dù lapses cao.
        let db = try Fixtures.seededDB()
        try db.run("UPDATE settings SET leech_lapses = NULL WHERE id = 1;")
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "leech-off")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review", lapses: 50)

        let outcome = try LeechService.evaluateAfterGrade(
            on: db, cardID: cardID, now: Fixtures.fixedNow)

        XCTAssertFalse(outcome.becameLeech)
        XCTAssertNil(outcome.threshold, "threshold nil = tính năng tắt")
        XCTAssertEqual(outcome.lapses, 50, "vẫn trả lapses hiện tại để debug")
        let suspended = try db.scalar(
            "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)])
        XCTAssertTrue(suspended?.isNull ?? true, "tắt leech thì không suspend")
    }

    func testEvaluateIdempotentOnAlreadySuspendedCard() throws {
        // Card đã suspend rồi → gọi lại KHÔNG đổi suspended_at (giữ timestamp cũ)
        // và becameLeech = false (không báo "mới đánh dấu" lần nữa).
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "leech-twice")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review", lapses: 7,
            suspendedIso: "2026-09-01T00:00:00Z")

        let later = Fixtures.iso("2026-09-19T08:00:00Z")
        let outcome = try LeechService.evaluateAfterGrade(
            on: db, cardID: cardID, now: later)

        XCTAssertFalse(outcome.becameLeech, "đã suspend trước đó → không phải sự kiện mới")
        XCTAssertEqual(
            try db.scalarString(
                "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)]),
            "2026-09-01T00:00:00Z",
            "timestamp suspend cũ phải giữ nguyên")
    }

    func testEvaluateUnknownCardThrows() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try LeechService.evaluateAfterGrade(
                on: db, cardID: "khong-ton-tai", now: Fixtures.fixedNow))
    }

    // MARK: — unsuspend / delete

    func testUnsuspendClearsSuspendedAtAndKeepsFSRSState() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "back-to-queue")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "relearning",
            dueIso: "2026-09-10T00:00:00Z", lapses: 8,
            suspendedIso: "2026-09-05T00:00:00Z")

        try LeechService.unsuspend(on: db, cardID: cardID)

        let row = try XCTUnwrap(
            db.rows(
                "SELECT state, due_at, suspended_at, lapses FROM cards WHERE id = ?;",
                [.text(cardID)]).first)
        XCTAssertNil(row[2].textValue, "suspended_at phải về NULL")
        XCTAssertEqual(row[0].textValue, "relearning", "state FSRS không đổi")
        XCTAssertEqual(row[1].textValue, "2026-09-10T00:00:00Z", "due giữ nguyên")
        XCTAssertEqual(row[3].intValue, 8, "lapses giữ nguyên — không reset")
    }

    func testDeleteCardRemovesRow() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "doomed")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review", lapses: 10,
            suspendedIso: "2026-09-05T00:00:00Z")

        try LeechService.deleteCard(on: db, cardID: cardID)

        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM cards WHERE id = ?;", [.text(cardID)]),
            0, "card phải bị xoá hẳn")
        // Từ vựng vẫn còn (deleteCard chỉ xoá card, không cascade lên vocab_items).
        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM vocab_items WHERE id = ?;", [.text(vocabID)]),
            1)
    }

    func testDeleteWordCascadesCardsAndReviewLogs() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "gone-for-good")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review", lapses: 10,
            suspendedIso: "2026-09-05T00:00:00Z")
        try Fixtures.insertLog(in: db, cardID: cardID, reviewedAtIso: "2026-09-04T00:00:00Z")

        try LeechService.deleteWord(on: db, vocabItemID: vocabID)

        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM vocab_items WHERE id = ?;", [.text(vocabID)]),
            0, "vocab_item phải bị xoá hẳn")
        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM cards WHERE id = ?;", [.text(cardID)]),
            0, "CASCADE phải dọn card")
        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM review_logs WHERE card_id = ?;", [.text(cardID)]),
            0, "CASCADE phải dọn review_logs")
    }

    // MARK: — fetchLeeches

    func testFetchLeechesReturnsOnlySuspendedWithVocabContext() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)

        // 2 card leech (suspend) + 1 card bình thường (không suspend).
        let vA = try Fixtures.insertVocab(in: db, collectionID: collectionID, term: "alpha")
        let cA = try Fixtures.insertCard(
            in: db, vocabItemID: vA, state: "review", lapses: 7,
            suspendedIso: "2026-09-02T00:00:00Z")
        let vB = try Fixtures.insertVocab(in: db, collectionID: collectionID, term: "beta")
        let cB = try Fixtures.insertCard(
            in: db, vocabItemID: vB, state: "relearning", lapses: 6,
            suspendedIso: "2026-09-08T00:00:00Z")
        let vC = try Fixtures.insertVocab(in: db, collectionID: collectionID, term: "gamma")
        _ = try Fixtures.insertCard(
            in: db, vocabItemID: vC, state: "review", lapses: 99)

        let leeches = try LeechService.fetchLeeches(on: db)
        XCTAssertEqual(leeches.count, 2, "chỉ card suspend mới vào danh sách")
        // ORDER BY suspended_at DESC → beta (09-08) trước alpha (09-02).
        XCTAssertEqual(leeches.map(\.cardID), [cB, cA])
        XCTAssertEqual(leeches.first?.term, "beta")
        XCTAssertEqual(leeches.first?.meaningVI, "nghĩa giả")
        XCTAssertEqual(leeches.first?.lapses, 6)
        XCTAssertEqual(leeches.last?.cardID, cA)
    }

    func testFetchLeechesEmptyWhenNoneSuspended() throws {
        let db = try Fixtures.seededDB()
        XCTAssertEqual(try LeechService.fetchLeeches(on: db), [])
    }

    // MARK: — tích hợp: card leech bị loại khỏi hàng đợi (FR-19 criterion 4)

    func testLeechedCardExcludedFromFullQueue() throws {
        // Sau khi evaluate suspend card, loadFullQueue không được thấy nó.
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)

        // Card A: due hôm qua, lapses đạt ngưỡng → sẽ bị suspend.
        let vA = try Fixtures.insertVocab(in: db, collectionID: collectionID, term: "soon-leech")
        let cA = try Fixtures.insertCard(
            in: db, vocabItemID: vA, state: "review",
            dueIso: "2026-09-17T00:00:00Z", lapses: 6)
        // Card B: due hôm qua, lapses thấp → ở lại hàng đợi.
        let vB = try Fixtures.insertVocab(in: db, collectionID: collectionID, term: "stay")
        let cB = try Fixtures.insertCard(
            in: db, vocabItemID: vB, state: "review",
            dueIso: "2026-09-17T00:00:00Z", lapses: 1)

        // Trước khi suspend: cả hai đều trong queue.
        let before = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(Set(before.0.map(\.cardID)), [cA, cB])

        // Đánh dấu leech cho A.
        _ = try LeechService.evaluateAfterGrade(
            on: db, cardID: cA, now: Fixtures.fixedNow)

        // Sau: chỉ còn B.
        let after = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: 10, now: Fixtures.fixedNow)
        XCTAssertEqual(after.0.map(\.cardID), [cB],
                       "card leech phải ra khỏi hàng đợi (FR-19)")
    }

    func testEndToEndGradeChainMarksLeechAtThreshold() throws {
        // Mô phỏng đúng chuỗi production: ReviewService.record ghi lapses 5→6
        // sau một lần Again trên thẻ review (FSRS tăng lapse khi quên thẻ review),
        // rồi evaluateAfterGrade suspend đúng ngưỡng (6).
        let db = try Fixtures.seededDB()
        let collectionID = try defaultCollectionID(db)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "grind")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review",
            dueIso: "2026-08-01T00:00:00Z", stability: 3.0, difficulty: 5.0,
            reps: 2, lapses: 5)

        let scheduler = try ReviewScheduler(settings: ReadoFSRS.readSettings(on: db))
        let before = try XCTUnwrap(
            ReviewService.fetchSnapshot(on: db, cardID: cardID))
        let fsrsOutcome = try scheduler.grade(
            .again, snapshot: before, now: Fixtures.fixedNow)
        _ = try ReviewService.record(
            on: db, cardID: cardID, before: before,
            outcome: fsrsOutcome, now: Fixtures.fixedNow)
        let leech = try LeechService.evaluateAfterGrade(
            on: db, cardID: cardID, now: Fixtures.fixedNow)

        XCTAssertTrue(leech.becameLeech,
                      "Again trên thẻ review lapses=5 phải chạm ngưỡng 6")
        XCTAssertGreaterThanOrEqual(leech.lapses, 6)
        let suspended = try db.scalar(
            "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)])
        XCTAssertFalse(suspended?.isNull ?? true,
                       "card phải suspend sau chuỗi Again")
    }

    // MARK: — T2 fsrs-queue-fix-r1: leech cùng transaction với lần chấm

    /// Thẻ review lapses=5 + Again → lapses 6 (chạm ngưỡng).
    private func makeLeechBorderCard(
        _ db: SQLiteDatabase, term: String
    ) throws -> (cardID: String, before: CardSnapshot, outcome: ReviewOutcome) {
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: try defaultCollectionID(db), term: term)
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "review",
            dueIso: "2026-08-01T00:00:00Z", stability: 3.0, difficulty: 5.0,
            reps: 2, lapses: 5)
        let before = try XCTUnwrap(ReviewService.fetchSnapshot(on: db, cardID: cardID))
        let scheduler = try ReviewScheduler(settings: ReadoFSRS.readSettings(on: db))
        let outcome = try scheduler.grade(.again, snapshot: before, now: Fixtures.fixedNow)
        return (cardID, before, outcome)
    }

    func testRecordWithThresholdSuspendsAndLogsInOneCall() throws {
        let db = try Fixtures.seededDB()
        let (cardID, before, outcome) = try makeLeechBorderCard(db, term: "atomic-leech")
        let threshold = try XCTUnwrap(LeechService.readThreshold(on: db))

        let result = try ReviewService.record(
            on: db, cardID: cardID, before: before, outcome: outcome,
            leechThreshold: threshold, now: Fixtures.fixedNow)

        XCTAssertTrue(result.becameLeech, "một lần gọi record vừa ghi log vừa suspend")
        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM review_logs WHERE card_id = ?;", [.text(cardID)]),
            1)
        XCTAssertEqual(
            try db.scalarString(
                "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)]),
            ISOTimestamp.string(from: Fixtures.fixedNow),
            "suspended_at dùng cùng `now` với reviewed_at")
    }

    func testUndoOfLeechGradeLiftsSuspension() throws {
        let db = try Fixtures.seededDB()
        let (cardID, before, outcome) = try makeLeechBorderCard(db, term: "undo-leech")
        let result = try ReviewService.record(
            on: db, cardID: cardID, before: before, outcome: outcome,
            leechThreshold: 6, now: Fixtures.fixedNow)
        XCTAssertTrue(result.becameLeech)

        try ReviewService.undo(
            on: db, cardID: cardID, logID: result.logID, before: before)

        let restored = try XCTUnwrap(ReviewService.fetchSnapshot(on: db, cardID: cardID))
        XCTAssertNil(restored.suspendedAt, "undo trả thẻ về hàng đợi (suspended_at từ snapshot)")
        XCTAssertEqual(restored.lapses, 5)
        XCTAssertEqual(
            try db.scalarInt64("SELECT COUNT(*) FROM review_logs;"), 0)
    }

    func testRecordWithoutThresholdNeverSuspends() throws {
        let db = try Fixtures.seededDB()
        let (cardID, before, outcome) = try makeLeechBorderCard(db, term: "leech-off")

        let result = try ReviewService.record(
            on: db, cardID: cardID, before: before, outcome: outcome,
            leechThreshold: nil, now: Fixtures.fixedNow)

        XCTAssertFalse(result.becameLeech)
        let suspended = try db.scalar(
            "SELECT suspended_at FROM cards WHERE id = ?;", [.text(cardID)])
        XCTAssertEqual(suspended?.isNull, true, "tắt leech → không suspend")
    }

    func testRecordBelowThresholdDoesNotSuspend() throws {
        let db = try Fixtures.seededDB()
        let (cardID, before, outcome) = try makeLeechBorderCard(db, term: "below")

        let result = try ReviewService.record(
            on: db, cardID: cardID, before: before, outcome: outcome,
            leechThreshold: 7, now: Fixtures.fixedNow)

        XCTAssertFalse(result.becameLeech, "lapses 6 < ngưỡng 7")
    }
}