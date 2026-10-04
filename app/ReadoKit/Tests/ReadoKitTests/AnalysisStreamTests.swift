import Foundation
import XCTest
import ReadoKit

/// Stream + AI-Box (plan "capture UX + OCR→AI-Box", đo thật 2026-09-26).
final class AnalysisStreamTests: AnalysisNetworkTestCase {

    /// SSE thật: reasoning_content rồi content chia 3 mảnh rồi [DONE] → ráp lại
    /// đúng JSON, tiến độ báo cả .thinking lẫn .writing.
    func testOpenAICompatClientDecodesSSEStreamAndReportsProgress() async throws {
        let fullJSON = """
            {"segments":[{"source_en":"Hello world.","translation_vi":"Chào thế giới."}],"vocabulary":[{"term":"world","pos":"noun","meaning_vi":"thế giới","example":"Hello world."}],"summary_vi":"Một lời chào."}
            """
        let third = fullJSON.count / 3
        let i1 = fullJSON.index(fullJSON.startIndex, offsetBy: third)
        let i2 = fullJSON.index(fullJSON.startIndex, offsetBy: third * 2)
        let chunks = [
            String(fullJSON[fullJSON.startIndex..<i1]),
            String(fullJSON[i1..<i2]),
            String(fullJSON[i2...]),
        ]
        StubURLProtocol.handler = { request in
            var lines = [try sseLine(reasoning: "đang phân tích trang")]
            lines += try chunks.map { try sseLine(content: $0) }
            lines.append("data: [DONE]")
            let body = lines.joined(separator: "\n\n") + "\n\n"
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"])!
            return (response, Data(body.utf8))
        }
        let progress = ProgressCapture()
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello world."),
            onProgress: { progress.append($0) })
        let result = try await client.analyze(
            image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
        XCTAssertEqual(result.vocabulary.first?.term, "world")
        XCTAssertEqual(result.segments.first?.sourceEN, "Hello world.")
        let events = progress.all
        XCTAssertTrue(events.contains(.thinking(chars: "đang phân tích trang".count)))
        XCTAssertTrue(events.contains { if case .writing = $0 { true } else { false } })
    }

    /// Request thật gửi `stream: true` + `response_format`, giữ nguyên
    /// `content: [{type:text}]` (khớp curl AI-Box của owner).
    func testOpenAICompatClientRequestHasStreamAndResponseFormat() async throws {
        let captured = RequestCapture()
        StubURLProtocol.handler = { request in
            captured.request = request
            let body = try sseLine(content: #"{"segments":[{"source_en":"Hello.","translation_vi":"Xin chào."}],"vocabulary":[],"summary_vi":""}"#)
                + "\n\ndata: [DONE]\n\n"
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"])!
            return (response, Data(body.utf8))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello world."))
        _ = try await client.analyze(
            image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
        let body = try XCTUnwrap(bodyData(of: XCTUnwrap(captured.request)))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertNotNil(json["response_format"])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertTrue(messages.contains { ($0["role"] as? String) == "system" })
    }

    /// `enable_thinking: false` chỉ cho host `ai-box.vn` (đo thật: đưa
    /// deepseek-v4.1-flash từ 63s xuống 15–18s) — provider khác không đụng.
    func testOpenAICompatClientEnableThinkingOnlyForAIBox() async throws {
        func requestBody(baseURL: String) async throws -> [String: Any] {
            let captured = RequestCapture()
            StubURLProtocol.handler = { request in
                captured.request = request
                let body = try sseLine(content: #"{"segments":[{"source_en":"Hello.","translation_vi":"Xin chào."}],"vocabulary":[],"summary_vi":""}"#)
                    + "\n\ndata: [DONE]\n\n"
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "text/event-stream"])!
                return (response, Data(body.utf8))
            }
            let client = OpenAICompatClient(
                session: StubURLProtocol.makeSession(),
                baseURL: baseURL,
                model: "m",
                agentID: "a",
                apiKey: "k",
                ocr: FixedPageOCR(text: "Hello world."))
            _ = try await client.analyze(
                image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            let body = try XCTUnwrap(bodyData(of: XCTUnwrap(captured.request)))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        }
        let aibox = try await requestBody(baseURL: AnalysisAgentStore.aiboxBaseURL)
        XCTAssertEqual(aibox["enable_thinking"] as? Bool, false)
        let gemini = try await requestBody(baseURL: AnalysisAgentStore.geminiBaseURL)
        XCTAssertNil(gemini["enable_thinking"])
    }

    /// HTTP 400 nhắc `response_format` → thử lại đúng 1 lần không kèm field;
    /// lần 2 thành công.
    func testOpenAICompatClientRetriesWithoutResponseFormatOn400() async throws {
        let attempts = AttemptCounter()
        StubURLProtocol.handler = { request in
            let attempt = attempts.increment()
            if attempt == 1 {
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
                let data = Data(
                    #"{"error":{"message":"Unrecognized request argument supplied: response_format"}}"#
                        .utf8)
                return (response, data)
            }
            let body = try sseLine(content: #"{"segments":[{"source_en":"Hello.","translation_vi":"Xin chào."}],"vocabulary":[],"summary_vi":""}"#)
                + "\n\ndata: [DONE]\n\n"
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"])!
            return (response, Data(body.utf8))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello world."))
        _ = try await client.analyze(
            image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
        XCTAssertEqual(attempts.value, 2)
    }

    /// Timeout → thông điệp gợi ý thử lại/đổi model, không phải lỗi mạng chung chung.
    func testOpenAICompatClientMapsTimeout() async throws {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello world."))
        do {
            _ = try await client.analyze(
                image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi timeout")
        } catch {
            guard case let AnalysisError.networkError(message) = error else {
                return XCTFail("mong đợi networkError, nhận \(error)")
            }
            XCTAssertTrue(message.contains("quá lâu"))
        }
    }

    // MARK: — analyzeText (pdf-reader-r1 T2, FR-23/ADR-058)

    /// Lối PDF không OCR (`FailingPageOCR` ném lỗi nếu bị gọi), body chứa
    /// `PAGE_TEXT` (không phải `PAGE_OCR`), `meta.imageHash` = `sourceHash`.
    func testAnalyzeTextSkipsOCRAndUsesPdfPrompt() async throws {
        let captured = RequestCapture()
        StubURLProtocol.handler = { request in
            captured.request = request
            let body = try sseLine(content: #"{"segments":[{"source_en":"Hello.","translation_vi":"Xin chào."}],"vocabulary":[],"summary_vi":""}"#)
                + "\n\ndata: [DONE]\n\n"
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"])!
            return (response, Data(body.utf8))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FailingPageOCR())
        let result = try await client.analyzeText(
            "Some real PDF page text.", cefr: "B2", sourceHash: "pdf-hash")
        XCTAssertEqual(result.segments.first?.sourceEN, "Hello.")
        XCTAssertEqual(result.meta.imageHash, "pdf-hash")
        XCTAssertEqual(result.meta.promptVersion, Prompt.pdfVersion)

        let body = try XCTUnwrap(bodyData(of: XCTUnwrap(captured.request)))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let userContent = try XCTUnwrap(
            messages.first { ($0["role"] as? String) == "user" }?["content"] as? [[String: Any]])
        let text = try XCTUnwrap(userContent.first?["text"] as? String)
        XCTAssertTrue(text.contains("PAGE_TEXT"))
        XCTAssertTrue(text.contains("Some real PDF page text."))
        XCTAssertFalse(text.contains("PAGE_OCR"))
    }

    /// Server trả 400 nhắc `response_format` → vẫn retry đúng một lần như lối
    /// ảnh, chung hàm `run`.
    func testAnalyzeTextRetriesWithoutResponseFormatOn400() async throws {
        let attempts = AttemptCounter()
        StubURLProtocol.handler = { request in
            let attempt = attempts.increment()
            if attempt == 1 {
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
                let data = Data(
                    #"{"error":{"message":"Unrecognized request argument supplied: response_format"}}"#
                        .utf8)
                return (response, data)
            }
            let body = try sseLine(content: #"{"segments":[{"source_en":"Hello.","translation_vi":"Xin chào."}],"vocabulary":[],"summary_vi":""}"#)
                + "\n\ndata: [DONE]\n\n"
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"])!
            return (response, Data(body.utf8))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FailingPageOCR())
        _ = try await client.analyzeText("Some text.", cefr: "B2", sourceHash: "h")
        XCTAssertEqual(attempts.value, 2)
    }

    /// 404 (model/endpoint sai) → providerError gợi ý kiểm tra Cài đặt.
    func testOpenAICompatClientMaps404() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello world."))
        do {
            _ = try await client.analyze(
                image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi")
        } catch {
            guard case let AnalysisError.providerError(message) = error else {
                return XCTFail("mong đợi providerError, nhận \(error)")
            }
            XCTAssertTrue(message.contains("Cài đặt"))
        }
    }
}
