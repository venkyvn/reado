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
    /// rồi tự `stopAccessingSecurityScopedResource()` ở `onDisappear`) và
    /// `pageIndex` đã lưu (kẹp về khoảng hợp lệ nếu trang đã lưu vượt quá số
    /// trang thật, ví dụ file bị thay bằng bản ngắn hơn).
    func openPDFDocument(
        collectionID: String
    ) -> Result<(document: PDFDocument, url: URL, pageIndex: Int), PDFOpenError> {
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

        guard url.startAccessingSecurityScopedResource() else {
            return .failure(.accessDenied)
        }
        guard let document = PDFDocument(url: url) else {
            url.stopAccessingSecurityScopedResource()
            return .failure(.unreadable)
        }
        if document.isLocked {
            url.stopAccessingSecurityScopedResource()
            return .failure(.locked)
        }
        let pageIndex = document.pageCount > 0
            ? min(max(source.pageIndex, 0), document.pageCount - 1)
            : 0
        return .success((document, url, pageIndex))
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
}
