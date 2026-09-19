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