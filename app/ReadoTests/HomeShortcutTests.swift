import ReadoKit
import XCTest

/// FR-17 — Home shortcut: đọc/ghi hai slot `settings.home_shortcut_*`, theo
/// thứ tự slot, tối đa 2, không kho tạm, không trùng; collection bị xoá → slot
/// tự NULL hoá (ON DELETE SET NULL), shortcut lỗi không dẫn màn hình chết.
final class HomeShortcutTests: XCTestCase {

    private func inboxID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(
            try db.scalarString(
                "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;"))
    }

    func testSeedHasNoShortcuts() throws {
        let db = try Fixtures.seededDB()
        XCTAssertEqual(try HomeShortcutService.ids(on: db), [])
    }

    func testSetTwoKeepsSlotOrder() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        let b = try Fixtures.insertCollection(in: db, name: "B")
        let written = try HomeShortcutService.set(on: db, ids: [a, b])
        XCTAssertEqual(written, [a, b])
        XCTAssertEqual(try HomeShortcutService.ids(on: db), [a, b])
        // Đọc thô đúng hai cột theo thứ tự slot 1 → 2.
        let row = try XCTUnwrap(
            db.rows(
                "SELECT home_shortcut_1_id, home_shortcut_2_id FROM settings WHERE id = 1;"
            ).first)
        XCTAssertEqual(row[0].textValue, a)
        XCTAssertEqual(row[1].textValue, b)
    }

    func testSetSingleSlot() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        XCTAssertEqual(try HomeShortcutService.set(on: db, ids: [a]), [a])
        XCTAssertEqual(try HomeShortcutService.ids(on: db), [a])
    }

    func testSetRejectsDuplicateIDs() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        XCTAssertThrowsError(
            try HomeShortcutService.set(on: db, ids: [a, a])
        ) { error in
            XCTAssertEqual(error as? HomeShortcutError, .duplicate)
        }
    }

    func testSetRejectsMoreThanTwo() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        let b = try Fixtures.insertCollection(in: db, name: "B")
        let c = try Fixtures.insertCollection(in: db, name: "C")
        XCTAssertThrowsError(
            try HomeShortcutService.set(on: db, ids: [a, b, c])
        ) { error in
            XCTAssertEqual(error as? HomeShortcutError, .tooMany)
        }
    }

    /// db.md A.2.2 — kho tạm không phải bài đọc chủ động, không ghim được.
    func testSetRejectsInbox() throws {
        let db = try Fixtures.seededDB()
        let inbox = try inboxID(db)
        XCTAssertThrowsError(
            try HomeShortcutService.set(on: db, ids: [inbox])
        ) { error in
            XCTAssertEqual(error as? HomeShortcutError, .isInbox)
        }
    }

    func testSetRejectsMissingCollection() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try HomeShortcutService.set(on: db, ids: ["missing-id"])
        ) { error in
            XCTAssertEqual(error as? HomeShortcutError, .notFound)
        }
    }

    func testSetFiltersEmptyIDs() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        XCTAssertEqual(
            try HomeShortcutService.set(on: db, ids: ["", a]), [a])
    }

    /// Xoá collection đang ghim → FK `ON DELETE SET NULL` bỏ slot, `ids` compact
    /// không trả slot NULL (PRD crit "shortcut lỗi bị bỏ").
    func testDeletePinnedCollectionClearsSlot() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        let b = try Fixtures.insertCollection(in: db, name: "B")
        try HomeShortcutService.set(on: db, ids: [a, b])
        try VocabRepository.deleteCollection(on: db, id: a)
        XCTAssertEqual(try HomeShortcutService.ids(on: db), [b])
    }

    /// Bỏ shortcut ở slot đầu → slot sau dồn lên, thứ tự vẫn compact.
    func testRemoveFirstKeepsOrderCompact() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        let b = try Fixtures.insertCollection(in: db, name: "B")
        try HomeShortcutService.set(on: db, ids: [a, b])
        let updated = try HomeShortcutService.set(on: db, ids: [b])
        XCTAssertEqual(updated, [b])
        XCTAssertEqual(try HomeShortcutService.ids(on: db), [b])
    }
}