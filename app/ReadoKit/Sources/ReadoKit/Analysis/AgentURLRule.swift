import Foundation

/// `base_url` của agent user: HTTPS, hoặc HTTP chỉ cho loopback / LAN (db.md A.2.2).
public enum AgentURLRule {
    public static func allows(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(),
              !host.isEmpty
        else { return false }
        if scheme == "https" { return true }
        if scheme == "http" {
            if host == "localhost" || host == "127.0.0.1" { return true }
            return isPrivateLAN(host)
        }
        return false
    }

    /// Bỏ `/chat/completions` nếu user dán cả endpoint. AI-Box (`api.ai-box.vn`)
    /// dán thiếu `/v1` thì server trả 301 thay vì lỗi rõ ràng (đo thật
    /// 2026-09-26) — tự thêm `/v1` cho đúng host này khi path đang rỗng; host
    /// khác giữ nguyên, không đoán.
    public static func storedBase(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        let suffix = "/chat/completions"
        if value.lowercased().hasSuffix(suffix) {
            value.removeLast(suffix.count)
            while value.hasSuffix("/") { value.removeLast() }
        }
        if let url = URL(string: value),
           url.host?.lowercased() == "api.ai-box.vn",
           url.path.isEmpty
        {
            value += "/v1"
        }
        return value
    }

    private static func isPrivateLAN(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        if parts[0] == 10 { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        return false
    }
}
