import Foundation
import ReadoKit

// Chụp trang, phân tích AI và chốt phiên duyệt (FR-01..04, FR-03/09).
// Tách từ AppModel.swift (refactor): logic giữ nguyên, chỉ đổi file.

extension AppModel {
    // MARK: — FR-01 Capture

    /// Nhận ảnh đã crop + nén xong từ CaptureView, giữ tạm trong bộ nhớ.
    /// NFR-04: ảnh không persist; buffer memory solution sau (SD mục 8).
    /// 2.2 sẽ dùng ảnh này gọi PageAnalyzer.
    func handleCapturedImage(_ image: CapturedImage) {
        capture.lastCapturedImage = image
        // FR-23: chụp ảnh thường luôn là lối camera — dọn sạch trang PDF cũ nếu
        // có (fen bấm chụp giữa lúc chưa đóng hẳn một lượt phân tích PDF dở).
        capture.pdfText = nil
        capture.origin = .camera
        capture.captureError = nil
        capture.analysisResult = nil
        capture.analysisFailure = nil
        shell.saveConfirmation = nil
    }

    // MARK: — FR-02 AI Analysis

    /// Gọi analyzer cho agent BYOK đang active, mock khi walking skeleton (SD 2.1).
    /// FR-02: hiện progress, nhận 3 nhóm dữ liệu; lỗi → báo + cho retry.
    /// FR-23/ADR-058 (pdf-reader-r1 T4): `capture.pdfText` có giá trị → lối PDF
    /// (`analyzeText`, không OCR); không thì lối ảnh cũ nguyên vẹn (PDF scan/lớp
    /// chữ rác đã được vẽ thành ảnh ở `preparePDFAnalysis`, đi đúng nhánh này).
    func analyzeCurrentPage() async {
        guard let database else { return }
        if let pdfPage = capture.pdfText {
            await runAnalysis(database: database) { analyzer, cefrLevel in
                try await analyzer.analyzeText(
                    pdfPage.text, cefr: cefrLevel, sourceHash: pdfPage.sourceHash)
            }
            return
        }
        guard let image = capture.lastCapturedImage else {
            // FR-04: không có trang → UI rơi về empty state "Chưa có trang để
            // phân tích" (không phải lỗi phân tích, không set analysisFailure).
            return
        }
        await runAnalysis(database: database) { analyzer, cefrLevel in
            try await analyzer.analyze(
                image: image.imageData,
                imageMime: image.mimeType,
                cefr: cefrLevel,
                imageHash: image.imageHash)
        }
    }

    /// Phần chung của hai lối (ảnh/PDF): mở analyzer, chạy progress, map lỗi.
    /// Tách ra T4 để `analyzeCurrentPage` chỉ còn khác nhau đúng một lời gọi.
    private func runAnalysis(
        database: SQLiteDatabase,
        call: (PageAnalyzer, String) async throws -> PageAnalysis
    ) async {
        capture.isAnalyzing = true
        capture.analysisFailure = nil
        capture.analysisResult = nil
        capture.analysisProgress = .readingPage
        defer {
            capture.isAnalyzing = false
            capture.analysisProgress = nil
        }

        let startedAt = Date()
        do {
            // FR-02/ADR-049: agent active đọc từ settings — placeholder (chưa
            // chọn agent) rơi vào NoAgentAnalyzer, báo lỗi rõ ở catch dưới.
            let (analyzer, cefrLevel) = try AnalyzerFactory.active(
                db: database,
                onProgress: { [weak self] progress in
                    Task { @MainActor in self?.capture.analysisProgress = progress }
                })
            let result = try await call(analyzer, cefrLevel)
            capture.analysisResult = result
            DebugTrace.event("analysis", "ok", [
                "segments": result.segments.count,
                "vocabulary": result.vocabulary.count,
                "totalMs": Int(Date().timeIntervalSince(startedAt) * 1000),
            ])
        } catch {
            // FR-04: phân loại lỗi để UI gợi ý đúng (chụp lại vs thử lại); KHÔNG
            // set capture.analysisResult → không bịa dữ liệu, không lưu bản ghi hỏng.
            capture.analysisFailure = (error as? AnalysisError) ?? .providerError(
                (error as? LocalizedError)?.errorDescription
                    ?? String(describing: error))
            DebugTrace.event("analysis", "failed", [
                "error": String(describing: capture.analysisFailure),
                "totalMs": Int(Date().timeIntervalSince(startedAt) * 1000),
            ])
        }
    }

    // MARK: — Chốt phiên duyệt (FR-03/FR-09 + transaction #4)

    /// Lưu các item đã duyệt & chọn vào collection (SD mục 6 khối #4 + #5).
    /// Chỉ item `isSelected` được ghi (FR-03 bỏ chọn = không lưu); validation
    /// trường bắt buộc + chuẩn hoá do `ReviewDraftBuilder.selected` (FR-03).
    /// collectionID nil → kho tạm (is_default, 2.4). `segments`/`summaryVI` ghi
    /// thành phiên đọc (FR-05/06) khi đích là collection có tên. Trả số item đã ghi.
    func saveSelection(
        _ drafts: [ReviewDraft],
        collectionID: String?,
        segments: [PageAnalysis.Segment] = [],
        summaryVI: String = ""
    ) throws -> Int {
        guard let database else { return 0 }
        let items = try ReviewDraftBuilder.selected(drafts)
        let saved = try VocabRepository.saveCapture(
            on: database,
            items: items,
            collectionID: collectionID,
            segments: segments,
            summaryVI: summaryVI,
            now: clock.now)
        DebugTrace.event("save", "selection", [
            "saved": saved, "collectionID": collectionID ?? "kho_tam", "segments": segments.count,
        ])
        if saved > 0 {
            reloadOverview()
            // ADR-053: RootView hiện banner "Đã lưu N từ vào X · Xem" (kho tạm cũng có id/tên).
            if let target = collectionID ?? collections.first(where: { $0.isDefault })?.id,
               let name = collections.first(where: { $0.id == target })?.name
            {
                shell.saveConfirmation = SaveConfirmation(
                    count: saved, collectionID: target, collectionName: name)
            }
            capture.lastCapturedImage = nil
            capture.pdfText = nil
            capture.origin = .camera
            capture.analysisResult = nil
            capture.analysisTargetCollectionID = nil
        }
        return saved
    }

    /// FR-03: user chủ động bỏ kết quả khi chưa confirm — dọn state để lần
    /// chụp sau bắt đầu sạch, không còn analysis cũ trong bộ nhớ.
    func discardAnalysis() {
        capture.analysisResult = nil
        capture.analysisFailure = nil
        capture.lastCapturedImage = nil
        capture.pdfText = nil
        capture.origin = .camera
        capture.captureError = nil
        capture.analysisTargetCollectionID = nil
    }

    /// FR-04: dọn state phân tích. Lối ảnh báo RootView mở lại CaptureView (ảnh
    /// mờ / trang không phải tiếng Anh → cần ảnh khác, retry cùng ảnh vô nghĩa).
    /// Lối PDF (FR-23/ADR-058) KHÔNG bật `pendingRecapture` — mở camera là sai,
    /// `AnalysisView` tự đóng sheet để lộ lại `PDFReaderView` đang đứng sẵn phía
    /// dưới (nút "Về trang đọc", không phải "Chụp lại").
    func prepareRecapture() {
        let wasPDF = capture.origin == .pdf
        discardAnalysis()
        if !wasPDF {
            capture.pendingRecapture = true
        }
    }
}
