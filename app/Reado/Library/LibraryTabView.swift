import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Thư viện (ux-redesign-r1 T4) — Kho tạm đầu màn, rồi các bộ có tên; tạo bộ bằng `+`, nhập/xuất
/// dữ liệu qua menu ⋯. Phạm vi ôn mặc định không còn chỉnh ở đây (chuyển vào `ScopePickerSheet`);
/// vuốt một bộ để ưu tiên/ghim vẫn như cũ.
struct LibraryTabView: View {
    @Environment(AppModel.self) private var model

    /// Đẩy `.data` lên stack Thư viện — RootView giữ path.
    let onData: () -> Void

    @State private var showNewCollection = false
    @State private var newCollectionName = ""
    // Lỗi từ swipe ghim/ưu tiên — hiện alert thay vì nuốt.
    @State private var actionError: String?

    private var inbox: AppModel.CollectionOverview? {
        model.collections.first(where: \.isDefault)
    }
    private var namedCollections: [AppModel.CollectionOverview] {
        model.collections.filter { !$0.isDefault }
    }

    var body: some View {
        List {
            if let inbox {
                Section {
                    inboxRow(inbox)
                }
            }

            Section("Bộ") {
                if namedCollections.isEmpty {
                    emptyNamedHint
                } else {
                    ForEach(namedCollections) { collection in
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
        }
        .shellScrollChrome()
        .navigationTitle("Thư viện")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // J-R1-D (ADR-052): cửa Dữ liệu là việc của thư viện. Hai mục cùng mở màn Dữ liệu
                // (có sẵn cả mục Xuất lẫn Nhập) — chưa tách luồng nhập riêng.
                Menu {
                    Button {
                        onData()
                    } label: {
                        Label("Nhập CSV", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        onData()
                    } label: {
                        Label("Xuất dữ liệu", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("Thêm", systemImage: "ellipsis.circle")
                }
                .accessibilityLabel("Thêm")
                Button {
                    openNewCollection()
                } label: {
                    Label("Tạo bộ", systemImage: "plus")
                }
                .accessibilityLabel("Tạo bộ")
            }
        }
        .alert("Tạo bộ", isPresented: $showNewCollection) {
            TextField("Tên bộ", text: $newCollectionName)
            Button("Tạo") {
                _ = model.createCollectionOrAlert(name: newCollectionName)
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

    private func openNewCollection() {
        newCollectionName = ""
        showNewCollection = true
    }

    /// Kho tạm = card đầu màn ("N từ chưa xếp") mở thẳng Hub kho tạm. Vẫn vuốt được để ưu tiên ôn
    /// (không ghim — kho tạm không có Ghim).
    @ViewBuilder
    private func inboxRow(_ inbox: AppModel.CollectionOverview) -> some View {
        let priorityOrder = model.reviewScopeDefault.priorityIDs.firstIndex(of: inbox.id)
        NavigationLink(value: ShellRoute.hub(inbox.id)) {
            HStack(spacing: Spacing.row) {
                IconTile(systemImage: "tray.fill")
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(inbox.name)
                        .font(Typo.rowTitle)
                    Text((priorityOrder.map { "Ưu tiên \($0 + 1) · " } ?? "")
                        + "\(inbox.totalItems) từ chưa xếp")
                        .font(Typo.rowSubtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if inbox.dueNow > 0 {
                    Pill(text: "\(inbox.dueNow)", tone: .due)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            reviewSwipe(inbox)
        }
    }

    /// Chưa có bộ nào có tên (chỉ có kho tạm) — gợi ý tạo bộ theo sách, kèm nút.
    private var emptyNamedHint: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Tạo bộ theo tên sách")
                .font(Typo.rowTitle)
            Text("Gom từ theo sách hoặc ngữ cảnh để ôn riêng từng bộ.")
                .font(Typo.rowSubtitle)
                .foregroundStyle(.secondary)
            Button("Tạo bộ") { openNewCollection() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, Spacing.xs)
    }

    /// Chạy một hành động ném lỗi (ghim/ưu tiên) — lỗi đổ vào `actionError` để
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
                MasteryRing(
                    mastered: collection.masteredCount,
                    total: collection.totalItems,
                    absorbed: collection.absorbedCount)
            }
            if collection.dueNow > 0 {
                Pill(text: "\(collection.dueNow)", tone: .due)
            }
        }
    }

    /// Vuốt trái → bật/tắt ưu tiên ôn (tối đa 3). Đủ 3 mà chưa chọn → vô hiệu.
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
