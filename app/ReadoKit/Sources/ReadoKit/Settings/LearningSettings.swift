import Foundation

/// FR-15 + 3.12 — Learning Settings: các núm user CHỈNH ĐƯỢC ở R1.
/// Một hàng `settings` id = 1 (NG-05 một người dùng). Năm núm này là toàn bộ
/// phần user ghi được; `request_retention` và các núm FSRS còn lại để mặc
/// định, KHÔNG mở cho user (PRD mục 10 + journey J-R1-S).
public struct LearningSettings: Equatable, Sendable {
    public let cefrLevel: CEFRLevel
    public let dailyNewLimit: Int
    public let dayCutoffHour: Int
    /// 3.12 — nhắc ôn tập (local notification). `reminderMinutes` = phút kể từ
    /// nửa đêm local (0…1439); default tắt + 20:00.
    public let reminderEnabled: Bool
    public let reminderMinutes: Int

    public init(
        cefrLevel: CEFRLevel,
        dailyNewLimit: Int,
        dayCutoffHour: Int,
        reminderEnabled: Bool = false,
        reminderMinutes: Int = 20 * 60
    ) {
        self.cefrLevel = cefrLevel
        self.dailyNewLimit = dailyNewLimit
        self.dayCutoffHour = dayCutoffHour
        self.reminderEnabled = reminderEnabled
        self.reminderMinutes = reminderMinutes
    }

    /// Khớp Seeder (db.md A.2.1): B2 / 10 / 04:00 · nhắc TẮT, 20:00.
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
    case invalidReminderMinutes(Int)

    public var errorDescription: String? {
        switch self {
        case .notSeeded:
            "settings id = 1 chưa seed"
        case let .invalidDailyNewLimit(value):
            "daily_new_limit ngoài 0…999: \(value)"
        case let .invalidDayCutoffHour(value):
            "day_cutoff_hour ngoài 0…23: \(value)"
        case let .invalidReminderMinutes(value):
            "reminder_minutes ngoài 0…1439: \(value)"
        }
    }
}

/// Đọc/ghi 5 núm user chỉnh được của `settings` (id = 1). Đây là đường ghi DUY
/// NHẤT cho cefr_level / daily_new_limit / day_cutoff_hour / reminder_enabled /
/// reminder_minutes ở tầng logic; các cột FSRS (`request_retention`,
/// `fsrs_params`, …) ngoài phạm vi update R1.
public enum SettingsService {
    /// D-lim-0: hạn mức 0 hợp lệ (không giới thiệu thẻ mới), trần 999.
    public static let dailyNewLimitRange = 0...999
    public static let dayCutoffHourRange = 0...23
    /// 3.12 — phút kể từ nửa đêm (00:00…23:59).
    public static let reminderMinutesRange = 0...1439

    /// Đọc 5 núm user chỉnh được. Không có hàng id = 1 → `.notSeeded`.
    public static func load(on db: SQLiteDatabase) throws -> LearningSettings {
        guard
            let row = try db.rows(
                """
                SELECT cefr_level, daily_new_limit, day_cutoff_hour,
                       reminder_enabled, reminder_minutes
                FROM settings WHERE id = 1;
                """
            ).first,
            row.count == 5
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
        let reminderEnabled =
            (row[3].intValue ?? 0) != 0
        let reminderMinutes =
            Int(row[4].intValue ?? Int64(LearningSettings.defaults.reminderMinutes))
        return LearningSettings(
            cefrLevel: cefr, dailyNewLimit: limit, dayCutoffHour: cutoff,
            reminderEnabled: reminderEnabled, reminderMinutes: reminderMinutes)
    }

    /// Validate rồi ghi 5 núm — trả về giá trị vừa ghi. CEFR đã typed enum nên
    /// không thể sai ở tầng này; ba núm số bị chặn ngoài phạm vi. Tham số
    /// nhắc (reminder*) có default → call-site FR-15 cũ (3 núm) vẫn compile.
    @discardableResult
    public static func update(
        on db: SQLiteDatabase,
        cefrLevel: CEFRLevel,
        dailyNewLimit: Int,
        dayCutoffHour: Int,
        reminderEnabled: Bool = false,
        reminderMinutes: Int = LearningSettings.defaults.reminderMinutes
    ) throws -> LearningSettings {
        guard dailyNewLimitRange.contains(dailyNewLimit) else {
            throw SettingsError.invalidDailyNewLimit(dailyNewLimit)
        }
        guard dayCutoffHourRange.contains(dayCutoffHour) else {
            throw SettingsError.invalidDayCutoffHour(dayCutoffHour)
        }
        guard reminderMinutesRange.contains(reminderMinutes) else {
            throw SettingsError.invalidReminderMinutes(reminderMinutes)
        }
        try db.run(
            """
            UPDATE settings
               SET cefr_level = ?, daily_new_limit = ?, day_cutoff_hour = ?,
                   reminder_enabled = ?, reminder_minutes = ?
             WHERE id = 1;
            """,
            [
                .text(cefrLevel.rawValue),
                .int(Int64(dailyNewLimit)),
                .int(Int64(dayCutoffHour)),
                .int(reminderEnabled ? 1 : 0),
                .int(Int64(reminderMinutes)),
            ])
        return LearningSettings(
            cefrLevel: cefrLevel,
            dailyNewLimit: dailyNewLimit,
            dayCutoffHour: dayCutoffHour,
            reminderEnabled: reminderEnabled,
            reminderMinutes: reminderMinutes)
    }
}