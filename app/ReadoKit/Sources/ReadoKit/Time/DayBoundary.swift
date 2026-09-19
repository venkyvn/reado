import Foundation

/// tech-stack mục 10.3 — "Injectable clock": mọi phép "hôm nay" đi qua hàm
/// `(instant, timezone, day_cutoff_hour)`, không gọi `Date()` trần rải rác.
/// FR-11/FR-14 (nhắc ôn, streak) và hàng đợi ôn dùng chung cửa sổ này.
public enum DayBoundary {

    /// Cửa sổ "hôm nay" [start, end) theo timezone + giờ cắt ngày.
    /// Ví dụ cutoff 4h: 03:59 sáng vẫn thuộc ngày hôm qua.
    public struct DayWindow: Equatable, Sendable {
        /// ISO-8601 UTC hậu tố `Z` (db.md A.1).
        public let start: String
        /// start + 24h; so sánh lexicographic = so sánh thời gian.
        public let end: String
    }

    public static func window(
        now: Date,
        timezone: TimeZone,
        dayCutoffHour: Int = 4
    ) -> DayWindow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        let baseStart = calendar.startOfDay(for: now)
        let cutoffStart =
            calendar.date(
                byAdding: .hour, value: dayCutoffHour, to: baseStart)
            ?? baseStart

        let start: Date
        if now < cutoffStart {
            start =
                calendar.date(byAdding: .day, value: -1, to: cutoffStart)
                ?? cutoffStart
        } else {
            start = cutoffStart
        }
        let end =
            calendar.date(byAdding: .day, value: 1, to: start) ?? start

        return DayWindow(
            start: ISOTimestamp.string(from: start),
            end: ISOTimestamp.string(from: end))
    }
}