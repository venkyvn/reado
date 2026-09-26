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

    func testNormalizerKeepsPageWhenOneWordIsOff() throws {
        let raw: [String: Any] = [
            "segments": [
                ["source_en": "Hello world.", "translation_vi": "Chào thế giới."],
                ["source_en": "  ", "translation_vi": "bỏ"],
            ],
            "vocabulary": [
                [
                    "term": "world",
                    "pos": "adjective",
                    "meaning_vi": "thế giới",
                    "cefr": "B2+",
                    "example": "Hello world.",
                ],
                [
                    "term": "broken",
                    "pos": "noun",
                    "meaning_vi": " ",
                    "example": "Hello world.",
                ],
            ],
            "summary_vi": "Một lời chào.",
        ]
        let normalized = try AnalysisResponseNormalizer.normalize(jsonData(raw))
        let analysis = try AnalysisResponseDecoder.decode(normalized)
        XCTAssertEqual(analysis.segments.count, 1)
        XCTAssertEqual(analysis.vocabulary.count, 1)
        XCTAssertEqual(analysis.vocabulary[0].term, "world")
        XCTAssertEqual(analysis.vocabulary[0].pos, "other")
        XCTAssertNil(analysis.vocabulary[0].cefr)
    }

    func testNormalizerEmptyPageIsNotEnglish() {
        let raw: [String: Any] = [
            "segments": [],
            "vocabulary": [["term": "x", "pos": "noun", "meaning_vi": "", "example": ""]],
        ]
        XCTAssertThrowsError(try AnalysisResponseNormalizer.normalize(jsonData(raw))) { error in
            guard case AnalysisError.notEnglishText = error else {
                return XCTFail("mong đợi notEnglishText, nhận \(error)")
            }
        }
    }

    func testAgentKeyCheckerAccepts200AndRejects401() async {
        StubURLProtocol.handler = { request in
            let ok = request.url?.path.hasSuffix("/models") == true
                && request.value(forHTTPHeaderField: "Authorization") == "Bearer good-key"
            let status = ok ? 200 : 401
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let session = StubURLProtocol.makeSession()
        let good = await AgentKeyChecker.check(
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
            apiKey: "good-key",
            session: session)
        XCTAssertEqual(good, .valid)
        let bad = await AgentKeyChecker.check(
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
            apiKey: "bad-key",
            session: session)
        XCTAssertEqual(bad, .invalid("Key không được chấp nhận"))
    }

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

    func testAgentStoreAddEditDeleteFallsBackToProxy() throws {
        let db = try Fixtures.seededDB()
        let secrets = MemorySecrets()
        let id = try AnalysisAgentStore.add(
            on: db,
            name: "Gemini",
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            model: "gemini-2.5-flash",
            apiKey: "secret-key",
            secrets: secrets)
        let listed = try AnalysisAgentStore.list(on: db, secrets: secrets)
        XCTAssertEqual(listed.activeID, id)
        XCTAssertEqual(listed.agents.count, 2)
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
        XCTAssertEqual(after.activeID, Seeder.readoProxyAgentID)
        XCTAssertEqual(after.agents.count, 1)
        XCTAssertFalse(secrets.contains(agentID: id))
        XCTAssertThrowsError(
            try AnalysisAgentStore.delete(on: db, id: Seeder.readoProxyAgentID, secrets: secrets))
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

    // MARK: - Stream + AI-Box (plan "capture UX + OCR→AI-Box", đo thật 2026-09-26)

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

private struct FixedPageOCR: PageTextRecognizer {
    let text: String
    func recognize(imageData: Data) async throws -> String { text }
}

private final class MemorySecrets: AgentSecretStore, @unchecked Sendable {
    private var keys: [String: String] = [:]

    func save(agentID: String, apiKey: String) throws {
        keys[agentID] = apiKey
    }

    func contains(agentID: String) -> Bool {
        keys[agentID]?.isEmpty == false
    }

    func delete(agentID: String) {
        keys.removeValue(forKey: agentID)
    }

    func key(agentID: String) -> String? {
        keys[agentID]
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

/// Đếm số lần handler được gọi — `StubURLProtocol.handler` chạy trên thread
/// loading của URLProtocol nên cần khoá, không bắt `var` thường trực tiếp.
final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

/// Gom `AnalysisProgress` phát ra qua `onProgress` — closure là `@Sendable`
/// nên không thể bắt biến `var` thường (test AnalysisTests §2.7 kế hoạch AI-Box).
final class ProgressCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AnalysisProgress] = []

    func append(_ event: AnalysisProgress) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }

    var all: [AnalysisProgress] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

/// Một dòng SSE `data: {...}` cho `choices[0].delta` — escaping đúng qua
/// JSONSerialization thay vì nối chuỗi tay.
private func sseLine(content: String? = nil, reasoning: String? = nil) throws -> String {
    var delta: [String: Any] = [:]
    if let content { delta["content"] = content }
    if let reasoning { delta["reasoning_content"] = reasoning }
    let object: [String: Any] = ["choices": [["delta": delta]]]
    let data = try JSONSerialization.data(withJSONObject: object)
    return "data: " + String(decoding: data, as: UTF8.self)
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