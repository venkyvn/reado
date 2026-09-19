import Foundation

/// Analyzer gọi proxy Reado (SD 7.2 — `ReadoProxyClient`). Proxy tự chọn model
/// Gemini + tự verify `example` (prompt-spec mục 6) — FR-02 một lần gọi multimodal.
/// Cấu hình (base_url, model) tới từ `analysis_agents` row (SD 7.2); walking
/// skeleton dùng builtin proxy id `00000000-0000-4000-a000-000000000001`.
///
/// Wire: multipart POST {base_url}/v1/analyze (SD 4.1). Envelope decode qua
/// AnalysisResponseDecoder; lỗi HTTP map qua AnalysisError (SD 4.1).
public struct ReadoProxyClient: PageAnalyzer {
    private let session: URLSession
    private let baseURL: String

    public init(session: URLSession = .shared, baseURL: String) {
        self.session = session
        // Cắt trailing slash để URL(path:) ghép không bị "//".
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public func analyze(
        image: Data,
        imageMime: String,
        cefr: String,
        imageHash: String
    ) async throws -> PageAnalysis {
        // SD 4.2 — hash là idempotency key; proxy cache theo hash để retry không tính phí đôi.
        let boundary = "Reado-\(Identifier.uuid())"
        var request = URLRequest(url: try endpoint())
        request.httpMethod = "POST"
        request.timeoutInterval = 60  // NFR-01 p95 ≤ 30s + margin 2x (SD 7.6)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(imageHash, forHTTPHeaderField: "X-Reado-Image-Hash")
        request.setValue(String(Prompt.version), forHTTPHeaderField: "X-Reado-Prompt-Version")
        request.httpBody = try Self.multipartBody(
            boundary: boundary,
            image: image,
            imageMime: imageMime,
            cefr: cefr)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnalysisError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AnalysisError.networkError("không phải HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw try Self.mapError(statusCode: http.statusCode, data: data)
        }

        return try AnalysisResponseDecoder.decode(data)
    }

    // MARK: - Private

    private func endpoint() throws -> URL {
        guard let url = URL(string: "\(baseURL)/v1/analyze") else {
            throw AnalysisError.networkError("base_url không hợp lệ: \(baseURL)")
        }
        return url
    }

    /// Body multipart theo SD 4.1: fields `image`, `cefr_level` (+ hậu tố `\r\n`).
    private static func multipartBody(
        boundary: String,
        image: Data,
        imageMime: String,
        cefr: String
    ) throws -> Data {
        var body = Data()
        let br = "\r\n"
        func appendField(name: String, value: String) {
            body.append(Data("--\(boundary)\(br)".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\(br)\(br)".utf8))
            body.append(Data(value.utf8))
            body.append(Data(br.utf8))
        }
        // Ảnh
        body.append(Data("--\(boundary)\(br)".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"image\"; filename=\"page.jpg\"\(br)".utf8))
        body.append(Data("Content-Type: \(imageMime)\(br)\(br)".utf8))
        body.append(image)
        body.append(Data(br.utf8))
        // Text fields
        appendField(name: "cefr_level", value: cefr)
        body.append(Data("--\(boundary)--\(br)".utf8))
        return body
    }
}

/// Envelope lỗi của proxy (SD 4.1) — `code` machine-readable, `message` cho UI.
private struct ErrorEnvelope: Decodable {
    struct Body: Decodable { let code: String; let message: String? }
    let error: Body
}

extension ReadoProxyClient {
    /// Map error envelope code (SD 4.1) → AnalysisError để UI hiểu lý do, không parse chuỗi.
    private static func mapError(statusCode: Int, data: Data) throws -> AnalysisError {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            switch envelope.error.code {
            case "IMAGE_UNREADABLE": return .imageUnreadable
            case "NON_ENGLISH_TEXT": return .notEnglishText
            case "SCHEMA_VIOLATION": return .schemaViolation(envelope.error.message ?? "")
            case "RATE_LIMITED": return .rateLimited
            case "IDEMPOTENCY_MISSING": return .idempotencyMissing
            case "PROVIDER_ERROR": return .providerError(envelope.error.message ?? "")
            default: return .providerError(envelope.error.message ?? envelope.error.code)
            }
        }
        return .providerError("HTTP \(statusCode)")
    }
}
