import CoreGraphics
import CoreText
import PDFKit
import ReadoKit
import XCTest

/// pdf-reader-r1 T2 (FR-23/ADR-058) — `PDFPageText`: dựng text bằng hình học
/// (hàm thuần, `Line` dựng tay — không cần PDFKit) + chấm chất lượng + một
/// test end-to-end dựng PDF thật bằng CoreText (cross-platform, không
/// UIKit/AppKit — file này chạy cả lane `kit` macOS và `ReadoKitTests` iOS).
final class PDFPageTextTests: XCTestCase {

    // MARK: — assembleText (hàm thuần)

    func testTwoParagraphsSeparatedByBigGapGetDoubleNewline() {
        // 3 hàng cách nhau 1pt (cùng đoạn) rồi một hàng cách 36pt (đoạn mới) —
        // khoảng trung vị của [1, 1, 36] là 1, 36 > 1.5×1 nên ngắt đoạn.
        let lines = [
            PDFPageText.Line(text: "Opening line one", minX: 50, maxX: 300, minY: 786, maxY: 800),
            PDFPageText.Line(
                text: "line two continued", minX: 50, maxX: 280, minY: 771, maxY: 785),
            PDFPageText.Line(text: "line three end.", minX: 50, maxX: 260, minY: 756, maxY: 770),
            PDFPageText.Line(
                text: "New paragraph starts.", minX: 50, maxX: 260, minY: 706, maxY: 720),
        ]
        XCTAssertEqual(
            PDFPageText.assembleText(lines: lines),
            "Opening line one line two continued line three end.\n\nNew paragraph starts.")
    }

    func testIndentedLineStartsNewParagraphEvenWithSmallGap() {
        // Gap nhỏ (2pt, dưới ngưỡng 1.5× trung vị) nhưng hàng 2 thụt vào 20pt
        // (> 0.3×height=4.2) — vẫn phải ngắt đoạn vì thụt đầu dòng.
        let lines = [
            PDFPageText.Line(text: "First paragraph.", minX: 50, maxX: 300, minY: 786, maxY: 800),
            PDFPageText.Line(text: "Indented second.", minX: 70, maxX: 300, minY: 770, maxY: 784),
        ]
        XCTAssertEqual(
            PDFPageText.assembleText(lines: lines),
            "First paragraph.\n\nIndented second.")
    }

    func testTwoColumnsReadLeftColumnFullyBeforeRight() {
        // Khe trống giữa 2 cột (200→350, 150pt) > 8% tổng chiều rộng (450×0.08=36)
        // → tách cột, đọc hết cột trái (trên→dưới) rồi mới sang cột phải.
        let lines = [
            PDFPageText.Line(text: "Right top", minX: 350, maxX: 500, minY: 786, maxY: 800),
            PDFPageText.Line(text: "Left top", minX: 50, maxX: 200, minY: 786, maxY: 800),
            PDFPageText.Line(text: "right bottom", minX: 350, maxX: 500, minY: 771, maxY: 785),
            PDFPageText.Line(text: "left bottom", minX: 50, maxX: 200, minY: 771, maxY: 785),
        ]
        XCTAssertEqual(
            PDFPageText.assembleText(lines: lines),
            "Left top left bottom\n\nRight top right bottom")
    }

    func testHyphenatedLineBreakIsJoinedIntoOneWord() {
        // Lỗi dàn trang (gạch nối cuối hàng) — NGOẠI LỆ duy nhất cho luật giữ
        // nguyên chữ: "remark-" + "able" → "remarkable", không phải 2 từ.
        let lines = [
            PDFPageText.Line(text: "This word is remark-", minX: 50, maxX: 300, minY: 786, maxY: 800),
            PDFPageText.Line(text: "able indeed.", minX: 50, maxX: 200, minY: 771, maxY: 785),
        ]
        XCTAssertEqual(
            PDFPageText.assembleText(lines: lines),
            "This word is remarkable indeed.")
    }

    func testLigatureIsExpandedToPlainLetters() {
        let lines = [
            PDFPageText.Line(text: "a \u{FB02}ower \u{FB01}eld", minX: 0, maxX: 100, minY: 0, maxY: 10),
        ]
        XCTAssertEqual(PDFPageText.assembleText(lines: lines), "a flower field")
    }

    // MARK: — quality (hàm thuần)

    func testQualityAcceptsCleanEnglishText() {
        let text = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 2)
        XCTAssertNil(PDFPageText.quality(of: text))
    }

    func testQualityRejectsTooShortText() {
        XCTAssertEqual(PDFPageText.quality(of: "Too short"), .tooShort)
    }

    func testQualityRejectsCidArtifacts() {
        let text = String(repeating: "x", count: 50) + "(cid:72)(cid:73)"
        XCTAssertEqual(PDFPageText.quality(of: text), .corruptCharacters)
    }

    func testQualityRejectsReplacementCharacter() {
        let text = String(repeating: "a", count: 50) + "\u{FFFD}\u{FFFD}"
        XCTAssertEqual(PDFPageText.quality(of: text), .corruptCharacters)
    }

    func testQualityRejectsLowLetterRatio() {
        // Nhiều ký tự ngoài bảng chữ/khoảng trắng/dấu câu cho phép (□) — mô
        // phỏng font lỗi bảng mã vẽ ra ô trống thay chữ.
        let text = String(repeating: "□", count: 60) + "ok"
        XCTAssertEqual(PDFPageText.quality(of: text), .lowLetterRatio)
    }

    func testQualityRejectsLowEnglishWordRatio() {
        // Toàn phụ âm, không nguyên âm nào — không token nào "trông như từ".
        let text = String(repeating: "Xqzpf Brgkt Vwnst Drmgl TrpklZnvbx ", count: 2)
        XCTAssertEqual(PDFPageText.quality(of: text), .lowWordRatio)
    }

    // MARK: — extract(page:) end-to-end (PDF thật dựng bằng CoreText)

    func testExtractReadsRealPDFPage() throws {
        let data = try Self.makeTestPDF(lines: [
            ("The quick brown fox jumps over the lazy dog near the riverbank.", CGPoint(x: 50, y: 700)),
        ])
        let document = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(document.page(at: 0))
        guard case let .text(text) = PDFPageText.extract(page: page) else {
            return XCTFail("Trang có chữ thật phải extract ra .text")
        }
        XCTAssertTrue(
            text.contains("quick brown fox"),
            "Text trích ra phải chứa nội dung đã vẽ — nhận: \(text)")
    }

    func testExtractReturnsNeedsOCRForBlankPage() throws {
        let data = try Self.makeTestPDF(lines: [])
        let document = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(PDFPageText.extract(page: page), .needsOCR(.empty))
    }

    /// Dựng một PDF 1 trang bằng CoreText trực tiếp lên `CGContext` — cross-
    /// platform (không UIKit/AppKit), vẽ TEXT THẬT (không phải ảnh) nên trang
    /// có lớp chữ để `PDFPageText` đọc. KHÔNG dùng sách thật (bản quyền).
    private static func makeTestPDF(lines: [(text: String, origin: CGPoint)]) throws -> Data {
        guard let data = CFDataCreateMutable(nil, 0) else {
            throw XCTSkip("Không tạo được CFMutableData")
        }
        guard let consumer = CGDataConsumer(data: data) else {
            throw XCTSkip("Không tạo được CGDataConsumer")
        }
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw XCTSkip("Không tạo được CGContext PDF")
        }
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        for (text, origin) in lines {
            guard let attributed = CFAttributedStringCreate(
                nil, text as CFString, [kCTFontAttributeName: font] as CFDictionary)
            else {
                throw XCTSkip("Không tạo được CFAttributedString")
            }
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = origin
            CTLineDraw(line, context)
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
