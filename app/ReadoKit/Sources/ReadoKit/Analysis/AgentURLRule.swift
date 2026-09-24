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

    /// Bỏ `/chat/completions` nếu user dán cả endpoint.
    public static func storedBase(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        let suffix = "/chat/completions"
        if value.lowercased().hasSuffix(suffix) {
            value.removeLast(suffix.count)
            while value.hasSuffix("/") { value.removeLast() }
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
