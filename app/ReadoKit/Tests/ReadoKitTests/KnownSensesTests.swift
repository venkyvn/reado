import ReadoKit
import XCTest

/// vocab-identity-r1 T3 (ADR-066) — `VocabRepository.knownSenses`: so khớp toàn app.
final class KnownSensesTests: XCTestCase {

    func testMatchesAcrossCollectionsWithCollectionNames() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "Sách A")
        let b = try Fixtures.insertCollection(in: db, name: "Sách B")
        let one = try Fixtures.insertVocab(
            in: db, collectionID: a, term: "bank", id: "v1", meaningVI: "ngân hàng",
            createdAt: "2026-09-01T00:00:00Z")
        let two = try Fixtures.insertVocab(
            in: db, collectionID: b, term: "bank", id: "v2", meaningVI: "bờ sông",
            createdAt: "2026-09-02T00:00:00Z")
        try Fixtures.insertCard(in: db, vocabItemID: one)
        try Fixtures.insertCard(in: db, vocabItemID: two)

        let senses = try VocabRepository.knownSenses(on: db)
        let list = try XCTUnwrap(senses[VocabRepository.matureKey(term: "bank", pos: "noun")])
        XCTAssertEqual(list.map(\.vocabItemID), ["v1", "v2"])
        XCTAssertEqual(list.map(\.collectionName), ["Sách A", "Sách B"])
        XCTAssertEqual(list.map(\.meaningVI), ["ngân hàng", "bờ sông"])
    }

    func testIncludesNewLearningAndReviewStates() throws {
        let db = try Fixtures.seededDB()
        let c = try Fixtures.insertCollection(in: db, name: "C")
        for (term, state) in [("aa", "new"), ("bb", "learning"), ("cc", "review")] {
            let id = try Fixtures.insertVocab(in: db, collectionID: c, term: term)
            try Fixtures.insertCard(in: db, vocabItemID: id, state: state, stability: 1)
        }
        let senses = try VocabRepository.knownSenses(on: db)
        XCTAssertEqual(Set(senses.keys), ["aa|noun", "bb|noun", "cc|noun"])
        XCTAssertTrue(senses.values.allSatisfy { !$0[0].isMature && !$0[0].isLeech })
    }

    func testIsMatureFollowsKnownStabilityThreshold() throws {
        let db = try Fixtures.seededDB()
        let c = try Fixtures.insertCollection(in: db, name: "C")
        let low = try Fixtures.insertVocab(in: db, collectionID: c, term: "low")
        try Fixtures.insertCard(in: db, vocabItemID: low, state: "review", stability: 20)
        let high = try Fixtures.insertVocab(in: db, collectionID: c, term: "high")
        try Fixtures.insertCard(in: db, vocabItemID: high, state: "review", stability: 21)

        var senses = try VocabRepository.knownSenses(on: db)
        XCTAssertEqual(senses["low|noun"]?.first?.isMature, false)
        XCTAssertEqual(senses["high|noun"]?.first?.isMature, true)

        try db.run("UPDATE settings SET known_stability = 10 WHERE id = 1;")
        senses = try VocabRepository.knownSenses(on: db)
        XCTAssertEqual(senses["low|noun"]?.first?.isMature, true, "ngưỡng đọc từ settings")
    }

    func testLeechIsFlaggedNotDropped() throws {
        let db = try Fixtures.seededDB()
        let c = try Fixtures.insertCollection(in: db, name: "C")
        let id = try Fixtures.insertVocab(in: db, collectionID: c, term: "stubborn")
        try Fixtures.insertCard(
            in: db, vocabItemID: id, state: "review", stability: 30,
            suspendedIso: "2026-09-10T00:00:00Z")
        let sense = try XCTUnwrap(VocabRepository.knownSenses(on: db)["stubborn|noun"]?.first)
        XCTAssertTrue(sense.isLeech)
        XCTAssertFalse(sense.isMature, "leech không tính là đã thuộc")
    }

    func testVocabWithTwoCardsYieldsOneSense() throws {
        let db = try Fixtures.seededDB()
        let c = try Fixtures.insertCollection(in: db, name: "C")
        let id = try Fixtures.insertVocab(in: db, collectionID: c, term: "twin")
        try Fixtures.insertCard(in: db, vocabItemID: id, direction: "receptive", state: "review", stability: 30)
        try Fixtures.insertCard(in: db, vocabItemID: id, direction: "productive", state: "new")
        let list = try XCTUnwrap(VocabRepository.knownSenses(on: db)["twin|noun"])
        XCTAssertEqual(list.count, 1)
        XCTAssertTrue(list[0].isMature)
    }

    /// N6: đo, KHÔNG assert - số ghi vào journal. `measure` chỉ một lần mỗi test.
    private func db3000() throws -> (SQLiteDatabase, String) {
        let db = try Fixtures.seededDB()
        let c = try Fixtures.insertCollection(in: db, name: "C")
        try db.inTransaction {
            for i in 0..<3000 {
                let id = try Fixtures.insertVocab(
                    in: db, collectionID: c, term: "word\(i)", id: "w\(i)")
                try Fixtures.insertCard(
                    in: db, vocabItemID: id, state: "review", stability: Double(i % 40))
            }
        }
        return (db, c)
    }

    func testKnownSensesTimingAt3000Words() throws {
        let (db, _) = try db3000()
        measure { _ = try? VocabRepository.knownSenses(on: db) }
    }

    func testSaveCaptureTimingAt3000Words() throws {
        let (db, c) = try db3000()
        let text = (0..<200).map { "Sentence number \($0) uses word\($0 * 7) here." }
            .joined(separator: " ")
        let item = PageAnalysis.VocabularyItemIn(
            term: "fresh", pos: "noun", ipa: nil, meaningVI: "m", cefr: nil,
            example: "e", verification: .verified)
        measure {
            _ = try? VocabRepository.saveCapture(
                on: db, items: [item], collectionID: c,
                segments: [PageAnalysis.Segment(sourceEN: text, translationVI: "d")],
                now: Date())
        }
    }
}
