import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Kho tab — toàn bộ collection (kho tạm + named) + tạo mới từ `+` nav.
struct KhoTabView: View {
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
        // Tối đa 2 phụ kiện phải (vòng thuộc + số due) — thứ tự ưu tiên nằm ở dòng phụ.
        let priorityOrder = model.reviewScopeDefault.priorityIDs.firstIndex(of: collection.id)
        HStack(spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                HStack(spacing: Spacing.sm) {
                    Text(collection.name)
                        .font(Typo.rowTitle)
                    if model.homePinIDs.contains(collection.id) {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Đã ghim")
                    }
                }
                Text(priorityOrder.map { "Ưu tiên \($0 + 1) · " + masteryLabel(collection) }
                    ?? masteryLabel(collection))
                    .font(Typo.rowSubtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if collection.totalItems > 0 {
                MasteryRing(mastered: collection.masteredCount, total: collection.totalItems)
            }
            if collection.dueNow > 0 {
                Pill(text: "\(collection.dueNow)", tone: .due)
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
        .tint(isPriority ? Color(.systemGray) : Theme.level)
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
            .tint(isPinned ? Color(.systemGray) : Color.accentColor)
            .disabled(
                !isPinned && model.homePinIDs.count >= HomePinService.maxPins)
        }
    }
}
