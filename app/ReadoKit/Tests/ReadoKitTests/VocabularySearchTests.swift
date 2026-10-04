import ReadoKit
import XCTest

/// FR-08 — tìm từ xuyên mọi collection theo `term` hoặc `meaning_vi`, không phân
/// biệt hoa/thường/dấu tiếng Việt (home-eevas-r1 T4).
final class VocabularySearchTests: XCTestCase {

    // MARK: — searchFold

    func testSearchFoldStripsVietnameseDiacriticsAndCase() throws {
        XCTAssertEqual(VocabRepository.searchFold("Đá"), VocabRepository.searchFold("da"))
        XCTAssertEqual(VocabRepository.searchFold("KIÊN CƯỜNG"), "kien cuong")
    }

    // MARK: — searchVocabulary

    func testSearchMatchesTermIgnoringCaseAndDiacritics() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Sách A")
        try Fixtures.insertVocab(in: db, collectionID: col, term: "resilient")

        let results = try VocabRepository.searchVocabulary(on: db, query: "RESIL")
        XCTAssertEqual(results.map(\.term), ["resilient"])
    }

    func testSearchMatchesMeaning() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Sách A")
        try Fixtures.insertVocab(
            in: db, collectionID: col, term: "resilient", meaningVI: "kiên cường")

        let results = try VocabRepository.searchVocabulary(on: db, query: "kien cuong")
        XCTAssertEqual(results.map(\.term), ["resilient"])
    }

    func testSearchAcrossMultipleCollections() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        try Fixtures.insertVocab(in: db, collectionID: colA, term: "habitat")
        try Fixtures.insertVocab(in: db, collectionID: colB, term: "habit")

        let results = try VocabRepository.searchVocabulary(on: db, query: "habit")
        XCTAssertEqual(Set(results.map(\.collectionName)), ["A", "B"])
        XCTAssertEqual(results.count, 2)
    }

    func testSearchEmptyOrBlankQueryReturnsEmpty() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        try Fixtures.insertVocab(in: db, collectionID: col, term: "anything")

        XCTAssertEqual(try VocabRepository.searchVocabulary(on: db, query: ""), [])
        XCTAssertEqual(try VocabRepository.searchVocabulary(on: db, query: "   "), [])
    }

    /// Thứ tự: prefix-match term > contains-match term > chỉ khớp nghĩa.
    func testSearchOrdersPrefixBeforeContainsBeforeMeaningOnly() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        try Fixtures.insertVocab(
            in: db, collectionID: col, term: "zzz-contains-abc-zzz",
            meaningVI: "nghĩa giả")
        try Fixtures.insertVocab(
            in: db, collectionID: col, term: "abc-prefix", meaningVI: "nghĩa giả")
        try Fixtures.insertVocab(
            in: db, collectionID: col, term: "khong-lien-quan", meaningVI: "co chu abc trong nghia")

        let results = try VocabRepository.searchVocabulary(on: db, query: "abc")
        XCTAssertEqual(
            results.map(\.term),
            ["abc-prefix", "zzz-contains-abc-zzz", "khong-lien-quan"])
    }

    func testSearchLimitCapsResults() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")
        for i in 0..<5 {
            try Fixtures.insertVocab(in: db, collectionID: col, term: "match-\(i)")
        }

        let results = try VocabRepository.searchVocabulary(on: db, query: "match", limit: 2)
        XCTAssertEqual(results.count, 2)
    }
}
