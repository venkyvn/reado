import Foundation
import CryptoKit

/// Mã xác thực khoá idempotency cho FR-02 (SD mục 4.2): hash của ảnh
/// SAU crop/nén. Cùng ảnh, cùng pipeline → cùng hash → không gọi lại.
public enum ImageHasher {
    /// Hex sha256 của bytes ảnh đã nén — khớp header `X-Reado-Image-Hash`.
    public static func hash(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}