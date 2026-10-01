import ReadoKit
import SwiftUI

/// Tab gốc — port UI lab (2026-09-23): ba tab Home / Ôn / Kho thay cho
/// NavigationStack + modal sheet cũ. Capture/Analysis vẫn là sheet phủ toàn
/// tab; Cài đặt/Dữ liệu là push trên Home. Chụp nhanh bằng `FloatShutter` nổi
/// (không tab Chụp). Thanh tab = `ShellTabBar` capsule, ẩn native tab bar.
enum AppTab: Hashable, CaseIterable {
    case home
    case review
    case kho

    var title: String {
        switch self {
        case .home: "Home"
        case .review: "Ôn"
        case .kho: "Kho"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .review: "brain.head.profile"
        case .kho: "archivebox"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: "house.fill"
        case .review: "brain.head.profile.fill"
        case .kho: "archivebox.fill"
        }
    }
}

/// Route đẩy vào NavigationStack của Home/Kho — để FloatShutter biết đang đứng
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
    @State private var selectedTab: AppTab = .home
    // port UI lab §5.7: sau Lưu → push Hub bộ vừa lưu lên Home stack.
    @State private var homePath: [ShellRoute] = []
    @State private var khoPath: [ShellRoute] = []
    @State private var showCapture = false
    @State private var showAnalysis = false
    // T3a shell-chrome-r1: ẩn thanh tab + shutter khi cuộn xuống.
    @State private var chrome = ShellChrome()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeTabView(
                    onReview: { selectedTab = .review },
                    onSettings: { homePath.append(.settings) },
                    onData: { homePath.append(.data) },
                    onCapture: openShutterCapture,
                    onReviewExtra: {
                        model.shell.pendingReviewMode = .extra
                        selectedTab = .review
                    })
                    .navigationDestination(for: ShellRoute.self) {
                        shellDestination($0)
                    }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
            .tag(AppTab.home)

            NavigationStack {
                // Tab Ôn không nằm trong path push nào — `safeAreaInset` của
                // ShellTabBar trên TabView không lan tới đây (đo bằng screenshot,
                // T2 shell-chrome-r1): tự chừa khe bằng đúng chiều cao capsule.
                ReviewQueueView(showsCloseButton: false)
                    .safeAreaPadding(.bottom, ShellTabBar.reservedHeight)
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .tabItem { Label(AppTab.review.title, systemImage: AppTab.review.icon) }
            .tag(AppTab.review)

            NavigationStack(path: $khoPath) {
                KhoTabView()
                    .navigationDestination(for: ShellRoute.self) {
                        shellDestination($0)
                    }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .tabItem { Label(AppTab.kho.title, systemImage: AppTab.kho.icon) }
            .tag(AppTab.kho)
        }
        .environment(chrome)
        .onChange(of: selectedTab) { chrome.reveal() }
        .onChange(of: homePath) { chrome.reveal() }
        .onChange(of: khoPath) { chrome.reveal() }
        .overlay(alignment: .bottom) {
            // Shutter nổi trên Home / Kho root và Hub; ẩn trên Ôn, lịch streak và
            // phiên đọc (port UI lab §10). Overlay (không inset) để không đẩy list.
            // ĐÃ ĐO BẰNG SCREENSHOT (không phải suy luận): dù overlay đứng TRƯỚC
            // `safeAreaInset` bên dưới, `.safeAreaPadding(.bottom)` vẫn đọc safe
            // area MÔI TRƯỜNG — safe area này do `safeAreaInset` gán cho CẢ SUBTREE
            // (kể cả overlay attach trước nó trong chain), nên đã gồm sẵn toàn bộ
            // chiều cao ShellTabBar (không chỉ home indicator như comment cũ tưởng).
            // Cộng thêm `shutterLift` (= height+outerBottomPadding+shutterGap) lên
            // trên safeAreaPadding là cộng trùng — đo được nút cao hơn capsule tới
            // ~100pt. Giữ đúng safeAreaPadding, chỉ cộng thêm khe hở nhỏ.
            if showShutter {
                FloatShutter(action: openShutterCapture)
                    .padding(.bottom, ShellTabBar.shutterGap)
                    .safeAreaPadding(.bottom)
                    // Scale nhẹ: nút tròn nở ra tại chỗ, không trượt lên như nội dung.
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: showShutter)
        .animation(reduceMotion ? nil : Motion.reveal, value: chrome.isHidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ShellTabBar(
                selection: $selectedTab,
                onReselect: popSelectedTabToRoot,
                isHidden: chrome.isHidden)
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
        .sheet(isPresented: $showAnalysis, onDismiss: {
            chrome.reveal()
            // port UI lab §5.7: Lưu xong → về Hub bộ vừa lưu (kể cả kho tạm).
            // Đang đứng trên đúng hub đó → chỉ refresh (dataRevision bump), không push trùng.
            if let hubID = model.shell.pendingHubNavigationID {
                model.shell.pendingHubNavigationID = nil
                if model.shell.shutterTargetCollectionID != hubID {
                    selectedTab = .home
                    homePath.append(.hub(hubID))
                }
            }
            // FR-04: ảnh mờ / không phải tiếng Anh → mở lại CaptureView.
            if model.capture.pendingRecapture {
                model.capture.pendingRecapture = false
                showCapture = true
            }
            // FR-21 GWT cuối: lỗi agent → nút "Mở Cài đặt" trong AnalysisView
            // bật cờ này; đưa thẳng về Home → push Settings.
            if model.shell.pendingSettingsNavigation {
                model.shell.pendingSettingsNavigation = false
                selectedTab = .home
                homePath = [.settings]
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

    /// Bấm lại tab đang đứng → pop stack về root (Home / Kho). Tab Ôn không có path.
    private func popSelectedTabToRoot(_ tab: AppTab) {
        switch tab {
        case .home: homePath = []
        case .kho: khoPath = []
        case .review: break
        }
    }

    /// Mở chụp từ shutter nổi — đích = bộ hub đang mở (nếu có), không thì kho tạm.
    private func openShutterCapture() {
        // port UI lab §9: haptic lúc chụp.
        Haptics.action()
        model.capture.analysisTargetCollectionID = model.shell.shutterTargetCollectionID
        showCapture = true
    }

    /// Shutter nổi chỉ hiện trên "bề mặt chụp": root Home, root Kho và Hub. Ẩn
    /// trên tab Ôn, lịch streak và phiên đọc (đang đọc, đang lật thẻ).
    private var showShutter: Bool {
        if chrome.isHidden { return false }
        if model.shell.suppressFloatShutter { return false }
        switch selectedTab {
        case .review: return false
        case .home: return isCaptureSurface(homePath)
        case .kho: return isCaptureSurface(khoPath)
        }
    }

    /// Root (path rỗng) hoặc đang mở 1 Hub = còn trên bề mặt chụp. Bất kỳ route
    /// khác (streak / settings / data) = vào sâu, ẩn shutter.
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
            selectedTab = .home
        case .kho:
            selectedTab = .kho
        case .review:
            selectedTab = .review
        case .reviewExtra:
            model.shell.pendingReviewMode = .extra
            selectedTab = .review
        case let .collection(key):
            guard let match = model.collections.first(where: { $0.id == key || $0.name == key })
            else {
                model.alertMessage = "Launch arg lạ: không thấy bộ '\(key)'"
                return
            }
            selectedTab = .kho
            khoPath = [.hub(match.id)]
        case .settings:
            selectedTab = .home
            homePath = [.settings]
        case .streak:
            selectedTab = .home
            homePath = [.streak]
        case .data:
            selectedTab = .home
            homePath = [.data]
        case .capture:
            openShutterCapture()
        case .analysisFixture:
            openDebugAnalysisFixture()
        case .encounterSheet:
            model.shell.debugOpenFirstEncounter = true
            openDebugAnalysisFixture()
        }
        if let alert = launch.alert {
            guard screen != .analysisFixture, screen != .encounterSheet else {
                // BUG CÓ SẴN (phát hiện lúc verify-nav-r1 T2, không phải lỗi
                // DebugLaunch): `RootView` và sheet (`AnalysisView`) cùng gắn
                // `.appErrorAlert()` trên CÙNG `model.alertMessage`. Set alert
                // trong lúc sheet đang mở — bất kể đồng bộ hay trễ bao lâu
                // (đã thử 0ms và 1.5s, cùng kết quả) — UIKit coi RootView
                // "already presenting" (log `com.apple.UIKit:Presentation`,
                // "Attempt to present ... which is already presenting ..."),
                // huỷ CẢ sheet lẫn alert vì cả hai cùng mount trên một Binding —
                // kể cả set CHÍNH alertMessage cảnh báo này cũng dính cùng lỗi
                // (đã thử, sheet biến mất) nên bỏ qua trong im lặng, không set
                // alertMessage ở đây. Ghi vào `docs/session-brief.md` §2 cho
                // owner — KHÔNG sửa `ErrorAlert.swift` ở task này (ngoài scope).
                return
            }
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

    /// Đích chung cho cả hai stack Home & Kho.
    @ViewBuilder
    private func shellDestination(_ route: ShellRoute) -> some View {
        switch route {
        case let .hub(collectionID):
            CollectionDetailView(collectionID: collectionID)
        case .streak:
            // J1: CTA "Chụp trang" ở màn này đích ngầm kho tạm — không set
            // `shutterTargetCollectionID` như `openShutterCapture` (đó là cho
            // FloatShutter trên Hub, muốn đích = hub đang mở).
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