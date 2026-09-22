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
                // FR-01: CTA Chụp trang.
                ToolbarItem(placement: .topBarTrailing) {
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
            .sheet(isPresented: $showReview) {
                NavigationStack { ReviewQueueView() }
            }
            .sheet(isPresented: $showExport) {
                NavigationStack { ExportView() }
            }
            .navigationDestination(for: String.self) { collectionID in
                CollectionDetailView(collectionID: collectionID)
            }
            .onAppear { model.reloadOverview() }
            .refreshable { model.reloadOverview() }
        }
    }

    private var collectionList: some View {
        List {
            // FR-11/12: Hàng đợi hôm nay — tổng quan nhanh.
            let totalDue = model.collections.map(\.dueNow).reduce(0, +)
            if totalDue > 0 {
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
                            Text("\(totalDue) thẻ đến hạn")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .listRowSeparator(.hidden)
            }

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
