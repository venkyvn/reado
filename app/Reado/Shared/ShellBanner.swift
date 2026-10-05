import SwiftUI
import UIKit

/// ux-redesign-r1 T2: nội dung banner không chặn (vd "Đã lưu 8 từ vào Kho tạm · Xem"). Chỉ là dữ
/// liệu thuần — hành động "Xem"/"Đóng" do nơi gắn (`RootView`) truyền vào `ShellBanner`.
struct ShellBannerItem: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var systemImage = "checkmark.circle.fill"
    /// nil = không có nút hành động (chỉ ✕).
    var actionTitle: String?
    /// Dòng phụ (engagement-r1 T7) — vd cụm EN–VI đáng nhớ của trang vừa lưu. Banner có dòng phụ ở lâu hơn.
    var detail: String?
    /// false = đứng yên tới khi đóng tay — dùng cho màn debug `save-banner` (chụp ảnh không kịp 4s).
    var autoHides = true
}

/// Banner nổi ở đáy, TRÊN thanh tab — thay alert chặn sau khi lưu (ADR-053). Là chrome nổi nên
/// dùng `chromeGlass` như thanh tab; chữ ngắn một dòng, không phải khối đọc lâu.
/// Nơi gắn đặt nó trong overlay đáy, bọc `Motion.run` khi đổi `item` và gắn `.revealTransition()`
/// ở cuối chuỗi modifier (transition phải nằm trên view nhánh `if`).
struct ShellBanner: View {
    /// Thời gian tự ẩn khi không bật VoiceOver — có dòng phụ (cụm để đọc) thì lâu hơn.
    private static func autoHideSeconds(for item: ShellBannerItem) -> Int {
        item.detail == nil ? 4 : 7
    }

    let item: ShellBannerItem
    let onAction: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Chữ cỡ lớn: nút xuống dưới thay vì bóp cột chữ.
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    message
                    HStack(spacing: Spacing.sm) {
                        actionButton
                        Spacer(minLength: 0)
                        dismissButton
                    }
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    message
                    Spacer(minLength: Spacing.sm)
                    actionButton
                    dismissButton
                }
            }
        }
        .padding(.leading, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .chromeGlass(in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        // Báo VoiceOver ngay khi hiện + tự ẩn sau 4s. VoiceOver đang chạy → KHÔNG tự ẩn (đóng
        // bằng ✕): người dùng cần thời gian nghe/chạm, WCAG 2.2.1. Task đổi theo `item.id` nên
        // banner mới thay banner cũ thì đếm lại từ đầu.
        .task(id: item.id) {
            AccessibilityNotification.Announcement(
                [item.message, item.detail].compactMap { $0 }.joined(separator: ". ")).post()
            guard item.autoHides, !UIAccessibility.isVoiceOverRunning else { return }
            try? await Task.sleep(for: .seconds(Self.autoHideSeconds(for: item)))
            guard !Task.isCancelled, !UIAccessibility.isVoiceOverRunning else { return }
            dismiss()
        }
    }

    private var message: some View {
        HStack(spacing: Spacing.row) {
            Image(systemName: item.systemImage)
                .foregroundStyle(Theme.ok)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Text(item.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = item.detail {
                    Text(detail)
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                        // Cỡ chữ accessibility: nới trần dòng để không cắt cụm (chữ đã to gấp đôi).
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 8 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle = item.actionTitle {
            Button(actionTitle) {
                Motion.run(reduceMotion: reduceMotion) { onAction() }
            }
            .font(Typo.meta.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(Typo.meta.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Đóng thông báo")
    }

    private func dismiss() {
        Motion.run(reduceMotion: reduceMotion) { onDismiss() }
    }
}
