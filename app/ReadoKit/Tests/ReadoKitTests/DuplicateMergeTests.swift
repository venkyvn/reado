import ReadoKit
import XCTest

/// engagement-r1 T1 (FR-24, ADR-067) — `DuplicateMerge`: nhóm trùng + gộp một transaction.
/// DB test: timezone `Asia/Ho_Chi_Minh`, cutoff 4h → ngày học đổi lúc 21:00Z.
final class DuplicateMergeTests: XCTestCase {

    // MARK: — Helpers

    private struct World {
        let db: SQLiteDatabase
        let colA: String
        let colB: String
    }

    private func world() throws -> World {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "Sách A")
        let b = try Fixtures.insertCollection(in: db, name: "Sách B")
        return World(db: db, colA: a, colB: b)
    }

    @discardableResult
    private func vocab(
        _ w: World, id: String, term: String = "bank", pos: String = "noun",
        collection: String? = nil, meaning: String = "nghĩa", example: String? = nil,
        createdAt: String = "2026-09-01T00:00:00Z", card: String? = nil,
        state: String = "new", stability: Double = 0, lastReview: String? = nil,
        suspended: String? = nil
    ) throws -> String {
        try Fixtures.insertVocab(
            in: w.db, collectionID: collection ?? w.colA, term: term, id: id, pos: pos,
            meaningVI: meaning, createdAt: createdAt)
        if let example {
            try w.db.run(
                "UPDATE vocab_items SET example = ? WHERE id = ?;", [.text(example), .text(id)])
        }
        if let card {
            try Fixtures.insertCard(
                in: w.db, vocabItemID: id, state: state, id: card, stability: stability,
                lastReviewIso: lastReview, suspendedIso: suspended)
        }
        return id
    }

    private func encounter(
        _ w: World, id: String, vocab: String, kind: String, createdAt: String,
        sentence: String? = nil, collection: String? = nil
    ) throws {
        try w.db.run(
            """
            INSERT INTO encounters (id, vocab_item_id, kind, created_at, sentence, collection_id)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            [
                .text(id), .text(vocab), .text(kind), .text(createdAt),
                sentence.map { .text($0) } ?? .null, collection.map { .text($0) } ?? .null,
            ])
    }

    private func count(_ db: SQLiteDatabase, _ sql: String, _ params: [SQLValue] = []) throws -> Int {
        Int(try db.scalarInt64(sql, params) ?? 0)
    }

    private func totals(_ db: SQLiteDatabase) throws -> [Int] {
        try ["vocab_items", "cards", "review_logs", "encounters"].map {
            try count(db, "SELECT COUNT(*) FROM \($0);")
        }
    }

    // MARK: — groups

    func testGroupsOnlyKeysWithTwoOrMoreRows() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1")
        try vocab(w, id: "v2", collection: w.colB, card: "c2")
        try vocab(w, id: "v3", pos: "verb", card: "c3")
        try vocab(w, id: "v4", term: "river", card: "c4")

        let groups = try DuplicateMerge.groups(on: w.db)
        XCTAssertEqual(groups.map(\.key), ["bank|noun"])
        XCTAssertEqual(Set(groups[0].members.map(\.vocabItemID)), ["v1", "v2"])
        XCTAssertEqual(Set(groups[0].members.map(\.collectionName)), ["Sách A", "Sách B"])
    }

    func testGroupKeyIgnoresPosCaseAndSpaces() throws {
        let w = try world()
        try vocab(w, id: "v1", pos: "Noun", card: "c1")
        try vocab(w, id: "v2", pos: "noun ", card: "c2")
        XCTAssertEqual(try DuplicateMerge.groups(on: w.db).count, 1)
    }

    func testGroupPutsKeeperFirstAndCarriesMasteryLevel() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1", state: "learning", stability: 2)
        try vocab(w, id: "v2", collection: w.colB, card: "c2", state: "review", stability: 30)
        try encounter(
            w, id: "r1", vocab: "v2", kind: "recognized", createdAt: "2026-09-05T00:00:00Z")

        let group = try XCTUnwrap(DuplicateMerge.groups(on: w.db).first)
        XCTAssertEqual(group.members.map(\.vocabItemID), ["v2", "v1"])
        XCTAssertEqual(group.members[0].level, .absorbed)
        XCTAssertEqual(group.members[1].level, .learning)
    }

    // MARK: — keeper

    func testKeeperOrder() {
        typealias M = DuplicateMerge.Member
        // thẻ leech thua dù stability cao
        XCTAssertEqual(
            DuplicateMerge.keeper(of: [
                M(vocabItemID: "a", stability: 50, isSuspended: true),
                M(vocabItemID: "b", stability: 1),
            ])?.vocabItemID, "b")
        // stability cao nhất
        XCTAssertEqual(
            DuplicateMerge.keeper(of: [
                M(vocabItemID: "a", stability: 5), M(vocabItemID: "b", stability: 10),
            ])?.vocabItemID, "b")
        // hoà stability → last_review mới hơn
        XCTAssertEqual(
            DuplicateMerge.keeper(of: [
                M(vocabItemID: "a", stability: 5, lastReviewAt: "2026-09-05T00:00:00Z"),
                M(vocabItemID: "b", stability: 5, lastReviewAt: "2026-09-10T00:00:00Z"),
            ])?.vocabItemID, "b")
        // hoà stability → có last_review thắng nil
        XCTAssertEqual(
            DuplicateMerge.keeper(of: [
                M(vocabItemID: "a", stability: 5),
                M(vocabItemID: "b", stability: 5, lastReviewAt: "2026-09-01T00:00:00Z"),
            ])?.vocabItemID, "b")
        // hoà hết → created_at cũ hơn
        XCTAssertEqual(
            DuplicateMerge.keeper(of: [
                M(vocabItemID: "a", createdAt: "2026-09-03T00:00:00Z"),
                M(vocabItemID: "b", createdAt: "2026-09-01T00:00:00Z"),
            ])?.vocabItemID, "b")
        // hoà hết → id nhỏ hơn
        XCTAssertEqual(
            DuplicateMerge.keeper(of: [M(vocabItemID: "z"), M(vocabItemID: "y")])?.vocabItemID,
            "y")
        XCTAssertNil(DuplicateMerge.keeper(of: []))
    }

    // MARK: — merge

    func testMergeMovesReviewLogsToKeeperCard() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1", state: "review", stability: 30)
        try vocab(w, id: "v2", collection: w.colB, card: "c2", state: "learning", stability: 5)
        for i in 1...2 {
            try Fixtures.insertLog(in: w.db, cardID: "c1", reviewedAtIso: "2026-09-0\(i)T00:00:00Z")
        }
        for i in 3...5 {
            try Fixtures.insertLog(in: w.db, cardID: "c2", reviewedAtIso: "2026-09-0\(i)T00:00:00Z")
        }

        let summary = try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        XCTAssertEqual(summary, .init(groupsMerged: 1, rowsMerged: 1))
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM review_logs;"), 5)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM review_logs WHERE card_id = 'c1';"), 5)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM vocab_items WHERE id = 'v2';"), 0)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM cards;"), 1)
    }

    func testMergeKeepsKeeperFSRSUnchanged() throws {
        let w = try world()
        try vocab(
            w, id: "v1", card: "c1", state: "review", stability: 30,
            lastReview: "2026-09-10T00:00:00Z")
        try vocab(w, id: "v2", collection: w.colB, card: "c2", state: "learning", stability: 5)
        let sql = """
            SELECT state, stability, difficulty, reps, lapses, learning_steps, scheduled_days,
                   last_review_at, due_at, suspended_at FROM cards WHERE id = 'c1';
            """
        let before = Array(try XCTUnwrap(w.db.rows(sql, []).first))

        try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        XCTAssertEqual(Array(try XCTUnwrap(w.db.rows(sql, []).first)), before)
    }

    func testMergeAddsSeenFromMergedRow() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1", state: "review", stability: 30)
        try vocab(
            w, id: "v2", collection: w.colB, example: "He sat on the bank.",
            createdAt: "2026-09-02T00:00:00Z", card: "c2")

        try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        let rows = try w.db.rows(
            """
            SELECT sentence, collection_id, created_at FROM encounters
            WHERE vocab_item_id = 'v1' AND kind = 'seen';
            """, [])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0][0].textValue, "He sat on the bank.")
        XCTAssertEqual(rows[0][1].textValue, w.colB)
        XCTAssertEqual(rows[0][2].textValue, "2026-09-02T00:00:00Z")
    }

    func testMergeMovesEncounters() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1")
        try vocab(w, id: "v2", collection: w.colB, card: "c2")
        try encounter(
            w, id: "e-seen", vocab: "v2", kind: "seen", createdAt: "2026-09-03T00:00:00Z",
            sentence: "old sentence", collection: w.colB)
        try encounter(
            w, id: "e-rec", vocab: "v2", kind: "recognized", createdAt: "2026-09-04T00:00:00Z")

        try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        XCTAssertEqual(
            try count(
                w.db, "SELECT COUNT(*) FROM encounters WHERE id IN ('e-seen','e-rec') AND vocab_item_id = 'v1';"),
            2)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM encounters WHERE vocab_item_id = 'v2';"), 0)
    }

    func testMergeDropsRecognizedOnSameLearningDay() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1")
        try vocab(w, id: "v2", collection: w.colB, card: "c2")
        // Ngày học VN: [2026-09-09T21:00Z, 2026-09-10T21:00Z)
        try encounter(
            w, id: "k", vocab: "v1", kind: "recognized", createdAt: "2026-09-10T00:00:00Z")
        try encounter(
            w, id: "same", vocab: "v2", kind: "recognized", createdAt: "2026-09-10T10:00:00Z")
        try encounter(
            w, id: "next", vocab: "v2", kind: "recognized", createdAt: "2026-09-10T22:00:00Z")

        try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM encounters WHERE id = 'same';"), 0)
        XCTAssertEqual(
            try count(
                w.db, "SELECT COUNT(*) FROM encounters WHERE id = 'next' AND vocab_item_id = 'v1';"),
            1)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM encounters WHERE id = 'k';"), 1)
    }

    func testUnselectedRowsUntouched() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1", state: "review", stability: 30)
        try vocab(w, id: "v2", collection: w.colB, card: "c2")
        try vocab(w, id: "v3", collection: w.colB, card: "c3")
        try Fixtures.insertLog(in: w.db, cardID: "c3", reviewedAtIso: "2026-09-05T00:00:00Z")

        try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM vocab_items WHERE id = 'v3';"), 1)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM cards WHERE id = 'c3';"), 1)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM review_logs WHERE card_id = 'c3';"), 1)
    }

    func testKeeperStaysInItsCollection() throws {
        let w = try world()
        try vocab(w, id: "v1", collection: w.colB, card: "c1", state: "review", stability: 30)
        try vocab(w, id: "v2", collection: w.colA, card: "c2")

        try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        XCTAssertEqual(
            try w.db.scalarString("SELECT collection_id FROM vocab_items WHERE id = 'v1';"), w.colB)
        XCTAssertEqual(
            try count(w.db, "SELECT COUNT(*) FROM vocab_items WHERE collection_id = ?;", [.text(w.colA)]),
            0)
    }

    func testMergeAdoptsMergedCardWhenKeeperHasNone() throws {
        let w = try world()
        try vocab(w, id: "v1")
        try vocab(w, id: "v2", collection: w.colB, card: "c2", state: "review", stability: 9)
        try Fixtures.insertLog(in: w.db, cardID: "c2", reviewedAtIso: "2026-09-05T00:00:00Z")

        try DuplicateMerge.merge(
            on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["v2"])])

        XCTAssertEqual(
            try w.db.scalarString("SELECT vocab_item_id FROM cards WHERE id = 'c2';"), "v1")
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM review_logs WHERE card_id = 'c2';"), 1)
    }

    func testMergeRollsBackWhenAnySelectionInvalid() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1", state: "review", stability: 30)
        try vocab(w, id: "v2", collection: w.colB, example: "x", card: "c2")
        try vocab(w, id: "v3", term: "river", card: "c3")
        try vocab(w, id: "v4", term: "river", pos: "verb", card: "c4")
        try Fixtures.insertLog(in: w.db, cardID: "c2", reviewedAtIso: "2026-09-05T00:00:00Z")
        try encounter(w, id: "e1", vocab: "v2", kind: "seen", createdAt: "2026-09-03T00:00:00Z")
        let before = try totals(w.db)

        XCTAssertThrowsError(
            try DuplicateMerge.merge(
                on: w.db,
                selections: [
                    .init(keeperID: "v1", mergedIDs: ["v2"]),
                    .init(keeperID: "v3", mergedIDs: ["v4"]),
                ])
        ) { error in
            XCTAssertEqual(
                error as? DuplicateMerge.MergeError, .keyMismatch(keeperID: "v3", mergedID: "v4"))
        }
        XCTAssertEqual(try totals(w.db), before)
        XCTAssertEqual(try count(w.db, "SELECT COUNT(*) FROM vocab_items WHERE id = 'v2';"), 1)
    }

    func testMergeRejectsMissingRow() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1")
        XCTAssertThrowsError(
            try DuplicateMerge.merge(
                on: w.db, selections: [.init(keeperID: "v1", mergedIDs: ["ghost"])])
        ) { error in
            XCTAssertEqual(error as? DuplicateMerge.MergeError, .missingRow("ghost"))
        }
    }

    func testMergeWithEmptySelectionsIsNoop() throws {
        let w = try world()
        try vocab(w, id: "v1", card: "c1")
        let before = try totals(w.db)
        XCTAssertEqual(
            try DuplicateMerge.merge(on: w.db, selections: []), .init(groupsMerged: 0, rowsMerged: 0))
        XCTAssertEqual(
            try DuplicateMerge.merge(
                on: w.db, selections: [.init(keeperID: "v1", mergedIDs: [])]),
            .init(groupsMerged: 0, rowsMerged: 0))
        XCTAssertEqual(try totals(w.db), before)
    }
}
