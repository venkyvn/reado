import ReadoKit
import SwiftUI

/// Màn hình gốc — scaffold cho ROADMAP task 1.2: chứng minh vòng nối
/// SQLite (migration + seed) → SwiftUI. Chưa phải FR nào; chi tiết UI
/// theo customer-journeys sẽ làm ở walking skeleton.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showCapture = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCapture = true
                    } label: {
                        Label("Chụp trang", systemImage: "camera.fill")
                    }
                    .accessibilityLabel("Chụp trang")
                }
            }
            .sheet(isPresented: $showCapture) {
                NavigationStack {
                    CaptureView()
                }
            }
            .navigationDestination(for: String.self) { collectionID in
                CollectionDetailView(collectionID: collectionID)
            }
            .onAppear { model.reloadOverview() }
            .refreshable { model.reloadOverview() }
        }
    }

    private var collectionList: some View {
        List(model.collections) { collection in
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