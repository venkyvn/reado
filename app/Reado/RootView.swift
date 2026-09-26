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
private enum ShellRoute: Hashable {
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

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeTabView(
                    onReview: { selectedTab = .review },
                    onSettings: { homePath.append(.settings) },
                    onData: { homePath.append(.data) })
                    .navigationDestination(for: ShellRoute.self) {
                        shellDestination($0)
                    }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
            .tag(AppTab.home)

            NavigationStack {
                ReviewQueueView(showsCloseButton: false)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ShellTabBar(selection: $selectedTab, onReselect: popSelectedTabToRoot)
        }
        // ADR-036: fullScreenCover (không sheet) — CaptureView tự vẽ full-bleed
        // đen; sheet để lộ viền bo góc + không che hết status bar, không hợp
        // camera. Không bọc NavigationStack: CaptureView tự có chrome (X/dest/+).
        .fullScreenCover(isPresented: $showCapture, onDismiss: {
            // FR-02: chụp xong (đã có ảnh trong model) → mở màn phân tích.
            if model.lastCapturedImage != nil {
                showAnalysis = true
            }
        }) {
            CaptureView()
        }
        .sheet(isPresented: $showAnalysis, onDismiss: {
            // port UI lab §5.7: Lưu xong → về Hub bộ vừa lưu (kể cả kho tạm).
            // Đang đứng trên đúng hub đó → chỉ refresh (dataRevision bump), không push trùng.
            if let hubID = model.pendingHubNavigationID {
                model.pendingHubNavigationID = nil
                if model.shutterTargetCollectionID != hubID {
                    selectedTab = .home
                    homePath.append(.hub(hubID))
                }
            }
            // FR-04: ảnh mờ / không phải tiếng Anh → mở lại CaptureView.
            if model.pendingRecapture {
                model.pendingRecapture = false
                showCapture = true
            }
            // FR-21 GWT cuối: lỗi agent → nút "Mở Cài đặt" trong AnalysisView
            // bật cờ này; đưa thẳng về Home → push Settings.
            if model.pendingSettingsNavigation {
                model.pendingSettingsNavigation = false
                selectedTab = .home
                homePath = [.settings]
            }
        }) {
            NavigationStack { AnalysisView() }
        }
        .onAppear { model.reloadOverview() }
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
        model.analysisTargetCollectionID = model.shutterTargetCollectionID
        showCapture = true
    }

    /// Shutter nổi chỉ hiện trên "bề mặt chụp": root Home, root Kho và Hub. Ẩn
    /// trên tab Ôn, lịch streak và phiên đọc (đang đọc, đang lật thẻ).
    private var showShutter: Bool {
        if model.suppressFloatShutter { return false }
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

    /// Đích chung cho cả hai stack Home & Kho.
    @ViewBuilder
    private func shellDestination(_ route: ShellRoute) -> some View {
        switch route {
        case let .hub(collectionID):
            CollectionDetailView(collectionID: collectionID)
        case .streak:
            StreakCalendarView()
        case .settings:
            SettingsView()
        case .data:
            ExportView()
        }
    }
}

/// Nút chụp nổi — chỉ nút này dùng hình shutter tròn (máy ảnh thật = hệ thống).
private struct FloatShutter: View {
    static let size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ShutterPressStyle())
        .accessibilityLabel("Chụp trang")
    }
}

/// port UI lab §9: shutter thu nhỏ nhẹ khi nhấn, bật trở lại bằng spring.
private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(
                .spring(response: 0.32, dampingFraction: 0.86),
                value: configuration.isPressed)
    }
}

/// Home tab — tổng quan: Ôn hôm nay → kho tạm (shortcut) → Streak → Đang đọc.
/// Không còn CTA "Chụp trang" to dưới đáy (đã chuyển thành shutter nổi).
private struct HomeTabView: View {
    @Environment(AppModel.self) private var model
    let onReview: () -> Void
    let onSettings: () -> Void
    let onData: () -> Void

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
        .navigationTitle("Reado")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onSettings) {
                    Label("Cài đặt", systemImage: "gearshape")
                }
                .accessibilityLabel("Cài đặt")
            }
            // J-R1-D: cửa Dữ liệu giữ icon tray trên Home (không tab thứ 4).
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onData) {
                    Label("Dữ liệu", systemImage: "archivebox")
                }
                .accessibilityLabel("Dữ liệu")
            }
        }
    }

    private var homeList: some View {
        List {
            dailyProgressRows
            inboxRow
            streakRow
            homePinRows
        }
        .refreshable { model.reloadOverview() }
    }

    // FR-14: tổng quan Daily Progress — "sẽ ôn hôm nay" theo hạn mức (FR-11),
    // tồn đọng RIÊNG, streak theo giờ chuyển ngày. Không tổng due_at thô.
    @ViewBuilder
    private var dailyProgressRows: some View {
        if let progress = model.dailyProgress {
            if progress.dueToday > 0 {
                Button {
                    onReview()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ôn tập hôm nay")
                                .font(.headline)
                            Text("\(progress.dueToday) thẻ sẽ ôn")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .listRowSeparator(.hidden)
            } else if progress.backlog > 0 {
                // FR-14: hết hạn mức hôm nay — tồn đọng hiện RIÊNG, không CTA giả.
                Label(
                    "Đã hết hạn mức hôm nay · \(progress.backlog) thẻ mới đang chờ",
                    systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
        }
    }

    /// Kho tạm luôn hiện trên Home (kể cả khi `dailyProgress` nil) — mở thẳng hub
    /// kho tạm. Không nằm trong `homePins` và không tính vào k/5 (không nút ghim).
    @ViewBuilder
    private var inboxRow: some View {
        if let inbox = model.collections.first(where: \.isDefault) {
            NavigationLink(value: ShellRoute.hub(inbox.id)) {
                HStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(inbox.name)
                            .font(.headline)
                        Text("\(inbox.totalItems) từ · trang chưa phân loại")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if inbox.dueNow > 0 {
                        Text("\(inbox.dueNow)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.due.opacity(0.18)))
                    }
                }
            }
            .listRowSeparator(.hidden)
        }
    }

    /// Ô Streak bấm được → Lịch streak (heatmap 18 tuần). Tách khỏi
    /// `dailyProgressRows` để đứng sau hàng kho tạm; vẫn cần `dailyProgress`
    /// nên ẩn khi nil.
    @ViewBuilder
    private var streakRow: some View {
        if let progress = model.dailyProgress {
            NavigationLink(value: ShellRoute.streak) {
                HStack(spacing: 12) {
                    Label("\(progress.streak) ngày ôn liên tục", systemImage: "flame.fill")
                        .foregroundStyle(Theme.due)
                    Spacer()
                    Text("\(progress.pagesAnalyzed) trang đã phân tích")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowSeparator(.hidden)
        }
    }

    // Pin Home — "Đang đọc" tối đa 5 (port UI lab), mở thẳng Collection Hub.
    @ViewBuilder
    private var homePinRows: some View {
        if !model.homePins.isEmpty {
            Section("Đang đọc · \(model.homePins.count)/5") {
                ForEach(model.homePins) { collection in
                    NavigationLink(value: ShellRoute.hub(collection.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: "pin")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(collection.name)
                                Text("\(collection.totalItems) từ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if collection.dueNow > 0 {
                                Text("\(collection.dueNow)")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(
                                            Theme.due.opacity(0.18)))
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Kho tab — toàn bộ collection (kho tạm + named) + tạo mới từ `+` nav.
private struct KhoTabView: View {
    @Environment(AppModel.self) private var model

    @State private var showNewCollection = false
    @State private var newCollectionName = ""
    // Lỗi từ swipe ghim/ôn nhanh hoặc ô "Ôn nhanh" — hiện alert thay vì nuốt.
    @State private var actionError: String?

    var body: some View {
        List {
            // Ôn nhanh — "tất cả" hoặc 1–3 bộ ưu tiên; nhãn phản ánh trạng thái.
            Section("Ôn nhanh") {
                Button {
                    run { try model.setReviewAll(!model.reviewScopeDefault.reviewAll) }
                } label: {
                    HStack {
                        Label(
                            model.reviewScopeDefault.reviewAll
                                ? "Tất cả kho"
                                : (model.reviewScopeDefault.priorityIDs.isEmpty
                                    ? "Tất cả kho"
                                    : "\(model.reviewScopeDefault.priorityIDs.count)/3 bộ ưu tiên"),
                            systemImage: "square.stack.3d.up")
                            .foregroundStyle(.primary)
                        Spacer()
                        if model.reviewScopeDefault.reviewAll {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            Section("Bộ") {
                ForEach(model.collections) { collection in
                    NavigationLink(value: ShellRoute.hub(collection.id)) {
                        collectionRow(collection)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        reviewSwipe(collection)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        pinSwipe(collection)
                    }
                }
            }
        }
        .navigationTitle("Kho")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newCollectionName = ""
                    showNewCollection = true
                } label: {
                    Label("Tạo bộ", systemImage: "plus")
                }
                .accessibilityLabel("Tạo bộ")
            }
        }
        .alert("Tạo bộ", isPresented: $showNewCollection) {
            TextField("Tên bộ", text: $newCollectionName)
            Button("Tạo") {
                _ = try? model.createCollection(name: newCollectionName)
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Từ chưa phân loại vào kho tạm; đặt tên bộ để gom theo sách hoặc ngữ cảnh.")
        }
        .alert(
            "Không thực hiện được",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } })
        ) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .overlay {
            if model.collections.isEmpty {
                ContentUnavailableView(
                    "Chưa có bộ",
                    systemImage: "books.vertical")
            }
        }
        .refreshable { model.reloadOverview() }
    }

    /// Chạy một hành động ném lỗi (ghim/ôn nhanh) — lỗi đổ vào `actionError` để
    /// alert hiện, không nuốt im (port UI lab: "không thêm toast framework").
    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            actionError = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
        }
    }

    @ViewBuilder
    private func collectionRow(_ collection: AppModel.CollectionOverview) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(collection.name)
                    if model.homePinIDs.contains(collection.id) {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text("\(collection.totalItems) từ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let order = model.reviewScopeDefault.priorityIDs.firstIndex(of: collection.id) {
                Text("\(order + 1)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }
            if collection.dueNow > 0 {
                Text("\(collection.dueNow)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.due.opacity(0.18)))
            }
        }
    }

    /// Vuốt trái → bật/tắt "Ôn nhanh" (tối đa 3). Đủ 3 mà chưa chọn → vô hiệu.
    @ViewBuilder
    private func reviewSwipe(_ collection: AppModel.CollectionOverview) -> some View {
        let isPriority = model.reviewScopeDefault.priorityIDs.contains(collection.id)
        Button {
            run { try model.toggleReviewPriority(collection.id) }
        } label: {
            Label(isPriority ? "Bỏ ưu tiên" : "Ưu tiên", systemImage: isPriority ? "bolt.slash" : "bolt")
        }
        .tint(isPriority ? .gray : .indigo)
        .disabled(
            !isPriority
                && model.reviewScopeDefault.priorityIDs.count >= ReviewScopeService.maxPriority)
    }

    /// Vuốt phải → bật/tắt Ghim (tối đa 5, ẩn trên kho tạm).
    @ViewBuilder
    private func pinSwipe(_ collection: AppModel.CollectionOverview) -> some View {
        if !collection.isDefault {
            let isPinned = model.homePinIDs.contains(collection.id)
            Button {
                run { try model.togglePin(collection.id) }
            } label: {
                Label(isPinned ? "Bỏ ghim" : "Ghim", systemImage: isPinned ? "pin.slash" : "pin")
            }
            .tint(isPinned ? .gray : .accentColor)
            .disabled(
                !isPinned && model.homePinIDs.count >= HomePinService.maxPins)
        }
    }
}