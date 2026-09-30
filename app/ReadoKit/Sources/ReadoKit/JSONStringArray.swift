import Foundation

/// Mảng chuỗi lưu dạng JSON trong cột TEXT (`home_pin_ids`, `review_priority_ids`).
/// Trước đây `HomePinService`, `ReviewScopeService` và `Migration` mỗi nơi tự
/// mã hoá/giải mã; gom một chỗ để cùng một quy ước (mã hoá lỗi → "[]").
enum JSONStringArray {
    static func decode(_ json: String) -> [String]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    static func encode(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
