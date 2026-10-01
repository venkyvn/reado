import ReadoKit
import SwiftUI

/// J-R1-P — Xem lịch streak (lens của FR-14). Heatmap 18 tuần (7 hàng × 18 cột,
/// vừa khít bề ngang phone, không scroll ngang). Một ô = một "ngày học" theo giờ
/// chuyển ngày FR-11; màu = số thẻ ôn hôm đó. Tap ô → dòng chi tiết NGAY DƯỚI lưới
/// (không popover). CTA: còn due → Ôn (J4), 0 due → Chụp trang (J1). Không Cram.
struct StreakCalendarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Mở Capture→Analysis qua RootView (xem RootView.swift) — KHÔNG tự giữ
    /// state/sheet riêng ở đây nữa: bản riêng từng thiếu `pendingHubNavigationID`
    /// và không thật sự đưa đi Cài đặt khi `pendingSettingsNavigation` bật
    /// (hai bản dismiss lệch nhau, bug đã xác nhận 2026-10-01).
    let onCapture: () -> Void

    @State private var selectedDay: StreakDay?
    @State private var showReview = false

    private var heatmap: StreakHeatmap? { model.streakHeatmap }
    private var hasDue: Bool { (model.dailyProgress?.dueToday ?? 0) > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                gridSection
                detailLine
            }
            .padding(Spacing.md)
        }
        .shellScrollChrome()
        .navigationTitle("Lịch ôn")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.loadStreakHeatmap() }
        .sheet(isPresented: $showReview, onDismiss: { reload() }) {
            NavigationStack { ReviewQueueView() }
        }
        // Lưu xong (qua sheet Analysis của RootView) bump `dataRevision` —
        // heatmap riêng của màn này không nằm trong `reloadOverview()`.
        .onChange(of: model.dataRevision) { model.loadStreakHeatmap() }
        .safeAreaInset(edge: .bottom) { cta }
    }

    // MARK: — Streak hiện tại + dài nhất

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.row) {
                currentStreak
                longestStreak
            }
        } else {
            HStack(spacing: Spacing.md) {
                currentStreak
                longestStreak
            }
        }
    }

    private var currentStreak: some View {
        stat(
            title: "Chuỗi hiện tại",
            value: "\(heatmap?.currentStreak ?? 0) ngày",
            icon: "flame.fill",
            tint: Theme.due)
    }

    private var longestStreak: some View {
        stat(
            title: "Dài nhất",
            value: "\(heatmap?.longestStreak ?? 0) ngày",
            icon: "crown.fill",
            tint: Theme.warn)
    }

    private func stat(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(title, systemImage: icon)
                .font(Typo.meta)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Typo.metric)
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .card()
    }

    // MARK: — Heatmap (7 hàng × 18 cột)

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("18 tuần qua")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                grid(width: geo.size.width)
                    // 126 ô không thể đồng thời đạt 44pt mà vẫn vừa 18 cột.
                    // Một vùng tap lớn chọn ô gần nhất; VoiceOver duyệt tuần tự.
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { selectDay(at: $0.location, width: geo.size.width) })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Lịch học 18 tuần")
                    .accessibilityValue(heatmapAccessibilityValue)
                    .accessibilityHint("Vuốt lên hoặc xuống để duyệt từng ngày")
                    .accessibilityAdjustableAction { direction in
                        moveAccessibleSelection(direction)
                    }
            }
            .aspectRatio(18.0 / 7.0, contentMode: .fit)
            HStack(spacing: Spacing.xs) {
                Text("Ít")
                ForEach(1...5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.due.opacity(0.25 + 0.15 * Double(level)))
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                }
                Text("Nhiều")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Mức độ ôn, từ ít đến nhiều")
        }
    }

    @ViewBuilder
    private func grid(width: CGFloat) -> some View {
        // Hình học lưới heatmap (radius 2, khe 3, ô tối thiểu 6) — ngoại lệ của thang Spacing/Radius.
        let spacing: CGFloat = 3
        let size = max(6, (width - spacing * CGFloat(StreakCalendarService.weekCount - 1))
            / CGFloat(StreakCalendarService.weekCount))
        HStack(spacing: spacing) {
            ForEach(0..<StreakCalendarService.weekCount, id: \.self) { col in
                VStack(spacing: spacing) {
                    ForEach(0..<StreakCalendarService.daysPerWeek, id: \.self) { row in
                        cell(day(at: col, row: row), size: size)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: StreakDay?, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color(for: day))
            .frame(width: size, height: size)
            .overlay {
                if day?.date == selectedDay?.date {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary, lineWidth: 2)
                }
            }
    }

    private func selectDay(at location: CGPoint, width: CGFloat) {
        let spacing: CGFloat = 3
        let size = max(6, (width - spacing * CGFloat(StreakCalendarService.weekCount - 1))
            / CGFloat(StreakCalendarService.weekCount))
        let step = size + spacing
        let col = min(max(Int(location.x / step), 0), StreakCalendarService.weekCount - 1)
        let row = min(max(Int(location.y / step), 0), StreakCalendarService.daysPerWeek - 1)
        guard let day = day(at: col, row: row) else { return }
        Motion.run(reduceMotion: reduceMotion) { selectedDay = day }
        Haptics.selection()
    }

    private var availableDays: [StreakDay] {
        heatmap?.weeks.flatMap { $0 }.compactMap { $0 } ?? []
    }

    private var heatmapAccessibilityValue: String {
        guard let day = selectedDay else { return "Chưa chọn ngày" }
        return dayAccessibilityValue(day)
    }

    private func dayAccessibilityValue(_ day: StreakDay) -> String {
        let date = day.date.formatted(date: .long, time: .omitted)
        return "\(date), \(day.reviewCount) thẻ ôn, \(day.pageCount) trang chụp"
    }

    private func moveAccessibleSelection(_ direction: AccessibilityAdjustmentDirection) {
        let days = availableDays
        guard !days.isEmpty else { return }
        let current = selectedDay.flatMap { selected in
            days.firstIndex { $0.date == selected.date }
        }
        let next: Int
        switch direction {
        case .increment:
            next = min((current ?? -1) + 1, days.count - 1)
        case .decrement:
            next = max((current ?? days.count) - 1, 0)
        @unknown default:
            return
        }
        Motion.run(reduceMotion: reduceMotion) { selectedDay = days[next] }
        Haptics.selection()
    }

    private func day(at col: Int, row: Int) -> StreakDay? {
        guard let heatmap, heatmap.weeks.indices.contains(col),
              heatmap.weeks[col].indices.contains(row) else { return nil }
        return heatmap.weeks[col][row]
    }

    /// Màu theo cường độ — chỉ NGÀY CÓ ÔN mới tô; ngày chỉ chụp / chưa ôn = xám
    /// (FR-14 nói streak ngày ÔN liên tục; capture không chứng minh retention).
    private func color(for day: StreakDay?) -> Color {
        guard let day, day.reviewCount > 0 else {
            return Color(.systemGray5)
        }
        let level = StreakIntensity.level(
            count: day.reviewCount, thresholds: intensityThresholds)
        return Theme.due.opacity(0.25 + 0.15 * Double(level))
    }

    /// B4 (owner chốt 2026-10-01): ngưỡng tứ phân vị tính từ CHÍNH lưới 18 tuần
    /// đang hiện — < 4 ngày có ôn thì `StreakIntensity` tự rơi về mốc cố định cũ.
    private var intensityThresholds: [Int] {
        let counts = (heatmap?.weeks.flatMap { $0 }.compactMap { $0 } ?? [])
            .map(\.reviewCount)
        return StreakIntensity.thresholds(from: counts)
    }

    // MARK: — Dòng chi tiết ngay dưới lưới (không popover)

    @ViewBuilder
    private var detailLine: some View {
        if let day = selectedDay {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(day.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text("\(day.reviewCount) thẻ ôn")
                    .font(Typo.meta)
                    .foregroundStyle(.secondary)
                if day.pageCount > 0 {
                    Text("\(day.pageCount) trang chụp")
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .card()
            .revealTransition()
        }
    }

    // MARK: — CTA (còn due → Ôn; 0 due → Chụp trang)

    private var cta: some View {
        Button {
            if hasDue { showReview = true } else { onCapture() }
        } label: {
            Label(
                hasDue ? "Ôn ngay" : "Chụp trang",
                systemImage: hasDue ? "brain.head.profile.fill" : "camera.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.row)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(.background)
        .overlay(alignment: .top) { Divider() }
    }

    private func reload() {
        model.loadStreakHeatmap()
        model.reloadOverview()
    }
}