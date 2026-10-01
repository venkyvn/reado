import ReadoKit
import XCTest

/// Home pin — port UI lab (2026-09-23): FR-17 nâng từ 2 shortcut (cũ)
/// lên TỐI ĐA 5 collection "đang đọc", lưu JSON `settings.home_pin_ids` qua
/// `HomePinService`. Kho tạm không ghim được; không trùng; đọc/ghi giữ thứ tự.
final class HomePinTests: XCTestCase {

    private func inboxID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(
            try db.scalarString(
                "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;"))
    }

    func testSeedHasNoPins() throws {
        let db = try Fixtures.seededDB()
        XCTAssertEqual(try HomePinService.ids(on: db), [])
    }

    func testSetSingleKeepsSlot() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        XCTAssertEqual(try HomePinService.set(on: db, ids: [a]), [a])
        XCTAssertEqual(try HomePinService.ids(on: db), [a])
    }

    /// port UI lab: ghim được đủ 5 collection, giữ nguyên thứ tự user thêm.
    func testSetFiveKeepsOrder() throws {
        let db = try Fixtures.seededDB()
        let ids = try [
            Fixtures.insertCollection(in: db, name: "A"),
            Fixtures.insertCollection(in: db, name: "B"),
            Fixtures.insertCollection(in: db, name: "C"),
            Fixtures.insertCollection(in: db, name: "D"),
            Fixtures.insertCollection(in: db, name: "E"),
        ]
        let written = try HomePinService.set(on: db, ids: ids)
        XCTAssertEqual(written, ids)
        XCTAssertEqual(try HomePinService.ids(on: db), ids)
        // Đọc thô là JSON array theo đúng thứ tự đó.
        let json = try XCTUnwrap(
            db.scalarString("SELECT home_pin_ids FROM settings WHERE id = 1;"))
        XCTAssertEqual(
            try XCTUnwrap(
                (try? JSONDecoder().decode([String].self, from: Data(json.utf8)))),
            ids)
    }

    func testSetRejectsDuplicateIDs() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        XCTAssertThrowsError(
            try HomePinService.set(on: db, ids: [a, a])
        ) { error in
            XCTAssertEqual(error as? HomePinError, .duplicate)
        }
    }

    /// port UI lab: ghim thứ 6 → lỗi (tối đa 5).
    func testSetRejectsMoreThanFive() throws {
        let db = try Fixtures.seededDB()
        let ids = try [
            Fixtures.insertCollection(in: db, name: "A"),
            Fixtures.insertCollection(in: db, name: "B"),
            Fixtures.insertCollection(in: db, name: "C"),
            Fixtures.insertCollection(in: db, name: "D"),
            Fixtures.insertCollection(in: db, name: "E"),
            Fixtures.insertCollection(in: db, name: "F"),
        ]
        XCTAssertThrowsError(
            try HomePinService.set(on: db, ids: ids)
        ) { error in
            XCTAssertEqual(error as? HomePinError, .tooMany)
        }
    }

    /// db.md A.2.2 — kho tạm không phải bài đọc chủ động, không ghim được.
    func testSetRejectsInbox() throws {
        let db = try Fixtures.seededDB()
        let inbox = try inboxID(db)
        XCTAssertThrowsError(
            try HomePinService.set(on: db, ids: [inbox])
        ) { error in
            XCTAssertEqual(error as? HomePinError, .isInbox)
        }
    }

    func testSetRejectsMissingCollection() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try HomePinService.set(on: db, ids: ["missing-id"])
        ) { error in
            XCTAssertEqual(error as? HomePinError, .notFound)
        }
    }

    func testSetFiltersEmptyIDs() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        XCTAssertEqual(
            try HomePinService.set(on: db, ids: ["", a]), [a])
    }

    /// Xoá collection đang ghim → pin tự mất khỏi danh sách (đọc lại không còn).
    func testDeletePinnedCollectionDropsPin() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        let b = try Fixtures.insertCollection(in: db, name: "B")
        try HomePinService.set(on: db, ids: [a, b])
        // Ghi lại số collection đang ghim; sau xoá A phải tự trừ đi.
        try VocabRepository.deleteCollection(on: db, id: a)
        let remaining = try HomePinService.ids(on: db)
        XCTAssertEqual(remaining, [b])
        // Pin còn lại được ghi lại qua `set` (JSON không chứa id đã xoá).
        XCTAssertEqual(try HomePinService.set(on: db, ids: remaining), [b])
    }

    /// Bỏ pin ở đầu → các pin sau dồn lên, thứ tự vẫn compact.
    func testRemoveFirstKeepsOrderCompact() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        let b = try Fixtures.insertCollection(in: db, name: "B")
        try HomePinService.set(on: db, ids: [a, b])
        let updated = try HomePinService.set(on: db, ids: [b])
        XCTAssertEqual(updated, [b])
        XCTAssertEqual(try HomePinService.ids(on: db), [b])
    }

    /// port UI lab: bỏ ghim HẾT → JSON "[]", đọc lại rỗng (không resurrect slot cũ).
    func testClearAllPinsYieldsEmpty() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        try HomePinService.set(on: db, ids: [a])
        XCTAssertEqual(try HomePinService.set(on: db, ids: []), [])
        XCTAssertEqual(try HomePinService.ids(on: db), [])
    }
}