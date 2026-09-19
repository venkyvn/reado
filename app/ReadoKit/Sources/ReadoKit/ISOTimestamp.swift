import Foundation

/// Timestamp TEXT ISO-8601 — LUÔN UTC, LUÔN hậu tố `Z` (db.md A.1; AGENTS mục 4).
/// Không lưu giờ địa phương, không để `datetime('now')` trần trong SQL.
/// Format cố định KHÔNG fractional giây — giữ cho chuỗi cùng độ dài, so sánh
/// lexicographic = so sánh thời gian (an toàn cho index/order).
public enum ISOTimestamp {
    /// `ISO8601FormatStyle` là struct Sendable — dùng được dưới Swift 6 strict
    /// concurrency (package tools 6.0); `ISO8601DateFormatter` không Sendable
    /// nên không thể giữ làm static let. Phải compose ĐỦ field: style khởi tạo
    /// trần không có year/month/day/time nên không parse được gì.
    private static let isoStyle = Date.ISO8601FormatStyle()
        .year().month().day()
        .time(includingFractionalSeconds: false)
        .timeZone(separator: .omitted)

    public static func string(from date: Date) -> String {
        isoStyle.format(date)
    }

    public static func date(from string: String) -> Date? {
        try? Date(string, strategy: isoStyle)
    }
}