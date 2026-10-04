import PDFKit
import ReadoKit

/// FR-23/ADR-059 (pdf-nav-r1) — điều khiển `PDFView` từ bên ngoài (slider/
/// ◀▶/gõ số trang/Mục lục). Dùng một object điều khiển thay vì binding "trang
/// yêu cầu" để tránh vòng lặp `.PDFViewPageChanged` → `@State` → `go(to:)` →
/// notification lại. `PDFView` không `Sendable` — giữ `weak` để không ngáng
/// deinit, chạy thẳng trên MainActor.
@MainActor
final class PDFReaderNavigator {
    weak var pdfView: PDFView?

    func go(to index: Int) {
        guard let pdfView, let document = pdfView.document else { return }
        let clamped = PDFNavigation.clamp(index, pageCount: document.pageCount)
        guard let page = document.page(at: clamped) else { return }
        pdfView.go(to: page)
    }
}
