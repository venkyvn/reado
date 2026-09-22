import Foundation

/// FR-15 — Learning Settings: các núm học tập người dùng CHỈNH ĐƯỢC ở R1.
/// Một hàng `settings` id = 1 (NG-05 một người dùng). Ba núm này là toàn bộ
/// phần user ghi được; `request_retention` và các núm FSRS còn lại để mặc
/// định, KHÔNG mở cho user (PRD mục 10 + journey J-R1-S).
public struct LearningSettings: Equatable, Sendable {
    public let cefrLevel: CEFRLevel
    public let dailyNewLimit: Int
    public let dayCutoffHour: Int

    public init(cefrLevel: CEFRLevel, dailyNewLimit: Int, dayCutoffHour: Int) {
        self.cefrLevel = cefrLevel
        self.dailyNewLimit = dailyNewLimit
        self.dayCutoffHour = dayCutoffHour
    }

    /// Khớp Seeder (db.md A.2.1): B2 / 10 / 04:00.
    public static let defaults = LearningSettings(
        cefrLevel: .b2, dailyNewLimit: 10, dayCutoffHour: 4)
}

/// Trình độ CEFR người dùng khai — target cho FR-02 (prompt-spec mục 3).
/// Chỉ A2–C1 (PRD FR-15); A1/C2 không nằm phạm vi lọc của R1.
public enum CEFRLevel: String, CaseIterable, Sendable, Identifiable {
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"

    public var id: String { rawValue }
}

public enum SettingsError: Error, LocalizedError, Equatable {
    /// settings id = 1 chưa tồn tại (chưa seed).
    case notSeeded
    case invalidDailyNewLimit(Int)
    case invalidDayCutoffHour(Int)

    public var errorDescription: String? {
        switch self {
        case .notSeeded:
            "settings id = 1 chưa seed"
        case let .invalidDailyNewLimit(value):
            "daily_new_limit ngoài 0…999: \(value)"
        case let .invalidDayCutoffHour(value):
            "day_cutoff_hour ngoài 0…23: \(value)"
        }
    }
}

/// Đọc/ghi 3 núm học tập của `settings` (id = 1). Đây là đường ghi DUY NHẤT
/// cho cefr_level / daily_new_limit / day_cutoff_hour ở tầng logic; các cột
/// FSRS (`request_retention`, `fsrs_params`, …) ngoài phạm vi update R1.
public enum SettingsService {
    /// D-lim-0: hạn mức 0 hợp lệ (không giới thiệu thẻ mới), trần 999.
    public static let dailyNewLimitRange = 0...999
    public static let dayCutoffHourRange = 0...23

    /// Đọc 3 núm user chỉnh được. Không có hàng id = 1 → `.notSeeded`.
    public static func load(on db: SQLiteDatabase) throws -> LearningSettings {
        guard
            let row = try db.rows(
                """
                SELECT cefr_level, daily_new_limit, day_cutoff_hour
                FROM settings WHERE id = 1;
                """
            ).first,
            row.count == 3
        else {
            throw SettingsError.notSeeded
        }
        let cefr =
            row[0].textValue.flatMap(CEFRLevel.init(rawValue:))
            ?? LearningSettings.defaults.cefrLevel
        let limit =
            Int(row[1].intValue ?? Int64(LearningSettings.defaults.dailyNewLimit))
        let cutoff =
            Int(row[2].intValue ?? Int64(LearningSettings.defaults.dayCutoffHour))
        return LearningSettings(
            cefrLevel: cefr, dailyNewLimit: limit, dayCutoffHour: cutoff)
    }

    /// Validate rồi ghi 3 núm — trả về giá trị vừa ghi. CEFR đã typed enum nên
    /// không thể sai ở tầng này; hai núm số bị chặn ngoài phạm vi.
    @discardableResult
    public static func update(
        on db: SQLiteDatabase,
        cefrLevel: CEFRLevel,
        dailyNewLimit: Int,
        dayCutoffHour: Int
    ) throws -> LearningSettings {
        guard dailyNewLimitRange.contains(dailyNewLimit) else {
            throw SettingsError.invalidDailyNewLimit(dailyNewLimit)
        }
        guard dayCutoffHourRange.contains(dayCutoffHour) else {
            throw SettingsError.invalidDayCutoffHour(dayCutoffHour)
        }
        try db.run(
            """
            UPDATE settings
               SET cefr_level = ?, daily_new_limit = ?, day_cutoff_hour = ?
             WHERE id = 1;
            """,
            [
                .text(cefrLevel.rawValue),
                .int(Int64(dailyNewLimit)),
                .int(Int64(dayCutoffHour)),
            ])
        return LearningSettings(
            cefrLevel: cefrLevel,
            dailyNewLimit: dailyNewLimit,
            dayCutoffHour: dayCutoffHour)
    }
}