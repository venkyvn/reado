import Foundation

/// apple-ai-r1 T6 (ADR-063) — agent Apple Intelligence, mirror
/// `OpenAICompatClient` (status check → OCR → gọi model → normalize/decode)
/// nhưng "gọi model" là pipeline CHIA NHỎ (T1 spike chốt): dịch từng đoạn +
/// một lượt từ vựng + một lượt tóm tắt, ráp lại thành đúng wire JSON rồi đi
/// qua `AnalysisResponseNormalizer`/`AnalysisResponseDecoder` CHUNG với BYOK
/// — luật lọc/validate (pos lạ→other, CEFR lạ bị bỏ, verify…) không viết lại.
public struct AppleIntelligenceAnalyzer: PageAnalyzer {
    private let model: AppleAnalysisModel
    private let status: @Sendable () -> AppleIntelligenceStatus
    private let ocr: PageTextRecognizer
    private let onProgress: (@Sendable (AnalysisProgress) -> Void)?
    private let timeout: Duration

    public init(
        model: AppleAnalysisModel,
        status: @escaping @Sendable () -> AppleIntelligenceStatus = {
            AppleIntelligence.status(needsVietnamese: true)
        },
        ocr: PageTextRecognizer = PageOCR.live,
        timeout: Duration = .seconds(120),
        onProgress: (@Sendable (AnalysisProgress) -> Void)? = nil
    ) {
        self.model = model
        self.status = status
        self.ocr = ocr
        self.timeout = timeout
        self.onProgress = onProgress
    }

    public func analyze(
        image: Data, imageMime: String, cefr: String, imageHash: String
    ) async throws -> PageAnalysis {
        _ = imageMime
        let trace = DebugTrace.startAnalysis()
        trace.write(image: image)
        trace.mergeMeta([
            "model": model.modelLabel, "cefr": cefr, "imageHash": imageHash,
            "source": "image", "agent": "apple",
        ])
        onProgress?(.readingPage)
        try checkStatus(trace: trace)

        let ocrStarted = Date()
        let ocrResult = try await ocr.recognizeDetailed(imageData: image)
        let pageOCR = ocrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
        trace.write(pageOCR: pageOCR)
        trace.write(ocrDebug: OpenAICompatClient.ocrDebugJSON(ocrResult))
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
            pageText: pageOCR, cefr: cefr, sourceHash: imageHash,
            promptVersion: Prompt.version, trace: trace)
    }

    public func analyzeText(
        _ pageText: String, cefr: String, sourceHash: String
    ) async throws -> PageAnalysis {
        let trace = DebugTrace.startAnalysis()
        trace.write(pageOCR: pageText)
        trace.mergeMeta([
            "model": model.modelLabel, "cefr": cefr, "imageHash": sourceHash,
            "source": "pdf", "agent": "apple",
        ])
        onProgress?(.readingPage)
        try checkStatus(trace: trace)

        guard !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            trace.mergeMeta(["error": "imageUnreadable"])
            throw AnalysisError.imageUnreadable
        }

        return try await run(
            pageText: pageText, cefr: cefr, sourceHash: sourceHash,
            promptVersion: Prompt.pdfVersion, trace: trace)
    }

    /// FR-21: Apple không sẵn sàng (chưa bật/máy không hỗ trợ/model đang
    /// tải/model KHÔNG hỗ trợ tiếng Việt) → báo lỗi rõ TRƯỚC khi đụng OCR hay
    /// gọi model — giống `OpenAICompatClient` báo thiếu key trước khi OCR.
    private func checkStatus(trace: DebugTrace.AnalysisSession) throws {
        let current = status()
        guard current.isAvailable else {
            let message = current.reasonVI ?? "Apple Intelligence chưa sẵn sàng"
            trace.mergeMeta(["error": "appleUnavailable", "reason": message])
            throw AnalysisError.providerError(message)
        }
    }

    private func run(
        pageText: String, cefr: String, sourceHash: String, promptVersion: Int,
        trace: DebugTrace.AnalysisSession
    ) async throws -> PageAnalysis {
        onProgress?(.waitingAgent)
        let started = Date()
        do {
            let wireJSON = try await TimeoutRunner.run(timeout) {
                try await self.chunkedPipeline(pageText: pageText, cefr: cefr)
            }
            trace.write(responseRaw: wireJSON)
            let normalized = try AnalysisResponseNormalizer.normalize(Data(wireJSON.utf8))
            let decoded = try AnalysisResponseDecoder.decode(normalized)
            if let object = try? JSONSerialization.jsonObject(with: normalized) as? [String: Any] {
                trace.write(analysisJSON: object)
            }
            trace.mergeMeta(["totalMs": Int(Date().timeIntervalSince(started) * 1000)])
            return PageAnalysis(
                segments: decoded.segments,
                vocabulary: decoded.vocabulary,
                summaryVI: decoded.summaryVI,
                meta: .init(imageHash: sourceHash, model: model.modelLabel, promptVersion: promptVersion))
        } catch {
            trace.mergeMeta([
                "error": String(describing: error),
                "totalMs": Int(Date().timeIntervalSince(started) * 1000),
            ])
            throw AppleIntelligenceErrorMapper.map(error)
        }
    }

    /// T1 spike (2026-10-05) chốt: chia theo đoạn (`\n\n`, các hàng trong một
    /// đoạn nối bằng 1 space — cùng luật `Prompt.text`) rồi dịch từng đoạn,
    /// MỘT lượt từ vựng + MỘT lượt tóm tắt cho cả trang. `phrases` để rỗng ở
    /// R1 (cần dịch theo đoạn ĐÃ gắn với cụm tương ứng — để sau nếu cần, xem
    /// ADR-063 "Đã cân nhắc").
    private func chunkedPipeline(pageText: String, cefr: String) async throws -> String {
        let paragraphs = pageText.components(separatedBy: "\n\n")
            .map { $0.components(separatedBy: "\n").joined(separator: " ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var segments: [[String: Any]] = []
        var writtenChars = 0
        for paragraph in paragraphs {
            let translated = try await model.translateParagraph(paragraph, cefr: cefr)
            segments.append(["source_en": paragraph, "translation_vi": translated])
            writtenChars += translated.count
            onProgress?(.writing(chars: writtenChars))
        }

        onProgress?(.thinking(chars: 0))
        let vocabularyJSON = try await model.extractVocabulary(pageText: pageText, cefr: cefr)
        let vocabulary = (try? JSONSerialization.jsonObject(with: Data(vocabularyJSON.utf8)))
            as? [[String: Any]] ?? []

        let summary = try await model.summarize(pageText: pageText, cefr: cefr)

        let wire: [String: Any] = [
            "segments": segments, "vocabulary": vocabulary, "summary_vi": summary,
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: wire), as: UTF8.self)
    }
}
