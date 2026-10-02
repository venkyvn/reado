import SwiftUI

/// ux-redesign-r1 T2: khối "việc cần làm lúc này" đầu màn Hôm nay — title, phụ đề, MỘT nút
/// chính, link phụ và dòng cảnh báo tuỳ chọn. Nhận chuỗi/closure thuần, không đọc model;
/// nơi gọi (`HomeTabView`) tự map từ `HomeHero`. Nền `card()` đặc — không glass (không phải chrome).
struct HeroCard: View {
    /// Một hành động bấm được: nhãn + symbol tuỳ chọn + closure.
    struct Action {
        let title: String
        var systemImage: String?
        let handler: () -> Void
    }

    /// Dòng cảnh báo phụ (`Theme.warn`) — chữ + link sửa tuỳ chọn.
    struct Warning {
        let text: String
        var fix: Action?
    }

    let title: String
    /// Symbol nhỏ đứng trước title (vd checkmark ở trạng thái xong) — tô `titleTint`.
    var titleSystemImage: String?
    var titleTint: Color = Color.accentColor
    var subtitle: String?
    /// nil = không có nút chính (trạng thái xong chỉ còn link phụ).
    var primary: Action?
    var secondary: Action?
    var warning: Warning?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                titleView
                if let subtitle {
                    Text(subtitle)
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                }
            }
            if let primary {
                Button(action: primary.handler) {
                    label(for: primary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            if let secondary {
                Button(action: secondary.handler) {
                    label(for: secondary)
                        .font(Typo.meta)
                        // Vùng chạm ≥ 44pt dù chữ phụ nhỏ.
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
            if let warning {
                warningRow(warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .card()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var titleView: some View {
        if let titleSystemImage {
            Label {
                Text(title)
            } icon: {
                Image(systemName: titleSystemImage)
                    .foregroundStyle(titleTint)
            }
            .font(.title3.weight(.semibold))
        } else {
            Text(title)
                .font(.title3.weight(.semibold))
        }
    }

    @ViewBuilder
    private func label(for action: Action) -> some View {
        if let systemImage = action.systemImage {
            Label(action.title, systemImage: systemImage)
        } else {
            Text(action.title)
        }
    }

    private func warningRow(_ warning: Warning) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label {
                Text(warning.text)
                    .font(Typo.meta)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.warn)
            }
            if let fix = warning.fix {
                Button(action: fix.handler) {
                    Text(fix.title)
                        .font(Typo.meta.weight(.semibold))
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

#Preview("HeroCard") {
    VStack(spacing: Spacing.md) {
        HeroCard(
            title: "10 thẻ đến hạn",
            subtitle: "Phạm vi: Tất cả bộ",
            primary: HeroCard.Action(title: "Ôn ngay", handler: {}),
            secondary: HeroCard.Action(title: "Đổi phạm vi", systemImage: "chevron.down", handler: {}),
            warning: HeroCard.Warning(
                text: "Agent chưa chạy được — chụp sẽ không phân tích được.",
                fix: HeroCard.Action(title: "Sửa", handler: {})))
        HeroCard(
            title: "Xong phần hôm nay",
            titleSystemImage: "checkmark.circle.fill",
            titleTint: Theme.ok,
            secondary: HeroCard.Action(title: "Chụp trang mới", systemImage: "camera", handler: {}))
    }
    .padding(Spacing.md)
}
