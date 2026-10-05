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
}
