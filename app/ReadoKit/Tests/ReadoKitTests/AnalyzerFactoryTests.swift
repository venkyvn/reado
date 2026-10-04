import Foundation
import XCTest
import ReadoKit

/// FR-21 — agent OpenAI-compat BYOK (list/add/edit/delete/setActive). ADR-049:
/// bỏ proxy mặc định — cài mới chưa thêm agent thì analyzer báo lỗi rõ.
final class AnalyzerFactoryTests: AnalysisNetworkTestCase {

    // MARK: - AnalyzerFactory (ADR-049 — chưa chọn agent)

    func testFactoryActiveWithoutAgentReturnsNoAgentAnalyzerAndSeededCEFR() async throws {
        let db = try Fixtures.seededDB()
        let (analyzer, cefrLevel) = try AnalyzerFactory.active(db: db)
        XCTAssertEqual(cefrLevel, "B2")
        XCTAssertTrue(analyzer is NoAgentAnalyzer)
        await assertThrowsNetworkError(analyzer)
    }

    /// pdf-reader-r1 T2 — placeholder báo lỗi rõ cho CẢ hai lối (ảnh + PDF).
    func testNoAgentAnalyzerAnalyzeTextThrowsNetworkError() async {
        do {
            _ = try await NoAgentAnalyzer().analyzeText("text", cefr: "B2", sourceHash: "h")
            XCTFail("mong đợi lỗi chưa có agent")
        } catch {
            guard case AnalysisError.networkError = error else {
                return XCTFail("mong đợi networkError, nhận \(error)")
            }
        }
    }

    /// `MockAnalyzer.analyzeText` trả cùng dữ liệu mẫu như `analyze`, nhưng
    /// `promptVersion` phải là `Prompt.pdfVersion` — meta không được lẫn lối ảnh.
    func testMockAnalyzerAnalyzeTextMatchesAnalyzeShapeWithPdfVersion() async throws {
        let mock = MockAnalyzer()
        let viaImage = try await mock.analyze(
            image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h1")
        let viaText = try await mock.analyzeText("page text", cefr: "B2", sourceHash: "h2")
        XCTAssertEqual(viaText.segments, viaImage.segments)
        XCTAssertEqual(viaText.vocabulary, viaImage.vocabulary)
        XCTAssertEqual(viaText.meta.imageHash, "h2")
        XCTAssertEqual(viaText.meta.promptVersion, Prompt.pdfVersion)
    }

    /// `analyze()` của placeholder phải ném lỗi rõ, không im lặng/không gọi mạng.
    private func assertThrowsNetworkError(_ analyzer: PageAnalyzer) async {
        do {
            _ = try await analyzer.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi chưa có agent")
        } catch {
            guard case AnalysisError.networkError = error else {
                return XCTFail("mong đợi networkError, nhận \(error)")
            }
        }
    }

    func testFactoryUnknownKindFallsBackToMock() {
        let analyzer = AnalyzerFactory.analyzer(
            for: "nope", baseURL: nil, model: nil)
        XCTAssertTrue(analyzer is MockAnalyzer)
    }

    func testFactoryOpenAICompatNeedsURLModelAndID() {
        XCTAssertTrue(
            AnalyzerFactory.analyzer(for: "openai_compat", baseURL: nil, model: nil) is MockAnalyzer)
        XCTAssertTrue(
            AnalyzerFactory.analyzer(
                for: "openai_compat",
                baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
                model: "gemini-2.5-flash",
                agentID: "agent-1") is OpenAICompatClient)
    }

    func testAgentURLRule() {
        XCTAssertTrue(AgentURLRule.allows("https://generativelanguage.googleapis.com/v1beta/openai"))
        XCTAssertTrue(AgentURLRule.allows("http://192.168.1.8:8080"))
        XCTAssertTrue(AgentURLRule.allows("http://127.0.0.1:8080"))
        XCTAssertFalse(AgentURLRule.allows("http://example.com"))
        XCTAssertFalse(AgentURLRule.allows("ftp://example.com"))
        XCTAssertEqual(
            AgentURLRule.storedBase("https://generativelanguage.googleapis.com/v1beta/openai/chat/completions/"),
            "https://generativelanguage.googleapis.com/v1beta/openai")
        // Đo thật 2026-09-26: thiếu /v1 → AI-Box trả 301 thay vì lỗi rõ ràng.
        // Tự thêm cho đúng host này; host khác không đoán.
        XCTAssertEqual(AgentURLRule.storedBase("https://api.ai-box.vn"), "https://api.ai-box.vn/v1")
        XCTAssertEqual(AgentURLRule.storedBase("https://api.ai-box.vn/"), "https://api.ai-box.vn/v1")
        XCTAssertEqual(AgentURLRule.storedBase("https://api.ai-box.vn/v1"), "https://api.ai-box.vn/v1")
        XCTAssertEqual(AgentURLRule.storedBase("https://example.com"), "https://example.com")
    }

    func testAgentStoreAddEditDeleteFallsBackToPlaceholder() throws {
        let db = try Fixtures.seededDB()
        let secrets = MemorySecrets()
        // Cài mới chưa thêm agent nào — placeholder bị lọc khỏi `agents`.
        XCTAssertTrue(try AnalysisAgentStore.list(on: db, secrets: secrets).agents.isEmpty)
        let id = try AnalysisAgentStore.add(
            on: db,
            name: "Gemini",
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            model: "gemini-2.5-flash",
            apiKey: "secret-key",
            secrets: secrets)
        let listed = try AnalysisAgentStore.list(on: db, secrets: secrets)
        XCTAssertEqual(listed.activeID, id)
        XCTAssertEqual(listed.agents.count, 1)
        let added = try XCTUnwrap(listed.agents.first { $0.id == id })
        XCTAssertEqual(added.baseURL, "https://generativelanguage.googleapis.com/v1beta/openai")
        XCTAssertTrue(added.hasKey)
        let stored = try db.rows(
            "SELECT name, base_url, model FROM analysis_agents WHERE id = ?;",
            [.text(id)])
        let blob = stored.flatMap { $0.compactMap(\.textValue) }.joined(separator: " ")
        XCTAssertFalse(blob.contains("secret-key"))
        let (analyzer, _) = try AnalyzerFactory.active(db: db)
        XCTAssertTrue(analyzer is OpenAICompatClient)

        try AnalysisAgentStore.update(
            on: db,
            id: id,
            name: " Qwen ",
            baseURL: "https://example.com/v1/chat/completions",
            model: " qwen-vl ",
            secrets: secrets)
        var edited = try XCTUnwrap(
            AnalysisAgentStore.list(on: db, secrets: secrets).agents.first { $0.id == id })
        XCTAssertEqual(edited.name, "Qwen")
        XCTAssertEqual(edited.baseURL, "https://example.com/v1")
        XCTAssertEqual(edited.model, "qwen-vl")
        XCTAssertEqual(secrets.key(agentID: id), "secret-key")

        try AnalysisAgentStore.update(
            on: db,
            id: id,
            name: "Qwen",
            baseURL: "https://example.com/v1",
            model: "qwen-vl",
            apiKey: "new-key",
            secrets: secrets)
        edited = try XCTUnwrap(
            AnalysisAgentStore.list(on: db, secrets: secrets).agents.first { $0.id == id })
        XCTAssertTrue(edited.hasKey)
        XCTAssertEqual(secrets.key(agentID: id), "new-key")

        try AnalysisAgentStore.delete(on: db, id: id, secrets: secrets)
        let after = try AnalysisAgentStore.list(on: db, secrets: secrets)
        XCTAssertEqual(after.activeID, Seeder.placeholderAgentID)
        XCTAssertTrue(after.agents.isEmpty)
        XCTAssertFalse(secrets.contains(agentID: id))
        XCTAssertThrowsError(
            try AnalysisAgentStore.delete(on: db, id: Seeder.placeholderAgentID, secrets: secrets))
    }

    /// `setActive(knownHasKey:)` bỏ qua Keychain khi caller đã biết sẵn (từ
    /// `list()`) — SettingsView.select() dùng đường này để không khựng UI.
    func testSetActiveKnownHasKeySkipsSecretsLookup() throws {
        let db = try Fixtures.seededDB()
        let secrets = MemorySecrets()
        let id = try AnalysisAgentStore.add(
            on: db,
            name: "Qwen",
            baseURL: "https://example.com/v1",
            model: "qwen-vl",
            apiKey: "secret-key",
            makeActive: false,
            secrets: secrets)

        // knownHasKey: true — không cần secrets có key thật (giả lập UI đã tin
        // agent.hasKey từ list() trước đó), vẫn set active thành công.
        let noKeySecrets = MemorySecrets()
        try AnalysisAgentStore.setActive(on: db, id: id, knownHasKey: true, secrets: noKeySecrets)
        XCTAssertEqual(try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"), id)

        // knownHasKey: false — báo thiếu key dù secrets thật có key, vì caller
        // chủ động khai không có (đường lạc quan khi UI đã biết sai).
        XCTAssertThrowsError(
            try AnalysisAgentStore.setActive(on: db, id: id, knownHasKey: false, secrets: secrets))

        // Không truyền knownHasKey — hành vi cũ, tự hỏi Keychain.
        try AnalysisAgentStore.setActive(on: db, id: id, secrets: secrets)
        XCTAssertEqual(try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"), id)
    }

    func testOpenAICompatClientPostsChatCompletion() async throws {
        let captured = RequestCapture()
        StubURLProtocol.handler = { request in
            captured.request = request
            let page = """
            {"segments":[{"source_en":"Hello world.","translation_vi":"Chào thế giới."}],"vocabulary":[{"term":"world","pos":"noun","meaning_vi":"thế giới","example":"Hello world."}],"summary_vi":"Một lời chào."}
            """
            let envelope: [String: Any] = [
                "choices": [["message": ["content": page]]]
            ]
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try JSONSerialization.data(withJSONObject: envelope))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/",
            model: "gemini-2.5-flash",
            agentID: "agent-1",
            apiKey: "test-key",
            ocr: FixedPageOCR(text: "Hello world."))
        let result = try await client.analyze(
            image: Data([0x01]),
            imageMime: "image/jpeg",
            cefr: "B2",
            imageHash: "abc")
        let request = try XCTUnwrap(captured.request)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        let body = try XCTUnwrap(bodyData(of: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gemini-2.5-flash")
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        // Tìm theo role "user" — không giả định vị trí, vì client giờ chèn thêm
        // một message "system" ngắn nhắc chỉ trả JSON (mục 2.1(b) plan AI-Box).
        let userMessage = try XCTUnwrap(messages.first { ($0["role"] as? String) == "user" })
        let content = try XCTUnwrap(userMessage["content"] as? [[String: Any]])
        XCTAssertNil(content.first { ($0["type"] as? String) == "image_url" })
        XCTAssertEqual(content.map { $0["type"] as? String }, ["text"])
        let prompt = try XCTUnwrap(content[0]["text"] as? String)
        XCTAssertTrue(prompt.contains("PAGE_OCR:"))
        XCTAssertTrue(prompt.contains("Hello world."))
        let bodyText = String(decoding: body, as: UTF8.self)
        XCTAssertFalse(bodyText.contains("test-key"))
        XCTAssertFalse(bodyText.contains("image_url"))
        XCTAssertEqual(result.vocabulary[0].term, "world")
        XCTAssertEqual(result.meta.model, "gemini-2.5-flash")
        XCTAssertEqual(result.meta.imageHash, "abc")
        XCTAssertEqual(result.meta.promptVersion, Prompt.version)
    }

    func testOpenAICompatClientEmptyOCRDoesNotPost() async {
        let posted = RequestCapture()
        StubURLProtocol.handler = { request in
            posted.request = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "   "))
        do {
            _ = try await client.analyze(
                image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi imageUnreadable")
        } catch {
            guard case AnalysisError.imageUnreadable = error else {
                return XCTFail("mong đợi imageUnreadable, nhận \(error)")
            }
        }
        XCTAssertNil(posted.request)
    }

    func testOpenAICompatClientKeepsWordsWhenPosIsOff() async throws {
        StubURLProtocol.handler = { request in
            let page = """
            {"segments":[{"source_en":"Hello world.","translation_vi":"Chào."}],"vocabulary":[{"term":"world","pos":"adjective","meaning_vi":"thế giới","example":"Hello world."},{"term":"hello","pos":"noun","meaning_vi":"chào","example":"Hello world."}]}
            """
            let envelope: [String: Any] = [
                "choices": [["message": ["content": page]]]
            ]
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try JSONSerialization.data(withJSONObject: envelope))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello world."))
        let result = try await client.analyze(
            image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
        XCTAssertEqual(result.vocabulary.map(\.term), ["world", "hello"])
        XCTAssertEqual(result.vocabulary[0].pos, "other")
    }

    func testOpenAICompatClientExtractsJSONAfterThinkingAndMarkdown() async throws {
        StubURLProtocol.handler = { request in
            let content = """
            <think>I should inspect the page and return {structured output}.</think>
            Here is the result:
            ```json
            {"segments":[{"source_en":"A {braced} phrase.","translation_vi":"Một cụm có ngoặc."}],"vocabulary":[],"summary_vi":"Tóm tắt."}
            ```
            """
            let envelope: [String: Any] = [
                "choices": [["message": ["content": content]]]
            ]
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try JSONSerialization.data(withJSONObject: envelope))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "qwen-vl",
            agentID: "qwen",
            apiKey: "k",
            ocr: FixedPageOCR(text: "A {braced} phrase."))

        let result = try await client.analyze(
            image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")

        XCTAssertEqual(result.segments.first?.sourceEN, "A {braced} phrase.")
        XCTAssertEqual(result.summaryVI, "Tóm tắt.")
    }

    func testOpenAICompatClientAcceptsObjectContent() async throws {
        StubURLProtocol.handler = { request in
            let content: [String: Any] = [
                "segments": [
                    ["source_en": "Hello.", "translation_vi": "Xin chào."]
                ],
                "vocabulary": [],
                "summary_vi": "Lời chào.",
            ]
            let envelope: [String: Any] = [
                "choices": [["message": ["content": content]]]
            ]
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try JSONSerialization.data(withJSONObject: envelope))
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com/v1",
            model: "provider-object-content",
            agentID: "agent",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello."))

        let result = try await client.analyze(
            image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")

        XCTAssertEqual(result.segments.first?.translationVI, "Xin chào.")
    }

    func testOpenAICompatClientMaps401() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let data = Data(#"{"error":{"message":"bad key"}}"#.utf8)
            return (response, data)
        }
        let client = OpenAICompatClient(
            session: StubURLProtocol.makeSession(),
            baseURL: "https://example.com",
            model: "m",
            agentID: "a",
            apiKey: "k",
            ocr: FixedPageOCR(text: "Hello world."))
        do {
            _ = try await client.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi")
        } catch {
            guard case let AnalysisError.providerError(message) = error else {
                return XCTFail("mong đợi providerError, nhận \(error)")
            }
            XCTAssertTrue(message.contains("bad key"))
        }
    }
}
