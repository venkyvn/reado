import Foundation
import ReadoKit
import UserNotifications

/// 3.12 — lịch nhắc ôn (local notification). Bọc `UNUserNotificationCenter` —
/// UserNotifications chỉ chạy ở app target, nên không nằm trong ReadoKit.
/// Logic giờ/phút + validation nằm ở `ReminderService` (thuần, test được).
enum NotificationScheduler {
    static let requestIdentifier = "reado.daily.reminder"

    /// Đồng bộ lịch nhắc với settings. Tắt → dọn hết pending; bật → xin quyền
    /// (nếu `requestPermission`) rồi đặt trigger lặp hằng ngày vào giờ đề.
    static func apply(enabled: Bool, minutes: Int, requestPermission: Bool) async {
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removeAllPendingNotificationRequests()
            return
        }
        if requestPermission {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        guard let (hour, minute) = try? ReminderService.time(fromMinutes: minutes) else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Đến giờ ôn từ vựng"
        content.body = "Vài phút mỗi ngày để nhớ lâu hơn."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: requestIdentifier, content: content, trigger: trigger)
        center.removeAllPendingNotificationRequests()
        do {
            try await center.add(request)
        } catch {
            DebugTrace.event("reminder", "scheduleFailed", ["error": String(describing: error)])
        }
    }
}