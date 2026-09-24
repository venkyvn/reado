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
