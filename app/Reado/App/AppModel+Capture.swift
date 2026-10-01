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
        capture.captureError = nil
        capture.analysisResult = nil
        capture.analysisFailure = nil
        shell.pendingHubNavigationID = nil
    }

    // MARK: — FR-02 AI Analysis

    /// Gọi analyzer cho ảnh hiện tại (proxy khi deploy, mock khi chưa — SD 2.1).
    /// FR-02: hiện progress, nhận 3 nhóm dữ liệu; lỗi → báo + cho retry.
    func analyzeCurrentImage() async {
        guard let image = capture.lastCapturedImage, let database else {
            // FR-04: không có ảnh → UI rơi về empty state "Chưa có trang để phân
            // tích" (đây không phải lỗi phân tích, không cần đặt capture.analysisFailure).
            return
        }
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
            // FR-02: agent seed là reado_proxy → ReadoProxyClient. URL lấy từ
            // READO_PROXY_BASE_URL nếu có, không thì AnalyzerFactory.proxyBaseURL.
            let (analyzer, cefrLevel) = try AnalyzerFactory.active(
                db: database,
                onProgress: { [weak self] progress in
                    Task { @MainActor in self?.capture.analysisProgress = progress }
                })
            let result = try await analyzer.analyze(
                image: image.imageData,
                imageMime: image.mimeType,
                cefr: cefrLevel,
                imageHash: image.imageHash)
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
            // port UI lab §5.7: Lưu → Hub bộ vừa chọn (kho tạm = hub kho tạm).
            shell.pendingHubNavigationID =
                collectionID ?? collections.first(where: { $0.isDefault })?.id
            capture.lastCapturedImage = nil
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
        capture.captureError = nil
        capture.analysisTargetCollectionID = nil
    }

    /// FR-04: dọn state phân tích + báo RootView mở lại CaptureView (ảnh mờ /
    /// trang không phải tiếng Anh → cần ảnh khác, retry cùng ảnh vô nghĩa).
    func prepareRecapture() {
        discardAnalysis()
        capture.pendingRecapture = true
    }
}
