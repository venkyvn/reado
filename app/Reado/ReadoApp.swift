import ReadoKit
import SwiftUI

/// Design tokens duy nhất của Reado — mọi màu semantic đều qua đây
/// (docs/ux/visual-redesign-plan.md §0). Không hardcode màu ở view.
enum Theme {
    /// Brand — gợi "đọc sách/giấy", tắt tone game (vision "Journey Over Summary").
    static let accent = Color(red: 0.184, green: 0.420, blue: 0.310)  // #2F6B4F

    /// Nền phụ (pill, ô editor, card).
    static let surface = Color.secondary.opacity(0.08)
    static let surfaceStrong = Color.secondary.opacity(0.12)

    /// Trạng thái — dùng màu hệ thống để tự thích nghi dark mode.
    static let due = Color.orange    // đến hạn / streak / tồn đọng
    static let ok = Color.green       // xong / đã kiểm / đã lưu
    static let warn = Color.orange    // cần xem / trùng / nghi ngờ
    static let danger = Color.red     // lỗi / "Quên" (again)
    static let level = Color.indigo   // CEFR — cấp độ, không đụng hue trạng thái
}

@main
struct ReadoApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
                // 3.12: khôi phục lịch nhắc từ settings lúc khởi động. Tắt →
                // dọn pending (không hỏi quyền); bật → đặt lại trigger hằng ngày.
                .task { await model.syncReminderSchedule(requestPermission: true) }
        }
    }
}