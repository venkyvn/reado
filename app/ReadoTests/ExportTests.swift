import Foundation
import ReadoKit
import XCTest

// MARK: - FR-16 Data Export — test hành vi TSV + JSON + collection filter + không lọt key
// DB: Fixtures.seededDB() tạo kho tạm "Kho tạm" is_default=1.
// Fixtures.insertCollection/isDefault=1 sẽ fail do UNIQUE partial index → KHÔNG insert second default.

final class ExportTests: XCTestCase {

    /// Tạo DB có 1 named collection + 1 vocab + 1 card; trả (db, colID).
    private func makeCol(
        name: String = "Sách A", id: String = "col-a", term: String = "hello"
    ) throws -> (db: SQLiteDatabase, colID: String, vocabID: String, cardID: String) {
        let db = try Fixtures.seededDB()
        let colID = try Fixtures.insertCollection(
            in: db, name: name, id: id, isDefault: 0)
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: colID, term: term)
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vocabID, state: "new")
        return (db, colID, vocabID, cardID)
    }

    // MARK: TSV — FR-16 #1/#2

    func testTSV_allCollections_includesSeedAndNamed() throws {
        let (db, _, _, _) = try makeCol(term: "hello")
        let tsv = try ExportService.buildTSV(on: db, collectionIDs: nil)
        let lines = tsv.split(separator: "\n").map(String.init)

        // Header + 1 row: "hello" (col-a); kho tạm seed không có vocab
        XCTAssertEqual(lines.first, "term\tpos\tipa\tmeaning_vi\tcefr\texample\tcollection")
        XCTAssertEqual(lines.count, 2, "1 từ col-a + header; kho tạm seed không có vocab")
        // Dùng components để đếm cả cột rỗng (ipa/cefr có thể rỗng → "\t\t").
        XCTAssertEqual(lines[1].components(separatedBy: "\t").count, 7)
    }

    func testTSV_filterByCollection() throws {
        let (db, colID, _, _) = try makeCol(term: "bonjour")
        let tsv = try ExportService.buildTSV(on: db, collectionIDs: [colID])
        let lines = tsv.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 2, "chỉ 1 row + header")
        XCTAssertTrue(lines[1].contains("bonjour"))
    }

    func testTSV_noVocabInAnyCollection_headerOnly() throws {
        let db = try Fixtures.seededDB()
        // kho tạm seed tồn tại nhưng KHÔNG có vocab → header-only
        let tsv = try ExportService.buildTSV(on: db, collectionIDs: nil)
        XCTAssertEqual(tsv, TSVBuilder.header + "\n")
    }

    func testTSV_nonexistentCollectionID_headerOnly() throws {
        let (db, _, _, _) = try makeCol()
        // collection không tồn tại → header-only, không crash
        let tsv = try ExportService.buildTSV(on: db, collectionIDs: ["col-khong-ton-tai"])
        XCTAssertEqual(tsv, TSVBuilder.header + "\n")
    }

    func testTSV_emptyArrayScope_returnsEmpty() throws {
        let (db, _, _, _) = try makeCol()
        let rows = try ExportService.fetchRows(on: db, collectionIDs: [])
        XCTAssertTrue(rows.isEmpty)
    }

    func testTSV_tabAndNewlineEscaped() throws {
        let db = try Fixtures.seededDB()
        let colID = try Fixtures.insertCollection(in: db, name: "Test", id: "col-t", isDefault: 0)
        let vid = try Fixtures.insertVocab(in: db, collectionID: colID, term: "x")
        try db.run(
            "UPDATE vocab_items SET meaning_vi = 'nghĩa\tcó\ttab\nvà\nnewline' WHERE id = ?;",
            [.text(vid)])
        let tsv = try ExportService.buildTSV(on: db, collectionIDs: [colID])
        let lines = tsv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 2, "row phải giữ nguyên 1 dòng, không bị newline tách")
        // Row vẫn đúng 7 cột TSV (tab trong field đã bị escape thành space)
        XCTAssertEqual(lines[1].components(separatedBy: "\t").count, 7)
        XCTAssertTrue(lines[1].contains("nghĩa có tab và newline"))
    }

    func testTSV_vietsnamesePreserved() throws {
        let (db, colID, vocabID, _) = try makeCol()
        // Ghi nghĩa tiếng Việt trực tiếp vào vocab item (Fixtures.insertVocab dùng meaning_vi "nghĩa giả")
        try db.run(
            "UPDATE vocab_items SET meaning_vi = 'Nghĩa tiếng Việt: â, ă, ơ, ô, ư' WHERE id = ?;",
            [.text(vocabID)])
        let tsv = try ExportService.buildTSV(on: db, collectionIDs: [colID])
        XCTAssertTrue(tsv.contains("Nghĩa tiếng Việt"))
    }

    // MARK: JSON — FR-16 #3

    func testJSON_structFormat() throws {
        let (db, _, _, _) = try makeCol(term: "hello")
        let data = try ExportService.buildJSON(on: db, now: Fixtures.fixedNow)
        let bundle = try JSONDecoder().decode(ExportBundle.self, from: data)

        XCTAssertEqual(bundle.format, "reado-export")
        XCTAssertEqual(bundle.version, 1)
        XCTAssertEqual(bundle.exportedAt, "2026-09-18T02:00:00Z")
        XCTAssertEqual(bundle.settings.timezone, "Asia/Ho_Chi_Minh")
        // 2 collections: kho tạm seed + col-a
        XCTAssertEqual(bundle.collections.count, 2)
        XCTAssertEqual(bundle.vocabItems.count, 1)
        XCTAssertEqual(bundle.cards.count, 1)
    }

    func testJSON_includesReviewLog() throws {
        let (db, _, _, cardID) = try makeCol(term: "hello")
        try Fixtures.insertLog(
            in: db, cardID: cardID, reviewedAtIso: "2026-09-18T02:05:00Z")
        let bundle = try ExportService.fetchBundle(on: db, now: Fixtures.fixedNow)
        XCTAssertEqual(bundle.reviewLogs.count, 1)
        XCTAssertEqual(bundle.reviewLogs.first?.stateBefore, "new")
        XCTAssertEqual(bundle.reviewLogs.first?.rating, 3)
    }

    func testJSON_includesEncounters() throws {
        let (db, _, vocabID, _) = try makeCol(term: "hello")
        try EncounterRepository.insertSeen(
            on: db, vocabItemIDs: [vocabID], now: Fixtures.fixedNow)
        try EncounterRepository.recordRecognized(
            on: db, vocabItemID: vocabID, now: Fixtures.fixedNow)

        let data = try ExportService.buildJSON(on: db, now: Fixtures.fixedNow)
        let bundle = try JSONDecoder().decode(ExportBundle.self, from: data)

        XCTAssertEqual(bundle.counts.encounters, 2)
        XCTAssertEqual(Set(bundle.encounters.map(\.kind)), ["seen", "recognized"])
        XCTAssertTrue(bundle.encounters.allSatisfy { $0.vocabItemID == vocabID })
        XCTAssertEqual(bundle.version, 1, "thêm khoá, không đổi version")
    }

    func testJSON_scopeRecorded() throws {
        let (db, colID, _, _) = try makeCol(term: "hello")
        let bundle = try ExportService.fetchBundle(
            on: db, scopeIDs: [colID], now: Fixtures.fixedNow)
        XCTAssertEqual(bundle.scope.collectionIDs, [colID])
        // data vẫn toàn bộ máy (backup) dù scope annotation
        XCTAssertEqual(bundle.vocabItems.count, 1)
    }

    // MARK: NFR-07 / Điều cấm #9 — không lọt key

    func testJSON_noApiKeys() throws {
        // Term "hello" — an toàn, không chứa chuỗi nhạy cảm.
        let (db, _, _, _) = try makeCol(term: "hello")
        let data = try ExportService.buildJSON(on: db, now: Fixtures.fixedNow)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(text.lowercased().contains("api_key"))
        XCTAssertFalse(text.lowercased().contains("base_url"))
    }

    func testExportBundleCodableRoundTrip() throws {
        let (db, _, _, _) = try makeCol(term: "roundtrip")
        let bundle = try ExportService.fetchBundle(on: db, now: Fixtures.fixedNow)
        let data = try JSONEncoder().encode(bundle)
        let decoded = try JSONDecoder().decode(ExportBundle.self, from: data)
        XCTAssertEqual(decoded.format, "reado-export")
        XCTAssertEqual(decoded.vocabItems.count, 1)
    }
}
