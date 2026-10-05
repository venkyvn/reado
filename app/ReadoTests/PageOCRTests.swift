import UIKit
import XCTest
import ReadoKit

/// T1: Vision OCR + reading order. Không mạng.
final class PageOCRTests: XCTestCase {

    func testReadingOrderTopThenBottom() {
        let items = [
            PageOCR.Observation(
                text: "HELLO",
                boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.4, height: 0.1)),
            PageOCR.Observation(
                text: "WORLD",
                boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.4, height: 0.1)),
        ]
        XCTAssertEqual(PageOCR.readingOrder(items), "HELLO\nWORLD")
    }

    func testReadingOrderSameLineLeftToRight() {
        let items = [
            PageOCR.Observation(
                text: "CAT",
                boundingBox: CGRect(x: 0.45, y: 0.5, width: 0.2, height: 0.1)),
            PageOCR.Observation(
                text: "THE",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.1)),
        ]
        XCTAssertEqual(PageOCR.readingOrder(items), "THE CAT")
    }

    func testReadingOrderTwoColumnsLeftThenRight() {
        let items = [
            PageOCR.Observation(
                text: "A",
                boundingBox: CGRect(x: 0.05, y: 0.7, width: 0.25, height: 0.1)),
            PageOCR.Observation(
                text: "B",
                boundingBox: CGRect(x: 0.05, y: 0.4, width: 0.25, height: 0.1)),
            PageOCR.Observation(
                text: "C",
                boundingBox: CGRect(x: 0.65, y: 0.7, width: 0.25, height: 0.1)),
            PageOCR.Observation(
                text: "D",
                boundingBox: CGRect(x: 0.65, y: 0.4, width: 0.25, height: 0.1)),
        ]
        XCTAssertEqual(PageOCR.readingOrder(items), "A\nB\n\nC\nD")
    }

    // MARK: - Ngắt đoạn trong một cột (ADR-037) — cột phải >= 3 hàng mới tính.

    /// Trục X cố định: minX=0.1, width=0.5 (maxX=0.6) trừ khi khác đi nói riêng.
    private func line(_ text: String, yTop: CGFloat, minX: CGFloat = 0.1, maxX: CGFloat = 0.6, height: CGFloat = 0.05) -> PageOCR.Observation {
        PageOCR.Observation(
            text: text,
            boundingBox: CGRect(x: minX, y: 1 - height - yTop, width: maxX - minX, height: height))
    }

    func testParagraphBreakByVerticalGap() {
        let items = [
            line("Line one of paragraph one", yTop: 0.10),
            line("continues here", yTop: 0.18),
            line("and ends this para", yTop: 0.26),
            // Khoảng cách gấp gần 2 lần (0.14 so với median 0.08) → đoạn mới.
            line("New paragraph starts", yTop: 0.40),
            line("and continues", yTop: 0.48),
        ]
        let result = PageOCR.detailedReadingOrder(items)
        XCTAssertEqual(result.lines.map(\.breakBefore), [false, false, false, true, false])
        XCTAssertEqual(result.lines[3].breakReason, "gap")
        XCTAssertEqual(
            result.text,
            "Line one of paragraph one\ncontinues here\nand ends this para\n\nNew paragraph starts\nand continues")
    }

    func testParagraphBreakByIndent() {
        let items = [
            line("First paragraph line one", yTop: 0.10),
            line("line two of first paragraph", yTop: 0.18),
            // Thụt vào so với lề trái, rồi hàng sau quay lại đúng lề → đầu đoạn mới.
            line("New paragraph indented start", yTop: 0.26, minX: 0.16, maxX: 0.66),
            line("continues normally", yTop: 0.34),
        ]
        let result = PageOCR.detailedReadingOrder(items)
        XCTAssertEqual(result.lines.map(\.breakBefore), [false, false, true, false])
        XCTAssertEqual(result.lines[2].breakReason, "indent")
    }

    func testParagraphBreakByShortEndingLine() {
        let items = [
            line("This is the first full line", yTop: 0.10),
            line("of the paragraph continuing", yTop: 0.18),
            // Hàng ngắn + kết câu → hàng SAU nó là đoạn mới.
            line("and it ends now.", yTop: 0.26, maxX: 0.30),
            line("A brand new paragraph begins", yTop: 0.34),
        ]
        let result = PageOCR.detailedReadingOrder(items)
        XCTAssertEqual(result.lines.map(\.breakBefore), [false, false, false, true])
        XCTAssertEqual(result.lines[3].breakReason, "shortEnding")
    }

    func testEvenlySpacedLinesDoNotBreak() {
        let items = [
            line("Line one of one long paragraph", yTop: 0.10),
            line("line two of the same paragraph", yTop: 0.18),
            line("line three still going strong", yTop: 0.26),
            line("and a fourth line here too", yTop: 0.34),
        ]
        let result = PageOCR.detailedReadingOrder(items)
        XCTAssertTrue(result.lines.allSatisfy { !$0.breakBefore })
        XCTAssertFalse(result.text.contains("\n\n"))
    }

    func testShortColumnNeverBreaks() {
        // Dưới 3 hàng — không đủ dữ liệu tính median/percentile, giữ nguyên `\n`.
        let items = [
            line("Heading", yTop: 0.10, maxX: 0.20),
            line("Very short caption line", yTop: 0.60),
        ]
        let result = PageOCR.detailedReadingOrder(items)
        XCTAssertTrue(result.lines.allSatisfy { !$0.breakBefore })
    }

    // MARK: - ocr-line-drop: lọc confidence tách riêng khỏi ghép hàng.

    func testPartitionByConfidenceKeepsHighDropsLow() {
        let high = PageOCR.Observation(
            text: "clear text", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.4, height: 0.1),
            confidence: 0.9)
        let low = PageOCR.Observation(
            text: "blurry text", boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.4, height: 0.1),
            confidence: 0.1)
        let (kept, dropped) = PageOCR.partitionByConfidence([high, low])
        XCTAssertEqual(kept, [high])
        XCTAssertEqual(dropped, [low])
    }

    // MARK: - ADR-042: engine documents — ghép đoạn có sẵn, không qua hình học.

    private func obs(_ text: String, y: CGFloat = 0.5) -> PageOCR.Observation {
        PageOCR.Observation(
            text: text, boundingBox: CGRect(x: 0.1, y: y, width: 0.8, height: 0.02))
    }

    func testJoinParagraphsSingleParagraphJoinsLinesWithNewline() {
        let result = PageOCR.joinParagraphs([[obs("line one", y: 0.9), obs("line two", y: 0.88)]])
        XCTAssertEqual(result.text, "line one\nline two")
        XCTAssertEqual(result.engine, "documents")
        XCTAssertEqual(result.lines.map(\.breakBefore), [false, false])
    }

    func testJoinParagraphsSeparatesParagraphsWithBlankLine() {
        let result = PageOCR.joinParagraphs([
            [obs("para one a"), obs("para one b")],
            [obs("para two")],
        ])
        XCTAssertEqual(result.text, "para one a\npara one b\n\npara two")
        XCTAssertEqual(result.lines.map(\.breakBefore), [false, false, true])
        XCTAssertEqual(result.lines.last?.breakReason, "document")
        XCTAssertEqual(result.observations.count, 3)
    }

    func testJoinParagraphsDropsEmptyParagraphsAndLines() {
        let result = PageOCR.joinParagraphs([
            [obs("  ")],
            [obs("real"), obs("")],
            [],
            [obs("second")],
        ])
        XCTAssertEqual(result.text, "real\n\nsecond")
    }

    func testJoinParagraphsYTopFollowsVisionOrigin() {
        // Box Vision origin dưới-trái: y=0.9,h=0.02 → mép trên cách đỉnh ảnh 0.08.
        let result = PageOCR.joinParagraphs([[obs("top", y: 0.9)]])
        XCTAssertEqual(result.lines[0].yTop, 0.08, accuracy: 0.0001)
    }

    // MARK: - mergeParagraphBoundaries (ocr-quality-r1 T3a, ADR-064)

    func testMergeParagraphBoundariesSplitsByWordCountProportion() {
        let documents = "one two three\n\nfour five"
        // 5 từ liveText, 2 đoạn (3 từ : 2 từ) — chia theo đúng tỉ lệ.
        let live = "ONE TWO THREE FOUR FIVE"
        let merged = PageOCR.mergeParagraphBoundaries(liveText: live, documents: documents)
        XCTAssertEqual(merged, "ONE TWO THREE\n\nFOUR FIVE")
    }

    func testMergeParagraphBoundariesHandlesWordCountMismatchOffByOne() {
        // documents 2+2=4 từ, liveText chỉ có 3 — đúng tình huống đo thật T2
        // (lệch ≤ 1 từ giữa hai engine trên cùng ảnh).
        let documents = "aa bb\n\ncc dd"
        let live = "AA BB CC"
        let merged = PageOCR.mergeParagraphBoundaries(liveText: live, documents: documents)
        // Đoạn cuối luôn nhận hết phần còn lại — không rớt từ.
        XCTAssertEqual(merged, "AA BB\n\nCC")
    }

    func testMergeParagraphBoundariesEmptyLiveTextFallsBackToDocuments() {
        let documents = "one two\n\nthree four"
        XCTAssertEqual(PageOCR.mergeParagraphBoundaries(liveText: "", documents: documents), documents)
    }

    func testMergeParagraphBoundariesEmptyDocumentsFallsBackToDocuments() {
        XCTAssertEqual(PageOCR.mergeParagraphBoundaries(liveText: "one two", documents: ""), "")
    }

    func testMergeParagraphBoundariesSingleParagraphKeepsAllWords() {
        let documents = "a b c"
        let merged = PageOCR.mergeParagraphBoundaries(liveText: "X Y Z", documents: documents)
        XCTAssertEqual(merged, "X Y Z")
    }

    /// code-review (sau T3a): làm tròn ĐỘC LẬP từng đoạn (bản cũ) dồn sai số
    /// vào cuối trang — trên trang nhiều đoạn NGẮN (hội thoại, giống
    /// courage-p12 thật: 14 đoạn, nhiều đoạn <5 từ) có thể làm rỗng một đoạn
    /// giữa trang dù tổng số từ khớp. Biên tích luỹ phải giữ đủ 10 đoạn.
    func testMergeParagraphBoundariesManyShortParagraphsNoDrift() {
        let documents = (1...10).map { "w\($0)" }.joined(separator: "\n\n")
        let live = (1...10).map { "W\($0)" }.joined(separator: " ")
        let merged = PageOCR.mergeParagraphBoundaries(liveText: live, documents: documents)
        XCTAssertEqual(merged.components(separatedBy: "\n\n").count, 10)
        XCTAssertEqual(merged, (1...10).map { "W\($0)" }.joined(separator: "\n\n"))
    }

    /// `liveText` ít từ hơn SỐ ĐOẠN — không đủ để mỗi đoạn có cơ hội nhận ≥1
    /// từ, trả nguyên `documents` thay vì làm rỗng một đoạn bất kỳ.
    func testMergeParagraphBoundariesFewerLiveWordsThanParagraphsFallsBack() {
        let documents = (1...10).map { "w\($0)" }.joined(separator: "\n\n")
        let live = "only nine words here yes really still not enough" // 9 từ, 10 đoạn
        let merged = PageOCR.mergeParagraphBoundaries(liveText: live, documents: documents)
        XCTAssertEqual(merged, documents)
    }

    func testGarbageBytesYieldEmpty() async throws {
        let text = try await PageOCR.recognize(imageData: Data([0x00, 0x01, 0x02]))
        XCTAssertEqual(text, "")
    }

    func testBlackImageYieldsEmpty() async throws {
        let text = try await PageOCR.recognize(imageData: solidPNG(UIColor.black))
        XCTAssertEqual(text, "")
    }

    func testPrintedEnglishIsNonEmpty() async throws {
        let data = pngLines(["HELLO"])
        let text = try await PageOCR.recognize(imageData: data)
        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(
            text.uppercased().contains("HELLO"),
            "OCR mong HELLO, nhận \(text)")
    }

    func testPrintedTwoLinesTopThenBottom() async throws {
        let data = pngLines(["ALPHA", "BRAVO"])
        let text = try await PageOCR.recognize(imageData: data)
        let upper = text.uppercased()
        let alpha = upper.range(of: "ALPHA")
        let bravo = upper.range(of: "BRAVO")
        XCTAssertNotNil(alpha, "OCR mong ALPHA, nhận \(text)")
        XCTAssertNotNil(bravo, "OCR mong BRAVO, nhận \(text)")
        if let alpha, let bravo {
            XCTAssertLessThan(
                alpha.lowerBound, bravo.lowerBound,
                "ALPHA phải đứng trước BRAVO, nhận \(text)")
        }
    }

    private func solidPNG(_ color: UIColor, size: CGSize = CGSize(width: 64, height: 64)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }.pngData()!
    }

    private func pngLines(_ lines: [String]) -> Data {
        let size = CGSize(width: 720, height: CGFloat(80 + lines.count * 90))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 64, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            for (index, line) in lines.enumerated() {
                line.draw(
                    at: CGPoint(x: 48, y: 36 + CGFloat(index) * 90),
                    withAttributes: attrs)
            }
        }
        return image.pngData()!
    }
}
