import ReadoKit
import XCTest

/// FR-08 Vocabulary List + FR-17 (a+b+c) — danh sách từ, tổng quan collection,
/// đổi tên / xoá / chuyển lô giữ nguyên FSRS (không reset lịch ôn).
final class VocabularyListTests: XCTestCase {

    /// Chèn vocab tự do về pos/createdAt (fixture chuẩn khoá cứng `noun` +
    /// createdAt cố định — cần biến thiên để test thứ tự FR-08).
    @discardableResult
    private func insertVocab(
        _ db: SQLiteDatabase,
        collection: String,
        term: String,
        pos: String = "noun",
        createdAt: String = "2026-09-01T00:00:00Z",
        id: String = Identifier.uuid()
    ) throws -> String {
        try db.run(
            """
            INSERT INTO vocab_items (
              id, collection_id, term, term_normalized, pos, ipa,
              meaning_vi, example, cefr, created_at
            ) VALUES (?, ?, ?, ?, ?, NULL, 'nghĩa', 'ví dụ', NULL, ?);
            """,
            [
                .text(id), .text(collection), .text(term),
                .text(term.lowercased()), .text(pos), .text(createdAt),
            ])
        return id
    }

    private func inboxID(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(
            try db.scalarString(
                "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;"))
    }

    // MARK: — FR-08 Vocabulary List

    func testListReturnsFieldsAndCollectionName() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Sách A")
        try insertVocab(
            db, collection: col, term: "serendipity", pos: "noun",
            createdAt: "2026-09-10T10:00:00Z")

        let entries = try VocabRepository.listVocabulary(on: db, collectionID: col)
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.term, "serendipity")
        XCTAssertEqual(entry.pos, "noun")
        XCTAssertEqual(entry.meaningVI, "nghĩa")
        XCTAssertEqual(entry.example, "ví dụ")
        XCTAssertEqual(entry.collectionName, "Sách A")
    }

    /// FR-08 crit 3: cùng `term` nhiều dòng (nghĩa khác nhau) nằm cạnh nhau,
    /// KHÔNG gộp làm một — phân biệt bằng `pos`.
    func testListOrdersSameTermAdjacentNotMerged() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Sách A")
        try insertVocab(db, collection: col, term: "run", pos: "verb")
        try insertVocab(db, collection: col, term: "apple", pos: "noun")
        try insertVocab(db, collection: col, term: "run", pos: "noun")

        let entries = try VocabRepository.listVocabulary(
            on: db, collectionID: col, order: .byTerm)
        XCTAssertEqual(entries.map(\.term), ["apple", "run", "run"])
        XCTAssertEqual(entries[1].pos, "noun")
        XCTAssertEqual(entries[2].pos, "verb")
        XCTAssertEqual(entries.count, 3, "hai nghĩa của `run` không được gộp")
    }

    /// J6 — kho tạm sắp theo thời điểm thêm để "chọn nguyên lô chiều hôm qua".
    func testListByDateAddedOrder() throws {
        let db = try Fixtures.seededDB()
        let inbox = try inboxID(db)
        try insertVocab(db, collection: inbox, term: "newest", createdAt: "2026-09-03T00:00:00Z")
        try insertVocab(db, collection: inbox, term: "oldest", createdAt: "2026-09-01T00:00:00Z")
        try insertVocab(db, collection: inbox, term: "middle", createdAt: "2026-09-02T00:00:00Z")

        let entries = try VocabRepository.listVocabulary(
            on: db, collectionID: inbox, order: .byDateAdded)
        XCTAssertEqual(entries.map(\.term), ["oldest", "middle", "newest"])
    }

    func testListFiltersByCollectionID() throws {
        let db = try Fixtures.seededDB()
        let colA = try Fixtures.insertCollection(in: db, name: "A")
        let colB = try Fixtures.insertCollection(in: db, name: "B")
        try insertVocab(db, collection: colA, term: "onlyA")
        try insertVocab(db, collection: colB, term: "onlyB")

        let entries = try VocabRepository.listVocabulary(on: db, collectionID: colA)
        XCTAssertEqual(entries.map(\.term), ["onlyA"])
    }

    // MARK: — FR-17(c) chuyển lô giữ FSRS

    func testMoveBatchKeepsCardsUntouched() throws {
        let db = try Fixtures.seededDB()
        let inbox = try inboxID(db)
        let target = try Fixtures.insertCollection(in: db, name: "Đích")
        let vID = try insertVocab(db, collection: inbox, term: "move")
        let cardID = try Fixtures.insertCard(
            in: db, vocabItemID: vID, state: "review",
            dueIso: "2026-09-20T00:00:00Z",
            stability: 3.5, lapses: 2, scheduledDays: 7)

        let moved = try VocabRepository.moveVocabularyItems(
            on: db, fromCollectionID: inbox, itemIDs: [vID],
            toCollectionID: target)
        XCTAssertEqual(moved, 1)

        let newCollection = try db.scalarString(
            "SELECT collection_id FROM vocab_items WHERE id = ?;", [.text(vID)])
        XCTAssertEqual(newCollection, target)

        // FR-17: chuyển collection KHÔNG reset lịch FSRS — card nguyên vẹn.
        let card = try XCTUnwrap(
            db.rows(
                """
                SELECT id, vocab_item_id, state, due_at, stability, lapses, scheduled_days
                FROM cards WHERE id = ?;
                """, [.text(cardID)]).first)
        XCTAssertEqual(card[0].textValue, cardID)
        XCTAssertEqual(card[1].textValue, vID)
        XCTAssertEqual(card[2].textValue, "review")
        XCTAssertEqual(card[3].textValue, "2026-09-20T00:00:00Z")
        XCTAssertEqual(card[4].doubleValue ?? 0, 3.5, accuracy: 0.0001)
        XCTAssertEqual(card[5].intValue, 2)
        XCTAssertEqual(card[6].intValue, 7)
    }

    func testMoveToMissingCollectionThrows() throws {
        let db = try Fixtures.seededDB()
        let inbox = try inboxID(db)
        let vID = try insertVocab(db, collection: inbox, term: "move")
        XCTAssertThrowsError(
            try VocabRepository.moveVocabularyItems(
                on: db, fromCollectionID: inbox, itemIDs: [vID],
                toCollectionID: "missing-id")) { error in
            XCTAssertEqual(error as? CollectionError, .notFound)
        }
    }

    // MARK: — FR-17(b) đổi tên / xoá

    func testRenameCollection() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Cũ")
        XCTAssertTrue(try VocabRepository.renameCollection(on: db, id: col, name: "Mới"))
        let name = try db.scalarString(
            "SELECT name FROM collections WHERE id = ?;", [.text(col)])
        XCTAssertEqual(name, "Mới")
    }

    func testRenameInboxAllowed() throws {
        let db = try Fixtures.seededDB()
        let inbox = try inboxID(db)
        XCTAssertTrue(
            try VocabRepository.renameCollection(
                on: db, id: inbox, name: "Ngăn chưa phân loại"))
    }

    func testRenameDuplicateNameFails() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        try Fixtures.insertCollection(in: db, name: "B")
        XCTAssertFalse(try VocabRepository.renameCollection(on: db, id: a, name: "B"))
    }

    func testRenameEmptyNameFails() throws {
        let db = try Fixtures.seededDB()
        let a = try Fixtures.insertCollection(in: db, name: "A")
        XCTAssertFalse(try VocabRepository.renameCollection(on: db, id: a, name: "   "))
    }

    func testDeleteEmptyCollection() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Rỗng")
        let moved = try VocabRepository.deleteCollection(on: db, id: col)
        XCTAssertEqual(moved, 0)
        let remains = try db.scalarString(
            "SELECT id FROM collections WHERE id = ?;", [.text(col)])
        XCTAssertNil(remains)
    }

    func testDeleteInboxThrowsCannotDeleteDefault() throws {
        let db = try Fixtures.seededDB()
        let inbox = try inboxID(db)
        XCTAssertThrowsError(
            try VocabRepository.deleteCollection(on: db, id: inbox)) { error in
            XCTAssertEqual(error as? CollectionError, .cannotDeleteDefault)
        }
    }

    func testDeleteWithWordsThrowsHasWords() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Có từ")
        try insertVocab(db, collection: col, term: "a")
        try insertVocab(db, collection: col, term: "b")

        XCTAssertThrowsError(
            try VocabRepository.deleteCollection(on: db, id: col)) { error in
            XCTAssertEqual(error as? CollectionError, .hasWords(2))
        }
        // Chưa xoá — collection vẫn còn.
        XCTAssertNotNil(
            try db.scalarString(
                "SELECT id FROM collections WHERE id = ?;", [.text(col)]))
    }

    func testDeleteMovesWordsThenDeletes() throws {
        let db = try Fixtures.seededDB()
        let target = try Fixtures.insertCollection(in: db, name: "Đích")
        let col = try Fixtures.insertCollection(in: db, name: "Nguồn")
        try insertVocab(db, collection: col, term: "a")
        try insertVocab(db, collection: col, term: "b")

        let moved = try VocabRepository.deleteCollection(
            on: db, id: col, moveWordsTo: target)
        XCTAssertEqual(moved, 2)
        XCTAssertNil(
            try db.scalarString(
                "SELECT id FROM collections WHERE id = ?;", [.text(col)]))
        let count = try db.scalarInt64(
            "SELECT COUNT(*) FROM vocab_items WHERE collection_id = ?;",
            [.text(target)])
        XCTAssertEqual(count, 2)
    }

    // MARK: — FR-17(a) tổng quan collection

    func testSummaryWordCountDueLastAdded() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "S")
        // vocab + card đến hạn (due <= fixedNow) → dueNow đếm.
        let v1 = try insertVocab(
            db, collection: col, term: "one", createdAt: "2026-09-01T00:00:00Z")
        try Fixtures.insertCard(
            in: db, vocabItemID: v1, state: "review",
            dueIso: "2026-09-01T00:00:00Z")
        // vocab không card → chỉ tăng wordCount.
        try insertVocab(
            db, collection: col, term: "two", createdAt: "2026-09-05T00:00:00Z")

        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: Fixtures.fixedNow)
        let summary = try XCTUnwrap(summaries.first { $0.id == col })
        XCTAssertEqual(summary.name, "S")
        XCTAssertEqual(summary.wordCount, 2)
        XCTAssertEqual(summary.dueNow, 1)
        XCTAssertEqual(
            summary.lastAddedAt, Fixtures.iso("2026-09-05T00:00:00Z"))
    }

    /// Ý 4 motivation-r1 — `masteredCount` (Q-08): `state='review' AND
    /// stability >= 21 AND suspended_at IS NULL`. Khớp đúng điều kiện
    /// `Mastery.stabilityThreshold` / `VocabRepository.matureKeys` (FR-10).
    func testSummaryMasteredCount() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "M")

        // review + stability=21 → tính.
        let mastered = try insertVocab(db, collection: col, term: "mastered")
        try Fixtures.insertCard(
            in: db, vocabItemID: mastered, state: "review", stability: 21)

        // learning + stability=30 → chưa qua state review, KHÔNG tính.
        let learning = try insertVocab(db, collection: col, term: "learning")
        try Fixtures.insertCard(
            in: db, vocabItemID: learning, state: "learning", stability: 30)

        // review + stability=21 nhưng suspended (leech) → KHÔNG tính.
        let suspended = try insertVocab(db, collection: col, term: "suspended")
        try Fixtures.insertCard(
            in: db, vocabItemID: suspended, state: "review", stability: 21,
            suspendedIso: "2026-09-10T00:00:00Z")

        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: Fixtures.fixedNow)
        let summary = try XCTUnwrap(summaries.first { $0.id == col })
        XCTAssertEqual(summary.wordCount, 3)
        XCTAssertEqual(summary.masteredCount, 1)
    }

    /// cram-collection-r1 T3 — mỗi từ đúng 1 nhóm theo ưu tiên Đã thuộc › Đang học
    /// › Đang nhớ › Chưa học; từ chỉ còn thẻ suspended không thuộc nhóm nào.
    func testSummaryBucketsPriorityAndSum() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "B")

        // Đã thuộc thắng learning: 2 thẻ (2 direction) — review 21 + learning.
        let mastered = try insertVocab(db, collection: col, term: "mastered")
        try Fixtures.insertCard(
            in: db, vocabItemID: mastered, direction: "receptive",
            state: "review", stability: 21)
        try Fixtures.insertCard(
            in: db, vocabItemID: mastered, direction: "productive",
            state: "learning", stability: 1)
        // learning + review (chưa thuộc) → Đang học.
        let mixed = try insertVocab(db, collection: col, term: "mixed")
        try Fixtures.insertCard(
            in: db, vocabItemID: mixed, direction: "receptive",
            state: "learning", stability: 1)
        try Fixtures.insertCard(
            in: db, vocabItemID: mixed, direction: "productive",
            state: "review", stability: 5)
        // relearning → Đang học.
        let relearning = try insertVocab(db, collection: col, term: "relearning")
        try Fixtures.insertCard(
            in: db, vocabItemID: relearning, state: "relearning", stability: 2)
        // review stability 5 → Đang nhớ.
        let reviewing = try insertVocab(db, collection: col, term: "reviewing")
        try Fixtures.insertCard(
            in: db, vocabItemID: reviewing, state: "review", stability: 5)
        // chỉ thẻ new → Chưa học.
        let fresh = try insertVocab(db, collection: col, term: "fresh")
        try Fixtures.insertCard(in: db, vocabItemID: fresh, state: "new")
        // không thẻ nào → Chưa học.
        try insertVocab(db, collection: col, term: "nocard")
        // chỉ thẻ suspended → không nhóm nào.
        let suspended = try insertVocab(db, collection: col, term: "suspended")
        try Fixtures.insertCard(
            in: db, vocabItemID: suspended, state: "review", stability: 30,
            suspendedIso: "2026-09-10T00:00:00Z")

        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: Fixtures.fixedNow)
        let summary = try XCTUnwrap(summaries.first { $0.id == col })
        XCTAssertEqual(summary.wordCount, 7)
        XCTAssertEqual(summary.masteredCount, 1)
        XCTAssertEqual(summary.learningCount, 2)
        XCTAssertEqual(summary.reviewingCount, 1)
        XCTAssertEqual(summary.notStartedCount, 2)
        XCTAssertEqual(
            summary.masteredCount + summary.learningCount
                + summary.reviewingCount + summary.notStartedCount,
            summary.wordCount - 1)
    }

    /// `addedLast7Days` — 6 ngày trước tính, 8 ngày trước không.
    func testSummaryAddedLast7Days() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "7d")
        // fixedNow = 2026-09-18T02:00:00Z
        try insertVocab(
            db, collection: col, term: "recent", createdAt: "2026-09-12T02:00:00Z")
        try insertVocab(
            db, collection: col, term: "old", createdAt: "2026-09-10T02:00:00Z")

        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: Fixtures.fixedNow)
        let summary = try XCTUnwrap(summaries.first { $0.id == col })
        XCTAssertEqual(summary.wordCount, 2)
        XCTAssertEqual(summary.addedLast7Days, 1)
    }

    /// `crammableCount` (header) khớp đúng `ReviewQueue.crammableCount` (hàng đợi
    /// Cram) — một nguồn sự thật về điều kiện thẻ Cram được.
    func testSummaryCrammableMatchesReviewQueue() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "C")
        let future = "2026-09-25T00:00:00Z"
        let vocab = try insertVocab(db, collection: col, term: "v")
        // review chưa due → tính (x2 direction).
        try Fixtures.insertCard(
            in: db, vocabItemID: vocab, direction: "receptive",
            state: "review", dueIso: future)
        try Fixtures.insertCard(
            in: db, vocabItemID: vocab, direction: "productive",
            state: "learning", dueIso: future)
        // review đã due → không.
        let due = try insertVocab(db, collection: col, term: "due")
        try Fixtures.insertCard(
            in: db, vocabItemID: due, state: "review",
            dueIso: "2026-09-01T00:00:00Z")
        // new (due tương lai) → không.
        let fresh = try insertVocab(db, collection: col, term: "fresh")
        try Fixtures.insertCard(
            in: db, vocabItemID: fresh, state: "new", dueIso: future)
        // suspended → không.
        let suspended = try insertVocab(db, collection: col, term: "susp")
        try Fixtures.insertCard(
            in: db, vocabItemID: suspended, state: "review", dueIso: future,
            suspendedIso: "2026-09-10T00:00:00Z")

        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: Fixtures.fixedNow)
        let summary = try XCTUnwrap(summaries.first { $0.id == col })
        let queueCount = try ReviewQueue.crammableCount(
            on: db, now: Fixtures.fixedNow, scope: [col])
        XCTAssertEqual(summary.crammableCount, 2)
        XCTAssertEqual(Int64(summary.crammableCount), queueCount)
    }

    /// `nextDue` — MIN(due_at) sau now + số thẻ trong cùng ngày học (Asia/Ho_Chi_Minh,
    /// cutoff FR-11); thẻ suspended và thẻ ngày sau không tính. Không lịch → nil.
    func testNextDueSameDayCount() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "N")
        let empty = try Fixtures.insertCollection(in: db, name: "Rỗng")
        // fixedNow = 2026-09-18T02:00Z → ngày học kế tiếp 19/09 (VN 10:00 và 17:00).
        for (term, due, suspended) in [
            ("a", "2026-09-19T03:00:00Z", String?.none),
            ("b", "2026-09-19T10:00:00Z", nil),
            ("c", "2026-09-20T03:00:00Z", nil),
            ("d", "2026-09-19T05:00:00Z", "2026-09-10T00:00:00Z"),
        ] {
            let v = try insertVocab(db, collection: col, term: term)
            try Fixtures.insertCard(
                in: db, vocabItemID: v, state: "review", dueIso: due,
                suspendedIso: suspended)
        }

        let next = try XCTUnwrap(
            VocabRepository.nextDue(
                on: db, collectionID: col, now: Fixtures.fixedNow))
        XCTAssertEqual(next.date, Fixtures.iso("2026-09-19T03:00:00Z"))
        XCTAssertEqual(next.count, 2)
        XCTAssertNil(
            try VocabRepository.nextDue(
                on: db, collectionID: empty, now: Fixtures.fixedNow))
    }

    /// Bộ rỗng (0 vocab) → cả wordCount và masteredCount đều 0 — UI ẩn thanh
    /// tiến độ thay vì hiện "0/0" trông như lỗi.
    func testSummaryMasteredCountEmptyCollection() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "Rỗng")

        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: Fixtures.fixedNow)
        let summary = try XCTUnwrap(summaries.first { $0.id == col })
        XCTAssertEqual(summary.wordCount, 0)
        XCTAssertEqual(summary.masteredCount, 0)
    }
}