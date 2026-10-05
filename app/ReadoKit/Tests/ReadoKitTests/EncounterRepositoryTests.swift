import ReadoKit
import XCTest

/// reencounter-r1 T1 (FR-22, ADR-048) — bảng `encounters` + repository.
final class EncounterRepositoryTests: XCTestCase {

    private func inbox(_ db: SQLiteDatabase) throws -> String {
        try XCTUnwrap(db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))
    }

    private func vocab(_ db: SQLiteDatabase, _ term: String, in collection: String? = nil) throws -> String {
        try Fixtures.insertVocab(
            in: db, collectionID: try collection ?? inbox(db), term: term)
    }

    // MARK: seen

    func testInsertSeenWritesOneRowPerDistinctVocab() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        let b = try vocab(db, "beta")

        let written = try EncounterRepository.insertSeen(
            on: db, vocabItemIDs: [a, a, b], now: Fixtures.fixedNow)

        XCTAssertEqual(written, 2, "id trùng trong một lần lưu chỉ tính một")
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: a, kind: .seen), 1)
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: b, kind: .seen), 1)
    }

    func testSeenAccumulatesAcrossSaves() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        try EncounterRepository.insertSeen(on: db, vocabItemIDs: [a], now: Fixtures.fixedNow)
        try EncounterRepository.insertSeen(
            on: db, vocabItemIDs: [a], now: Fixtures.fixedNow.addingTimeInterval(60))
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: a, kind: .seen), 2)
    }

    func testInsertSeenRejectsUnknownVocabAndRollsBackInCallersTransaction() throws {
        // FK bật: id lạ ném lỗi; trong transaction của caller thì cả lô rollback.
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        XCTAssertThrowsError(
            try db.inTransaction {
                try EncounterRepository.insertSeen(
                    on: db, vocabItemIDs: [a, "khong-ton-tai"], now: Fixtures.fixedNow)
            })
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM encounters;"), 0)
    }

    // MARK: recognized — một lần / vocab / ngày học

    func testRecognizedOncePerLearningDay() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        let t0 = Fixtures.fixedNow   // 09:00 VN ngày 18

        XCTAssertTrue(try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: t0))
        XCTAssertFalse(
            try EncounterRepository.recordRecognized(
                on: db, vocabItemID: a, now: t0.addingTimeInterval(3600)),
            "cùng ngày học → không ghi thêm")
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: a, kind: .recognized), 1)

        XCTAssertTrue(
            try EncounterRepository.recordRecognized(
                on: db, vocabItemID: a, now: t0.addingTimeInterval(24 * 3600)),
            "ngày học kế → ghi được")
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: a, kind: .recognized), 2)
    }

    func testRecognizedUsesDayCutoffNotMidnight() throws {
        // Seed: Asia/Ho_Chi_Minh, cutoff 4h. 03:59 VN ngày 19 (= 20:59Z ngày 18) vẫn
        // thuộc ngày học 18; 04:00 VN ngày 19 (= 21:00Z) là ngày học mới.
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        let beforeCutoff = Fixtures.iso("2026-09-18T20:59:00Z")
        let afterCutoff = Fixtures.iso("2026-09-18T21:00:00Z")

        XCTAssertTrue(try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: Fixtures.fixedNow))
        XCTAssertFalse(
            try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: beforeCutoff),
            "03:59 VN ngày 19 vẫn là ngày học 18")
        XCTAssertTrue(
            try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: afterCutoff),
            "04:00 VN ngày 19 → ngày học mới")
    }

    func testRecognizedIsPerVocab() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        let b = try vocab(db, "beta")
        XCTAssertTrue(try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: Fixtures.fixedNow))
        XCTAssertTrue(try EncounterRepository.recordRecognized(on: db, vocabItemID: b, now: Fixtures.fixedNow))
    }

    // MARK: vòng đời dữ liệu

    func testCascadeOnVocabDelete() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        try EncounterRepository.insertSeen(on: db, vocabItemIDs: [a], now: Fixtures.fixedNow)
        try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: Fixtures.fixedNow)

        try db.run("DELETE FROM vocab_items WHERE id = ?;", [.text(a)])

        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM encounters;"), 0)
    }

    func testEncountersSurviveMovingVocabToAnotherCollection() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        try EncounterRepository.insertSeen(on: db, vocabItemIDs: [a], now: Fixtures.fixedNow)
        let book = try Fixtures.insertCollection(in: db, name: "Sách B")

        try db.run("UPDATE vocab_items SET collection_id = ? WHERE id = ?;", [.text(book), .text(a)])

        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: a, kind: .seen), 1)
    }

    func testReviewTablesUntouchedByEncounters() throws {
        // Retention (vision): nhận ra khi đọc KHÔNG đổi lịch — không dòng review_logs,
        // không đổi cards.
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        let card = try Fixtures.insertCard(in: db, vocabItemID: a, state: "review", stability: 3, reps: 2)
        let before = try XCTUnwrap(ReviewService.fetchSnapshot(on: db, cardID: card))

        try EncounterRepository.insertSeen(on: db, vocabItemIDs: [a], now: Fixtures.fixedNow)
        try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: Fixtures.fixedNow)

        XCTAssertEqual(try ReviewService.fetchSnapshot(on: db, cardID: card), before)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM review_logs;"), 0)
    }

    // MARK: số liệu + lexicon

    func testDistinctWordsEncounteredCountsWordsNotRows() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        let b = try vocab(db, "beta")
        let now = Fixtures.fixedNow
        // a: hai dòng trong tuần; b: một dòng cách đây 10 ngày (ngoài cửa sổ 7 ngày).
        try EncounterRepository.insertSeen(on: db, vocabItemIDs: [a], now: now.addingTimeInterval(-2 * 86_400))
        try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: now)
        try EncounterRepository.insertSeen(on: db, vocabItemIDs: [b], now: now.addingTimeInterval(-10 * 86_400))

        let count = try EncounterRepository.distinctWordsEncountered(
            on: db, since: now.addingTimeInterval(-7 * 86_400))

        XCTAssertEqual(count, 1)
    }

    func testLoadLexiconSpansCollectionsAndSkipsSuspended() throws {
        let db = try Fixtures.seededDB()
        let book = try Fixtures.insertCollection(in: db, name: "Sách B")
        let inInbox = try vocab(db, "alpha")
        let inBook = try vocab(db, "beta", in: book)
        let noCard = try vocab(db, "gamma", in: book)
        let leech = try vocab(db, "delta", in: book)
        _ = try Fixtures.insertCard(in: db, vocabItemID: inInbox)
        _ = try Fixtures.insertCard(in: db, vocabItemID: inBook)
        _ = try Fixtures.insertCard(
            in: db, vocabItemID: leech, state: "review", suspendedIso: "2026-09-17T00:00:00Z")

        let lexicon = try EncounterRepository.loadLexicon(on: db)

        XCTAssertEqual(Set(lexicon.map(\.term)), ["alpha", "beta", "gamma"],
                       "leech (thẻ suspend) bị loại; vocab chưa có thẻ vẫn vào")
        XCTAssertEqual(lexicon.first { $0.vocabItemID == inBook }?.collectionName, "Sách B")
        XCTAssertEqual(lexicon.first { $0.vocabItemID == inInbox }?.collectionName, "Kho tạm")
        XCTAssertNotNil(lexicon.first { $0.vocabItemID == noCard })
    }

    // MARK: recognizedToday

    func testRecognizedTodayFollowsTheLearningDay() throws {
        let db = try Fixtures.seededDB()
        let a = try vocab(db, "alpha")
        let t0 = Fixtures.fixedNow
        XCTAssertFalse(try EncounterRepository.recognizedToday(on: db, vocabItemID: a, now: t0))
        try EncounterRepository.recordRecognized(on: db, vocabItemID: a, now: t0)
        XCTAssertTrue(try EncounterRepository.recognizedToday(on: db, vocabItemID: a, now: t0.addingTimeInterval(3600)))
        XCTAssertFalse(
            try EncounterRepository.recognizedToday(
                on: db, vocabItemID: a, now: t0.addingTimeInterval(24 * 3600)),
            "ngày học kế tiếp → chưa nhận ra")
    }

    // MARK: T2 — `seen` ghi cùng transaction lưu trang

    private func item(_ term: String) -> PageAnalysis.VocabularyItemIn {
        PageAnalysis.VocabularyItemIn(
            term: term, pos: "noun", ipa: nil, meaningVI: "nghĩa", cefr: nil,
            example: "ví dụ", verification: .verified)
    }

    private func segments(_ texts: String...) -> [PageAnalysis.Segment] {
        texts.map { PageAnalysis.Segment(sourceEN: $0, translationVI: "dịch") }
    }

    func testSaveCaptureWritesSeenForExistingWordsInSegmentsOnly() throws {
        let db = try Fixtures.seededDB()
        let bookA = try Fixtures.insertCollection(in: db, name: "Sách A")
        let bookB = try Fixtures.insertCollection(in: db, name: "Sách B")
        let old = try vocab(db, "serendipity", in: bookA)
        let unrelated = try vocab(db, "zebra", in: bookA)

        let saved = try VocabRepository.saveCapture(
            on: db, items: [item("novel")], collectionID: bookB,
            segments: segments("Pure Serendipity struck him."), now: Fixtures.fixedNow)

        XCTAssertEqual(saved, 1)
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: old, kind: .seen), 1,
                       "từ cũ ở collection khác, xuất hiện trong đoạn → seen")
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: unrelated, kind: .seen), 0)
        let newID = try XCTUnwrap(db.scalarString(
            "SELECT id FROM vocab_items WHERE term = 'novel';"))
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: newID, kind: .seen), 0,
                       "từ vừa lưu không phải gặp lại")
    }

    func testSaveCaptureStoresSentenceAndTargetCollectionOnSeen() throws {
        let db = try Fixtures.seededDB()
        let bookA = try Fixtures.insertCollection(in: db, name: "Sách A")
        let bookB = try Fixtures.insertCollection(in: db, name: "Sách B")
        let old = try vocab(db, "serendipity", in: bookA)

        _ = try VocabRepository.saveCapture(
            on: db, items: [item("novel")], collectionID: bookB,
            segments: segments("It was dark. Pure serendipity struck him."), now: Fixtures.fixedNow)

        let row = try XCTUnwrap(db.rows(
            "SELECT sentence, collection_id FROM encounters WHERE vocab_item_id = ? AND kind = 'seen';",
            [.text(old)]).first)
        XCTAssertEqual(row["sentence"].textValue, "Pure serendipity struck him.")
        XCTAssertEqual(row["collection_id"].textValue, bookB)
    }

    func testSaveCaptureToTempStoreRecordsTempStoreIDOnSeen() throws {
        let db = try Fixtures.seededDB()
        let book = try Fixtures.insertCollection(in: db, name: "Sách A")
        let old = try vocab(db, "serendipity", in: book)

        _ = try VocabRepository.saveCapture(
            on: db, items: [item("novel")], collectionID: nil,
            segments: segments("Pure serendipity struck him."), now: Fixtures.fixedNow)

        let inbox = try XCTUnwrap(db.scalarString(
            "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;"))
        XCTAssertEqual(
            try db.scalarString(
                "SELECT collection_id FROM encounters WHERE vocab_item_id = ?;", [.text(old)]),
            inbox)
    }

    func testDeletingCollectionNullsEncounterCollectionKeepsRow() throws {
        let db = try Fixtures.seededDB()
        let bookA = try Fixtures.insertCollection(in: db, name: "Sách A")
        let bookX = try Fixtures.insertCollection(in: db, name: "Sách X")
        let old = try vocab(db, "serendipity", in: bookA)
        try EncounterRepository.insertSeen(
            on: db, contexts: [EncounterContext(vocabItemID: old, sentence: "Câu.")],
            collectionID: bookX, now: Fixtures.fixedNow)

        _ = try VocabRepository.deleteCollection(on: db, id: bookX)

        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: old, kind: .seen), 1)
        XCTAssertEqual(
            try db.scalarInt64("SELECT COUNT(*) FROM encounters WHERE collection_id IS NULL;"), 1)
    }

    func testSaveCaptureSameTermSavedAgainOnlyMarksTheOldRowSeen() throws {
        let db = try Fixtures.seededDB()
        let book = try Fixtures.insertCollection(in: db, name: "Sách A")
        let old = try vocab(db, "bank", in: book)

        _ = try VocabRepository.saveCapture(
            on: db, items: [item("bank")], collectionID: book,
            segments: segments("The bank was closed."), now: Fixtures.fixedNow)

        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: old, kind: .seen), 1)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM encounters;"), 1,
                       "dòng mới thêm (nghĩa khác) không tự có seen")
    }

    func testSaveCaptureWithoutSegmentsWritesNoSeen() throws {
        let db = try Fixtures.seededDB()
        _ = try vocab(db, "alpha")
        _ = try VocabRepository.saveCapture(
            on: db, items: [item("beta")], collectionID: nil, segments: [],
            now: Fixtures.fixedNow)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM encounters;"), 0)
    }

    func testSaveCaptureToInboxStillWritesSeenEvenWithoutSavingASession() throws {
        let db = try Fixtures.seededDB()
        let old = try vocab(db, "alpha")

        _ = try VocabRepository.saveCapture(
            on: db, items: [item("beta")], collectionID: nil,
            segments: segments("Alpha and beta."), now: Fixtures.fixedNow)

        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM reading_sessions;"), 0,
                       "kho tạm không lưu phiên (ADR-029)")
        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: old, kind: .seen), 1)
    }

    func testSaveCaptureSkipsSeenForLeechedWords() throws {
        let db = try Fixtures.seededDB()
        let leech = try vocab(db, "stubborn")
        _ = try Fixtures.insertCard(
            in: db, vocabItemID: leech, state: "review", suspendedIso: "2026-09-17T00:00:00Z")

        _ = try VocabRepository.saveCapture(
            on: db, items: [item("other")], collectionID: nil,
            segments: segments("A stubborn page."), now: Fixtures.fixedNow)

        XCTAssertEqual(try EncounterRepository.count(on: db, vocabItemID: leech, kind: .seen), 0)
    }

    // MARK: vocab-identity-r1 T3 — contextOnly

    private func seenRows(_ db: SQLiteDatabase, _ id: String) throws -> [SQLRow] {
        try db.rows(
            "SELECT sentence, collection_id FROM encounters WHERE vocab_item_id = ? AND kind = 'seen';",
            [.text(id)])
    }

    func testContextOnlyAloneWritesNoCardAndOneSeenWithPageSentence() throws {
        let db = try Fixtures.seededDB()
        let bookA = try Fixtures.insertCollection(in: db, name: "Sách A")
        let bookB = try Fixtures.insertCollection(in: db, name: "Sách B")
        let old = try vocab(db, "serendipity", in: bookA)
        let before = try db.scalarInt64("SELECT COUNT(*) FROM vocab_items;")

        let saved = try VocabRepository.saveCapture(
            on: db, items: [], collectionID: bookB,
            segments: segments("Pure serendipity struck him."),
            contextOnly: [ContextOnlyItem(term: "serendipity", pos: "noun", example: "AI câu")],
            now: Fixtures.fixedNow)

        XCTAssertEqual(saved, 0)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM vocab_items;"), before)
        let rows = try seenRows(db, old)
        XCTAssertEqual(rows.count, 1, "matcher + contextOnly cùng vocab -> 1 dòng")
        XCTAssertEqual(rows[0]["sentence"].textValue, "Pure serendipity struck him.")
        XCTAssertEqual(rows[0]["collection_id"].textValue, bookB)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM reading_sessions;"), 1, "Q7")
    }

    func testContextOnlyFallsBackToExampleWhenSegmentsLackTheWord() throws {
        let db = try Fixtures.seededDB()
        let book = try Fixtures.insertCollection(in: db, name: "Sách A")
        let old = try vocab(db, "serendipity", in: book)
        _ = try VocabRepository.saveCapture(
            on: db, items: [], collectionID: book,
            segments: segments("Nothing relevant here."),
            contextOnly: [ContextOnlyItem(term: "Serendipity", pos: "Noun", example: "AI câu")],
            now: Fixtures.fixedNow)
        XCTAssertEqual(try seenRows(db, old).first?["sentence"].textValue, "AI câu")
    }

    func testContextOnlyWithNilExampleAndNoSegmentMatchWritesNullSentence() throws {
        let db = try Fixtures.seededDB()
        let book = try Fixtures.insertCollection(in: db, name: "Sách A")
        let old = try vocab(db, "serendipity", in: book)
        _ = try VocabRepository.saveCapture(
            on: db, items: [], collectionID: book, segments: [],
            contextOnly: [ContextOnlyItem(term: "serendipity", pos: "noun", example: nil)],
            now: Fixtures.fixedNow)
        let rows = try seenRows(db, old)
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows[0]["sentence"].textValue)
    }

    func testContextOnlySkipsLeech() throws {
        let db = try Fixtures.seededDB()
        let leech = try vocab(db, "stubborn")
        _ = try Fixtures.insertCard(
            in: db, vocabItemID: leech, state: "review", suspendedIso: "2026-09-17T00:00:00Z")
        let saved = try VocabRepository.saveCapture(
            on: db, items: [], collectionID: nil, segments: segments("A stubborn page."),
            contextOnly: [ContextOnlyItem(term: "stubborn", pos: "noun", example: "x")],
            now: Fixtures.fixedNow)
        XCTAssertEqual(saved, 0)
        XCTAssertEqual(try seenRows(db, leech).count, 0)
    }

    func testItemsAndContextOnlyTogether() throws {
        let db = try Fixtures.seededDB()
        let book = try Fixtures.insertCollection(in: db, name: "Sách A")
        let old = try vocab(db, "serendipity", in: book)
        let saved = try VocabRepository.saveCapture(
            on: db, items: [item("novel")], collectionID: book, segments: [],
            contextOnly: [ContextOnlyItem(term: "serendipity", pos: "noun", example: "AI câu")],
            now: Fixtures.fixedNow)
        XCTAssertEqual(saved, 1)
        XCTAssertEqual(try seenRows(db, old).count, 1)
    }

    func testEmptyItemsAndEmptyContextOnlyStillReturnsZeroWithoutWriting() throws {
        let db = try Fixtures.seededDB()
        let saved = try VocabRepository.saveCapture(
            on: db, items: [], collectionID: nil, segments: segments("x"), now: Fixtures.fixedNow)
        XCTAssertEqual(saved, 0)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM encounters;"), 0)
    }
}
