import Foundation

/// FR-21 — `{base}/chat/completions`, Bearer từ Keychain ngay trước khi gửi.
/// `verification` thiếu thì decoder gọi VerifyEngine; không verify lần hai.
public struct OpenAICompatClient: PageAnalyzer {
    private let session: URLSession
    private let baseURL: String
    private let model: String
    private let agentID: String
    /// Chỉ test. Nil thì `analyze` đọc Keychain.
    private let apiKeyOverride: String?

    public init(
        session: URLSession = .shared,
        baseURL: String,
        model: String,
        agentID: String,
        apiKey: String? = nil
    ) {
        self.session = session
        self.baseURL = AgentURLRule.storedBase(baseURL)
        self.model = model
        self.agentID = agentID
        self.apiKeyOverride = apiKey
    }

    public func analyze(
        image: Data,
        imageMime: String,
        cefr: String,
        imageHash: String
    ) async throws -> PageAnalysis {
        let apiKey = apiKeyOverride ?? KeychainStore.load(agentID: agentID)
        guard let apiKey, !apiKey.isEmpty else {
            throw AnalysisError.providerError("Chưa có API key — mở Cài đặt và thêm key")
        }

        var request = URLRequest(url: try endpoint())
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.body(
            model: model,
            prompt: Prompt.text(cefrLevel: cefr),
            image: image,
            imageMime: imageMime)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnalysisError.networkError(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AnalysisError.networkError("không phải HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.mapHTTP(status: http.statusCode, data: data)
        }

        let content = try Self.messageContent(from: data)
        let normalized = try AnalysisResponseNormalizer.normalize(Data(content.utf8))
        var analysis = try AnalysisResponseDecoder.decode(normalized)
        analysis = PageAnalysis(
            segments: analysis.segments,
            vocabulary: analysis.vocabulary,
            summaryVI: analysis.summaryVI,
            meta: .init(imageHash: imageHash, model: model, promptVersion: Prompt.version))
        return analysis
    }

    private func endpoint() throws -> URL {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AnalysisError.networkError("base_url không hợp lệ: \(baseURL)")
        }
        return url
    }

    private static func body(
        model: String,
        prompt: String,
        image: Data,
        imageMime: String
    ) throws -> Data {
        let dataURI = "data:\(imageMime);base64,\(image.base64EncodedString())"
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": dataURI]],
                    ],
                ],
            ],
            "response_format": ["type": "json_object"],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private static func messageContent(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else {
            throw AnalysisError.schemaViolation("thiếu choices[0].message")
        }
        if let text = message["content"] as? String, !text.isEmpty {
            return unwrapJSON(text)
        }
        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined()
            if !text.isEmpty { return unwrapJSON(text) }
        }
        throw AnalysisError.schemaViolation("message.content rỗng")
    }

    private static func unwrapJSON(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```") else { return text }
        if let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }
        if let fence = text.range(of: "```", options: .backwards) {
            text = String(text[..<fence.lowerBound])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mapHTTP(status: Int, data: Data) -> AnalysisError {
        let root = try? JSONSerialization.jsonObject(with: data)
        let errorObject = (root as? [String: Any])?["error"] as? [String: Any]
        let message = errorObject?["message"] as? String
        switch status {
        case 401:
            return .providerError(message ?? "Key bị từ chối — kiểm tra lại trong Cài đặt")
        case 429:
            return .rateLimited
        default:
            return .providerError(message ?? "HTTP \(status)")
        }
    }
}
