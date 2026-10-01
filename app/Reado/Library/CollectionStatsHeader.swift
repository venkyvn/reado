import ReadoKit
import SwiftUI

/// Header màn collection (cram-collection-r1 T4): thẻ tiến độ 4 màu + 3 ô số +
/// CTA đổi theo ngữ cảnh. View thuần — không đọc `AppModel`, chỉ nhận số liệu và
/// hai closure (ôn thường / ôn thêm).
struct CollectionStatsHeader: View {
    let overview: AppModel.CollectionOverview
    let nextDue: VocabRepository.NextDue?
    let onReview: () -> Void
    let onCram: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if segments.total > 0 {
                progressCard
            }
            statTiles
            cta
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: — Thẻ tiến độ

    private struct Segment: Identifiable {
        let label: String
        let count: Int
        let color: Color
        var id: String { label }
    }

    /// Thang 4 mức (vision #6, reencounter-r1 T3): Đã thấm › Đã nhớ › Đang học ›
    /// Mới. Đã nhớ = Q-08 chưa nhận ra (`masteredCount − absorbedCount`); Đang học
    /// gộp "Đang nhớ" cũ (`learning + reviewing`). Mẫu số là tổng 4 nhóm (không
    /// phải `totalItems`) để thanh luôn đầy khi có từ chỉ còn thẻ suspended.
    private var segments: (items: [Segment], total: Int) {
        let remembered = max(0, overview.masteredCount - overview.absorbedCount)
        let items = [
            Segment(label: "Đã thấm", count: overview.absorbedCount, color: Theme.ok),
            Segment(
                label: "Đã nhớ", count: remembered,
                color: Color.accentColor.opacity(0.6)),
            Segment(
                label: "Đang học",
                count: overview.learningCount + overview.reviewingCount,
                color: Theme.due),
            Segment(
                label: "Mới", count: overview.notStartedCount,
                color: Theme.surfaceStrong),
        ]
        return (items, items.reduce(0) { $0 + $1.count })
    }

    private var progressCard: some View {
        let (items, total) = segments
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Đã nhớ \(overview.masteredCount)/\(overview.totalItems)")
                .font(Typo.rowTitle)
                .monospacedDigit()
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(items.filter { $0.count > 0 }) { segment in
                        segment.color
                            .frame(
                                width: max(
                                    2,
                                    proxy.size.width * CGFloat(segment.count)
                                        / CGFloat(total)))
                    }
                }
                .frame(width: proxy.size.width, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            .frame(height: 8)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.md) {
                    ForEach(items) { legendItem($0) }
                }
                Grid(alignment: .leading, horizontalSpacing: Spacing.md,
                     verticalSpacing: Spacing.xs) {
                    GridRow { legendItem(items[0]); legendItem(items[1]) }
                    GridRow { legendItem(items[2]); legendItem(items[3]) }
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tiến độ")
        .accessibilityValue(
            items.map { "\($0.label) \($0.count)" }.joined(separator: ", "))
    }

    private func legendItem(_ segment: Segment) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(segment.color).frame(width: 8, height: 8)
            Text("\(segment.label) \(segment.count)")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
        }
    }

    // MARK: — 3 ô số

    private var statTiles: some View {
        let tiles = VStack(spacing: Spacing.sm) { tileViews }
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                tiles
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.sm) { tileViews }
                    tiles
                }
            }
        }
    }

    @ViewBuilder
    private var tileViews: some View {
        tile(
            title: "Đến hạn", value: "\(overview.dueNow)", detail: nil,
            valueColor: overview.dueNow > 0 ? Theme.due : .primary)
        tile(
            title: "7 ngày qua", value: "+\(overview.addedLast7Days) từ",
            detail: lastAddedText, valueColor: .primary)
        tile(
            title: "Lần ôn tiếp", value: nextDueValue, detail: nextDueDetail,
            valueColor: .primary)
    }

    private func tile(
        title: String, value: String, detail: String?, valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(title)
                .font(Typo.meta)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Typo.metric)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(Typo.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.row)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
    }

    private var lastAddedText: String? {
        guard let last = overview.lastAddedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "thêm lần cuối " + formatter.localizedString(for: last, relativeTo: Date())
    }

    private var nextDueValue: String {
        if overview.dueNow > 0 { return "Ngay bây giờ" }
        guard let nextDue else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(for: nextDue.date, relativeTo: Date())
    }

    private var nextDueDetail: String? {
        guard overview.dueNow == 0, let nextDue else { return nil }
        return "\(nextDue.count) thẻ"
    }

    // MARK: — CTA theo ngữ cảnh

    @ViewBuilder
    private var cta: some View {
        if overview.dueNow > 0 {
            Button(action: onReview) {
                Label("Ôn bộ này · \(overview.dueNow) đến hạn", systemImage: "brain.head.profile")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if overview.crammableCount > 0 {
            VStack(spacing: Spacing.xs) {
                Button(action: onCram) {
                    Label(
                        "Ôn thêm \(min(overview.crammableCount, ReviewQueue.cramBatchSize)) thẻ",
                        systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Không ảnh hưởng lịch ôn")
                    .font(Typo.meta)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Chụp trang để thêm từ — dùng nút chụp nổi.")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
        }
    }
}
