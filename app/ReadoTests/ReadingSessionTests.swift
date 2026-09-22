import ReadoKit
import XCTest

/// FR-05/06 — phiên đọc song ngữ + ý chính: ghi CÙNG transaction với capture,
/// chỉ cho collection có tên, tối đa 10/collection (Q-10/ADR-029). FR-14
/// `pagesAnalyzed` đếm từ bảng `reading_sessions` nên các test này cũng chốt
/// hành vi ghi phiên.
final class ReadingSessionTests: XCTestCase {

    private func vocabIn(term: String) -> PageAnalysis.VocabularyItemIn {
        PageAnalysis.VocabularyItemIn(
            term: term, pos: "noun", ipa: nil, meaningVI: "nghĩa",
            cefr: nil, example: "ex", verification: .verified)
    }

    private func segment(_ en: String, _ vi: String) -> PageAnalysis.Segment {
        PageAnalysis.Segment(sourceEN: en, translationVI: vi)
    }

    private func namedCollection(_ db: SQLiteDatabase) throws -> String {
        try Fixtures.insertCollection(in: db, name: "Sách A")
    }

    // MARK: — Ghi phiên (saveCapture)

    func testSaveCaptureToNamedCollectionWritesSessionAndDecodes() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try namedCollection(db)
        let segments = [
            segment("The wind blew", "Gió thổi"),
            segment("Across the hill", "Qua ngọn đồi"),
        ]

        let saved = try VocabRepository.saveCapture(
            on: db,
            items: [vocabIn(term: "wind")],
            collectionID: collectionID,
            segments: segments,
            summaryVI: "Hai câu về gió.",
            now: Fixtures.fixedNow)
        XCTAssertEqual(saved, 1)

        let sessions = try ReadingSessionRepository.listSessions(
            on: db, collectionID: collectionID)
        XCTAssertEqual(sessions.count, 1)
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.collectionID, collectionID)
        XCTAssertEqual(session.segments, segments, "JSON round-trip giữ nguyên cặp song ngữ")
        XCTAssertEqual(session.summary, "Hai câu về gió.")
    }

    func testSaveCaptureToInboxDoesNotWriteSession() throws {
        let db = try Fixtures.seededDB()
        let inboxID = try XCTUnwrap(
            db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))

        _ = try VocabRepository.saveCapture(
            on: db,
            items: [vocabIn(term: "default")],
            collectionID: nil,
            segments: [segment("A", "B")],
            summaryVI: "s",
            now: Fixtures.fixedNow)

        let sessions = try ReadingSessionRepository.listSessions(
            on: db, collectionID: inboxID)
        XCTAssertTrue(sessions.isEmpty, "kho tạm không lưu phiên (Q-10)")
        // FR-14: pagesAnalyzed không nhảy khi chỉ ghi kho tạm.
        let pagesAnalyzed = try db.scalarInt64(
            "SELECT COUNT(*) FROM reading_sessions;") ?? 0
        XCTAssertEqual(pagesAnalyzed, 0)
    }

    func testNamedCollectionEmptySegmentsAndSummarySkipsSession() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try namedCollection(db)

        _ = try VocabRepository.saveCapture(
            on: db,
            items: [vocabIn(term: "skip")],
            collectionID: collectionID,
            segments: [],
            summaryVI: "",
            now: Fixtures.fixedNow)

        XCTAssertTrue(
            try ReadingSessionRepository.listSessions(on: db, collectionID: collectionID)
                .isEmpty,
            "không có nội dung → không ghi phiên trống")
    }

    // MARK: — Trim 10 (Q-10/ADR-029)

    func testTrimKeepsNewestTenSessions() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try namedCollection(db)

        // 11 lần ghi, mỗi lần một "giờ" khác nhau (created_at tăng dần).
        for i in 0..<11 {
            let now = Fixtures.iso(
                String(format: "2026-09-01T%02d:00:00Z", i))
            _ = try VocabRepository.saveCapture(
                on: db,
                items: [vocabIn(term: "w\(i)")],
                collectionID: collectionID,
                segments: [segment("s\(i)", "v\(i)")],
                summaryVI: "phiên \(i)",
                now: now)
        }

        let sessions = try ReadingSessionRepository.listSessions(
            on: db, collectionID: collectionID)
        XCTAssertEqual(sessions.count, 10, "phiên thứ 11 cắt phiên cũ nhất")

        // Mới nhất trước + chỉ giữ 10 mới nhất.
        XCTAssertEqual(sessions.first?.summary, "phiên 10")
        XCTAssertFalse(sessions.contains { $0.summary == "phiên 0" }, "phiên 0 bị cắt")
    }

    // MARK: — Codec

    func testEncodeDecodeRoundTripWithUnicodeAndQuotes() throws {
        let segments = [
            segment("He said \"hello\"", "Anh ấy nói «xin chào» — có dấu đầy đủ"),
            segment("", "bản dịch rỗng nguồn"),
        ]
        let json = try ReadingSessionRepository.encodeSegments(segments)
        XCTAssertEqual(ReadingSessionRepository.decodeSegments(json), segments)
    }

    func testDecodeMalformedJSONReturnsEmpty() {
        XCTAssertTrue(ReadingSessionRepository.decodeSegments("not-json").isEmpty)
        XCTAssertTrue(ReadingSessionRepository.decodeSegments("").isEmpty)
    }

    func testListSessionsOrdersNewestFirst() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try namedCollection(db)
        for i in 0..<3 {
            _ = try VocabRepository.saveCapture(
                on: db,
                items: [vocabIn(term: "o\(i)")],
                collectionID: collectionID,
                segments: [segment("s\(i)", "v\(i)")],
                summaryVI: "p\(i)",
                now: Fixtures.iso("2026-09-01T00:0\(i):00Z"))
        }
        let sessions = try ReadingSessionRepository.listSessions(
            on: db, collectionID: collectionID)
        XCTAssertEqual(sessions.map(\.summary), ["p2", "p1", "p0"])
    }
}