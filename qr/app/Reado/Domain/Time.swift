import Foundation

enum IDs {
    static func uuid() -> String {
        UUID().uuidString.lowercased()
    }
}

enum ISO8601UTC {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: string)
    }
}

protocol Clock: Sendable {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

struct FixedClock: Clock {
    var now: Date
}

enum LearningDay {
    static func dayString(instant: Date, timeZone: TimeZone, cutoffHour: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: instant)
        if (components.hour ?? 0) < cutoffHour {
            guard let today = calendar.date(from: DateComponents(
                year: components.year, month: components.month, day: components.day
            )),
                  let previous = calendar.date(byAdding: .day, value: -1, to: today)
            else {
                return format(components)
            }
            components = calendar.dateComponents([.year, .month, .day], from: previous)
        }
        return format(components)
    }

    static func startOfDay(day: String, timeZone: TimeZone, cutoffHour: Int) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts[2], hour: cutoffHour
        ))
    }

    static func weekdayName(instant: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: instant)
    }

    private static func format(_ components: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

enum TermNormalizer {
    static func normalize(_ term: String) -> String {
        term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
