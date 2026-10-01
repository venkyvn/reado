import Foundation

/// Đổi status HTTP / `URLError` của agent OpenAI-compatible thành `AnalysisError`
/// có thông điệp tiếng Việt. Tách từ `OpenAICompatClient` (refactor-r2): hàm
/// thuần, logic giữ nguyên.
enum OpenAICompatErrorMapper {
    static func http(status: Int, data: Data) -> AnalysisError {
        let root = try? JSONSerialization.jsonObject(with: data)
        let errorObject = (root as? [String: Any])?["error"] as? [String: Any]
        let message = errorObject?["message"] as? String
        switch status {
        case 301, 302, 307, 308:
            // Đo thật: `https://api.ai-box.vn/chat/completions` (thiếu `/v1`)
            // trả 301 thay vì lỗi rõ ràng — chặn redirect (noRedirectDelegate)
            // để lộ đúng status này thay vì âm thầm follow sang GET.
            return .providerError("Base URL có vẻ sai — thường phải kết thúc bằng /v1")
        case 401:
            return .providerError(message ?? "Key bị từ chối — kiểm tra lại trong Cài đặt")
        case 403, 404:
            return .providerError(message ?? "Model hoặc endpoint không tồn tại — kiểm tra trong Cài đặt")
        case 429:
            return .rateLimited
        default:
            if let message { return .providerError(message) }
            let preview = String(decoding: data.prefix(200), as: UTF8.self)
            return .providerError(preview.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(preview)")
        }
    }

    static func url(_ error: URLError) -> AnalysisError {
        switch error.code {
        case .timedOut:
            return .networkError(
                "Agent phản hồi quá lâu — thử lại, hoặc đổi model nhanh hơn trong Cài đặt")
        case .cannotFindHost, .cannotConnectToHost, .notConnectedToInternet:
            let host = error.failingURL?.host.map { " (\($0))" } ?? ""
            return .networkError("Không kết nối được tới agent\(host)")
        default:
            return .networkError(error.localizedDescription)
        }
    }
}
