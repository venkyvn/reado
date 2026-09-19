import Foundation
import ReadoKit

/// Kết quả bọc ảnh sau khi user chọn/chụp + crop/xoay (FR-01).
/// Lưu trong bộ nhớ tạm — ảnh không persist (NFR-04), chỉ sống đến khi submit.
public struct CapturedImage: Equatable, Sendable {
    public let imageData: Data
    public let mimeType: String

    /// Hash sha256 — SD mục 4.2: hash SAU crop/nén, dùng làm image_hash idempotency key.
    public var imageHash: String { ImageHasher.hash(of: imageData) }

    public init(imageData: Data, mimeType: String = "image/jpeg") {
        self.imageData = imageData
        self.mimeType = mimeType
    }
}