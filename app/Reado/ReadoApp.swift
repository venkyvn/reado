import ReadoKit
import SwiftUI

/// Design tokens duy nhất của Reado — mọi màu semantic đều qua đây
/// (docs/ux/visual-redesign-plan.md §0). Không hardcode màu ở view.
///
/// Lưu ý: `accent` KHÔNG nằm ở đây — màu nhấn do người dùng chọn qua Settings
/// (`AppTheme`) và áp ở `ReadoApp` qua `.tint`. View dùng `Color.accentColor`.
enum Theme {
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

/// Bộ màu nhấn (theme) người dùng chọn — "Hệ thống" + 3 palette gợi đọc sách.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case forest
    case indigo
    case sepia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Hệ thống"
        case .forest: "Xanh rừng"
        case .indigo: "Chàm"
        case .sepia: "Nâu giấy"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .forest: "leaf.fill"
        case .indigo: "drop.fill"
        case .sepia: "book.closed.fill"
        }
    }

    /// Màu nhấn; nil = dùng accent hệ thống (xanh iOS mặc định).
    var accent: Color? {
        switch self {
        case .system: nil
        case .forest: Color(red: 0.184, green: 0.420, blue: 0.310)    // #2F6B4F
        case .indigo: Color(red: 0.231, green: 0.290, blue: 0.420)    // #3B4A6B
        case .sepia: Color(red: 0.549, green: 0.357, blue: 0.247)     // #8C5B3F
        }
    }
}

/// Nền card mờ đồng nhất (`Theme.surface`) — thay chuỗi `.background(opacity)`.
private struct SurfaceCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    func body(content: Content) -> some View {
        content.background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func card(cornerRadius: CGFloat = 12) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius))
    }
}

@main
struct ReadoApp: App {
    @State private var model = AppModel()
    /// Chủ đề màu nhấn — lưu UserDefaults, đổi ngay không cần khởi động lại.
    @AppStorage("appTheme") private var appTheme = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(AppTheme(rawValue: appTheme)?.accent)
                // 3.12: khôi phục lịch nhắc từ settings lúc khởi động. Tắt →
                // dọn pending (không hỏi quyền); bật → đặt lại trigger hằng ngày.
                .task { await model.syncReminderSchedule(requestPermission: true) }
        }
    }
}