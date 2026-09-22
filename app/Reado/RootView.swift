import ReadoKit
import SwiftUI

/// Màn hình gốc — Home shell tối thiểu theo ROADMAP 2.4–2.5:
/// - Tổng quan collection (due badge, default badge)
/// - CTA Ôn tập → ReviewQueueView (FR-11/12)
/// - CTA Chụp trang → CaptureView → AnalysisView (FR-01/02/03/09)
/// - CTA Dữ liệu → ExportView (FR-16, task 3.1)
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showCapture = false
    @State private var showAnalysis = false
    @State private var showReview = false
    @State private var showExport = false
    @State private var showSettings = false
    @State private var showNewCollection = false
    @State private var newCollectionName = ""

    var body: some View {
        NavigationStack {
            Group {
                if let failure = model.failure {
                    ContentUnavailableView {
                        Label("Không mở được dữ liệu", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(failure)
                    }
                } else {
                    collectionList
                }
            }
            .navigationTitle("Reado")
            .toolbar {
                // FR-15: CTA Cài đặt học tập (leading).
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Cài đặt", systemImage: "gearshape")
                    }
                    .accessibilityLabel("Cài đặt")
                }
                // FR-17 tạo collection + J-R1-D cửa Dữ liệu — CTA thứ cấp gom về
                // một hàng trailing, nhường đáy cho CTA chính "Chụp trang".
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showExport = true
                    } label: {
                        Label("Dữ liệu", systemImage: "archivebox")
                    }
                    .accessibilityLabel("Dữ liệu")

                    Button {
                        newCollectionName = ""
                        showNewCollection = true
                    } label: {
                        Label("Tạo collection", systemImage: "folder.badge.plus")
                    }
                    .accessibilityLabel("Tạo collection")
                }
            }
            .alert("Tạo collection", isPresented: $showNewCollection) {
                TextField("Tên collection", text: $newCollectionName)
                Button("Tạo") { createNewCollection() }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Từ chưa phân loại vào kho tạm; collection có tên để gom theo sách hoặc ngữ cảnh.")
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
                // FR-04: ảnh mờ / không phải tiếng Anh → mở lại CaptureView để
                // chụp ảnh khác (retry cùng ảnh vô nghĩa).
                if model.pendingRecapture {
                    model.pendingRecapture = false
                    showCapture = true
                }
            }) {
                NavigationStack { AnalysisView() }
            }
            .sheet(isPresented: $showReview, onDismiss: { model.reloadOverview() }) {
                NavigationStack { ReviewQueueView() }
            }
            .sheet(isPresented: $showExport) {
                NavigationStack { ExportView() }
            }
            .sheet(isPresented: $showSettings, onDismiss: { model.reloadOverview() }) {
                NavigationStack { SettingsView() }
            }
            .navigationDestination(for: String.self) { collectionID in
                CollectionDetailView(collectionID: collectionID)
            }
            .onAppear { model.reloadOverview() }
            .refreshable { model.reloadOverview() }
        }
    }

    // FR-14: tổng quan Daily Progress — "sẽ ôn hôm nay" theo hạn mức (FR-11),
    // tồn đọng RIÊNG, streak theo giờ chuyển ngày. Không tổng due_at thô.
    @ViewBuilder
    private var dailyProgressRows: some View {
        if let progress = model.dailyProgress {
            if progress.dueToday > 0 {
                Button {
                    showReview = true
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

    // FR-17: tối đa 2 collection "đang đọc" ghim trên Home — mở thẳng Collection
    // Hub. Thứ tự = thứ tự slot; shortcut trỏ vào collection đã xoá đã bị bỏ
    // (đã `compactMap` trong `model.homeShortcuts`).
    @ViewBuilder
    private var homeShortcutRows: some View {
        if !model.homeShortcuts.isEmpty {
            Section("Đang đọc trên Home") {
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

    private var collectionList: some View {
        List {
            homeShortcutRows
            dailyProgressRows

            ForEach(model.collections) { collection in
                NavigationLink(value: collection.id) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(collection.name)
                                if collection.isDefault {
                                    Text("Mặc định")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(
                                                Theme.surfaceStrong))
                                }
                            }
                            Text("\(collection.totalItems) từ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let lastAddedAt = collection.lastAddedAt {
                                Text(
                                    "Thêm gần nhất "
                                        + lastAddedAt.formatted(
                                            date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
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
        .overlay {
            if model.collections.isEmpty {
                ContentUnavailableView(
                    "Chưa có collection",
                    systemImage: "books.vertical")
            }
        }
        // FR-01: CTA chính "Chụp trang" nổi bật dưới đáy (J1 ≤3 thao tác), thay
        // cho icon camera nhỏ trên toolbar.
        .safeAreaInset(edge: .bottom) { captureCTA }
    }

    /// FR-01: CTA chính "Chụp trang" — nút nổi toàn bề ngang dưới đáy (màu accent).
    private var captureCTA: some View {
        Button {
            showCapture = true
        } label: {
            Label("Chụp trang", systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    /// FR-17: tạo collection có tên từ alert trên Home. Tên rỗng/trùng → giữ
    /// nguyên, không tạo (Repository trả nil).
    private func createNewCollection() {
        _ = try? model.createCollection(name: newCollectionName)
        newCollectionName = ""
    }
}
