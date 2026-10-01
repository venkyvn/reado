import ReadoKit
import XCTest

/// refactor-r3 #2 — `SQLRow`: đọc theo TÊN cột (không vỡ im lặng khi đổi thứ tự
/// SELECT) mà vẫn dùng được như mảng như mã cũ.
final class SQLRowTests: XCTestCase {

    private func makeDB() throws -> SQLiteDatabase {
        let db = try SQLiteDatabase(inMemory: ())
        try db.exec("CREATE TABLE t (id TEXT, n INTEGER, x REAL, note TEXT);")
        try db.run(
            "INSERT INTO t (id, n, x, note) VALUES (?, ?, ?, ?);",
            [.text("a"), .int(7), .double(2.5), .null])
        return db
    }

    func testReadByNameMatchesPositionalRead() throws {
        let db = try makeDB()
        let row = try XCTUnwrap(db.rows("SELECT id, n, x, note FROM t;").first)
        XCTAssertEqual(row["id"].textValue, "a")
        XCTAssertEqual(row["n"].intValue, 7)
        XCTAssertEqual(row["x"].doubleValue, 2.5)
        XCTAssertTrue(row["note"].isNull)
        // Tương thích mã cũ: vẫn là Collection theo vị trí.
        XCTAssertEqual(row[0].textValue, "a")
        XCTAssertEqual(row.count, 4)
        XCTAssertEqual(row.first?.textValue, "a")
        XCTAssertEqual(row.last, .null)
    }

    func testNamedReadSurvivesReorderingTheSelectList() throws {
        // Đổi thứ tự cột trong SELECT: đọc theo tên vẫn đúng (đọc theo vị trí thì sai).
        let db = try makeDB()
        let row = try XCTUnwrap(db.rows("SELECT note, x, n, id FROM t;").first)
        XCTAssertEqual(row["id"].textValue, "a")
        XCTAssertEqual(row["n"].intValue, 7)
        XCTAssertEqual(row[0], .null, "vị trí 0 giờ là `note` — chính là chỗ vỡ im lặng")
    }

    func testAliasAndExpressionColumnsAreAddressableByAlias() throws {
        let db = try makeDB()
        let row = try XCTUnwrap(
            db.rows("SELECT t.id AS card_id, n * 2 AS doubled, IFNULL(note, '') AS note_text FROM t;").first)
        XCTAssertEqual(row["card_id"].textValue, "a")
        XCTAssertEqual(row["doubled"].intValue, 14)
        XCTAssertEqual(row["note_text"].textValue, "")
    }

    func testDuplicateColumnNameFirstOneWins() throws {
        let db = try makeDB()
        let row = try XCTUnwrap(db.rows("SELECT id AS k, n AS k FROM t;").first)
        XCTAssertEqual(row["k"].textValue, "a")
        XCTAssertEqual(row[1].intValue, 7, "cột thứ hai vẫn đọc được theo vị trí")
    }

    func testEveryRowKeepsItsOwnValuesButSharesTheNames() throws {
        let db = try makeDB()
        try db.run("INSERT INTO t (id, n, x, note) VALUES (?, ?, ?, ?);",
                   [.text("b"), .int(9), .double(0.5), .text("hi")])
        let rows = try db.rows("SELECT id, note FROM t ORDER BY id;")
        XCTAssertEqual(rows.map { $0["id"].textValue }, ["a", "b"])
        XCTAssertEqual(rows.map { $0["note"].textValue }, [nil, "hi"])
    }

    func testLimitStillApplies() throws {
        let db = try makeDB()
        try db.run("INSERT INTO t (id, n, x, note) VALUES (?, ?, ?, ?);",
                   [.text("b"), .int(9), .double(0.5), .null])
        XCTAssertEqual(try db.rows("SELECT id FROM t ORDER BY id;", limit: 1).count, 1)
    }
}
