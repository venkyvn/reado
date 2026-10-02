import ReadoKit
import XCTest

/// Q-13 phương án B (ADR-056, `docs/plans/q13-sense-filter-r1.md` T1) —
/// `VocabRepository.matureSenses` / `matureKeys`: khoá `term|pos` → nghĩa
/// trong kho của các dòng đã thuộc, đúng điều kiện FR-10 (Q-08 + Q-09).
final class MatureSensesTests: XCTestCase {

    /// Một dòng đã thuộc → khoá có đúng 1 nghĩa trong kho.
    func testMatureSensesReturnsMeaningForMatchingKey() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "C")
        let bank = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "bank", pos: "noun",
            meaningVI: "ngân hàng")
        try Fixtures.insertCard(in: db, vocabItemID: bank, state: "review", stability: 21)

        let senses = try VocabRepository.matureSenses(on: db, collectionID: col)
        XCTAssertEqual(senses["bank|noun"], ["ngân hàng"])

        let keys = try VocabRepository.matureKeys(on: db, collectionID: col)
        XCTAssertEqual(keys, ["bank|noun"], "matureKeys là wrapper lấy khoá của matureSenses")
    }

    /// Ca lệch spec ở Context: khoá `term|pos` có NHIỀU dòng đã thuộc (vd đồng
    /// âm) → liệt kê đủ nghĩa, không chỉ lấy một.
    func testMatureSensesListsAllMeaningsForSameKey() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "C")
        let bank1 = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "bank", id: "bank-1", pos: "noun",
            meaningVI: "ngân hàng")
        try Fixtures.insertCard(in: db, vocabItemID: bank1, state: "review", stability: 21)
        let bank2 = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "bank", id: "bank-2", pos: "noun",
            meaningVI: "bờ sông")
        try Fixtures.insertCard(in: db, vocabItemID: bank2, state: "review", stability: 25)

        let senses = try VocabRepository.matureSenses(on: db, collectionID: col)
        XCTAssertEqual(Set(senses["bank|noun"] ?? []), ["ngân hàng", "bờ sông"])
    }

    /// Q-09: khác collection thì không khớp dù cùng term+pos+đã thuộc.
    func testMatureSensesDoesNotCrossCollections() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        let item = try Fixtures.insertVocab(
            in: db, collectionID: colA, term: "bank", pos: "noun", meaningVI: "ngân hàng")
        try Fixtures.insertCard(in: db, vocabItemID: item, state: "review", stability: 21)

        let sensesB = try VocabRepository.matureSenses(on: db, collectionID: colB)
        XCTAssertTrue(sensesB.isEmpty)
    }

    /// Leech (`suspended_at` khác NULL) không tính dù state/stability đạt.
    func testMatureSensesExcludesSuspendedLeech() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "C")
        let item = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "leechy", pos: "verb", meaningVI: "bị kẹt")
        try Fixtures.insertCard(
            in: db, vocabItemID: item, state: "review", stability: 30,
            suspendedIso: "2026-09-10T00:00:00Z")

        let senses = try VocabRepository.matureSenses(on: db, collectionID: col)
        XCTAssertTrue(senses.isEmpty)
    }

    /// `known_stability` NULL (mặc định seed) → ngưỡng 21 (Q-08): 20 chưa thuộc,
    /// 21 đã thuộc.
    func testMatureSensesDefaultThresholdIs21() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "C")
        let below = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "below", pos: "noun", meaningVI: "m1")
        try Fixtures.insertCard(in: db, vocabItemID: below, state: "review", stability: 20)
        let atThreshold = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "at21", pos: "noun", meaningVI: "m2")
        try Fixtures.insertCard(in: db, vocabItemID: atThreshold, state: "review", stability: 21)

        let senses = try VocabRepository.matureSenses(on: db, collectionID: col)
        XCTAssertNil(senses["below|noun"])
        XCTAssertEqual(senses["at21|noun"], ["m2"])
    }

    /// `known_stability` có giá trị tuỳ chỉnh trong settings → dùng số đó thay 21.
    func testMatureSensesUsesCustomKnownStability() throws {
        let db = try Fixtures.seededDB()
        try db.run("UPDATE settings SET known_stability = 10 WHERE id = 1;")
        let col = try Fixtures.insertCollection(in: db, name: "C")
        let item = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "early", pos: "noun", meaningVI: "sớm")
        try Fixtures.insertCard(in: db, vocabItemID: item, state: "review", stability: 10)

        let senses = try VocabRepository.matureSenses(on: db, collectionID: col)
        XCTAssertEqual(senses["early|noun"], ["sớm"], "ngưỡng tuỳ chỉnh 10 thay vì 21")
    }

    /// state khác `review` (vd `learning`) dù stability cao vẫn chưa thuộc —
    /// khớp điều kiện Q-08.
    func testMatureSensesRequiresReviewState() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "C")
        let item = try Fixtures.insertVocab(
            in: db, collectionID: col, term: "learning-word", pos: "noun", meaningVI: "m")
        try Fixtures.insertCard(in: db, vocabItemID: item, state: "learning", stability: 30)

        let senses = try VocabRepository.matureSenses(on: db, collectionID: col)
        XCTAssertTrue(senses.isEmpty)
    }
}
