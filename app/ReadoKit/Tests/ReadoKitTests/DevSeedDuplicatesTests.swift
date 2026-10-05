import ReadoKit
import XCTest

/// engagement-r1 T2 — `DevSeed.addDuplicates` dựng đúng nhóm trùng cho màn "Gộp từ trùng".
final class DevSeedDuplicatesTests: XCTestCase {

    func testAddDuplicatesBuildsTwoGroupsAndIsIdempotent() throws {
        let db = try Fixtures.seededDB()
        let c = try Fixtures.insertCollection(in: db, name: "Sách A")
        for (id, term) in [("v1", "bank"), ("v2", "river"), ("v3", "stone")] {
            try Fixtures.insertVocab(in: db, collectionID: c, term: term, id: id)
            try Fixtures.insertCard(in: db, vocabItemID: id)
        }

        try DevSeed.addDuplicates(on: db, now: Fixtures.fixedNow)
        try DevSeed.addDuplicates(on: db, now: Fixtures.fixedNow)

        let groups = try DuplicateMerge.groups(on: db)
        XCTAssertEqual(groups.map(\.key), ["bank|noun", "river|noun"])
        XCTAssertEqual(groups[0].members.count, 3)
        XCTAssertEqual(groups[1].members.count, 2)
        XCTAssertEqual(groups[0].members[0].vocabItemID, "v1", "thẻ đã học đứng đầu (giữ)")
        XCTAssertEqual(groups[0].members[0].level, .remembered)
    }

    func testAddDuplicatesOnEmptyKhoDoesNothing() throws {
        let db = try Fixtures.seededDB()
        try DevSeed.addDuplicates(on: db, now: Fixtures.fixedNow)
        XCTAssertTrue(try DuplicateMerge.groups(on: db).isEmpty)
    }
}
