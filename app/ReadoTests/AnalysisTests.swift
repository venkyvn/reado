import Foundation
import XCTest
import ReadoKit

/// FR-02: decoder schema (prompt-spec #4), verify engine (mục 6), factory (FR-21),
/// proxy client wire (SD 4.1). Chạy offline — stub URLProtocol, không mạng thật.
final class AnalysisTests: XCTestCase {

    // MARK: - Response JSON fixtures

    private func validResponseJSON() -> [String: Any] {
        [
            "segments": [
                [
                    "source_en": "The old lighthouse stood on the cliff, battered by winter storms.",
                    "translation_vi": "Ngọn hải đăng cũ đứng trên vách đá, bị bão mùa đông dày vò.",
                ]
            ],
            "vocabulary": [
                [
                    "term": "battered",
                    "pos": "adj",
                    "ipa": "/ˈbætərd/",
                    "meaning_vi": "dày vò",
                    "cefr": "B2",
                    "example": "The old lighthouse stood on the cliff, battered by winter storms.",
                ]
            ],
            "summary_vi": "Mô tả ngọn hải đăng cổ trên vách đá.",
        ]
    }

    private func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    // MARK: - Decoder (FR-02: JSON đúng schema → PageAnalysis; sai → lỗi, không lưu)

    func testDecoderValidResponseMapsAllThreeGroups() throws {
        let analysis = try AnalysisResponseDecoder.decode(jsonData(validResponseJSON()))
        XCTAssertEqual(analysis.segments.count, 1)
        XCTAssertEqual(analysis.segments[0].sourceEN, "The old lighthouse stood on the cliff, battered by winter storms.")
        XCTAssertEqual(analysis.vocabulary.count, 1)
        XCTAssertEqual(analysis.vocabulary[0].term, "battered")
        XCTAssertEqual(analysis.vocabulary[0].pos, "adj")
        XCTAssertEqual(analysis.vocabulary[0].cefr, "B2")
        XCTAssertEqual(analysis.summaryVI, "Mô tả ngọn hải đăng cổ trên vách đá.")
    }

    func testDecoderMissingRequiredFieldThrowsSchemaViolation() {
        var json = validResponseJSON()
        json.removeValue(forKey: "segments")
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderInvalidPOSThrows() {
        var json = validResponseJSON()
        var vocab = (json["vocabulary"] as! [[String: Any]])[0]
        vocab["pos"] = "gerund"  // enum chỉ có noun|verb|adj|adv|phrase|other
        json["vocabulary"] = [vocab]
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderInvalidCEFRThrows() {
        var json = validResponseJSON()
        var vocab = (json["vocabulary"] as! [[String: Any]])[0]
        vocab["cefr"] = "ZZ"
        json["vocabulary"] = [vocab]
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderEmptyExampleThrows() {
        var json = validResponseJSON()
        var vocab = (json["vocabulary"] as! [[String: Any]])[0]
        vocab["example"] = "   "
        json["vocabulary"] = [vocab]
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderWithoutVerificationUsesVerifyEngine() throws {
        // Proxy contract cộng thêm `verification`; decode raw không có field đó
        // → VerifyEngine đối chiếu example với segments (SD 7.3, không verify hai lần).
        let json = validResponseJSON()
        let bytes = try JSONSerialization.data(withJSONObject: json)
        let analysis = try AnalysisResponseDecoder.decode(bytes)
        XCTAssertEqual(analysis.vocabulary[0].verification, .verified)
    }

    // MARK: - VerifyEngine (prompt-spec mục 6)

    func testVerifyThreeBranches() throws {
        let pageText =
            "The old lighthouse stood on the cliff and weathered the winter storms bravely."
        // verified: example có thật trên trang và chứa term.
        XCTAssertEqual(
            VerifyEngine.verify(
                term: "weathered",
                example: "weathered the winter storms bravely",
                pageText: pageText),
            .verified)
        // suspect: example có thật nhưng KHÔNG chứa term.
        XCTAssertEqual(
            VerifyEngine.verify(
                term: "lighthouse",
                example: "weathered the winter storms bravely",
                pageText: pageText),
            .suspect)
        // unverified: example không xuất hiện trên trang.
        XCTAssertEqual(
            VerifyEngine.verify(
                term: "lighthouse",
                example: "a sentence invented by the AI",
                pageText: pageText),
            .unverified)
    }

    // MARK: - AnalyzerFactory (FR-21 — proxy mặc định)

    func testFactoryActiveReturnsProxyAnalyzerAndSeededCEFR() throws {
        let db = try Fixtures.seededDB()
        let (analyzer, cefrLevel) = try AnalyzerFactory.active(db: db)
        XCTAssertEqual(cefrLevel, "B2")
        XCTAssertTrue(analyzer is ReadoProxyClient)
    }

    func testFactoryUnknownKindFallsBackToMock() {
        let analyzer = AnalyzerFactory.analyzer(
            for: "nope", baseURL: nil, model: nil)
        XCTAssertTrue(analyzer is MockAnalyzer)
    }

    // MARK: - ReadoProxyClient wire (SD 4.1/4.2)

    func testProxyClientSendsMultipartWithHeadersAndDecodes() async throws {
        let stub = StubURLProtocol.self
        let captured = RequestCapture()
        stub.handler = { request in
            captured.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            let encoder = JSONEncoder()
            let raw: [String: Any] = [
                "segments": [["source_en": "Hello world.", "translation_vi": "Chào thế giới."]],
                "vocabulary": [
                    [
                        "term": "world",
                        "pos": "noun",
                        "ipa": "/wɜːld/",
                        "meaning_vi": "thế giới",
                        "cefr": "A2",
                        "example": "Hello world.",
                    ]
                ],
                "summary_vi": "Một lời chào.",
            ]
            let data = try! JSONSerialization.data(withJSONObject: raw)
            return (response, data)
        }

        let session = StubURLProtocol.makeSession()
        let client = ReadoProxyClient(session: session, baseURL: "https://proxy.reado.app/")
        let result = try await client.analyze(
            image: Data([0x01, 0x02]),
            imageMime: "image/jpeg",
            cefr: "B2",
            imageHash: "abc123")

        // Request shape
        let request = try XCTUnwrap(captured.request)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://proxy.reado.app/v1/analyze")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Reado-Image-Hash"), "abc123")
        let body = try XCTUnwrap(bodyData(of: request))
        let bodyString = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(bodyString.contains("name=\"cefr_level\""))
        XCTAssertTrue(bodyString.contains("B2"))
        // Result decode ok
        XCTAssertEqual(result.vocabulary[0].term, "world")
        XCTAssertEqual(result.segments[0].sourceEN, "Hello world.")
    }

    func testProxyClientMapsErrorEnvelope() async throws {
        let stub = StubURLProtocol.self
        stub.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            let data = Data("""
                {"error": {"code": "RATE_LIMITED", "message": "chậm lại"}}
                """.utf8)
            return (response, data)
        }
        let client = ReadoProxyClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://proxy.reado.app")
        do {
            _ = try await client.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi")
        } catch {
            guard case AnalysisError.rateLimited = error else {
                return XCTFail("mong đợi rateLimited, nhận \(error)")
            }
        }
    }

    // MARK: - Map error envelope FR-04 (SD 4.1 — ảnh mờ / không phải tiếng Anh)

    func testProxyClientMapsImageUnreadable() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 422,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            let data = Data("""
                {"error": {"code": "IMAGE_UNREADABLE", "message": "too blurry"}}
                """.utf8)
            return (response, data)
        }
        let client = ReadoProxyClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://proxy.reado.app")
        do {
            _ = try await client.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi IMAGE_UNREADABLE")
        } catch {
            guard case AnalysisError.imageUnreadable = error else {
                return XCTFail("mong đợi imageUnreadable, nhận \(error)")
            }
        }
    }

    func testProxyClientMapsNonEnglishText() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 422,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            let data = Data("""
                {"error": {"code": "NON_ENGLISH_TEXT", "message": "not english"}}
                """.utf8)
            return (response, data)
        }
        let client = ReadoProxyClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://proxy.reado.app")
        do {
            _ = try await client.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi NON_ENGLISH_TEXT")
        } catch {
            guard case AnalysisError.notEnglishText = error else {
                return XCTFail("mong đợi notEnglishText, nhận \(error)")
            }
        }
    }

    // MARK: - ReviewDraftBuilder (FR-03/FR-09, ROADMAP 2.3)

    private func vocabIn(
        term: String,
        pos: String = "noun",
        ipa: String? = nil,
        meaning: String = "nghĩa",
        cefr: String? = nil,
        example: String = "câu ví dụ",
        verification: PageAnalysis.VerificationStatus
    ) -> PageAnalysis.VocabularyItemIn {
        PageAnalysis.VocabularyItemIn(
            term: term,
            pos: pos,
            ipa: ipa,
            meaningVI: meaning,
            cefr: cefr,
            example: example,
            verification: verification)
    }

    func testDraftBuilderPutsUnverifiedAndSuspectFirstAndDeselected() {
        // SD 10.3: unverified/suspect lên đầu và bỏ chọn sẵn; verified giữ thứ
        // tự gốc và chọn sẵn (FR-09 "mặc định tất cả" trừ nhóm chưa xác minh).
        let items = [
            vocabIn(term: "alpha", verification: .verified),
            vocabIn(term: "bravo", verification: .unverified),
            vocabIn(term: "charlie", verification: .suspect),
            vocabIn(term: "delta", verification: .verified),
        ]
        let drafts = ReviewDraftBuilder.drafts(from: items)
        XCTAssertEqual(drafts.map(\.term), ["bravo", "charlie", "alpha", "delta"])
        XCTAssertEqual(drafts.map(\.isSelected), [false, false, true, true])
    }

    /// port UI lab §5.5: preselect = verified VÀ cefr ∈ selectedLevels — verified
    /// nhưng ngoài level chọn thì vẫn bỏ chọn sẵn; cefr rỗng cũng bỏ.
    func testDraftBuilderPreselectsOnlyVerifiedInSelectedLevels() {
        let items = [
            vocabIn(term: "a-b2", cefr: "B2", verification: .verified),
            vocabIn(term: "b-b2", cefr: "B2", verification: .unverified),
            vocabIn(term: "c-c1", cefr: "C1", verification: .verified),
            vocabIn(term: "d-none", cefr: nil, verification: .verified),
        ]
        let drafts = ReviewDraftBuilder.drafts(
            from: items, selectedLevels: ["B2"])
        // c-c1 (verified, ngoài B2) và d-none (verified, cefr rỗng) bỏ chọn sẵn.
        let selected = Dictionary(
            drafts.map { ($0.term, $0.isSelected) },
            uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(selected["a-b2"], true)
        XCTAssertEqual(selected["b-b2"], false)
        XCTAssertEqual(selected["c-c1"], false)
        XCTAssertEqual(selected["d-none"], false)
    }

    /// `selectedLevels = nil` giữ hành vi cũ: chọn mọi verified (tương thích).
    func testDraftBuilderNilLevelsSelectsAllVerified() {
        let drafts = ReviewDraftBuilder.drafts(from: [
            vocabIn(term: "a", cefr: "B2", verification: .verified),
            vocabIn(term: "b", cefr: "C1", verification: .verified),
        ])
        XCTAssertEqual(drafts.map(\.isSelected), [true, true])
    }

    func testSelectedReturnsOnlySelectedItemsInDisplayOrder() throws {
        let drafts = [
            ReviewDraft(
                term: "alpha", pos: "noun", ipa: "", meaningVI: "a",
                cefr: "", example: "ex-a", verification: .verified,
                isSelected: false),
            ReviewDraft(
                term: "beta", pos: "verb", ipa: "", meaningVI: "b",
                cefr: "", example: "ex-b", verification: .verified,
                isSelected: true),
            ReviewDraft(
                term: "gamma", pos: "adj", ipa: "", meaningVI: "g",
                cefr: "", example: "ex-g", verification: .unverified,
                isSelected: true),  // user chủ động chọn lại item chưa xác minh
        ]
        let items = try ReviewDraftBuilder.selected(drafts)
        XCTAssertEqual(items.map(\.term), ["beta", "gamma"])
    }

    func testSelectedNormalizesFields() throws {
        // FR-03: trim mọi field; pos rỗng → other (FR-02); cefr upper + rỗng → nil;
        // ipa rỗng → nil.
        let draft = ReviewDraft(
            term: "  Trimmed  ", pos: " ", ipa: "  ", meaningVI: "  nghĩa ",
            cefr: "  b2 ", example: "  ví dụ ", verification: .verified,
            isSelected: true)
        let items = try ReviewDraftBuilder.selected([draft])
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.term, "Trimmed")
        XCTAssertEqual(item.pos, "other")
        XCTAssertEqual(item.ipa, nil)
        XCTAssertEqual(item.meaningVI, "nghĩa")
        XCTAssertEqual(item.cefr, "B2")
        XCTAssertEqual(item.example, "ví dụ")
    }

    func testSelectedThrowsForEmptyRequiredFieldsWithDisplayIndex() {
        // Trường bắt buộc rỗng sau khi user sửa → chặn lưu bản ghi hỏng (FR-02/03).
        // Index 1-based theo thứ tự hiển thị — item đầu không chọn không đếm.
        let unselected = ReviewDraft(
            term: "ok", pos: "noun", ipa: "", meaningVI: "m",
            cefr: "", example: "e", verification: .verified, isSelected: false)
        let cases: [(ReviewDraft, ReviewDraftError.Field)] = [
            (
                ReviewDraft(
                    term: "  ", pos: "noun", ipa: "", meaningVI: "m",
                    cefr: "", example: "e", verification: .verified,
                    isSelected: true),
                .term
            ),
            (
                ReviewDraft(
                    term: "t", pos: "noun", ipa: "", meaningVI: " ",
                    cefr: "", example: "e", verification: .verified,
                    isSelected: true),
                .meaning
            ),
            (
                ReviewDraft(
                    term: "t", pos: "noun", ipa: "", meaningVI: "m",
                    cefr: "", example: "\n", verification: .verified,
                    isSelected: true),
                .example
            ),
        ]
        for (bad, field) in cases {
            XCTAssertThrowsError(
                try ReviewDraftBuilder.selected([unselected, bad])
            ) { error in
                guard let draftError = error as? ReviewDraftError else {
                    return XCTFail("mong đợi ReviewDraftError, nhận \(error)")
                }
                XCTAssertEqual(draftError.index, 2)
                XCTAssertEqual(draftError.field, field)
            }
        }
    }

    func testSaveCapturePersistsOnlySelectedItemsAsNewCardsDueToday() throws {
        // FR-09: item được chọn khi lưu → SRS queue state=new, due_at hôm nay;
        // 2.4: không chọn collection → kho tạm (is_default). FR-03: bỏ chọn = không lưu.
        let db = try Fixtures.seededDB()
        let drafts = ReviewDraftBuilder.drafts(from: [
            vocabIn(term: " keep ", verification: .verified),
            vocabIn(term: "drop", verification: .unverified),  // không preselect
        ])
        let items = try ReviewDraftBuilder.selected(drafts)
        XCTAssertEqual(items.map(\.term), ["keep"])

        let saved = try VocabRepository.saveCapture(
            on: db, items: items, collectionID: nil, now: Fixtures.fixedNow)
        XCTAssertEqual(saved, 1)

        let rows = try db.rows(
            """
            SELECT v.term, v.collection_id, c.state, c.due_at
            FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id;
            """)
        XCTAssertEqual(rows.count, 1, "bỏ chọn trong màn duyệt thì không được lưu")
        let inboxID = try db.scalarString(
            "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;")
        XCTAssertEqual(rows[0][1].textValue, inboxID, "đích ngầm = kho tạm")
        XCTAssertEqual(rows[0][2].textValue, "new")
        XCTAssertEqual(rows[0][3].textValue, "2026-09-18T02:00:00Z")
    }
}

// MARK: - URLProtocol stub (offline test wire)

/// URLSession với custom URLProtocol chuyển httpBody sang httpBodyStream
/// cho data task — đọc body phải đi qua stream (bẫy test đã gặp 2026-09-19).
private func bodyData(of request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        guard read > 0 else { break }
        data.append(buffer, count: read)
    }
    return data
}

final class RequestCapture: @unchecked Sendable {
    var request: URLRequest?
}

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}