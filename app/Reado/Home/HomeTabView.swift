import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Màn Hôm nay (ux-redesign-r1 T3) — một hero cho việc cần làm lúc này (`HomeHero`, ADR-054),
/// rồi "Đang đọc" (pin). Kho tạm nằm ở Thư viện, onboarding gộp vào hero. Streak lên pill
/// toolbar, "Gặp lại tuần này"/"Đã nhớ" thành số phụ trong hero (home-eevas-r1 T1, ADR-057).
/// Toolbar: pill 🔥N · 🔍 Tìm từ (home-eevas-r1 T4, FR-08) · ⚙ — ba hình tròn tách nhau.
/// Không còn CTA "Chụp trang" to dưới đáy (nút chụp nằm trong thanh tab).
struct HomeTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// ux-redesign-r1 T1a: "Ôn ngay" / "Ôn thêm" mở phiên ôn toàn màn qua `RootView`,
    /// không còn đổi sang tab Ôn.
    @Environment(\.startReview) private var startReview
    @AppStorage("reado.onboarding.cefrConfirmed") private var cefrConfirmed = false
    let onSettings: () -> Void
    let onCapture: () -> Void

    @State private var showAgentForm = false
    @State private var showScopePicker = false
    /// Phạm vi chọn riêng cho phiên sắp ôn — chỉ có hiệu lực khi `hasScopeOverride`, còn không thì
    /// theo mặc định đã lưu. Hết hiệu lực sau khi mở phiên (không ghi đè mặc định).
    @State private var scopeOverride: Set<String>?
    @State private var hasScopeOverride = false
    @State private var cefrLabel = "B2"

    var body: some View {
        Group {
            if model.database == nil, model.failure == nil {
                ProgressView("Đang mở kho…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let failure = model.failure {
                ContentUnavailableView {
                    Label("Không mở được kho", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(failure)
                }
            } else {
                homeList
            }
        }
        .navigationTitle("Hôm nay")
        .toolbar {
            // home-eevas-r1 T1 (ADR-057): pill streak tách khỏi hàng riêng, lên góc phải toolbar
            // kiểu eevas — ẩn lúc onboarding (chưa có trang để streak có nghĩa).
            if let progress = model.dailyProgress, model.hasFirstPage {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: ShellRoute.streak) {
                        // `Label` tự rút về chỉ-icon trong nút tròn toolbar iOS 26 dù đã
                        // `.labelStyle(.titleAndIcon)` — HStack thường để số streak luôn hiện.
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Theme.due)
                                .symbolEffect(.bounce, value: reduceMotion ? 0 : progress.streak)
                            Text("\(progress.streak)")
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    .accessibilityLabel("Chuỗi \(progress.streak) ngày, mở lịch streak")
                }
                if #available(iOS 26, *) {
                    // Tách pill streak khỏi 🔍 thành hai hình tròn riêng — không gộp capsule.
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
            }
            // home-eevas-r1 T4 (FR-08): tìm từ xuyên mọi collection — giữa pill streak và ⚙.
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: ShellRoute.search) {
                    Label("Tìm từ", systemImage: "magnifyingglass")
                }
                .accessibilityLabel("Tìm từ")
            }
            if #available(iOS 26, *) {
                // Tách 🔍 khỏi ⚙ thành hai hình tròn riêng — không gộp capsule.
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            // ux-redesign-r1 T1b: cửa Dữ liệu chuyển sang Thư viện, ⚙ chỉ còn Cài đặt.
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSettings) {
                    Label("Cài đặt", systemImage: "gearshape")
                }
                .accessibilityLabel("Cài đặt")
            }
        }
    }

    private var homeList: some View {
        List {
            Section {
                heroCard(hero)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            leechBannerRow
            homePinRows
        }
        .refreshable { model.reloadOverview() }
        .shellScrollChrome()
        .onAppear { loadCefrLabel() }
        .sheet(isPresented: $showAgentForm) {
            AgentFormSheet(agent: nil) { name, base, modelName, key in
                model.addAgent(name: name, baseURL: base, model: modelName, apiKey: key)
            }
            .appErrorAlert()
        }
        .sheet(isPresented: $showScopePicker) {
            ScopePickerSheet(
                scope: Binding(
                    get: { reviewScope },
                    set: {
                        scopeOverride = $0
                        hasScopeOverride = true
                    }),
                onApply: {})
        }
    }

    // MARK: — Hero (ADR-054)

    private var hero: HomeHero {
        let progress = model.dailyProgress
        return HomeHero.resolve(
            cefrConfirmed: cefrConfirmed,
            agentReady: model.activeAgentReady,
            hasFirstPage: model.hasFirstPage,
            dueToday: progress?.dueToday ?? 0,
            extraAvailable: model.homeExtraAvailableCount,
            backlog: progress?.backlog ?? 0)
    }

    /// Phạm vi của lần bấm Ôn kế tiếp: lựa chọn riêng nếu có, không thì mặc định đã lưu (Ôn nhanh).
    private var reviewScope: Set<String>? {
        hasScopeOverride ? scopeOverride : model.reviewScopeDefault.scopeSet
    }

    private var scopeAction: HeroCard.Action {
        let label = reviewScope.map { "Phạm vi: \($0.count) bộ" } ?? "Phạm vi: Tất cả bộ"
        return HeroCard.Action(
            title: label, systemImage: "line.3.horizontal.decrease.circle",
            handler: { showScopePicker = true })
    }

    private func start(_ mode: ReviewMode) {
        startReview(ReviewRequest(scope: reviewScope, mode: mode))
        hasScopeOverride = false
    }

    private func heroCard(_ hero: HomeHero) -> HeroCard {
        // Agent hỏng ở người dùng đã có trang: chỉ là dòng cảnh báo, không che thẻ đến hạn.
        let warning: HeroCard.Warning? = hero.agentWarning
            ? HeroCard.Warning(
                text: "Agent chưa chạy được — chụp sẽ không phân tích được.",
                fix: HeroCard.Action(title: "Sửa", handler: onSettings))
            : nil
        switch hero.state {
        case .confirmCefr:
            return HeroCard(
                title: "Trình độ đọc: \(cefrLabel)",
                subtitle: "Reado lọc từ theo mức này khi phân tích trang.",
                primary: HeroCard.Action(title: "Đúng", handler: { cefrConfirmed = true }),
                secondary: HeroCard.Action(title: "Đổi", handler: {
                    cefrConfirmed = true
                    onSettings()
                }))
        case .connectAgent:
            return HeroCard(
                title: "Kết nối agent phân tích",
                subtitle: "Mặc định AI-Box — dán API key một lần.",
                primary: HeroCard.Action(title: "Thêm agent", handler: { showAgentForm = true }))
        case .firstCapture:
            return HeroCard(
                title: "Chụp trang sách đầu tiên",
                subtitle: "Trang giấy hoặc màn hình đều chụp được.",
                primary: HeroCard.Action(
                    title: "Chụp trang", systemImage: "camera.fill", handler: onCapture))
        case let .review(count):
            let progress = model.dailyProgress
            return HeroCard(
                title: "thẻ đến hạn",
                value: "\(count)",
                subtitle: progress?.weekReminder,
                metrics: heroMetrics,
                primary: HeroCard.Action(title: "Ôn ngay", handler: { start(.srs) }),
                secondary: scopeAction,
                // Chỉ khi còn nhiều hơn một phiên nhanh — ít hơn thì "Ôn ngay" đã là phiên nhanh.
                quick: count > ReviewQueue.quickSessionSize
                    ? HeroCard.Action(
                        title: "Ôn nhanh \(ReviewQueue.quickSessionSize) thẻ · ~2 phút",
                        handler: { start(.quick) })
                    : nil,
                warning: warning)
        case let .extra(count):
            return HeroCard(
                title: "Xong phần hôm nay",
                titleSystemImage: "checkmark.circle.fill",
                titleTint: Theme.ok,
                subtitle: "Bạn vẫn có thể ôn thêm từ mới hoặc ôn sớm.",
                metrics: heroMetrics,
                primary: HeroCard.Action(title: "Ôn thêm \(count) thẻ", handler: { start(.extra) }),
                secondary: scopeAction,
                warning: warning)
        case .done:
            return HeroCard(
                title: "Xong phần hôm nay",
                titleSystemImage: "checkmark.circle.fill",
                titleTint: Theme.ok,
                metrics: heroMetrics,
                secondary: HeroCard.Action(
                    title: "Chụp trang mới", systemImage: "camera", handler: onCapture),
                warning: warning)
        }
    }

    /// "Gặp lại tuần này" (FR-22, ẩn khi 0 — 0 trông như lỗi) · "Đã nhớ" (Q-08, luôn hiện —
    /// số đo thật kể cả 0). Chỉ dùng ở trạng thái đã có trang (`.review/.extra/.done`).
    private var heroMetrics: [HeroCard.Metric] {
        var metrics: [HeroCard.Metric] = []
        if model.reencounteredThisWeek > 0 {
            metrics.append(
                HeroCard.Metric(value: "\(model.reencounteredThisWeek)", label: "Gặp lại tuần này"))
        }
        let masteredTotal = model.collections.reduce(0) { $0 + $1.masteredCount }
        metrics.append(HeroCard.Metric(value: "\(masteredTotal) từ", label: "Đã nhớ"))
        return metrics
    }

    /// FR-19 (home-eevas-r1 T3): banner "N từ hay quên ›" dưới hero — ẩn khi N=0.
    /// Chỉ icon tô `Theme.warn` (MASTER §Màu: `.tint` chỉ hợp lệ khi tô nền control hệ thống);
    /// chữ giữ `.foregroundStyle(.primary)` mặc định của `Label`/`NavigationLink`.
    @ViewBuilder
    private var leechBannerRow: some View {
        if !model.leeches.isEmpty {
            Section {
                NavigationLink(value: ShellRoute.leeches) {
                    Label {
                        Text("\(model.leeches.count) từ hay quên")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warn)
                    }
                }
            }
        }
    }

    private func loadCefrLabel() {
        let levels = model.loadLearningSettings()?.cefrLevels ?? [.b2]
        cefrLabel = levels.map(\.rawValue).joined(separator: ", ")
    }

    // Pin Home — "Đang đọc" tối đa 5 (port UI lab), mở thẳng Collection Hub.
    @ViewBuilder
    private var homePinRows: some View {
        if !model.homePins.isEmpty {
            Section("Đang đọc · \(model.homePins.count)/5") {
                ForEach(model.homePins) { collection in
                    NavigationLink(value: ShellRoute.hub(collection.id)) {
                        HStack(spacing: Spacing.row) {
                            // Cùng bề rộng IconTile để mép trái các row thẳng hàng.
                            Image(systemName: "pin.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: IconTile.size)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.tight) {
                                Text(collection.name)
                                    .font(Typo.rowTitle)
                                Text(masteryLabel(collection))
                                    .font(Typo.rowSubtitle)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if collection.totalItems > 0 {
                                MasteryRing(
                                    mastered: collection.masteredCount,
                                    total: collection.totalItems,
                                    absorbed: collection.absorbedCount)
                            }
                            if collection.dueNow > 0 {
                                Pill(text: "\(collection.dueNow)", tone: .due)
                            }
                        }
                    }
                }
            }
        }
    }
}
