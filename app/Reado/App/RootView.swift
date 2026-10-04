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
    /// FR-19 (home-eevas-r1 T3): màn "Từ hay quên" — danh sách card leech.
    case leeches
    /// FR-08 (home-eevas-r1 T4): tìm từ xuyên mọi collection.
    case search
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: AppTab = .today
    // Stack riêng mỗi tab: Hôm nay (Cài đặt, Lịch streak, Hub) và Thư viện (Hub, Dữ liệu).
    @State private var todayPath: [ShellRoute] = []
    @State private var libraryPath: [ShellRoute] = []
    @State private var showCapture = false
    @State private var showAnalysis = false
    // ux-redesign-r1 T1a: phiên ôn toàn màn — nil = đóng.
    @State private var reviewRequest: ReviewRequest?
    // ux-redesign-r1 T2/T5a: banner không chặn ở đáy (ADR-053) — hiện sau Lưu; màn debug
    // `save-banner` cũng đặt nó. `bannerHubID` = Hub mà nút "Xem" mở (nil = banner không có đích).
    @State private var banner: ShellBannerItem?
    @State private var bannerHubID: String?
    // ux-redesign-r1 T9: chụp khi chưa có agent chạy được → mở form thêm agent thay vì camera.
    @State private var showAgentSetup = false
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
                LibraryTabView(onData: { libraryPath.append(.data) })
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
                ShellBanner(item: banner, onAction: openBannerHub, onDismiss: dismissBanner)
                    .padding(.horizontal, Spacing.md)
                    // Khe giữa banner và thanh tab: đã đo bằng ảnh (`open save-banner`) — thoáng,
                    // không chạm thanh tab, không hở quá. Giữ Spacing.sm.
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
        // camera. Không bọc NavigationStack: CaptureView tự có chrome (X + chọn bộ).
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
            // Màn ôn rỗng → "Chụp trang" (T7): cover ôn đã đóng hẳn mới mở camera.
            if model.shell.pendingCaptureAfterReview {
                model.shell.pendingCaptureAfterReview = false
                openShutterCapture()
            }
        }) { request in
            NavigationStack {
                ReviewQueueView(initialScope: request.scope, initialMode: request.mode)
            }
            .appErrorAlert()
        }
        .sheet(isPresented: $showAnalysis, onDismiss: {
            chrome.reveal()
            // ADR-053: Lưu xong → ở NGUYÊN chỗ đang đứng, chỉ hiện banner "Đã lưu N từ vào X · Xem"
            // (không đổi tab, không alert chặn). "Xem" mở Hub bộ vừa lưu, xem `openBannerHub`.
            if let saved = model.shell.saveConfirmation {
                model.shell.saveConfirmation = nil
                Motion.run(reduceMotion: reduceMotion) {
                    bannerHubID = saved.collectionID
                    banner = ShellBannerItem(
                        message: "Đã lưu \(saved.count) từ vào \(saved.collectionName)",
                        actionTitle: "Xem")
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
        // T9: phòng lỗi trước — không để người dùng chụp xong rồi mới biết thiếu agent. Nối agent xong thì
        // tiếp tục việc đang làm dở (mở camera) thay vì bắt bấm lại; huỷ form thì ở nguyên chỗ.
        .sheet(isPresented: $showAgentSetup, onDismiss: {
            if model.activeAgentReady { openShutterCapture() }
        }) {
            AgentFormSheet(agent: nil) { name, base, modelName, key in
                model.addAgent(name: name, baseURL: base, model: modelName, apiKey: key)
            }
            .appErrorAlert()
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
        bannerHubID = nil
    }

    /// Nút "Xem" của banner sau Lưu: mở Hub bộ vừa lưu NGAY trên stack của tab đang đứng (không đổi tab).
    private func openBannerHub() {
        let hubID = bannerHubID
        dismissBanner()
        guard let hubID else { return }
        switch selectedTab {
        case .today: todayPath = pathShowingHub(hubID, in: todayPath)
        case .library: libraryPath = pathShowingHub(hubID, in: libraryPath)
        }
    }

    /// Đang ở đúng Hub đó → giữ nguyên (đã tự refresh qua `dataRevision`). Đang ở Hub của bộ khác
    /// (path đúng 1 phần tử) → thay bằng Hub mới, không chồng hub lên hub (nút chụp chỉ hiện khi
    /// path rỗng hoặc đúng 1 Hub). Còn lại thì đẩy thêm.
    private func pathShowingHub(_ hubID: String, in path: [ShellRoute]) -> [ShellRoute] {
        if let last = path.last, last == .hub(hubID) { return path }
        if path.count == 1, case .hub = path[0] { return [.hub(hubID)] }
        return path + [.hub(hubID)]
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
        openCapture(targetCollectionID: model.shell.shutterTargetCollectionID)
    }

    /// Cửa chung mọi đường vào camera. Chưa có agent chạy được (J1: phòng lỗi trước, Nielsen #5) →
    /// form thêm agent, không mở camera rồi mới báo lỗi sau khi chụp.
    private func openCapture(targetCollectionID: String?) {
        guard model.activeAgentReady else {
            showAgentSetup = true
            return
        }
        // port UI lab §9: haptic lúc chụp.
        Haptics.action()
        model.capture.analysisTargetCollectionID = targetCollectionID
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
        case .leeches:
            selectedTab = .today
            todayPath = [.leeches]
        case .search:
            selectedTab = .today
            todayPath = [.search]
        case .capture:
            // Bỏ qua kiểm agent: chụp được màn camera kể cả `--seed empty` (chưa có agent).
            model.capture.analysisTargetCollectionID = model.shell.shutterTargetCollectionID
            showCapture = true
        case .analysisFixture:
            openDebugAnalysisFixture()
        case .analysisFixturePage:
            model.shell.debugShowAnalysisPage = true
            openDebugAnalysisFixture()
        case .encounterSheet:
            model.shell.debugOpenFirstEncounter = true
            openDebugAnalysisFixture()
        case .phraseHighlight:
            model.shell.debugShowAnalysisPage = true
            model.shell.debugActivateFirstPhrase = true
            openDebugAnalysisFixture()
        case .analysisFixtureMature:
            model.shell.debugExpandMatureHidden = true
            openDebugAnalysisFixture()
        case .saveBanner:
            selectedTab = .today
            bannerHubID = model.collections.first(where: { $0.isDefault })?.id
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
            StreakCalendarView(onCapture: { openCapture(targetCollectionID: nil) })
        case .settings:
            SettingsView()
        case .data:
            ExportView()
        case .leeches:
            LeechListView()
        case .search:
            VocabSearchView()
        }
    }
}