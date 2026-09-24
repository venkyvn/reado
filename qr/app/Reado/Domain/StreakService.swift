import Foundation
import GRDB

struct DayLog: Equatable, Identifiable {
    var id: String { date }
    var date: String
    var reviews: Int
    var captures: Int
}

struct StreakStats: Equatable {
    var current: Int
    var longest: Int
    var totalReviews: Int
    var activeDays: Int
}

enum StreakService {
    static func history(
        db: Database,
        settings: SettingsRecord,
        clock: Clock,
        sessions: [ReadingSession],
        weeks: Int = 18
    ) throws -> (days: [DayLog], stats: StreakStats) {
        let today = LearningDay.dayString(
            instant: clock.now,
            timeZone: settings.timeZone,
            cutoffHour: settings.dayCutoffHour
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        guard let todayDate = date(from: today) else {
            return ([], StreakStats(current: 0, longest: 0, totalReviews: 0, activeDays: 0))
        }
        let weekday = calendar.component(.weekday, from: todayDate) // 1 = Sunday
        let mondayOffset = (weekday + 5) % 7
        let totalDays = weeks * 7
        guard let gridEnd = calendar.date(byAdding: .day, value: 6 - mondayOffset, to: todayDate),
              let gridStart = calendar.date(byAdding: .day, value: -(totalDays - 1), to: gridEnd)
        else {
            return ([], StreakStats(current: 0, longest: 0, totalReviews: 0, activeDays: 0))
        }

        let logs = try ReviewLogRecord.fetchAll(db)
        var reviewCounts: [String: Int] = [:]
        for log in logs {
            guard let reviewed = ISO8601UTC.date(from: log.reviewedAt) else { continue }
            let day = LearningDay.dayString(
                instant: reviewed,
                timeZone: settings.timeZone,
                cutoffHour: settings.dayCutoffHour
            )
            reviewCounts[day, default: 0] += 1
        }
        var captureCounts: [String: Int] = [:]
        for session in sessions {
            captureCounts[String(session.capturedAt.prefix(10)), default: 0] += 1
        }

        var days: [DayLog] = []
        var cursor = gridStart
        while cursor <= gridEnd {
            let key = format(cursor)
            days.append(DayLog(date: key, reviews: reviewCounts[key] ?? 0, captures: captureCounts[key] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let past = days.filter { $0.date <= today }
        var current = 0
        for day in past.reversed() {
            if day.reviews > 0 { current += 1 } else { break }
        }
        var longest = 0
        var run = 0
        for day in past {
            if day.reviews > 0 {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        let stats = StreakStats(
            current: current,
            longest: longest,
            totalReviews: past.reduce(0) { $0 + $1.reviews },
            activeDays: past.filter { $0.reviews > 0 }.count
        )
        return (days, stats)
    }

    static func ranked(db: Database) throws -> [RankedCollection] {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT c.id AS id, c.name AS name, COUNT(rl.id) AS n
            FROM review_logs rl
            JOIN cards card ON card.id = rl.card_id
            JOIN vocab_items v ON v.id = card.vocab_item_id
            JOIN collections c ON c.id = v.collection_id
            GROUP BY c.id
            ORDER BY n DESC, c.name COLLATE NOCASE
            """
        )
        return rows.map { row in
            RankedCollection(id: row["id"], name: row["name"], reviews: row["n"])
        }
    }

    private static func date(from day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func format(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
