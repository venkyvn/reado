import ReadoKit
import SwiftUI
import UIKit

/// Tab gốc — port UI lab (2026-09-23): ba tab Home / Ôn / Kho thay cho
/// NavigationStack + modal sheet cũ. Capture/Analysis/Settings/Dữ liệu vẫn là
/// sheet phủ toàn tab; chụp nhanh bằng `FloatShutter` nổi (không tab Chụp).
enum AppTab: Hashable {
    case home
    case review
    case kho
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTab: AppTab = .home
    // port UI lab §5.7: sau Lưu → push Hub bộ vừa lưu lên Home stack.
    @State private var homePath = NavigationPath()
    @State private var showCapture = false
    @State private var showAnalysis = false
    @State private var showExport = false
    @State private var showSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeTabView(
                    onReview: { selectedTab = .review },
                    onSettings: { showSettings = true },
                    onData: { showExport = true })
                    .navigationDestination(for: String.self) { collectionID in
                        CollectionDetailView(collectionID: collectionID)
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                ReviewQueueView(showsCloseButton: false)
            }
            .tabItem { Label("Ôn", systemImage: "brain.head.profile") }
            .tag(AppTab.review)

            NavigationStack {
                KhoTabView()
                    .navigationDestination(for: String.self) { collectionID in
                        CollectionDetailView(collectionID: collectionID)
                    }
            }
            .tabItem { Label("Kho", systemImage: "archivebox") }
            .tag(AppTab.kho)
        }
        .overlay(alignment: .bottom) {
            // Shutter nổi trên Home / Kho và Hub; ẩn khi ở tab Ôn (đang lật thẻ).
            if selectedTab != .review {
                FloatShutter(action: openShutterCapture)
                    .padding(.bottom, 84)
            }
        }
        .sheet(isPresented: $showCapture, onDismiss: {
            // FR-02: chụp xong (đã có ảnh trong model) → mở màn phân tích.
            if model.lastCapturedImage != nil {
                showAnalysis = true
            }
        }) {
            NavigationStack { CaptureView() }
        }
        .sheet(isPresented: $showAnalysis, onDismiss: {
            // port UI lab §5.7: Lưu xong → về Hub bộ vừa lưu (kể cả kho tạm).
            // Đang đứng trên đúng hub đó → chỉ refresh (dataRevision bump), không push trùng.
            if let hubID = model.pendingHubNavigationID {
                model.pendingHubNavigationID = nil
                if model.shutterTargetCollectionID != hubID {
                    selectedTab = .home
                    homePath.append(hubID)
                }
            }
            // FR-04: ảnh mờ / không phải tiếng Anh → mở lại CaptureView.
            if model.pendingRecapture {
                model.pendingRecapture = false
                showCapture = true
            }
        }) {
            NavigationStack { AnalysisView() }
        }
        .sheet(isPresented: $showExport) {
            NavigationStack { ExportView() }
        }
        .sheet(isPresented: $showSettings, onDismiss: { model.reloadOverview() }) {
            NavigationStack { SettingsView() }
        }
        .onAppear { model.reloadOverview() }
    }

    /// Mở chụp từ shutter nổi — đích = bộ hub đang mở (nếu có), không thì kho tạm.
    private func openShutterCapture() {
        // port UI lab §9: haptic lúc chụp.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        model.analysisTargetCollectionID = model.shutterTargetCollectionID
        showCapture = true
    }
}

/// Nút chụp nổi — chỉ nút này dùng hình shutter tròn (máy ảnh thật = hệ thống).
private struct FloatShutter: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
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
        List {
            dailyProgressRows
            homePinRows
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
            // J-R1-P: ô Streak bấm được → Lịch streak (heatmap 18 tuần).
            NavigationLink {
                StreakCalendarView()
            } label: {
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
        if !model.homeShortcuts.isEmpty {
            Section("Đang đọc · \(model.homeShortcuts.count)/5") {
                ForEach(model.homeShortcuts) { collection in
                    NavigationLink(value: collection.id) {
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

    var body: some View {
        List {
            // Ôn nhanh — "tất cả" hoặc 1–3 bộ ưu tiên; nhãn phản ánh trạng thái.
            Section("Ôn nhanh") {
                Button {
                    model.setReviewAll(!model.reviewScopeDefault.reviewAll)
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

            Section("Collection") {
                ForEach(model.collections) { collection in
                    NavigationLink(value: collection.id) {
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
                    Label("Tạo collection", systemImage: "plus")
                }
                .accessibilityLabel("Tạo collection")
            }
        }
        .alert("Tạo collection", isPresented: $showNewCollection) {
            TextField("Tên collection", text: $newCollectionName)
            Button("Tạo") {
                _ = try? model.createCollection(name: newCollectionName)
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Từ chưa phân loại vào kho tạm; collection có tên để gom theo sách hoặc ngữ cảnh.")
        }
        .overlay {
            if model.collections.isEmpty {
                ContentUnavailableView(
                    "Chưa có collection",
                    systemImage: "books.vertical")
            }
        }
        .refreshable { model.reloadOverview() }
    }

    @ViewBuilder
    private func collectionRow(_ collection: AppModel.CollectionOverview) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(collection.name)
                    if collection.isDefault {
                        Text("Mặc định")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.surfaceStrong))
                    }
                    if model.homeShortcutIDs.contains(collection.id) {
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
            model.toggleReviewPriority(collection.id)
        } label: {
            Label(isPriority ? "Bỏ ôn" : "Ôn", systemImage: isPriority ? "bolt.slash" : "bolt")
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
            let isPinned = model.homeShortcutIDs.contains(collection.id)
            Button {
                model.togglePin(collection.id)
            } label: {
                Label(isPinned ? "Bỏ ghim" : "Ghim", systemImage: isPinned ? "pin.slash" : "pin")
            }
            .tint(isPinned ? .gray : .accentColor)
            .disabled(
                !isPinned && model.homeShortcutIDs.count >= HomePinService.maxPins)
        }
    }
}