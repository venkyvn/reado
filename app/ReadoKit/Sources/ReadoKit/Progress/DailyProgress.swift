import Foundation

/// FR-14 — Daily Progress: mấy con số Home cần.
/// Mọi phép "hôm nay" đi qua `DayBoundary` (giờ chuyển ngày FR-11), KHÔNG dùng
/// nửa đêm hệ thống — cùng một ngày phải nói cùng một điều trên cùng màn hình.
public struct DailyProgress: Equatable, Sendable {
    /// Số thẻ THỰC SỰ sẽ ôn hôm nay = nhánh due + nhánh new còn trong hạn mức
    /// (FR-11). KHÔNG phải tổng `due_at` quá khứ — PageCapture đổ cả trăm card
    /// `due_at` hôm nay, còn `daily_new_limit` tồn tại để chặn đúng con số đó.
    public let dueToday: Int
    /// Số thẻ new vượt hạn mức hôm nay — con số RIÊNG, nhãn riêng (FR-14).
    public let backlog: Int
    /// Số trang đã phân tích — đếm `reading_sessions` (0 cho tới khi FR-05/06 ghi).
    public let pagesAnalyzed: Int
    /// Ngày ôn LIÊN TỤC tính theo giờ chuyển ngày (FR-14).
    public let streak: Int
    /// Có ≥1 lượt ôn `mode = 'srs'` từ đầu cửa sổ ngày hiện tại (FR-11 giờ
    /// chuyển ngày) — dùng cho dòng nhắc "giữ streak" (ý 7, không tính `cram`).
    public let reviewedToday: Bool
    /// Tổng thẻ `state = 'new'` còn tồn trong kho (chưa từng giới thiệu),
    /// KHÔNG áp hạn mức.
    public let totalNewRemaining: Int

    public init(
        dueToday: Int, backlog: Int, pagesAnalyzed: Int, streak: Int,
        reviewedToday: Bool, totalNewRemaining: Int
    ) {
        self.dueToday = dueToday
        self.backlog = backlog
        self.pagesAnalyzed = pagesAnalyzed
        self.streak = streak
        self.reviewedToday = reviewedToday
        self.totalNewRemaining = totalNewRemaining
    }
}

/// Tính số đếm Home theo settings + giờ chuyển ngày (giống `ReviewQueue.loadFullQueue`).
/// Leech (card `suspended_at` không null) tự bị loại khỏi MỌI con số nhờ các query
/// nhánh đều gắn `suspended_at IS NULL`.
public enum DailyProgressService {

    public static func load(
        on db: SQLiteDatabase,
        dailyNewLimit: Int,
        now: Date
    ) throws -> DailyProgress {
        // timezone + giờ chuyển ngày — đúng cặp giá trị FR-11 dùng chung.
        let window = ReviewQueue.currentDayWindow(on: db, now: now)
        let dayStartIso = window.start
        let (timezone, cutoffHour) = DayContext.read(on: db)

        // Nhánh new (hạn mức) — luật FR-11: quota trừ số thẻ mới đã giới thiệu.
        // `introduced` có thể vượt `dailyNewLimit` khi Ôn thêm (extra-review-r1)
        // đã giới thiệu thêm từ mới hôm đó (owner chốt: chấp nhận, không trần
        // qua Ôn thêm) — `max(0, …)` kẹp quota còn lại về 0, không âm.
        let totalNew = Int((try db.scalarInt64(
            "SELECT COUNT(*) FROM cards WHERE state = 'new' AND suspended_at IS NULL;")) ?? 0)
        let introduced = Int(try ReviewQueue.newIntroducedCount(on: db, dayStartIso: dayStartIso))
        let remainingQuota = max(0, Int64(dailyNewLimit) - Int64(introduced))
        let newQueued = try ReviewQueue.newCardIDs(on: db, quota: remainingQuota).count

        // Nhánh due — không hạn mức (FR-11); hạn theo ngày học (window.end),
        // không theo `now` thời điểm gọi (T1 fsrs-queue-fix-r1).
        let dueCount = try ReviewQueue.dueCardIDs(on: db, dueBeforeIso: window.end).count

        let dueToday = newQueued + dueCount
        // backlog = thẻ new còn lại chưa vào hôm nay (thẻ đã giới thiệu đã rời
        // state 'new' nên totalNew không gồm chúng).
        let backlog = max(0, totalNew - newQueued)

        let pagesAnalyzed = Int((try db.scalarInt64(
            "SELECT COUNT(*) FROM reading_sessions;")) ?? 0)

        let streak = try self.streak(
            on: db, now: now, timezone: timezone, cutoffHour: cutoffHour)

        // reviewedToday: >= dayStartIso cùng cách so lexicographic mà
        // `newIntroducedCount` đang dùng — chuỗi ISO cùng độ dài nên so sánh
        // chuỗi = so sánh thời gian.
        let reviewedToday = (try db.scalarInt64(
            "SELECT COUNT(*) FROM review_logs WHERE mode = 'srs' AND reviewed_at >= ?;",
            [.text(dayStartIso)]) ?? 0) > 0

        return DailyProgress(
            dueToday: dueToday,
            backlog: backlog,
            pagesAnalyzed: pagesAnalyzed,
            streak: streak,
            reviewedToday: reviewedToday,
            totalNewRemaining: totalNew)
    }

    /// Streak = số ngày ôn liên tục tính từ hôm nay (nếu hôm nay chưa ôn thì tính
    /// từ hôm qua) theo giờ chuyển ngày. Một ngày "có ôn" = có ≥1 `review_log`.
    /// Logic chia sẻ với `StreakCalendarService` (J-R1-P) để hai con số trên cùng
    /// màn hình không tính kiểu khác nhau.
    private static func streak(
        on db: SQLiteDatabase,
        now: Date,
        timezone: TimeZone,
        cutoffHour: Int
    ) throws -> Int {
        let dayStarts = try StreakCalendarService.reviewedDayStarts(
            on: db, timezone: timezone, cutoffHour: cutoffHour)
        return StreakCalendarService.currentStreak(
            from: dayStarts, now: now, timezone: timezone, cutoffHour: cutoffHour)
    }
}