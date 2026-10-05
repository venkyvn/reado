import Foundation

/// J-R1-P — lịch streak (lens của FR-14, phục vụ M-02). KHÔNG metric mới: một ô
/// = một "ngày học" theo giờ chuyển ngày FR-11, màu = số thẻ ôn hôm đó đếm từ
/// `review_logs` (review.md mục 6.1: không dựng cột counter), số trang chụp đếm
/// từ `reading_sessions`. Không share, không so sánh, không leaderboard (NG-04).
public struct StreakDay: Equatable, Sendable, Identifiable {
    /// Key duy nhất = ISO-8601 `Z` của ĐẦU cửa sổ ngày (giờ chuyển ngày FR-11).
    /// Độ dài cố định → so sánh lexicographic = so sánh thời gian.
    public let dayStartISO: String
    /// Thời điểm đại diện (đầu cửa sổ) — chỉ để UI hiển thị ngày.
    public let date: Date
    /// Số thẻ ôn trong ngày (mọi rating, mọi mode — kể cả log `cram` cũ từ R1
    /// trước extra-review-r1).
    public let reviewCount: Int
    /// Số trang đã chụp/phân tích trong ngày (reading_sessions; 0 cho kho tạm —
    /// Q-10/ADR-029 kho tạm không lưu phiên).
    public let pageCount: Int

    public var id: String { dayStartISO }

    public init(
        dayStartISO: String,
        date: Date,
        reviewCount: Int,
        pageCount: Int
    ) {
        self.dayStartISO = dayStartISO
        self.date = date
        self.reviewCount = reviewCount
        self.pageCount = pageCount
    }
}

/// 18 tuần (7 hàng × 18 cột) — vừa khít bề ngang phone, không scroll ngang.
/// `nil` = ô TƯƠNG LAI (sau hôm nay) — UI tô xám, không chọn được. Cột 0 = cũ nhất.
public struct StreakHeatmap: Equatable, Sendable {
    public let currentStreak: Int
    public let longestStreak: Int
    /// `weeks[col][row]`, col 0…17 (cũ → mới), row 0…6 (thứ Hai → Chủ Nhật).
    public let weeks: [[StreakDay?]]

    public init(
        currentStreak: Int,
        longestStreak: Int,
        weeks: [[StreakDay?]]
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.weeks = weeks
    }
}

/// B4 extra-review-r1 (owner chốt 2026-10-01): màu heatmap chia theo TỨ PHÂN VỊ
/// số thẻ của chính user (kiểu GitHub) thay vì mốc cố định — ngày ôn nhiều hẳn
/// mới thật sự đậm, không bão hoà ở 7 thẻ như thang cũ. Hàm thuần — test không
/// cần DB.
public enum StreakIntensity {
    /// Dưới ngần này ngày CÓ ôn trong lưới → chưa đủ dữ liệu chia phân vị có
    /// nghĩa (vài mốc trùng nhau) — dùng mốc cố định cũ (1 / 2 / 3–4 / 5–6 / 7+).
    public static let minDaysForPercentile = 4
    private static let fixedThresholds = [1, 2, 4, 6]

    /// 4 ngưỡng tăng dần (p25/p50/p75/max) từ số thẻ các ngày CÓ ôn (> 0).
    /// `level(count:thresholds:)` dùng ngưỡng này: mức 1 nếu `count` ≤ ngưỡng
    /// đầu, … mức 5 nếu vượt ngưỡng cuối.
    public static func thresholds(from counts: [Int]) -> [Int] {
        let sorted = counts.filter { $0 > 0 }.sorted()
        guard sorted.count >= minDaysForPercentile else { return fixedThresholds }
        func quantile(_ q: Double) -> Int {
            let idx = min(
                sorted.count - 1,
                max(0, Int((Double(sorted.count) * q).rounded(.up)) - 1))
            return sorted[idx]
        }
        let t1 = quantile(0.25)
        let t2 = max(t1 + 1, quantile(0.5))
        let t3 = max(t2 + 1, quantile(0.75))
        let t4 = max(t3 + 1, sorted.last ?? t3)
        return [t1, t2, t3, t4]
    }

    /// Mức 1…5 theo 4 ngưỡng tăng dần — 0 nếu `count` = 0 (ngày không ôn, UI tô
    /// xám riêng, không gọi hàm này).
    public static func level(count: Int, thresholds: [Int]) -> Int {
        guard count > 0 else { return 0 }
        for (index, threshold) in thresholds.enumerated() where count <= threshold {
            return index + 1
        }
        return thresholds.count + 1
    }
}

public enum StreakCalendarService {
    public static let weekCount = 18
    public static let daysPerWeek = 7

    // MARK: — Streak (chia sẻ với DailyProgressService)

    /// Tập đầu-cửa-sổ ngày có ≥1 review log — dùng chung cho streak của FR-14.
    public static func reviewedDayStarts(
        on db: SQLiteDatabase, timezone: TimeZone, cutoffHour: Int
    ) throws -> Set<String> {
        Set(
            try db.rows("SELECT reviewed_at FROM review_logs;")
                .compactMap { row -> String? in
                    guard let iso = row.first?.textValue,
                          let date = ISOTimestamp.date(from: iso) else {
                        return nil
                    }
                    return DayBoundary.window(
                        now: date, timezone: timezone, dayCutoffHour: cutoffHour).start
                })
    }

    /// Ngày ôn LIÊN TỤC tính từ hôm nay (hôm nay chưa ôn thì tính từ hôm qua —
    /// streak chưa đứt) theo giờ chuyển ngày FR-11.
    public static func currentStreak(
        from dayStarts: Set<String>,
        now: Date,
        timezone: TimeZone,
        cutoffHour: Int
    ) -> Int {
        var cursor = DayBoundary.window(
            now: now, timezone: timezone, dayCutoffHour: cutoffHour).start
        if !dayStarts.contains(cursor) {
            cursor = previousWindowStart(cursor, timezone: timezone, cutoffHour: cutoffHour)
        }
        var streak = 0
        while dayStarts.contains(cursor) {
            streak += 1
            cursor = previousWindowStart(cursor, timezone: timezone, cutoffHour: cutoffHour)
        }
        return streak
    }

    /// Số ngày học có ôn trong `days` ngày học gần nhất, TÍNH CẢ hôm nay (M-02: ≥ 5/7) — cùng nguồn
    /// `dayStarts` và cùng cửa sổ ngày với `currentStreak` (engagement-r1 T4).
    public static func reviewedDays(
        inLast days: Int,
        from dayStarts: Set<String>,
        now: Date,
        timezone: TimeZone,
        cutoffHour: Int
    ) -> Int {
        var cursor = DayBoundary.window(
            now: now, timezone: timezone, dayCutoffHour: cutoffHour).start
        var count = 0
        for _ in 0..<max(0, days) {
            if dayStarts.contains(cursor) { count += 1 }
            cursor = previousWindowStart(cursor, timezone: timezone, cutoffHour: cutoffHour)
        }
        return count
    }

    /// Chuỗi dài nhất trong TOÀN BỘ lịch sử ôn (không gắn 18 tuần của lưới).
    public static func longestStreak(
        from dayStarts: Set<String>, timezone: TimeZone, cutoffHour: Int
    ) -> Int {
        let sorted = dayStarts.sorted()
        var best = 0
        var run = 0
        var previous: String?
        for start in sorted {
            if let previous,
               start == nextWindowStart(previous, timezone: timezone, cutoffHour: cutoffHour) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = start
        }
        return best
    }

    // MARK: — Heatmap

    /// Toàn bộ dữ liệu cho màn Lịch streak: streak hiện tại + dài nhất + lưới
    /// 18×7. `timezone` / `day_cutoff_hour` đọc từ settings (cùng cặp FR-11/14).
    public static func load(on db: SQLiteDatabase, now: Date) throws -> StreakHeatmap {
        let (timezone, cutoffHour) = DayContext.read(on: db)
        let reviews = try dayCounts(
            on: db, column: "reviewed_at", table: "review_logs",
            timezone: timezone, cutoffHour: cutoffHour)
        let pages = try dayCounts(
            on: db, column: "created_at", table: "reading_sessions",
            timezone: timezone, cutoffHour: cutoffHour)
        let reviewDays = Set(reviews.keys)
        return StreakHeatmap(
            currentStreak: currentStreak(
                from: reviewDays, now: now, timezone: timezone, cutoffHour: cutoffHour),
            longestStreak: longestStreak(
                from: reviewDays, timezone: timezone, cutoffHour: cutoffHour),
            weeks: buildWeeks(
                now: now, timezone: timezone, cutoffHour: cutoffHour,
                reviews: reviews, pages: pages))
    }

    // MARK: — Nội bộ

    /// Gộp timestamp của một cột thành [đầu-cửa-sổ ngày: số lần].
    private static func dayCounts(
        on db: SQLiteDatabase,
        column: String,
        table: String,
        timezone: TimeZone,
        cutoffHour: Int
    ) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for row in try db.rows("SELECT \(column) FROM \(table);") {
            guard let iso = row.first?.textValue,
                  let date = ISOTimestamp.date(from: iso) else { continue }
            let start = DayBoundary.window(
                now: date, timezone: timezone, dayCutoffHour: cutoffHour).start
            counts[start, default: 0] += 1
        }
        return counts
    }

    /// Lưới 18 cột (tuần, thứ Hai→Chủ Nhật) × 7 dòng. Cột cuối là tuần chứa hôm
    /// nay; ô sau hôm nay = nil. Mỗi ô mang số đếm ngày tương ứng.
    private static func buildWeeks(
        now: Date,
        timezone: TimeZone,
        cutoffHour: Int,
        reviews: [String: Int],
        pages: [String: Int]
    ) -> [[StreakDay?]] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.firstWeekday = 2  // tuần bắt đầu thứ Hai (VI)

        let todayStart = DayBoundary.window(
            now: now, timezone: timezone, dayCutoffHour: cutoffHour).start
        guard let todayDate = ISOTimestamp.date(from: todayStart) else {
            let empty = [StreakDay?](repeating: nil, count: daysPerWeek)
            return [[StreakDay?]](repeating: empty, count: weekCount)
        }

        // Căn cột cuối theo thứ Hai của tuần chứa hôm nay; cột 0 = 17 tuần trước.
        let weekday = calendar.component(.weekday, from: todayDate)  // 1=CN…7=T7
        let daysSinceMonday = (weekday + 5) % 7  // T2=0 … CN=6
        let currentMonday = calendar.date(
            byAdding: .day, value: -daysSinceMonday, to: todayDate) ?? todayDate
        let firstMonday = calendar.date(
            byAdding: .day, value: -(weekCount - 1) * daysPerWeek, to: currentMonday)
            ?? currentMonday

        var weeks: [[StreakDay?]] = []
        weeks.reserveCapacity(weekCount)
        for col in 0..<weekCount {
            var column: [StreakDay?] = []
            column.reserveCapacity(daysPerWeek)
            for row in 0..<daysPerWeek {
                let offset = col * daysPerWeek + row
                guard let dayDate = calendar.date(
                    byAdding: .day, value: offset, to: firstMonday)
                else {
                    column.append(nil)
                    continue
                }
                let start = DayBoundary.window(
                    now: dayDate, timezone: timezone, dayCutoffHour: cutoffHour).start
                if start > todayStart {
                    // Ngày tương lai — chưa xảy ra, không có dữ liệu.
                    column.append(nil)
                    continue
                }
                column.append(
                    StreakDay(
                        dayStartISO: start,
                        date: dayDate,
                        reviewCount: reviews[start] ?? 0,
                        pageCount: pages[start] ?? 0))
            }
            weeks.append(column)
        }
        return weeks
    }

    private static func previousWindowStart(
        _ iso: String, timezone: TimeZone, cutoffHour: Int
    ) -> String {
        guard let date = ISOTimestamp.date(from: iso) else { return iso }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let prev = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return DayBoundary.window(
            now: prev, timezone: timezone, dayCutoffHour: cutoffHour).start
    }

    private static func nextWindowStart(
        _ iso: String, timezone: TimeZone, cutoffHour: Int
    ) -> String {
        guard let date = ISOTimestamp.date(from: iso) else { return iso }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let next = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return DayBoundary.window(
            now: next, timezone: timezone, dayCutoffHour: cutoffHour).start
    }
}