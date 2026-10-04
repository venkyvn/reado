import Foundation
import PDFKit
import ReadoKit

// FR-23/ADR-058 (pdf-reader-r1 T3) — đọc PDF trong Reado, cửa thu từ vựng thứ
// hai. File không bao giờ được chép vào app: chỉ giữ security-scoped bookmark
// + trang đang đọc (bảng `pdf_sources`, `PDFSourceRepository`). Mỗi collection
// có tên gắn tối đa 1 PDF; kho tạm bị chặn ở TẦNG UI (Hub không hiện mục "Gắn
// PDF…" khi `isDefault`) — model ở đây không tự kiểm lại, theo đúng db.md
// A.2.2 (app-rule, không CHECK SQL).

/// Vì sao không mở được PDF — tách khỏi `AnalysisError` vì đây là lỗi MỞ file,
/// không phải lỗi phân tích (T4 mới chạm tới phân tích).
enum PDFOpenError: Error, LocalizedError, Equatable {
    /// Collection chưa gắn PDF nào.
    case notAttached
    /// Bookmark không resolve được (file đã xoá, đổi chỗ, hoặc chưa đồng bộ
    /// xong từ iCloud) — `URL(resolvingBookmarkData:)` trả `nil`.
    case bookmarkUnresolvable
    /// `startAccessingSecurityScopedResource()` trả `false`.
    case accessDenied
    /// `PDFDocument(url:)` trả `nil` — file hỏng hoặc không phải PDF hợp lệ.
    case unreadable
    /// `PDFDocument.isLocked` — có mật khẩu. R1 không có ô nhập mật khẩu.
    case locked

    var errorDescription: String? {
        switch self {
        case .notAttached:
            "Bộ này chưa gắn PDF."
        case .bookmarkUnresolvable, .accessDenied, .unreadable:
            "Không mở được file PDF — file có thể đã bị xoá, di chuyển, hoặc chưa tải xong từ iCloud."
        case .locked:
            "PDF có mật khẩu — mở khoá trong app khác rồi gắn lại."
        }
    }

    /// GWT FR-23: lỗi nào cho chọn lại file, lỗi nào thì không (mật khẩu —
    /// chọn lại cùng file vẫn vậy, phải mở khoá trước ở nơi khác).
    var allowsPickingAgain: Bool { self != .locked }
}

extension AppModel {
    // MARK: — Đọc trạng thái gắn PDF (Hub)

    /// Nạp PDF đang gắn của một collection cho `library.pdfSource` (Hub đọc để
    /// vẽ hàng "Đọc PDF · tr. N" + chọn nhãn menu "Gắn"/"Đổi PDF…").
    func loadPDFSource(collectionID: String) {
        guard let database else {
            library.pdfSource = nil
            return
        }
        library.pdfSource = read("PDF đã gắn", fallback: nil) {
            try PDFSourceRepository.source(on: database, collectionID: collectionID)
        }
    }

    // MARK: — Gắn / đổi / gỡ (hành động người dùng từ menu Hub — alert khi lỗi)

    /// Tạo bookmark trỏ tới `url` — KHÔNG chép file — rồi ghi `pdf_sources`
    /// (UPSERT: gắn lại bộ đã có PDF thì ghi đè, trang đang đọc về 0). Đếm
    /// trang bằng `PDFDocument(url:)`; đọc lỗi/0 trang vẫn gắn được (fen có thể
    /// đang chọn một file hơi khác thường) — `page_count` chỉ để hiện UI, T3
    /// chưa chặn gắn PDF hỏng ở đây, reader tự báo lỗi lúc mở.
    private func attachPDF(url: URL, collectionID: String) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        // iOS: KHÔNG có option `.withSecurityScope` (chỉ macOS) — bookmark rỗng
        // `[]` là đúng cho sandbox iOS (Apple docs).
        let bookmark = try url.bookmarkData(options: [])
        let pageCount = PDFDocument(url: url)?.pageCount ?? 0
        try PDFSourceRepository.attach(
            on: database,
            collectionID: collectionID,
            displayName: url.lastPathComponent,
            bookmark: bookmark.base64EncodedString(),
            pageCount: pageCount,
            now: clock.now)
        loadPDFSource(collectionID: collectionID)
    }

    /// `false` = chưa gắn và ĐÃ báo lỗi (`attempt`).
    @discardableResult
    func attachPDFOrAlert(url: URL, collectionID: String) -> Bool {
        attempt("gắn PDF") { try attachPDF(url: url, collectionID: collectionID) } != nil
    }

    /// Chỉ xoá dòng `pdf_sources` — KHÔNG đụng file gốc (chưa từng chép) và
    /// KHÔNG đụng vocab/session đã lưu từ PDF đó.
    private func detachPDF(collectionID: String) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try PDFSourceRepository.detach(on: database, collectionID: collectionID)
        loadPDFSource(collectionID: collectionID)
    }

    @discardableResult
    func detachPDFOrAlert(collectionID: String) -> Bool {
        attempt("gỡ PDF") { try detachPDF(collectionID: collectionID) } != nil
    }

    // MARK: — Mở để đọc (PDFReaderView)

    /// Resolve bookmark → mở `PDFDocument`. Trả thêm `url` (caller GIỮ access
    /// mở suốt vòng đời reader — PDFKit đọc trang lười, không phải lúc mở —
    /// rồi tự `stopAccessingSecurityScopedResource()` ở `onDisappear`, NHƯNG
    /// chỉ khi `didStartAccess` — xem comment ở `startAccessingSecurityScopedResource`
    /// dưới) và `pageIndex` đã lưu (kẹp về khoảng hợp lệ nếu trang đã lưu vượt
    /// quá số trang thật, ví dụ file bị thay bằng bản ngắn hơn).
    func openPDFDocument(
        collectionID: String
    ) -> Result<(document: PDFDocument, url: URL, pageIndex: Int, didStartAccess: Bool), PDFOpenError> {
        guard let database else { return .failure(.unreadable) }
        let source: PDFSource?
        do {
            source = try PDFSourceRepository.source(on: database, collectionID: collectionID)
        } catch {
            DebugTrace.event("error", "pdf:openSource", ["error": String(describing: error)])
            return .failure(.unreadable)
        }
        guard let source, let bookmarkData = Data(base64Encoded: source.bookmark) else {
            return .failure(.notAttached)
        }

        var isStale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil,
                bookmarkDataIsStale: &isStale)
        else {
            return .failure(.bookmarkUnresolvable)
        }
        if isStale, let refreshed = try? url.bookmarkData(options: []) {
            // Vẫn CÙNG file — chỉ refresh con trỏ hệ thống, không đụng
            // page_index/page_count (khác `attachPDF`, đó là đổi FILE).
            try? PDFSourceRepository.updateBookmark(
                on: database, collectionID: collectionID,
                bookmark: refreshed.base64EncodedString(), now: clock.now)
        }

        // Apple: `false` không chắc nghĩa "không đọc được" — URL không thật
        // security-scoped (file trong container app, ổ đĩa host của simulator)
        // cũng trả `false` nhưng vẫn mở được bình thường. Chỉ coi là lỗi khi
        // CẢ hai cùng fail: không start được VÀ không mở được document.
        let didStartAccess = url.startAccessingSecurityScopedResource()
        guard let document = PDFDocument(url: url) else {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
            return .failure(didStartAccess ? .unreadable : .accessDenied)
        }
        if document.isLocked {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
            return .failure(.locked)
        }
        let pageIndex = document.pageCount > 0
            ? min(max(source.pageIndex, 0), document.pageCount - 1)
            : 0
        return .success((document, url, pageIndex, didStartAccess))
    }

    // MARK: — Lưu trang đang đọc (gọi liên tục lúc lật trang — không alert)

    /// Ghi `page_index`. Lỗi ở đây hiếm (SQLite local) và không đáng làm gián
    /// đoạn việc đọc bằng alert — chỉ log, giống `readQuietly` nhưng cho ghi.
    func savePDFPage(collectionID: String, pageIndex: Int) {
        guard let database else { return }
        do {
            try PDFSourceRepository.updatePage(
                on: database, collectionID: collectionID, pageIndex: pageIndex, now: clock.now)
        } catch {
            DebugTrace.event("error", "pdf:savePage", ["error": String(describing: error)])
        }
    }

    // MARK: — Phân tích trang đang đọc (T4)

    /// Bấm "Phân tích trang này" trong `PDFReaderView`. `PDFPageText` quyết
    /// định lớp chữ dùng được hay phải rơi về OCR — người dùng không tự chọn,
    /// không thấy khác biệt ngoài dòng tiến độ. Cả hai nhánh set
    /// `analysisTargetCollectionID` + `origin = .pdf` rồi bật
    /// `shell.pendingPDFAnalysis`; `RootView` tiêu thụ cờ đó (kiểm
    /// `activeAgentReady` trước, giống `openCapture`) rồi mở sheet phân tích
    /// dùng CHUNG với lối ảnh (`AnalysisView.task` đọc `capture.hasPendingPage`).
    ///
    /// `PDFPage` không phải kiểu `Sendable` (PDFKit) nên chạy thẳng trên
    /// MainActor thay vì tách `Task` nền — trích chữ MỘT trang là việc nhẹ,
    /// khác hẳn OCR/gọi mạng (những chỗ thật sự cần async).
    func preparePDFAnalysis(page: PDFPage, collectionID: String) {
        capture.lastCapturedImage = nil
        capture.pdfText = nil
        capture.analysisResult = nil
        capture.analysisFailure = nil
        capture.origin = .pdf
        capture.analysisTargetCollectionID = collectionID

        switch PDFPageText.extract(page: page) {
        case let .text(text):
            capture.pdfText = PDFTextPage(
                text: text, sourceHash: ImageHasher.hash(of: Data(text.utf8)))
        case .needsOCR:
            guard let image = Self.renderPageAsImage(page) else {
                // Cực hiếm (JPEG encode hỏng) — không có gì để phân tích, báo
                // lỗi thẳng thay vì mở sheet rỗng.
                alertMessage = "Không đọc được trang này. Thử trang khác."
                return
            }
            capture.lastCapturedImage = image
        }
        shell.pendingPDFAnalysis = true
    }

    /// Vẽ trang thành ảnh cho OCR — cạnh dài ~2800px (≈300 DPI). KHÔNG qua
    /// `ImageCompressor`: mức nén 1600px của nó đặt ra cho thời ảnh còn phải
    /// upload; giờ OCR chạy trên máy, chỉ text đi ra ngoài.
    private static func renderPageAsImage(_ page: PDFPage) -> CapturedImage? {
        let targetLongEdge: CGFloat = 2800
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = targetLongEdge / max(bounds.width, bounds.height)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let image = page.thumbnail(of: size, for: .mediaBox)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        return CapturedImage(imageData: data)
    }
}
