import Foundation
import os

/// FR-21 — `{base}/chat/completions`, Bearer từ Keychain ngay trước khi gửi.
/// Ảnh: OCR trên máy trước POST. PDF (FR-23/ADR-058, `analyzeText`): lớp chữ
/// trang đã có sẵn, không OCR. Cả hai body chỉ `type:text`. `verification`
/// thiếu thì decoder gọi VerifyEngine; không verify lần hai.
///
/// **Đo thật trên AI-Box (2026-09-26, `deepseek-v4.1-flash`, trang ~200 từ):**
/// non-stream, không tắt suy nghĩ (cấu hình cũ) → byte đầu ở **63s**, quá
/// idle-timeout 60s cũ → luôn timeout. Tắt suy nghĩ (`enable_thinking: false`,
/// chỉ áp cho host `ai-box.vn`) + stream → byte đầu ~1s, tổng **15–18s**. Xem
/// `docs/decisions-log.md` / plan liên quan cho bảng đo đầy đủ.
public struct OpenAICompatClient: PageAnalyzer {
    private let session: URLSession
    private let baseURL: String
    private let model: String
    private let agentID: String
    /// Chỉ test. Nil thì `analyze` đọc Keychain.
    private let apiKeyOverride: String?
    private let ocr: PageTextRecognizer
    /// Báo tiến độ khi đang gọi agent (đọc trang / chờ / đang suy nghĩ / đang
    /// viết kèm số ký tự) — UI dùng để không để màn "Đang xử lý…" đứng im khi
    /// model mất 15–30s. Không bắt buộc, mặc định im lặng.
    private let onProgress: (@Sendable (AnalysisProgress) -> Void)?

    private static let logger = Logger(subsystem: "app.reado", category: "analysis")

    public init(
        session: URLSession = .shared,
        baseURL: String,
        model: String,
        agentID: String,
        apiKey: String? = nil,
        ocr: PageTextRecognizer = PageOCR.live,
        onProgress: (@Sendable (AnalysisProgress) -> Void)? = nil
    ) {
        self.session = session
        self.baseURL = AgentURLRule.storedBase(baseURL)
        self.model = model
        self.agentID = agentID
        self.apiKeyOverride = apiKey
        self.ocr = ocr
        self.onProgress = onProgress
    }

    public func analyze(
        image: Data,
        imageMime: String,
        cefr: String,
        imageHash: String
    ) async throws -> PageAnalysis {
        _ = imageMime
        // DebugTrace no-op ngoài bản DEBUG (ADR-037) — gọi thẳng, không cần
        // `#if DEBUG` ở đây.
        let trace = DebugTrace.startAnalysis()
        trace.write(image: image)
        trace.mergeMeta([
            "model": model, "baseURL": baseURL, "cefr": cefr, "imageHash": imageHash,
            "source": "image",
        ])
        onProgress?(.readingPage)
        let apiKey = apiKeyOverride ?? KeychainStore.load(agentID: agentID)
        guard let apiKey, !apiKey.isEmpty else {
            throw AnalysisError.providerError("Chưa có API key — mở Cài đặt và thêm key")
        }

        let ocrStarted = Date()
        let ocrResult = try await ocr.recognizeDetailed(imageData: image)
        let pageOCR = ocrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
        trace.write(pageOCR: pageOCR)
        trace.write(ocrDebug: Self.ocrDebugJSON(ocrResult))
        trace.mergeMeta([
            "ocrMs": Int(Date().timeIntervalSince(ocrStarted) * 1000),
            "ocrChars": pageOCR.count,
            "ocrLines": ocrResult.lines.count,
        ])
        guard !pageOCR.isEmpty else {
            trace.mergeMeta(["error": "imageUnreadable"])
            throw AnalysisError.imageUnreadable
        }

        return try await run(
            prompt: Prompt.text(cefrLevel: cefr, pageOCR: pageOCR),
            promptVersion: Prompt.version,
            sourceHash: imageHash,
            apiKey: apiKey,
            trace: trace)
    }

    /// FR-23/ADR-058 (pdf-reader-r1 T2) — lớp chữ của một trang PDF, **không
    /// OCR**: `pageText` đã được `PDFPageText` (tầng app) dò ranh giới đoạn
    /// bằng hình học và chấm chất lượng trước khi tới đây — trang rác/scan đi
    /// lối `analyze(image:...)` thay vì vào đây. `sourceHash` thay `imageHash`
    /// (cùng field `meta.imageHash` — giá trị là hash của text, không phải ảnh).
    public func analyzeText(
        _ pageText: String, cefr: String, sourceHash: String
    ) async throws -> PageAnalysis {
        let trace = DebugTrace.startAnalysis()
        // Ghi vào CÙNG file `page_ocr.txt` (không phải file riêng) — để
        // `prompt_eval.py` và `diag_summary.py` đọc được không cần đổi layout.
        trace.write(pageOCR: pageText)
        trace.mergeMeta([
            "model": model, "baseURL": baseURL, "cefr": cefr, "imageHash": sourceHash,
            "source": "pdf",
        ])
        onProgress?(.readingPage)
        let apiKey = apiKeyOverride ?? KeychainStore.load(agentID: agentID)
        guard let apiKey, !apiKey.isEmpty else {
            throw AnalysisError.providerError("Chưa có API key — mở Cài đặt và thêm key")
        }
        guard !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            trace.mergeMeta(["error": "imageUnreadable"])
            throw AnalysisError.imageUnreadable
        }

        return try await run(
            prompt: Prompt.pdfText(cefrLevel: cefr, pageText: pageText),
            promptVersion: Prompt.pdfVersion,
            sourceHash: sourceHash,
            apiKey: apiKey,
            trace: trace)
    }

    /// Phần chung của `analyze`/`analyzeText` sau khi đã có prompt text sẵn
    /// sàng gửi: gọi agent (kèm retry bỏ `response_format`), map lỗi, gắn
    /// `meta`. Tách ra pdf-reader-r1 T2 để hai lối dùng chung logic retry/lỗi.
    private func run(
        prompt: String,
        promptVersion: Int,
        sourceHash: String,
        apiKey: String,
        trace: DebugTrace.AnalysisSession
    ) async throws -> PageAnalysis {
        onProgress?(.waitingAgent)
        let started = Date()
        do {
            let analysis: PageAnalysis
            do {
                analysis = try await send(
                    prompt: prompt, apiKey: apiKey, includeResponseFormat: true, trace: trace)
            } catch is ResponseFormatRejected {
                // Server trả 400/422 nhắc response_format — một số OpenAI-compat
                // gateway không hỗ trợ field này. Thử lại đúng một lần, bỏ field.
                trace.mergeMeta(["retriedWithoutResponseFormat": true])
                analysis = try await send(
                    prompt: prompt, apiKey: apiKey, includeResponseFormat: false, trace: trace)
            }
            #if DEBUG
            Self.logger.debug(
                "analysis ok model=\(model, privacy: .public) totalMs=\(Int(Date().timeIntervalSince(started) * 1000), privacy: .public)"
            )
            #endif
            trace.mergeMeta(["totalMs": Int(Date().timeIntervalSince(started) * 1000)])
            return PageAnalysis(
                segments: analysis.segments,
                vocabulary: analysis.vocabulary,
                summaryVI: analysis.summaryVI,
                meta: .init(imageHash: sourceHash, model: model, promptVersion: promptVersion))
        } catch let urlError as URLError {
            #if DEBUG
            Self.logger.debug(
                "analysis urlError model=\(model, privacy: .public) code=\(urlError.code.rawValue, privacy: .public)"
            )
            #endif
            trace.mergeMeta(["error": "urlError", "urlErrorCode": urlError.code.rawValue])
            throw OpenAICompatErrorMapper.url(urlError)
        } catch {
            trace.mergeMeta(["error": String(describing: error)])
            throw error
        }
    }

    /// apple-ai-r1 T4 — đổi `private` → internal: `AppleIntelligenceAnalyzer`
    /// (T6, cùng module) ghi `ocr.json` cùng khuôn để `diag_summary.py` không
    /// phải phân biệt agent khi đọc log chẩn đoán.
    static func ocrDebugJSON(_ result: PageOCR.OCRResult) -> [String: Any] {
        [
            "engine": result.engine,
            "observationCount": result.observations.count,
            // ocr-quality-r1 T3a (ADR-064) — khi engine="liveText", `lines`/
            // `observations` dưới đây vẫn là lượt `documents` TRƯỚC KHI ghép Live
            // Text (xem doc-comment `OCRResult.engine`) — không phải bản đã phân
            // tích thật (đó là `pageOCR`/`ocrChars` ở event cha). Review sau T3a
            // tìm được: đọc `lines[].text` mà tưởng là bản cuối thì bị sai.
            "linesSource": result.engine == "liveText" ? "documents (trước khi ghép)" : result.engine,
            // ocr-line-drop: rawObservationCount là tổng Vision trả về TRƯỚC lọc
            // confidence — chênh với observationCount + droppedLowConfidence.count
            // là phần Vision không hề thấy (không phải bị code mình lọc).
            "rawObservationCount": result.rawObservationCount,
            "droppedLowConfidence": result.droppedLowConfidence.map { obs in
                [
                    "text": String(obs.text.prefix(200)),
                    "confidence": Double(obs.confidence),
                    "yTop": Double(1 - obs.boundingBox.origin.y - obs.boundingBox.height),
                ] as [String: Any]
            },
            "lines": result.lines.map { line in
                [
                    "text": String(line.text.prefix(200)),
                    "minX": Double(line.minX),
                    "maxX": Double(line.maxX),
                    "yTop": Double(line.yTop),
                    "height": Double(line.height),
                    "breakBefore": line.breakBefore,
                    "breakReason": line.breakReason ?? NSNull(),
                ] as [String: Any]
            },
        ]
    }

    /// Gửi một lượt chat/completions dạng stream, đọc `data:` từng chunk cho
    /// tới `[DONE]`. Server lờ `stream` và trả JSON thường (Content-Type
    /// `application/json`, không dòng nào bắt đầu `data:`) vẫn decode được —
    /// đi qua đường `AnalysisResponseExtractor.messageContent(from:)` cũ.
    private func send(
        prompt: String,
        apiKey: String,
        includeResponseFormat: Bool,
        trace: DebugTrace.AnalysisSession
    ) async throws -> PageAnalysis {
        var request = URLRequest(url: try endpoint())
        request.httpMethod = "POST"
        // Idle timeout — có dữ liệu chảy liên tục qua stream nên hiếm khi chạm
        // tới; 63s đo được ở cấu hình cũ (không tắt suy nghĩ) đã sát 60s cũ.
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.body(
            model: model,
            prompt: prompt,
            extra: Self.extraBodyParams(forBaseURL: baseURL),
            includeResponseFormat: includeResponseFormat)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        // Chặn tự follow redirect: base URL thiếu `/v1` (ví dụ AI-Box) trả 301,
        // URLSession mặc định follow (có thể đổi POST→GET) sẽ che mất lỗi thật.
        (bytes, response) = try await session.bytes(for: request, delegate: Self.noRedirectDelegate)
        guard let http = response as? HTTPURLResponse else {
            throw AnalysisError.networkError("không phải HTTP response")
        }
        trace.mergeMeta(["httpStatus": http.statusCode, "includeResponseFormat": includeResponseFormat])

        guard (200..<300).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            trace.write(responseRaw: String(decoding: errorData, as: UTF8.self))
            if includeResponseFormat,
               (http.statusCode == 400 || http.statusCode == 422),
               String(decoding: errorData, as: UTF8.self).lowercased().contains("response_format")
            {
                throw ResponseFormatRejected()
            }
            throw OpenAICompatErrorMapper.http(status: http.statusCode, data: errorData)
        }

        let content = try await Self.readContent(from: bytes, onProgress: onProgress)
        trace.write(responseRaw: content)
        let normalized = try AnalysisResponseNormalizer.normalize(Data(content.utf8))
        do {
            let analysis = try AnalysisResponseDecoder.decode(normalized)
            if let json = try? JSONSerialization.jsonObject(with: normalized) as? [String: Any] {
                trace.write(analysisJSON: json)
            }
            return analysis
        } catch {
            trace.mergeMeta(["decodeError": String(describing: error)])
            throw error
        }
    }

    /// Đọc `bytes` dòng theo dòng; dòng khác rỗng đầu tiên quyết định chế độ.
    private static func readContent(
        from bytes: URLSession.AsyncBytes,
        onProgress: (@Sendable (AnalysisProgress) -> Void)?
    ) async throws -> String {
        var iterator = bytes.lines.makeAsyncIterator()
        var firstLine: String?
        while let line = try await iterator.next() {
            if line.isEmpty { continue }
            firstLine = line
            break
        }
        guard let firstLine else {
            throw AnalysisError.schemaViolation("phản hồi rỗng")
        }

        guard firstLine.hasPrefix("data:") else {
            // Server lờ "stream": true, trả JSON thường trong (có thể) nhiều dòng.
            var full = firstLine
            while let line = try await iterator.next() {
                full += "\n" + line
            }
            guard let data = full.data(using: .utf8) else {
                throw AnalysisError.schemaViolation("phản hồi không phải UTF-8")
            }
            return try AnalysisResponseExtractor.messageContent(from: data)
        }

        var buffer = ""
        var reasoningChars = 0
        var lastReport = Date.distantPast
        func report(_ progress: AnalysisProgress, force: Bool = false) {
            let now = Date()
            guard force || now.timeIntervalSince(lastReport) >= 0.25 else { return }
            lastReport = now
            onProgress?(progress)
        }
        func handle(_ line: String) -> Bool {
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { return true }
            guard let data = payload.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]]
            else { return false }
            for choice in choices {
                guard let delta = choice["delta"] as? [String: Any] else { continue }
                if let text = delta["content"] as? String, !text.isEmpty {
                    buffer += text
                    report(.writing(chars: buffer.count))
                }
                if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                    reasoningChars += reasoning.count
                    report(.thinking(chars: reasoningChars))
                }
            }
            return false
        }

        var done = handle(firstLine)
        while !done {
            guard let line = try await iterator.next() else { break }
            if line.isEmpty || line.hasPrefix(":") { continue }
            guard line.hasPrefix("data:") else { continue }
            done = handle(line)
        }
        if !buffer.isEmpty { report(.writing(chars: buffer.count), force: true) }
        return try AnalysisResponseExtractor.extractAnalysisJSON(from: buffer)
    }

    private func endpoint() throws -> URL {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AnalysisError.networkError("base_url không hợp lệ: \(baseURL)")
        }
        return url
    }

    /// Tham số riêng cho host đã kiểm — tránh gửi đại trà làm provider khác
    /// (Gemini, OpenRouter…) trả 400 vì field lạ. `enable_thinking: false` đo
    /// được cắt AI-Box từ 63s xuống 15–18s (xem doc header file này).
    static func extraBodyParams(forBaseURL baseURL: String) -> [String: Any] {
        guard let host = URL(string: baseURL)?.host?.lowercased() else { return [:] }
        if host == "api.ai-box.vn" || host.hasSuffix(".ai-box.vn") {
            return ["enable_thinking": false]
        }
        return [:]
    }

    private static func body(
        model: String,
        prompt: String,
        extra: [String: Any],
        includeResponseFormat: Bool
    ) throws -> Data {
        var payload: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                [
                    "role": "system",
                    "content": "Chỉ trả về một JSON object hợp lệ, không markdown, không giải thích.",
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                    ],
                ],
            ],
        ]
        if includeResponseFormat {
            payload["response_format"] = ["type": "json_object"]
        }
        for (key, value) in extra { payload[key] = value }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// Đánh dấu nội bộ: server từ chối `response_format`, thử lại 1 lần không kèm field.
    private struct ResponseFormatRejected: Error {}

    /// `URLSession` mặc định tự follow redirect (có thể đổi POST→GET, nuốt lỗi
    /// 301 thật). Trả `nil` ở đây để giữ nguyên response gốc cho `OpenAICompatErrorMapper.http`.
    private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _: URLSession,
            task _: URLSessionTask,
            willPerformHTTPRedirection _: HTTPURLResponse,
            newRequest _: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }

    private static let noRedirectDelegate = NoRedirectDelegate()
}
