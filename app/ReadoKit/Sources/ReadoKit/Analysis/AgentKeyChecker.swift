import Foundation

/// Kiểm tra API key bằng `GET {base}/models`. Không gửi ảnh, không log key.
public enum AgentKeyChecker {
    public enum Verdict: Equatable, Sendable {
        case valid
        case invalid(String)
    }

    public static func check(
        baseURL: String,
        apiKey: String,
        session: URLSession = .shared
    ) async -> Verdict {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = AgentURLRule.storedBase(baseURL)
        guard !key.isEmpty else { return .invalid("Thiếu API key") }
        guard AgentURLRule.allows(base), let url = URL(string: "\(base)/models") else {
            return .invalid("Base URL không hợp lệ")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            return .invalid("Không kết nối được để kiểm tra key")
        }
        guard let http = response as? HTTPURLResponse else {
            return .invalid("Không kiểm tra được key")
        }
        if (200..<300).contains(http.statusCode) { return .valid }
        if http.statusCode == 401 || http.statusCode == 403 {
            return .invalid("Key không được chấp nhận")
        }
        return .invalid("Không kiểm tra được key (HTTP \(http.statusCode))")
    }
}
