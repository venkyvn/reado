import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// apple-ai-r1 T6 (ADR-063) — map lỗi FoundationModels sang `AnalysisError`
/// chung (cùng kiểu UI đang xử lý cho BYOK). Xét họ lỗi iOS 27
/// (`LanguageModelError`) TRƯỚC — các case tương ứng ở `GenerationError` (iOS
/// 26) đã deprecated từ 27 nhưng máy chạy iOS 26 vẫn ném được, nên vẫn phải bắt.
public enum AppleIntelligenceErrorMapper {
    public static func map(_ error: Error) -> AnalysisError {
        if let analysisError = error as? AnalysisError {
            return analysisError
        }
        if error is TimeoutError {
            return .networkError("Apple Intelligence phản hồi quá lâu")
        }

        #if canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *), let modelError = error as? LanguageModelError {
            switch modelError {
            case .contextSizeExceeded:
                return .providerError("Trang quá dài cho Apple Intelligence — thử agent khác cho trang này")
            case .guardrailViolation, .refusal:
                return .providerError("Apple Intelligence từ chối xử lý trang này — thử agent khác")
            case .unsupportedLanguageOrLocale:
                return .providerError("Apple Intelligence chưa hỗ trợ tiếng Việt trên máy này")
            case .rateLimited:
                return .providerError("Hết lượt Apple Intelligence lúc này — thử lại sau hoặc chọn agent khác")
            case .timeout:
                return .networkError("Apple Intelligence phản hồi quá lâu")
            case .unsupportedCapability, .unsupportedTranscriptContent, .unsupportedGenerationGuide:
                return .providerError("Apple Intelligence không hỗ trợ yêu cầu này trên máy — thử agent khác")
            @unknown default:
                break
            }
        }
        if #available(iOS 26.0, macOS 26.0, *), let genError = error as? LanguageModelSession.GenerationError {
            switch genError {
            case .exceededContextWindowSize:
                return .providerError("Trang quá dài cho Apple Intelligence — thử agent khác cho trang này")
            case .guardrailViolation, .refusal:
                return .providerError("Apple Intelligence từ chối xử lý trang này — thử agent khác")
            case .unsupportedLanguageOrLocale:
                return .providerError("Apple Intelligence chưa hỗ trợ tiếng Việt trên máy này")
            case .rateLimited:
                return .providerError("Hết lượt Apple Intelligence lúc này — thử lại sau hoặc chọn agent khác")
            case .assetsUnavailable:
                return .providerError("Model đang tải về — thử lại sau")
            case .unsupportedGuide, .decodingFailure, .concurrentRequests:
                return .providerError("Apple Intelligence không hỗ trợ yêu cầu này trên máy — thử agent khác")
            @unknown default:
                break
            }
        }
        #endif

        return .providerError((error as? LocalizedError)?.errorDescription ?? String(describing: error))
    }
}
