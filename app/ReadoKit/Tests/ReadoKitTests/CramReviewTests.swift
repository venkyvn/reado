import ReadoKit
import XCTest

/// FR-18 tiêu chí 4 / ADR-011 / ADR-043 — Cram: ôn thẻ đã học mà CHƯA đến hạn.
/// Chấm + ghi log `mode='cram'`, KHÔNG đụng `cards` (lịch FSRS nguyên vẹn).
final class CramReviewTests: XCTestCase {

    private let now = Fixtures.fixedNow  // 2026-09-18T02:00:00Z
    private let future = "2026-09-25T00:00:00Z"
    private let past = "2026-09-10T00:00:00Z"

    @discardableResult
    private func insertCard(
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

    private func cardRow(_ db: SQLiteDatabase, _ id: String) throws -> [String] {
        let row = try XCTUnwrap(
            db.rows(
                """
                SELECT state, stability, difficulty, reps, lapses,
                       learning_steps, scheduled_days, last_review_at, due_at,
                       suspended_at
                FROM cards WHERE id = ?;
                """, [.text(id)]).first)
        return row.map { $0.textValue ?? String($0.intValue ?? -1) + "|" + String($0.doubleValue ?? -1) }
    }

    // MARK: — queue

    func testCramQueueOnlyLearnedNotDueNotSuspendedOrdered() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let later = try insertCard(db, collectionID: col, term: "later", dueIso: "2026-10-30T00:00:00Z")
        let soon = try insertCard(db, collectionID: col, term: "soon", dueIso: "2026-09-19T00:00:00Z")
        try insertCard(db, collectionID: col, term: "due", dueIso: past)
        try insertCard(db, collectionID: col, term: "new", state: "new", dueIso: future)
        try insertCard(
            db, collectionID: col, term: "susp", dueIso: future,
            suspended: "2026-09-16T00:00:00Z")

        let ids = try ReviewQueue.cramCardIDs(on: db, now: now)
        XCTAssertEqual(ids, [soon, later], "chỉ thẻ đã học, chưa due, chưa suspend; due gần trước")
        XCTAssertEqual(try ReviewQueue.crammableCount(on: db, now: now), 2)
    }

    /// T1 fsrs-queue-fix-r1 — thẻ due TỐI NAY (trước giờ chuyển ngày, dù sau
    /// `now`) đi đường srs (`dueCardIDs`), KHÔNG được lọt vào Cram dù
    /// `due_at > now` (bug cũ so trực tiếp với `now` thay vì `window.end`).
    func testCramExcludesCardsDueLaterTodayBeforeDayCutoff() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let window = ReviewQueue.currentDayWindow(on: db, now: now)
        let windowEndDate = try XCTUnwrap(ISOTimestamp.date(from: window.end))

        let laterToday = try insertCard(
            db, collectionID: col, term: "later-today",
            dueIso: ISOTimestamp.string(from: windowEndDate.addingTimeInterval(-3600)))
        let afterCutoff = try insertCard(
            db, collectionID: col, term: "after-cutoff",
            dueIso: ISOTimestamp.string(from: windowEndDate.addingTimeInterval(3600)))

        let ids = try ReviewQueue.cramCardIDs(on: db, now: now)
        XCTAssertEqual(
            ids, [afterCutoff],
            "due trước window.end (kể cả sau now) đi đường srs, không phải Cram")
        XCTAssertFalse(ids.contains(laterToday))
        XCTAssertEqual(try ReviewQueue.crammableCount(on: db, now: now), 1)
    }

    func testCramQueueRespectsScopeAndLimit() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        for i in 0..<25 {
            try insertCard(db, collectionID: colA, term: "a\(i)", dueIso: future)
        }
        try insertCard(db, collectionID: colB, term: "b0", dueIso: future)

        XCTAssertEqual(try ReviewQueue.cramCardIDs(on: db, now: now, scope: [colA]).count, 20)
        XCTAssertEqual(try ReviewQueue.cramCardIDs(on: db, now: now, scope: [colB]).count, 1)
        XCTAssertEqual(try ReviewQueue.cramCardIDs(on: db, now: now).count, 20, "limit 20 kể cả scope nil")
        XCTAssertEqual(
            try ReviewQueue.crammableCount(on: db, now: now, scope: [colA]), 25,
            "crammableCount không bị limit")
    }

    func testLoadCramQueueHydratesItemsAndSnapshots() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let id = try insertCard(db, collectionID: col, term: "hydrate", dueIso: future)

        let (items, snaps) = try ReviewQueue.loadCramQueue(on: db, now: now, scope: [col])
        XCTAssertEqual(items.map(\.cardID), [id])
        XCTAssertEqual(items.first?.term, "hydrate")
        XCTAssertEqual(snaps[id]?.state, "review")

        let empty = try ReviewQueue.loadCramQueue(on: db, now: now, scope: ["không-tồn-tại"])
        XCTAssertTrue(empty.items.isEmpty)
    }

    // MARK: — chấm

    func testRecordCramWritesCramLogAndLeavesCardUntouched() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let id = try insertCard(db, collectionID: col, term: "cram", dueIso: future)
        let before = try XCTUnwrap(ReviewService.fetchSnapshot(on: db, cardID: id))
        let cardBefore = try cardRow(db, id)

        let logID = try ReviewService.recordCram(
            on: db, cardID: id, before: before, rating: .again, now: now)

        XCTAssertEqual(try cardRow(db, id), cardBefore, "cards không đổi một cột nào (kể cả lapses)")
        let log = try XCTUnwrap(
            db.rows(
                """
                SELECT mode, rating, state_before, stability_before, due_before,
                       scheduled_days, reviewed_at
                FROM review_logs WHERE id = ?;
                """, [.text(logID)]).first)
        XCTAssertEqual(log[0].textValue, "cram")
        XCTAssertEqual(log[1].intValue, 1)
        XCTAssertEqual(log[2].textValue, "review")
        XCTAssertEqual(log[3].doubleValue, 5)
        XCTAssertEqual(log[4].textValue, future)
        XCTAssertEqual(log[5].intValue, 10, "scheduled_days = của card, không đổi")
        XCTAssertEqual(log[6].textValue, "2026-09-18T02:00:00Z")
    }

    func testCramAgainNeverTriggersLeechOrDueChange() throws {
        // Cram không gọi LeechService; lapses ở `cards` không tăng dù chấm Again nhiều lần.
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let id = try insertCard(db, collectionID: col, term: "leech?", dueIso: future)
        let before = try XCTUnwrap(ReviewService.fetchSnapshot(on: db, cardID: id))
        for _ in 0..<8 {
            try ReviewService.recordCram(
                on: db, cardID: id, before: before, rating: .again, now: now)
        }
        let after = try XCTUnwrap(ReviewService.fetchSnapshot(on: db, cardID: id))
        XCTAssertEqual(after, before)
        XCTAssertNil(after.suspendedAt)
    }

    func testUndoCramDeletesOnlyThatCramLog() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        let id = try insertCard(db, collectionID: col, term: "undo", dueIso: future)
        let srsLog = try Fixtures.insertLog(
            in: db, cardID: id, reviewedAtIso: "2026-09-15T00:00:00Z", mode: "srs")
        let before = try XCTUnwrap(ReviewService.fetchSnapshot(on: db, cardID: id))
        let cramLog = try ReviewService.recordCram(
            on: db, cardID: id, before: before, rating: .good, now: now)
        let cardBefore = try cardRow(db, id)

        try ReviewService.undoCram(on: db, cardID: id, logID: cramLog)
        XCTAssertNil(try db.scalarString("SELECT id FROM review_logs WHERE id = ?;", [.text(cramLog)]))

        // undoCram không xoá được log srs.
        try ReviewService.undoCram(on: db, cardID: id, logID: srsLog)
        XCTAssertNotNil(try db.scalarString("SELECT id FROM review_logs WHERE id = ?;", [.text(srsLog)]))
        XCTAssertEqual(try cardRow(db, id), cardBefore)
    }

    // MARK: — hạn mức thẻ mới (FR-11)

    func testCramLogDoesNotConsumeNewQuota() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        // Thẻ mới, chỉ có log cram hôm nay (kịch bản lý thuyết) → không tính "đã giới thiệu".
        let id = try insertCard(db, collectionID: col, term: "n", state: "new", dueIso: future)
        try Fixtures.insertLog(
            in: db, cardID: id, reviewedAtIso: "2026-09-18T01:00:00Z", mode: "cram")
        XCTAssertEqual(
            try ReviewQueue.newIntroducedCount(on: db, dayStartIso: "2026-09-17T21:00:00Z"), 0)

        // Log srs cùng thẻ vẫn được đếm như cũ.
        try Fixtures.insertLog(
            in: db, cardID: id, reviewedAtIso: "2026-09-18T01:30:00Z", mode: "srs")
        XCTAssertEqual(
            try ReviewQueue.newIntroducedCount(on: db, dayStartIso: "2026-09-17T21:00:00Z"), 1)
    }
}
