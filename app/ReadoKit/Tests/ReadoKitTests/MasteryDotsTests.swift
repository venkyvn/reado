import ReadoKit
import XCTest

/// engagement-r1 T6 — `VocabRepository.masteryDots`: luật mức phải KHỚP bộ đếm của header Hub
/// (`allCollectionSummaries`), nếu không lưới chấm và legend sẽ nói hai điều khác nhau.
final class MasteryDotsTests: XCTestCase {

    private func insertVocab(_ db: SQLiteDatabase, _ col: String, _ term: String, _ day: Int) throws -> String {
        try Fixtures.insertVocab(
            in: db, collectionID: col, term: term,
            createdAt: "2026-09-\(String(format: "%02d", day))T00:00:00Z")
    }

    func testDotCountsMatchHeaderSummary() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "T")
        let other = try Fixtures.insertCollection(in: db, name: "Other")
        // (term, state, stability, suspended, số lần nhận ra)
        let specs: [(String, String, Double, Bool, Int)] = [
            ("fresh", "new", 0, false, 0),
            ("learn", "learning", 3, false, 0),
            ("review5", "review", 5, false, 0),
            ("relearn", "relearning", 40, false, 0),
            ("rem", "review", 30, false, 0),
            ("abs", "review", 30, false, 1),
            ("absTwo", "review", 25, false, 2),
            ("leech", "review", 30, true, 1),
        ]
        for (index, spec) in specs.enumerated() {
            let (term, state, stability, suspended, recognized) = spec
            let vocab = try insertVocab(db, col, term, index + 1)
            try Fixtures.insertCard(
                in: db, vocabItemID: vocab, state: state, stability: stability,
                suspendedIso: suspended ? "2026-09-10T00:00:00Z" : nil)
            for day in 0..<recognized {
                try EncounterRepository.recordRecognized(
                    on: db, vocabItemID: vocab,
                    now: Fixtures.fixedNow.addingTimeInterval(Double(day) * 86_400))
            }
        }
        _ = try insertVocab(db, col, "nocard", 20)
        // Từ ở bộ khác không lọt vào chấm của bộ này.
        let stray = try insertVocab(db, other, "stray", 21)
        try Fixtures.insertCard(in: db, vocabItemID: stray)

        let dots = try VocabRepository.masteryDots(on: db, collectionID: col)
        var byLevel: [Mastery.Level: Int] = [:]
        for dot in dots { byLevel[dot.level, default: 0] += 1 }
        let summary = try XCTUnwrap(
            VocabRepository.allCollectionSummaries(on: db, now: Fixtures.fixedNow)
                .first { $0.id == col })

        XCTAssertEqual(byLevel[.absorbed] ?? 0, summary.absorbedCount)
        XCTAssertEqual(byLevel[.remembered] ?? 0, summary.masteredCount - summary.absorbedCount)
        XCTAssertEqual(byLevel[.learning] ?? 0, summary.learningCount + summary.reviewingCount)
        XCTAssertEqual(byLevel[.new] ?? 0, summary.notStartedCount)
        XCTAssertEqual(
            byLevel[.absorbed], 2, "abs + absTwo")
        XCTAssertEqual(byLevel[.remembered], 1, "rem")
        XCTAssertEqual(byLevel[.learning], 3, "learn + review5 + relearn")
        XCTAssertEqual(byLevel[.new], 2, "fresh + nocard")
        XCTAssertEqual(dots.count, 8, "leech (chỉ còn thẻ suspend) không có chấm; từ bộ khác không vào")
        XCTAssertFalse(dots.map(\.term).contains("leech"))
        XCTAssertFalse(dots.map(\.term).contains("stray"))
    }

    func testDotsFollowCreatedAtOrderAndCarryDetail() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "T")
        let late = try insertVocab(db, col, "late", 9)
        let early = try insertVocab(db, col, "early", 2)
        try db.run(
            "UPDATE vocab_items SET example = 'An early example.', meaning_vi = 'sớm' WHERE id = ?;",
            [.text(early)])
        _ = late

        let dots = try VocabRepository.masteryDots(on: db, collectionID: col)

        XCTAssertEqual(dots.map(\.term), ["early", "late"])
        XCTAssertEqual(dots.first?.example, "An early example.")
        XCTAssertEqual(dots.first?.meaningVI, "sớm")
        XCTAssertEqual(dots.first?.level, .new, "từ chưa có thẻ = Mới")
    }

    func testEmptyCollectionHasNoDots() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Empty")
        XCTAssertTrue(try VocabRepository.masteryDots(on: db, collectionID: col).isEmpty)
    }
}
