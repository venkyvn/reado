import CoreGraphics
import CoreText
import XCTest

/// Dựng PDF nhiều trang bằng CoreText trực tiếp lên `CGContext` — cross-
/// platform (không UIKit/AppKit), vẽ TEXT THẬT (không phải ảnh) nên trang có
/// lớp chữ để `PDFPageText`/`PDFNavigation` đọc được trong test. Chạy cả lane
/// `kit` (macOS) và `ReadoKitTests` (iOS). KHÔNG dùng sách thật (bản quyền).
enum PDFTestSupport {
    static func makeTestPDF(pages: [[(text: String, origin: CGPoint)]]) throws -> Data {
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
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        for page in pages {
            context.beginPDFPage(nil)
            for (text, origin) in page {
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
        }
        context.closePDF()
        return data as Data
    }

    static func makeTestPDF(lines: [(text: String, origin: CGPoint)]) throws -> Data {
        try makeTestPDF(pages: [lines])
    }
}
