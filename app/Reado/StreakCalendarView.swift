import ReadoKit
import SwiftUI

/// J-R1-P — Xem lịch streak (lens của FR-14). Heatmap 18 tuần (7 hàng × 18 cột,
/// vừa khít bề ngang phone, không scroll ngang). Một ô = một "ngày học" theo giờ
/// chuyển ngày FR-11; màu = số thẻ ôn hôm đó. Tap ô → dòng chi tiết NGAY DƯỚI lưới
/// (không popover). CTA: còn due → Ôn (J4), 0 due → Chụp trang (J1). Không Cram.
struct StreakCalendarView: View {
    @Environment(AppModel.self) private var model

    @State private var selectedDay: StreakDay?
    @State private var showReview = false
    @State private var showCapture = false
    @State private var showAnalysis = false

    private var heatmap: StreakHeatmap? { model.streakHeatmap }
    private var hasDue: Bool { (model.dailyProgress?.dueToday ?? 0) > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                gridSection
                detailLine
            }
            .padding()
        }
        .navigationTitle("Lịch streak")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.loadStreakHeatmap() }
        .sheet(isPresented: $showReview, onDismiss: { reload() }) {
            NavigationStack { ReviewQueueView() }
        }
        .sheet(isPresented: $showCapture, onDismiss: {
            // J1: chụp xong (đã có ảnh) → mở phân tích, đích ngầm kho tạm.
            if model.lastCapturedImage != nil { showAnalysis = true }
        }) {
            NavigationStack { CaptureView() }
        }
        .sheet(isPresented: $showAnalysis, onDismiss: {
            if model.pendingRecapture {
                model.pendingRecapture = false
                showCapture = true
            }
            reload()
        }) {
            NavigationStack { AnalysisView() }
        }
        .safeAreaInset(edge: .bottom) { cta }
    }

    // MARK: — Streak hiện tại + dài nhất

    private var header: some View {
        HStack(spacing: 16) {
            stat(
                title: "Chuỗi hiện tại",
                value: "\(heatmap?.currentStreak ?? 0) ngày",
                icon: "flame.fill",
                tint: Theme.due)
            stat(
                title: "Dài nhất",
                value: "\(heatmap?.longestStreak ?? 0) ngày",
                icon: "crown.fill",
                tint: Theme.warn)
        }
    }

    private func stat(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .card()
    }

    // MARK: — Heatmap (7 hàng × 18 cột)

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("18 tuần qua")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                grid(width: geo.size.width)
            }
            .aspectRatio(18.0 / 7.0, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func grid(width: CGFloat) -> some View {
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
            .contentShape(Rectangle())
            .onTapGesture {
                if let day { selectedDay = day }
            }
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
        let level = Self.intensity(for: day.reviewCount)
        return Color.orange.opacity(0.25 + 0.15 * Double(level))
    }

    /// Cường độ màu 1…5 theo số thẻ ôn (1 / 2 / 3–4 / 5–6 / 7+).
    static func intensity(for reviewCount: Int) -> Int {
        switch reviewCount {
        case 1: 1
        case 2: 2
        case 3...4: 3
        case 5...6: 4
        default: 5
        }
    }

    // MARK: — Dòng chi tiết ngay dưới lưới (không popover)

    @ViewBuilder
    private var detailLine: some View {
        if let day = selectedDay {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text("\(day.reviewCount) thẻ ôn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if day.pageCount > 0 {
                    Text("\(day.pageCount) trang chụp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .card()
        }
    }

    // MARK: — CTA (còn due → Ôn; 0 due → Chụp trang)

    private var cta: some View {
        Button {
            if hasDue { showReview = true } else { showCapture = true }
        } label: {
            Label(
                hasDue ? "Ôn ngay" : "Chụp trang",
                systemImage: hasDue ? "brain.head.profile" : "camera.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    private func reload() {
        model.loadStreakHeatmap()
        model.reloadOverview()
    }
}