#if DEBUG
import UIKit

/// pdf-reader-r1 T3 — PDF demo cho `-ReadoScreen pdf-reader`: 2 trang, text tự
/// viết (KHÔNG phải sách thật — bản quyền), trang 2 có bố cục 2 cột để agent
/// chụp màn cũng thấy được đường "đọc hết cột trái rồi mới sang cột phải"
/// (T2 `PDFPageText`, dùng khi làm T4). Ghi vào thư mục tmp — không commit.
enum DebugPDFFixture {
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

    static func makeTwoPagePDF() -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            drawSingleColumn(page: 1, in: context.cgContext)
            context.beginPage()
            drawTwoColumn(page: 2, in: context.cgContext)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reado-pdf-fixture-\(UUID().uuidString).pdf")
        try? data.write(to: url)
        return url
    }

    private static func drawSingleColumn(page: Int, in cgContext: CGContext) {
        UIGraphicsPushContext(cgContext)
        defer { UIGraphicsPopContext() }
        let text = """
        Reado PDF demo fixture — page \(page).

        This is NOT a real book. It exists only so the DebugLaunch screen \
        "-ReadoScreen pdf-reader" can open a reader without the owner manually \
        picking a file in the Files app on the simulator.

        The quick brown fox jumps over the lazy dog near the old lighthouse by \
        the river, watching the winter storm roll in across the bay.
        """
        draw(text, in: CGRect(x: 50, y: 60, width: 512, height: 672))
    }

    private static func drawTwoColumn(page: Int, in cgContext: CGContext) {
        UIGraphicsPushContext(cgContext)
        defer { UIGraphicsPopContext() }
        let left = """
        Left column, page \(page). Reado demo fixture — two columns side by \
        side, separated by a visible gap, so the geometry-based column split \
        has something real to exercise during manual screenshots.
        """
        let right = """
        Right column, page \(page). Read the left column fully from top to \
        bottom first, then move to this one — the same rule a real two-column \
        PDF page would need.
        """
        draw(left, in: CGRect(x: 50, y: 60, width: 220, height: 672))
        draw(right, in: CGRect(x: 342, y: 60, width: 220, height: 672))
    }

    private static func draw(_ text: String, in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black,
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}
#endif
