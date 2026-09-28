import ImageIO
import ReadoKit
import UIKit
import XCTest

/// FR-01: nén cạnh dài ≤ 1600px THẬT (pixel, không phải point).
final class ImageCompressorTests: XCTestCase {
    private func solidImage(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func pixelSize(of jpeg: Data) throws -> (w: Int, h: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let props = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (props[kCGImagePropertyPixelWidth] as? Int ?? 0,
                props[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    func testLargeImageIsResizedToLongEdge1600Pixels() throws {
        let data = try XCTUnwrap(ImageCompressor.compress(solidImage(width: 4000, height: 3000)))
        let size = try pixelSize(of: data)
        XCTAssertEqual(size.w, 1600)
        XCTAssertEqual(size.h, 1200)
    }

    func testSmallImageKeepsPixelSize() throws {
        let data = try XCTUnwrap(ImageCompressor.compress(solidImage(width: 800, height: 600)))
        let size = try pixelSize(of: data)
        XCTAssertEqual(size.w, 800)
        XCTAssertEqual(size.h, 600)
    }
}
