import ReadoKit
import SwiftUI
import UIKit

/// Design tokens duy nhất của Reado — mọi màu semantic đều qua đây
/// (`design-system/reado/MASTER.md` §Màu). Không hardcode màu ở view.
///
/// Lưu ý: `accent` KHÔNG nằm ở đây — màu nhấn do người dùng chọn qua Settings
/// (`AppTheme`) và áp ở `ReadoApp` qua `.tint`. View dùng `Color.accentColor`.
enum Theme {
    /// Nền phụ (pill, ô editor, card). System fill, không phải `secondary.opacity`:
    /// alpha cố định đủ tách nền sáng nhưng gần như tàng hình trên nền tối.
    static let surface = Color(.tertiarySystemFill)
    static let surfaceStrong = Color(.secondarySystemFill)

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

    /// Màu nhấn; nil = dùng accent hệ thống (xanh iOS mặc định). Hex sáng chọn cho
    /// nền trắng nên quá tối trên nền đen — dark mode dùng bản nhạt cùng hue, nếu
    /// không chữ và nút accent chìm hẳn vào nền.
    var accent: Color? {
        switch self {
        case .system: nil
        case .forest: Color(light: 0x2F6B4F, dark: 0x6FBF95)
        case .indigo: Color(light: 0x3B4A6B, dark: 0x93A9DC)
        case .sepia: Color(light: 0x8C5B3F, dark: 0xD79C79)
        }
    }
}

private extension Color {
    /// Một token hai sắc độ, resolve theo trait nên đổi Appearance là đổi theo.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1)
    }
}

/// Nhịp motion duy nhất của app — nội dung hiện/ẩn báo "vừa xuất hiện", không ăn mừng
/// (vision "Journey Over Summary"). Luật dùng: `design-system/reado/MASTER.md` §Bố cục.
/// Sheet / tab / push KHÔNG đi qua đây — hệ thống tự animate, đè vào là hỏng.
enum Motion {
    static let reveal = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)

    /// Hiện/ẩn nội dung trong cùng một màn.
    static let revealTransition = AnyTransition.opacity.combined(
        with: .offset(y: 10))

    /// Reduce Motion → gán state thẳng, không animate.
    static func run(
        reduceMotion: Bool,
        _ animation: Animation = reveal,
        _ change: () -> Void
    ) {
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, change)
        } else {
            withAnimation(animation, change)
        }
    }
}

/// Haptic semantic dùng chung — intensity theo ý nghĩa, không theo từng màn.
enum Haptics {
    /// Đổi lựa chọn, lật thẻ, chọn ngày.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Chạm tới ngưỡng của một gesture liên tục.
    static func threshold() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Xác nhận hành động chính: chấm thẻ, mở camera.
    static func action() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

extension View {
    /// Transition reveal cho nhánh `if`. Cặp với `Motion.run` ở chỗ đổi cờ.
    func revealTransition() -> some View {
        transition(Motion.revealTransition)
    }
}

/// Nền card mờ đồng nhất (`Theme.surface`) — thay chuỗi `.background(opacity)`.
private struct SurfaceCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.md
    func body(content: Content) -> some View {
        content.background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func card(cornerRadius: CGFloat = Radius.md) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius))
    }

    /// ux-polish-r1 T4: Liquid Glass cho chrome nổi (tab bar, shutter) — khớp
    /// `design-system/reado/MASTER.md` (FROZEN: glass trên chrome, nội dung
    /// đọc đặc). Deployment target 17.0 → iOS < 26 rơi về material cũ.
    @ViewBuilder
    func chromeGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay { shape.stroke(Theme.surfaceStrong, lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}

@main
struct ReadoApp: App {
    @State private var model = AppModel()
    /// Chủ đề màu nhấn — lưu UserDefaults, đổi ngay không cần khởi động lại.
    /// Mặc định mới = rừng; user cũ đã ghi "system" được migrate một lần.
    @AppStorage("appTheme") private var appTheme = AppTheme.forest.rawValue
    /// Cờ "đã áp mặc định rừng một lần" — set vô điều kiện lúc khởi động lần đầu
    /// để người đã chủ động chọn theme (Chàm/Nâu giấy/Hệ thống) không bị kéo lại
    /// về rừng ở các lần mở app sau.
    @AppStorage("reado.appliedForestDefault") private var appliedForestDefault = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(AppTheme(rawValue: appTheme)?.accent)
                // 3.12: khôi phục lịch nhắc từ settings lúc khởi động. Tắt →
                // dọn pending (không hỏi quyền); bật → đặt lại trigger hằng ngày.
                .task { await model.syncReminderSchedule(requestPermission: true) }
                .onAppear { applyForestDefaultIfNeeded() }
        }
    }

    /// Một lần duy nhất: user cũ chưa từng chọn theme (đã lưu "system") → chuyển
    /// về mặc định rừng mới. Cờ set vô điều kiện nên ai đã chọn rồi là giữ nguyên.
    private func applyForestDefaultIfNeeded() {
        guard !appliedForestDefault else { return }
        appliedForestDefault = true
        if appTheme == AppTheme.system.rawValue {
            appTheme = AppTheme.forest.rawValue
        }
    }
}