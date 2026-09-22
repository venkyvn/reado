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
                // FR-11/12: CTA Ôn tập.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showReview = true
                    } label: {
                        Label("Ôn tập", systemImage: "brain.head.profile")
                    }
                    .accessibilityLabel("Ôn tập")
                }
                // FR-01: CTA Chụp trang + FR-15: Cài đặt học tập.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Cài đặt", systemImage: "gearshape")
                    }
                    .accessibilityLabel("Cài đặt")

                    Button {
                        showCapture = true
                    } label: {
                        Label("Chụp trang", systemImage: "camera.fill")
                    }
                    .accessibilityLabel("Chụp trang")
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
                    systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
            HStack(spacing: 12) {
                Label("\(progress.streak) ngày ôn liên tục", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(progress.pagesAnalyzed) trang đã phân tích")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowSeparator(.hidden)
        }
    }

    private var collectionList: some View {
        List {
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
                                                Color.accentColor.opacity(0.15)))
                                }
                            }
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
                                        Color.orange.opacity(0.18)))
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
    }
}

struct CollectionDetailView: View {
    let collectionID: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let overview = model.collections.first { $0.id == collectionID }
        List {
            if let overview {
                LabeledContent("Tổng số từ", value: "\(overview.totalItems)")
                LabeledContent("Đến hạn (scaffold)", value: "\(overview.dueNow)")
            }
        }
        .navigationTitle(overview?.name ?? "Collection")
        .onAppear { model.reloadOverview() }
    }
}
