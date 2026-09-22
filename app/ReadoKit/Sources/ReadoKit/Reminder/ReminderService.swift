import Foundation

/// 3.12 — Reminder ôn tập: biến `reminder_minutes` (0…1439, phút kể từ nửa đêm
/// local) thành (giờ, phút) cho `UNCalendarNotificationTrigger`, và mô tả giờ
/// cho UI. Thuần — KHÔNG đụng `UserNotifications` nên test được không cần
/// simulator; phần lịch thật nằm ở app layer (`NotificationScheduler.swift`).
public enum ReminderService {
    /// D-rem-0: 00:00…23:59 hợp lệ.
    public static let minutesRange = 0...1439

    /// Phút → (giờ, phút) cho trigger. Ngoài 0…1439 → `.invalidReminderMinutes`.
    public static func time(fromMinutes minutes: Int) throws -> (hour: Int, minute: Int) {
        guard minutesRange.contains(minutes) else {
            throw SettingsError.invalidReminderMinutes(minutes)
        }
        return (minutes / 60, minutes % 60)
    }

    /// "20:00", "07:30" — hiển thị 24 giờ cho UI (nhãn Picker).
    public static func describe(minutes: Int) -> String {
        let (h, m) = (try? time(fromMinutes: minutes)) ?? (0, 0)
        return String(format: "%02d:%02d", h, m)
    }
}