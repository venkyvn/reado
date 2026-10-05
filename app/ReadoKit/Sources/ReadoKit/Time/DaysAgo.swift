import Foundation

/// Nhãn "N ngày trước" cho ngữ cảnh gặp lại (engagement-r1 T3/T4). Hàm thuần — số ngày tính ở
/// `DayBoundary.daysBetween` (ngày học FR-11).
public enum DaysAgo {
    public static func text(_ days: Int) -> String {
        switch days {
        case ..<1: "hôm nay"
        case 1: "hôm qua"
        default: "\(days) ngày trước"
        }
    }

    /// Từ đã lưu từ mấy ngày thì mặt sau thẻ mới hiện "Gặp lần đầu" (từ mới lưu thì dòng này vô nghĩa).
    public static let firstSeenMinDays = 7

    /// "Gặp lần đầu N ngày trước" — nil khi chưa biết số ngày hoặc từ còn mới (< `firstSeenMinDays`).
    public static func firstSeenLabel(days: Int?) -> String? {
        guard let days, days >= firstSeenMinDays else { return nil }
        return "Gặp lần đầu \(days) ngày trước"
    }
}
