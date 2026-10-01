import Foundation
import XCTest
import ReadoKit

/// `ReadoProxyClient` wire (SD 4.1/4.2) + map error envelope FR-04 (ảnh mờ /
/// không phải tiếng Anh).
final class ReadoProxyClientTests: AnalysisNetworkTestCase {

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
}
