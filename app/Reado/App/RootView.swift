import ReadoKit
import SwiftUI

/// Tab gốc — ux-redesign-r1 T1b (ADR-052 nháp): hai tab Hôm nay / Thư viện, nút chụp nằm TRONG
/// hàng của thanh tab (không tab Chụp, không overlay nổi). Capture/Analysis là cover/sheet phủ
/// toàn tab; Cài đặt là push trên Hôm nay, Dữ liệu là push trên Thư viện. Phiên ôn là cover toàn
/// màn (`ReviewRequest`, T1a) mở từ mọi nơi qua `\.startReview` — không còn tab Ôn.
/// Thanh tab = `ShellTabBar`, ẩn native tab bar.
enum AppTab: Hashable, CaseIterable {
    case today
    case library

    var title: String {
        switch self {
        case .today: "Hôm nay"
        case .library: "Thư viện"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .library: "books.vertical"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: "sun.max.fill"
        case .library: "books.vertical.fill"
        }
    }
}

/// Route đẩy vào NavigationStack của Hôm nay/Thư viện — để nút chụp biết đang đứng
/// ở "bề mặt chụp" (root/Hub) hay bên trong (lịch streak, phiên đọc qua hub).
enum ShellRoute: Hashable {
    case hub(String)
    case streak
    case settings
    case data
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: AppTab = .today
    // port UI lab §5.7: sau Lưu → push Hub bộ vừa lưu lên stack Hôm nay.
    @State private var todayPath: [ShellRoute] = []
    @State private var libraryPath: [ShellRoute] = []
    @State private var showCapture = false
    @State private var showAnalysis = false
    // ux-redesign-r1 T1a: phiên ôn toàn màn — nil = đóng.
    @State private var reviewRequest: ReviewRequest?
    // ux-redesign-r1 T2: banner không chặn ở đáy (ADR-053). Tạm chỉ có `-ReadoScreen save-banner`
    // đặt nó; luồng Lưu thật (T5a) gắn vào sau.
    @State private var banner: ShellBannerItem?
    // T3a shell-chrome-r1: ẩn thanh tab (kèm nút chụp) khi cuộn xuống.
    @State private var chrome = ShellChrome()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $todayPath) {
                HomeTabView(
                    onSettings: { todayPath.append(.settings) },
                    onCapture: openShutterCapture)
                    .navigationDestination(for: ShellRoute.self) {
                        shellDestination($0)
                    }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.icon) }
            .tag(AppTab.today)

            NavigationStack(path: $libraryPath) {
                KhoTabView()
                    .navigationDestination(for: ShellRoute.self) {
                        shellDestination($0)
                    }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .tabItem { Label(AppTab.library.title, systemImage: AppTab.library.icon) }
            .tag(AppTab.library)
        }
        .environment(chrome)
        .environment(\.startReview, { reviewRequest = $0 })
        .onChange(of: selectedTab) { chrome.reveal() }
        .onChange(of: todayPath) { chrome.reveal() }
        .onChange(of: libraryPath) { chrome.reveal() }
        .overlay(alignment: .bottom) {
            // Banner nằm ngay trên thanh tab. ĐÃ ĐO BẰNG SCREENSHOT (không phải suy luận): dù overlay
            // đứng TRƯỚC `safeAreaInset` bên dưới, `.safeAreaPadding(.bottom)` vẫn đọc safe area
            // MÔI TRƯỜNG — safe area này do `safeAreaInset` gán cho CẢ SUBTREE (kể cả overlay attach
            // trước nó trong chain), nên đã gồm sẵn toàn bộ chiều cao ShellTabBar (không chỉ home
            // indicator). Cộng thêm chiều cao thanh lên trên safeAreaPadding là cộng trùng — chỉ cộng
            // khe hở nhỏ.
            if let banner {
                ShellBanner(item: banner, onAction: dismissBanner, onDismiss: dismissBanner)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
                    .safeAreaPadding(.bottom)
                    .revealTransition()
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: chrome.isHidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ShellTabBar(
                selection: $selectedTab,
                onReselect: popSelectedTabToRoot,
                isHidden: chrome.isHidden,
                showsCapture: showsCaptureButton,
                onCapture: openShutterCapture,
                badgedTabs: (model.dailyProgress?.dueToday ?? 0) > 0 ? [.today] : [])
        }
        // ADR-036: fullScreenCover (không sheet) — CaptureView tự vẽ full-bleed
        // đen; sheet để lộ viền bo góc + không che hết status bar, không hợp
        // camera. Không bọc NavigationStack: CaptureView tự có chrome (X/dest/+).
        .fullScreenCover(isPresented: $showCapture, onDismiss: {
            chrome.reveal()
            // FR-02: chụp xong (đã có ảnh trong model) → mở màn phân tích.
            if model.capture.lastCapturedImage != nil {
                showAnalysis = true
            }
        }) {
            CaptureView()
        }
        // ux-redesign-r1 T1a: phiên ôn toàn màn — che cả thanh tab nên không đổi tab giữa phiên,
        // `tally` không mất. Đóng → nạp lại tổng quan: Home/Hub/Lịch streak tự refresh qua
        // `dataRevision`.
        .fullScreenCover(item: $reviewRequest, onDismiss: {
            chrome.reveal()
            model.reloadOverview()
        }) { request in
            NavigationStack {
                ReviewQueueView(initialScope: request.scope, initialMode: request.mode)
            }
            .appErrorAlert()
        }
        .sheet(isPresented: $showAnalysis, onDismiss: {
            chrome.reveal()
            // port UI lab §5.7: Lưu xong → về Hub bộ vừa lưu (kể cả kho tạm).
            // Đang đứng trên đúng hub đó → chỉ refresh (dataRevision bump), không push trùng.
            if let hubID = model.shell.pendingHubNavigationID {
                model.shell.pendingHubNavigationID = nil
                if model.shell.shutterTargetCollectionID != hubID {
                    selectedTab = .today
                    todayPath.append(.hub(hubID))
                }
            }
            // FR-04: ảnh mờ / không phải tiếng Anh → mở lại CaptureView.
            if model.capture.pendingRecapture {
                model.capture.pendingRecapture = false
                showCapture = true
            }
            // FR-21 GWT cuối: lỗi agent → nút "Mở Cài đặt" trong AnalysisView
            // bật cờ này; đưa thẳng về Hôm nay → push Settings.
            if model.shell.pendingSettingsNavigation {
                model.shell.pendingSettingsNavigation = false
                selectedTab = .today
                todayPath = [.settings]
            }
        }) {
            NavigationStack { AnalysisView() }
        }
        .onAppear {
            model.reloadOverview()
            #if DEBUG
            applyDebugScreenIfNeeded()
            #endif
        }
        .appErrorAlert()
    }

    private func dismissBanner() {
        banner = nil
    }

    /// Bấm lại tab đang đứng → pop stack về root (Hôm nay / Thư viện).
    private func popSelectedTabToRoot(_ tab: AppTab) {
        switch tab {
        case .today: todayPath = []
        case .library: libraryPath = []
        }
    }

    /// Mở chụp từ nút chụp trong thanh tab — đích = bộ hub đang mở (nếu có), không thì kho tạm.
    private func openShutterCapture() {
        // port UI lab §9: haptic lúc chụp.
        Haptics.action()
        model.capture.analysisTargetCollectionID = model.shell.shutterTargetCollectionID
        showCapture = true
    }

    /// Nút chụp chỉ hiện trên "bề mặt chụp": root hai tab và Hub. Ẩn trên lịch streak,
    /// cài đặt, dữ liệu và phiên đọc (đang đọc).
    private var showsCaptureButton: Bool {
        if model.shell.suppressFloatShutter { return false }
        switch selectedTab {
        case .today: return isCaptureSurface(todayPath)
        case .library: return isCaptureSurface(libraryPath)
        }
    }

    /// Root (path rỗng) hoặc đang mở 1 Hub = còn trên bề mặt chụp. Bất kỳ route
    /// khác (streak / settings / data) = vào sâu, ẩn nút chụp.
    private func isCaptureSurface(_ path: [ShellRoute]) -> Bool {
        if path.isEmpty { return true }
        if path.count == 1, case .hub = path[0] { return true }
        return false
    }

    #if DEBUG
    /// verify-nav-r1 — `-ReadoScreen …` (`DebugLaunch`, `scripts/sim_screens.sh
    /// open`) để agent mở thẳng một màn và chụp, không cần chạm tay. `problems`
    /// (key lạ/thiếu value) hoặc `collection:` không khớp bộ nào → alert, không
    /// bao giờ âm thầm đứng im ở Home.
    private func applyDebugScreenIfNeeded() {
        let launch = DebugLaunch.parse(ProcessInfo.processInfo.arguments)
        guard let screen = launch.screen else {
            if let problem = launch.problems.first {
                model.alertMessage = "Launch arg lạ: \(problem)"
            }
            return
        }
        switch screen {
        case .home:
            selectedTab = .today
        case .library:
            selectedTab = .library
        case .review:
            reviewRequest = ReviewRequest(scope: model.reviewScopeDefault.scopeSet, mode: .srs)
        case .reviewExtra:
            reviewRequest = ReviewRequest(scope: model.reviewScopeDefault.scopeSet, mode: .extra)
        case let .collection(key):
            guard let match = model.collections.first(where: { $0.id == key || $0.name == key })
            else {
                model.alertMessage = "Launch arg lạ: không thấy bộ '\(key)'"
                return
            }
            selectedTab = .library
            libraryPath = [.hub(match.id)]
        case .settings:
            selectedTab = .today
            todayPath = [.settings]
        case .streak:
            selectedTab = .today
            todayPath = [.streak]
        case .data:
            selectedTab = .library
            libraryPath = [.data]
        case .capture:
            openShutterCapture()
        case .analysisFixture:
            openDebugAnalysisFixture()
        case .encounterSheet:
            model.shell.debugOpenFirstEncounter = true
            openDebugAnalysisFixture()
        case .saveBanner:
            selectedTab = .today
            Motion.run(reduceMotion: reduceMotion) {
                banner = ShellBannerItem(
                    message: "Đã lưu 8 từ vào Kho tạm", actionTitle: "Xem", autoHides: false)
            }
        }
        if let alert = launch.alert {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                applyDebugAlert(alert)
            }
        }
    }

    private func applyDebugAlert(_ alert: DebugLaunch.Alert) {
        switch alert {
        case .dupName:
            _ = model.createCollectionOrAlert(name: Seeder.defaultCollectionName)
        case .pinLimit:
            model.debugTriggerPinLimitAlert()
        }
    }

    /// verify-nav-r1 T2 — đọc JSON tĩnh (`READO_DEV_ANALYSIS_FIXTURE`,
    /// `scripts/fixtures/analysis-demo.json`) qua đúng decoder thật
    /// (`AnalysisResponseDecoder`) rồi mở thẳng màn "Duyệt & lưu từ vựng" —
    /// không cần OCR/agent thật. Lỗi đọc/parse → alert, không đứng im ở Home.
    private func openDebugAnalysisFixture() {
        guard let path = ProcessInfo.processInfo.environment["READO_DEV_ANALYSIS_FIXTURE"],
              let data = FileManager.default.contents(atPath: path)
        else {
            model.alertMessage = "Launch arg lạ: thiếu READO_DEV_ANALYSIS_FIXTURE"
            return
        }
        do {
            model.capture.analysisResult = try AnalysisResponseDecoder.decode(data)
            showAnalysis = true
        } catch {
            model.alertMessage = "Launch arg lạ: fixture phân tích lỗi — \(error.localizedDescription)"
        }
    }
    #endif

    /// Đích chung cho cả hai stack Hôm nay & Thư viện.
    @ViewBuilder
    private func shellDestination(_ route: ShellRoute) -> some View {
        switch route {
        case let .hub(collectionID):
            CollectionDetailView(collectionID: collectionID)
        case .streak:
            // J1: CTA "Chụp trang" ở màn này đích ngầm kho tạm — không set
            // `shutterTargetCollectionID` như `openShutterCapture` (đó là cho
            // nút chụp trên Hub, muốn đích = hub đang mở).
            StreakCalendarView(onCapture: {
                Haptics.action()
                model.capture.analysisTargetCollectionID = nil
                showCapture = true
            })
        case .settings:
            SettingsView()
        case .data:
            ExportView()
        }
    }
}