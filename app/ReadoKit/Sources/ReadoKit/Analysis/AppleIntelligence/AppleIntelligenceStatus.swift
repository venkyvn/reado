import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// apple-ai-r1 T3 (ADR-061).
public enum AppleIntelligenceStatus: Equatable, Sendable {
    case available
    case unavailable(Reason)

    public enum Reason: String, Equatable, Sendable {
        case osTooOld, deviceNotEligible, notEnabled, modelNotReady, vietnameseUnsupported
        /// R1 không dùng PCC (spike T1 2026-10-05: construct
        /// `PrivateCloudComputeLanguageModel` crash cứng — thiếu entitlement
        /// `com.apple.developer.private-cloud-compute`, cần fen bật trong Xcode).
        /// Giữ case cho R2 khi PCC được bật thật.
        case pccUnavailable
    }

    public var isAvailable: Bool { self == .available }

    /// Copy hiển thị ở Settings/lỗi phân tích (T7).
    public var reasonVI: String? {
        switch self {
        case .available: nil
        case .unavailable(.osTooOld): "Cần iOS 26 trở lên"
        case .unavailable(.deviceNotEligible): "Máy này không hỗ trợ Apple Intelligence"
        case .unavailable(.notEnabled): "Chưa bật Apple Intelligence trong Cài đặt iPhone"
        case .unavailable(.modelNotReady): "Model đang tải về — thử lại sau"
        case .unavailable(.vietnameseUnsupported): "Apple Intelligence chưa hỗ trợ tiếng Việt trên máy này"
        case .unavailable(.pccUnavailable): "Private Cloud Compute chưa sẵn sàng"
        }
    }
}

/// Cổng duy nhất mà code không mang `@available` gọi vào (AppModel,
/// AnalyzerFactory) — bên trong tự `#available`/`#if canImport`.
public enum AppleIntelligence {
    public static let ocrFixDefaultsKey = "ocrFixEnabled"

    /// Test/DebugLaunch ghi đè (giống `DebugTrace.documentsDirectoryOverride`).
    /// `nonisolated(unsafe)`: test set 1 lần trong setUp/tearDown, launch set 1
    /// lần lúc khởi động — không ghi đồng thời từ nhiều thread.
    public nonisolated(unsafe) static var statusOverride: AppleIntelligenceStatus?

    public static func status(needsVietnamese: Bool) -> AppleIntelligenceStatus {
        if let statusOverride { return statusOverride }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                if needsVietnamese, !model.supportsLocale(Locale(identifier: "vi_VN")) {
                    return .unavailable(.vietnameseUnsupported)
                }
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return .unavailable(.deviceNotEligible)
                case .appleIntelligenceNotEnabled: return .unavailable(.notEnabled)
                case .modelNotReady: return .unavailable(.modelNotReady)
                @unknown default: return .unavailable(.deviceNotEligible)
                }
            }
        }
        #endif
        return .unavailable(.osTooOld)
    }

    /// nil khi OS < 26 hoặc SDK không có framework.
    public static func liveOCRCorrector() -> OCRCorrector? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return FoundationModelsOCRCorrector() }
        #endif
        return nil
    }
}
