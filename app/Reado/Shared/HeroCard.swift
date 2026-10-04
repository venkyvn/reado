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

    /// Một số phụ dưới title (vd "Gặp lại tuần này", "Đã nhớ") — eevas-r1 T1 (ADR-057).
    struct Metric: Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    let title: String
    /// Symbol nhỏ đứng trước title (vd checkmark ở trạng thái xong) — tô `titleTint`.
    var titleSystemImage: String?
    var titleTint: Color = Color.accentColor
    /// Số to đứng trước title (vd "12" + "thẻ đến hạn") — nil = title đứng một mình như cũ.
    var value: String? = nil
    var subtitle: String?
    /// 0–2 số phụ, rỗng = không vẽ hàng.
    var metrics: [Metric] = []
    /// nil = không có nút chính (trạng thái xong chỉ còn link phụ).
    var primary: Action?
    var secondary: Action?
    var warning: Warning?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            metricsRow
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
        if let value {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(value)
                    .font(.largeTitle.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(title)
                    .font(.title3.weight(.semibold))
            }
        } else if let titleSystemImage {
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

    /// Hàng số phụ dưới title/subtitle — xếp dọc ở cỡ chữ accessibility (như `statsSection` cũ).
    @ViewBuilder
    private var metricsRow: some View {
        if !metrics.isEmpty {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
                : AnyLayout(HStackLayout(spacing: Spacing.lg))
            layout {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        Text(metric.value)
                            .font(.headline)
                            .monospacedDigit()
                        Text(metric.label)
                            .font(Typo.meta)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
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
            title: "thẻ đến hạn",
            value: "10",
            subtitle: "Hôm nay chưa ôn — 1 thẻ là giữ streak",
            metrics: [
                HeroCard.Metric(value: "3", label: "Gặp lại tuần này"),
                HeroCard.Metric(value: "42 từ", label: "Đã nhớ"),
            ],
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
