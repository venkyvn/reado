import ReadoKit
import XCTest

/// FR-20 — nhập CSV gộp: parse (tab/comma), khớp collection không hoa thường giữ dấu,
/// route collection (khớp/trống→kho tạm/lạ→tạo), card mới `new` due hôm nay, cảnh báo
/// term trùng (không tự loại), atomic (0 chọn → không ghi).
final class CSVImportTests: XCTestCase {

    private static let columns = [
        "term", "pos", "ipa", "meaning_vi", "cefr", "example", "collection",
    ]

    private func header(_ delimiter: String) -> String {
        Self.columns.joined(separator: delimiter)
    }

    /// Dựng text file từ header + các dòng.
    private func text(_ lines: [String], delimiter: String = "\t") -> String {
        ([header(delimiter)] + lines).joined(separator: "\n")
    }

    private func row(
        term: String, collection: String = "", meaningVI: String = "nghĩa"
    ) -> CSVImport.CSVRow {
        CSVImport.CSVRow(
            lineNumber: 2, term: term, pos: "noun", ipa: "", meaningVI: meaningVI,
            cefr: "", example: "", collection: collection)
    }

    private func vocabCount(_ db: SQLiteDatabase) throws -> Int {
        Int(try db.scalarInt64("SELECT COUNT(*) FROM vocab_items;") ?? 0)
    }

    private func collectionCount(_ db: SQLiteDatabase) throws -> Int {
        Int(try db.scalarInt64("SELECT COUNT(*) FROM collections;") ?? 0)
    }

    // MARK: — Parse

    func testParseTabSeparatedHeaderMatchesFR16() throws {
        let rows = try CSVImport.parse(
            text(["book\tnoun\t/bʊk/\tsách\tA2\ta book\tSách tiếng Anh"]))
        XCTAssertEqual(rows.count, 1)
        let r = try XCTUnwrap(rows.first)
        XCTAssertEqual(r.term, "book")
        XCTAssertEqual(r.pos, "noun")
        XCTAssertEqual(r.ipa, "/bʊk/")
        XCTAssertEqual(r.meaningVI, "sách")
        XCTAssertEqual(r.cefr, "A2")
        XCTAssertEqual(r.example, "a book")
        XCTAssertEqual(r.collection, "Sách tiếng Anh")
        XCTAssertEqual(r.lineNumber, 2)
    }

    func testParseCommaSeparatedWithQuotes() throws {
        let rows = try CSVImport.parse(
            text(
                ["\"hello there\",noun,,xin chào,B1,\"he said, hi\",Du lịch"],
                delimiter: ","))
        let r = try XCTUnwrap(rows.first)
        XCTAssertEqual(r.term, "hello there")
        XCTAssertEqual(r.example, "he said, hi")
        XCTAssertEqual(r.collection, "Du lịch")
    }

    func testParseThrowsOnMissingHeader() {
        XCTAssertThrowsError(
            try CSVImport.parse("book\tnoun\t\t\t\t\t")
        ) { error in
            XCTAssertEqual(error as? CSVImport.ImportError, .missingHeader)
        }
    }

    func testParseThrowsOnMalformedRow() {
        XCTAssertThrowsError(
            try CSVImport.parse(text(["book\tonly-two-columns"]))
        ) { error in
            guard case .malformedRow(let line, _) = error as? CSVImport.ImportError else {
                return XCTFail("phải là malformedRow, nhận \(error)")
            }
            XCTAssertEqual(line, 2)
        }
    }

    func testParseThrowsOnEmptyFile() {
        XCTAssertThrowsError(try CSVImport.parse("")) { error in
            XCTAssertEqual(error as? CSVImport.ImportError, .emptyFile)
        }
    }

    // MARK: — Khớp collection (gập hoa thường giữ dấu)

    func testImportMatchesCollectionVietnameseCaseInsensitive() throws {
        let db = try Fixtures.seededDB()
        let colID = try Fixtures.insertCollection(in: db, name: "sách")
        let summary = try CSVImport.importRows(
            on: db, rows: [row(term: "book", collection: "SÁCH")],
            now: Fixtures.fixedNow)
        XCTAssertEqual(summary.newItems, 1)
        XCTAssertEqual(summary.newCollections, 0, "không tạo collection trùng")
        let vocabCol = try XCTUnwrap(
            db.scalarString("SELECT collection_id FROM vocab_items WHERE term_normalized = 'book';"))
        XCTAssertEqual(vocabCol, colID)
        XCTAssertEqual(try collectionCount(db), 2, "kho tạm + sách")
    }

    func testImportKeepsDistinctToneMarks() throws {
        let db = try Fixtures.seededDB()
        let da = try Fixtures.insertCollection(in: db, name: "Đá")
        let da2 = try Fixtures.insertCollection(in: db, name: "Đã")
        _ = da2
        let summary = try CSVImport.importRows(
            on: db, rows: [row(term: "ice", collection: "Đá")],
            now: Fixtures.fixedNow)
        XCTAssertEqual(summary.newCollections, 0)
        let vocabCol = try XCTUnwrap(
            db.scalarString("SELECT collection_id FROM vocab_items WHERE term_normalized = 'ice';"))
        XCTAssertEqual(vocabCol, da, "Đá ≠ Đã — phải chọn đúng Đá")
        XCTAssertEqual(try collectionCount(db), 3)
    }

    // MARK: — Route collection

    func testImportEmptyCollectionGoesToInbox() throws {
        let db = try Fixtures.seededDB()
        let inbox = try XCTUnwrap(
            db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))
        _ = try CSVImport.importRows(
            on: db, rows: [row(term: "stray", collection: "  ")],
            now: Fixtures.fixedNow)
        let vocabCol = try XCTUnwrap(
            db.scalarString("SELECT collection_id FROM vocab_items WHERE term_normalized = 'stray';"))
        XCTAssertEqual(vocabCol, inbox)
    }

    func testImportUnknownCollectionCreatesNew() throws {
        let db = try Fixtures.seededDB()
        let summary = try CSVImport.importRows(
            on: db, rows: [row(term: "travel", collection: "Du lịch")],
            now: Fixtures.fixedNow)
        XCTAssertEqual(summary.newCollections, 1)
        let name = try XCTUnwrap(
            db.scalarString("SELECT name FROM collections WHERE name = 'Du lịch';"))
        XCTAssertEqual(name, "Du lịch")
    }

    // MARK: — Card mới

    func testImportCreatesNewCardDueToday() throws {
        let db = try Fixtures.seededDB()
        _ = try CSVImport.importRows(
            on: db, rows: [row(term: "book", collection: "sách")],
            now: Fixtures.fixedNow)
        let card = try XCTUnwrap(
            db.rows(
                """
                SELECT c.state, c.direction, c.due_at
                FROM cards c JOIN vocab_items v ON v.id = c.vocab_item_id
                WHERE v.term_normalized = 'book';
                """).first)
        XCTAssertEqual(card[0].textValue, "new")
        XCTAssertEqual(card[1].textValue, "receptive")
        XCTAssertEqual(
            card[2].textValue, ISOTimestamp.string(from: Fixtures.fixedNow))
    }

    // MARK: — Trùng term + atomic

    func testMarkDuplicateTermsFlagsAndKeepsSelected() throws {
        let db = try Fixtures.seededDB()
        let inbox = try XCTUnwrap(
            db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))
        try Fixtures.insertVocab(in: db, collectionID: inbox, term: "hello")
        let rows = try CSVImport.parse(text(["HELLO\tnoun\t\t\t\t\t"]))
        let existing = try CSVImport.existingTermNormalizedSet(on: db)
        let marked = CSVImport.markDuplicateTerms(rows, existing: existing)
        XCTAssertTrue(marked[0].duplicateTerm)
        XCTAssertTrue(marked[0].isSelected, "không tự loại dòng trùng")
    }

    func testImportZeroSelectedWritesNothing() throws {
        let db = try Fixtures.seededDB()
        let beforeVocab = try vocabCount(db)
        let beforeCol = try collectionCount(db)
        let rows = try CSVImport.parse(text(["book\tnoun\t\t\t\t\t"]))
        let deselected = rows.map { r -> CSVImport.CSVRow in
            var x = r; x.isSelected = false; return x
        }
        let summary = try CSVImport.importRows(
            on: db, rows: deselected, now: Fixtures.fixedNow)
        XCTAssertEqual(summary.newItems, 0)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(try vocabCount(db), beforeVocab)
        XCTAssertEqual(try collectionCount(db), beforeCol)
    }
}