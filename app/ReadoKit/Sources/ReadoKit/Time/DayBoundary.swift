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

    /// Số NGÀY HỌC (FR-11) từ `earlier` tới `later` — cùng ngày học = 0; `later` < `earlier` → 0.
    public static func daysBetween(
        _ earlier: Date, _ later: Date, timezone: TimeZone, dayCutoffHour: Int = 4
    ) -> Int {
        guard later > earlier,
              let from = ISOTimestamp.date(
                from: window(now: earlier, timezone: timezone, dayCutoffHour: dayCutoffHour).start),
              let to = ISOTimestamp.date(
                from: window(now: later, timezone: timezone, dayCutoffHour: dayCutoffHour).start)
        else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    /// Đầu cửa sổ ngày học (ISO) của **thứ Hai** tuần chứa ngày học hiện tại — mốc "tuần" của thẻ
    /// "Tuần qua" (engagement-r1 T8). Thứ Hai 03:30 sáng (trước giờ chuyển ngày) vẫn thuộc Chủ nhật,
    /// tức tuần trước (FR-11).
    public static func weekStart(
        now: Date, timezone: TimeZone, dayCutoffHour: Int = 4
    ) -> String {
        let dayStartIso = window(now: now, timezone: timezone, dayCutoffHour: dayCutoffHour).start
        guard let dayStart = ISOTimestamp.date(from: dayStartIso) else { return dayStartIso }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        // `dayStart` rơi đúng giờ chuyển ngày của ngày học → `weekday` là thứ của ngày học (1 = CN … 7 = T7).
        let weekday = calendar.component(.weekday, from: dayStart)
        let daysBack = (weekday + 5) % 7  // T2 → 0, T3 → 1, …, CN → 6
        let monday = calendar.date(byAdding: .day, value: -daysBack, to: dayStart) ?? dayStart
        return window(now: monday, timezone: timezone, dayCutoffHour: dayCutoffHour).start
    }
}