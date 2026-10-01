import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Màn Hôm nay (ux-redesign-r1 T3) — một hero cho việc cần làm lúc này (`HomeHero`, ADR-054),
/// hàng chỉ số gọn, rồi "Đang đọc" (pin). Kho tạm nằm ở Thư viện, onboarding gộp vào hero.
/// Không còn CTA "Chụp trang" to dưới đáy (nút chụp nằm trong thanh tab).
struct HomeTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            // ux-redesign-r1 T1b: chỉ còn ⚙ ở góc phải (quy ước iOS) — cửa Dữ liệu chuyển sang Thư viện.
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
            statsSection
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
                .appErrorAlert()
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
            return HeroCard(
                title: "\(count) thẻ đến hạn",
                primary: HeroCard.Action(title: "Ôn ngay", handler: { start(.srs) }),
                secondary: scopeAction,
                warning: warning)
        case let .extra(count):
            return HeroCard(
                title: "Xong phần hôm nay",
                titleSystemImage: "checkmark.circle.fill",
                titleTint: Theme.ok,
                subtitle: "Bạn vẫn có thể ôn thêm từ mới hoặc ôn sớm.",
                primary: HeroCard.Action(title: "Ôn thêm \(count) thẻ", handler: { start(.extra) }),
                secondary: scopeAction,
                warning: warning)
        case .done:
            return HeroCard(
                title: "Xong phần hôm nay",
                titleSystemImage: "checkmark.circle.fill",
                titleTint: Theme.ok,
                secondary: HeroCard.Action(
                    title: "Chụp trang mới", systemImage: "camera", handler: onCapture),
                warning: warning)
        }
    }

    private func loadCefrLabel() {
        let levels = model.loadLearningSettings()?.cefrLevels ?? [.b2]
        cefrLabel = levels.map(\.rawValue).joined(separator: ", ")
    }

    // MARK: — Chỉ số gọn

    /// Streak bấm được → Lịch streak (heatmap 18 tuần); "Gặp lại N từ tuần này" (FR-22) chỉ để
    /// đọc, ẩn khi 0 (0 trông như lỗi, không phải tiến bộ). Ý 7 motivation-r1: streak > 0 mà hôm
    /// nay CHƯA ôn thẻ nào thì thêm lời nhắc giữ streak (không nhắc người mới).
    @ViewBuilder
    private var statsSection: some View {
        if let progress = model.dailyProgress {
            Section {
                NavigationLink(value: ShellRoute.streak) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
                            : AnyLayout(HStackLayout(spacing: Spacing.md))
                        layout {
                            Label {
                                Text("\(progress.streak) ngày liên tục")
                                    .contentTransition(.numericText())
                            } icon: {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(Theme.due)
                                    .symbolEffect(.bounce, value: reduceMotion ? 0 : progress.streak)
                            }
                            if model.reencounteredThisWeek > 0 {
                                Label {
                                    Text("Gặp lại \(model.reencounteredThisWeek) từ tuần này")
                                        .contentTransition(.numericText())
                                } icon: {
                                    Image(systemName: "eye")
                                        .foregroundStyle(Theme.ok)
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        if progress.streak > 0 && !progress.reviewedToday {
                            Text("Hôm nay chưa ôn — 1 thẻ là giữ streak")
                                .font(Typo.meta)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .animation(reduceMotion ? nil : Motion.reveal, value: progress.streak)
                }
            }
        }
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
