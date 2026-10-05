import Foundation

/// "Tuần qua" (engagement-r1 T8, ý 5 của tang_gang_bo, ADR-068): kể lại 7 ngày học của TUẦN TRƯỚC (thứ Hai →
/// Chủ nhật, theo ngày học FR-11) bằng số đo có thật — từ giữ lại, từ gặp lại khi đọc, lần nhận ra, ngày ôn, từ
/// gặp nhiều nhất (vision #6: tiến bộ thật, không điểm/XP). Không đếm số trang: `reading_sessions` chỉ giữ 10
/// phiên mỗi bộ nên không có nguồn bền (NFR-04).
public struct WeekStory: Equatable, Sendable {
    /// Thứ Hai của tuần HIỆN TẠI (ISO) — khoá "đã đóng thẻ" của tuần này, sang tuần mới thì thẻ mới hiện lại.
    public let weekStart: String
    /// `vocab_items.created_at` trong tuần trước.
    public let wordsSaved: Int
    /// Số TỪ khác nhau có một lần gặp lại (`seen`) trong tuần trước.
    public let wordsReencountered: Int
    /// Số lần "nhận ra" khi đọc (`recognized`) trong tuần trước.
    public let recognizedCount: Int
    /// Số ngày học có ôn trong tuần trước (0…7).
    public let reviewDays: Int
    /// Từ có nhiều lần gặp (seen + recognized) nhất tuần trước, ≥ 2 lần; hoà → từ lưu sớm hơn.
    public let topTerm: String?

    public init(
        weekStart: String, wordsSaved: Int, wordsReencountered: Int, recognizedCount: Int,
        reviewDays: Int, topTerm: String?
    ) {
        self.weekStart = weekStart
        self.wordsSaved = wordsSaved
        self.wordsReencountered = wordsReencountered
        self.recognizedCount = recognizedCount
        self.reviewDays = reviewDays
        self.topTerm = topTerm
    }

    /// Không có gì để kể → thẻ ẩn.
    public var isEmpty: Bool {
        wordsSaved == 0 && wordsReencountered == 0 && recognizedCount == 0 && reviewDays == 0
            && topTerm == nil
    }

    /// Câu kể chuyện theo thứ tự cố định; bỏ câu có số 0.
    public var lines: [String] {
        var result: [String] = []
        if wordsSaved > 0 { result.append("Giữ lại \(wordsSaved) từ mới.") }
        if wordsReencountered > 0 { result.append("Gặp lại \(wordsReencountered) từ cũ khi đọc.") }
        if recognizedCount > 0 { result.append("Nhận ra \(recognizedCount) lần.") }
        if reviewDays > 0 { result.append("Ôn \(reviewDays)/7 ngày.") }
        if let topTerm { result.append("Gặp nhiều nhất: \(topTerm).") }
        return result
    }
}

public enum WeekStoryService {

    /// Tuần trước = `[weekStart − 7 ngày, weekStart)` theo ngày học. `now` ở tuần nào thì `weekStart` là thứ Hai
    /// của tuần đó (mốc khoá "đã đóng").
    public static func load(on db: SQLiteDatabase, now: Date) throws -> WeekStory {
        let (timezone, cutoffHour) = DayContext.read(on: db)
        let weekStartIso = DayBoundary.weekStart(
            now: now, timezone: timezone, dayCutoffHour: cutoffHour)
        guard let weekStartDate = ISOTimestamp.date(from: weekStartIso) else {
            return WeekStory(
                weekStart: weekStartIso, wordsSaved: 0, wordsReencountered: 0, recognizedCount: 0,
                reviewDays: 0, topTerm: nil)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let previous = calendar.date(byAdding: .day, value: -7, to: weekStartDate) ?? weekStartDate
        let from = DayBoundary.window(
            now: previous, timezone: timezone, dayCutoffHour: cutoffHour).start
        let to = weekStartIso
        let range: [SQLValue] = [.text(from), .text(to)]

        let wordsSaved = Int(try db.scalarInt64(
            "SELECT COUNT(*) FROM vocab_items WHERE created_at >= ? AND created_at < ?;", range) ?? 0)
        let wordsReencountered = Int(try db.scalarInt64(
            """
            SELECT COUNT(DISTINCT vocab_item_id) FROM encounters
            WHERE kind = 'seen' AND created_at >= ? AND created_at < ?;
            """, range) ?? 0)
        let recognizedCount = Int(try db.scalarInt64(
            """
            SELECT COUNT(*) FROM encounters
            WHERE kind = 'recognized' AND created_at >= ? AND created_at < ?;
            """, range) ?? 0)
        let dayStarts = try StreakCalendarService.reviewedDayStarts(
            on: db, timezone: timezone, cutoffHour: cutoffHour)
        let reviewDays = dayStarts.filter { $0 >= from && $0 < to }.count
        let topRows = try db.rows(
            """
            SELECT v.term AS term, COUNT(*) AS n
            FROM encounters e JOIN vocab_items v ON v.id = e.vocab_item_id
            WHERE e.created_at >= ? AND e.created_at < ?
            GROUP BY e.vocab_item_id
            HAVING n >= 2
            ORDER BY n DESC, v.created_at, v.id
            LIMIT 1;
            """, range)
        return WeekStory(
            weekStart: weekStartIso, wordsSaved: wordsSaved, wordsReencountered: wordsReencountered,
            recognizedCount: recognizedCount, reviewDays: reviewDays,
            topTerm: topRows.first?["term"].textValue)
    }
}
