import Foundation
import XCTest
import ReadoKit

/// FR-09 / ADR-066 D1 — `VocabRepository.newSavedToday` đếm theo ngày học FR-11.
final class NewSavedTodayTests: XCTestCase {

    private func collectionID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(VocabRepository.defaultCollectionID(on: db))
    }

    func testCountsOnlyTodaysWindow() throws {
        let db = try Fixtures.seededDB()
        let cid = try collectionID(db)
        // fixedNow = 09:00 VN 2026-09-18, cutoff 4h → cửa sổ [09-17T21:00Z, 09-18T21:00Z).
        try Fixtures.insertVocab(in: db, collectionID: cid, term: "a", createdAt: "2026-09-18T01:00:00Z")
        try Fixtures.insertVocab(in: db, collectionID: cid, term: "b", createdAt: "2026-09-18T02:00:00Z")
        try Fixtures.insertVocab(in: db, collectionID: cid, term: "old", createdAt: "2026-09-17T05:00:00Z")
        XCTAssertEqual(try VocabRepository.newSavedToday(on: db, now: Fixtures.fixedNow), 2)
    }

    func testBoundaryAtCutoffHour() throws {
        let db = try Fixtures.seededDB()
        let cid = try collectionID(db)
        try Fixtures.insertVocab(in: db, collectionID: cid, term: "before", createdAt: "2026-09-17T20:59:00Z")
        XCTAssertEqual(try VocabRepository.newSavedToday(on: db, now: Fixtures.fixedNow), 0)
        try Fixtures.insertVocab(in: db, collectionID: cid, term: "at", createdAt: "2026-09-17T21:00:00Z")
        XCTAssertEqual(try VocabRepository.newSavedToday(on: db, now: Fixtures.fixedNow), 1)
    }

    func testWindowShiftsWithDayCutoffHour() throws {
        let db = try Fixtures.seededDB()
        let cid = try collectionID(db)
        try Fixtures.insertVocab(in: db, collectionID: cid, term: "x", createdAt: "2026-09-17T21:30:00Z")
        XCTAssertEqual(try VocabRepository.newSavedToday(on: db, now: Fixtures.fixedNow), 1)
        // cutoff 6h → ngày bắt đầu 09-17T23:00Z → "x" (04:30 VN) thuộc ngày trước.
        _ = try SettingsService.update(
            on: db, cefrLevels: [.b1], dailyNewLimit: 10, dayCutoffHour: 6)
        XCTAssertEqual(try VocabRepository.newSavedToday(on: db, now: Fixtures.fixedNow), 0)
    }
}
