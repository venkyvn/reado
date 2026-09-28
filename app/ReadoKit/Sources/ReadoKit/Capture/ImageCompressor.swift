import Foundation

// UIKit-only: bọc để package build/test được trên macOS (`scripts/test.sh kit`).
#if canImport(UIKit)
import UIKit

/// FR-01: Nén ảnh JPEG — cạnh dài ≤ 1600px, quality 0.80.
/// Gọi SAU crop/xoay, TRƯỚC khi hash (ImageHasher) và tạo CapturedImage.
/// NFR-04: ảnh chỉ sống tạm trong memory, không persist.
public enum ImageCompressor {
    /// Cạnh dài tối đa (pixel) — SD mục 8: ảnh nhỏ hơn giúp NFR-01/NFR-02 tốt hơn.
    static let maxEdge: CGFloat = 1600

    /// JPEG quality — journal 18-09: q0.80.
    static let jpegQuality: CGFloat = 0.80

    /// Nén UIImage → Data JPEG, resize nếu cạnh dài > 1600px.
    /// Trả về nil nếu image không encode được.
    public static func compress(_ image: UIImage) -> Data? {
        let resized = resizeIfNeeded(image)
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    /// Resize ảnh nếu cạnh dài vượt maxEdge, giữ nguyên tỷ lệ.
    private static func resizeIfNeeded(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let longest = max(w, h)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let newW = Int(w * scale)
        let newH = Int(h * scale)
        // scale = 1: mặc định của renderer là scale màn hình (@3x) nên "1600px"
        // từng ra ~4800px và FR-01 không được áp (ocr-line-drop).
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: newW, height: newH), format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: newW, height: newH))
        }
    }
}
#endif
