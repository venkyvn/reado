import ReadoKit
import SwiftUI

/// Chi tiết một collection (FR-08 + FR-17):
/// - danh sách từ đầy đủ trường (term / pos / ipa / meaning_vi / cefr / example)
/// - kho tạm (is_default): sắp theo thời điểm thêm, chọn lô chuyển collection —
///   thẻ giữ nguyên FSRS (collection là nhãn, không phải danh tính)
/// - named collection: đổi tên / xoá (xoá còn từ → buộc chuyển sang collection khác)
struct CollectionDetailView: View {
    let collectionID: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []

    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var moveSheetIntention: MoveIntention?

    private var overview: AppModel.CollectionOverview? {
        model.collections.first { $0.id == collectionID }
    }
    private var isInbox: Bool { overview?.isDefault ?? false }
    private var wordCount: Int { overview?.totalItems ?? 0 }

    var body: some View {
        List {
            if let overview {
                Section {
                    LabeledContent("Số từ", value: "\(overview.totalItems)")
                    if let lastAddedAt = overview.lastAddedAt {
                        LabeledContent(
                            "Lần thêm gần nhất",
                            value: lastAddedAt.formatted(
                                date: .abbreviated, time: .shortened))
                    }
                }
            }

            if model.vocabulary.isEmpty {
                ContentUnavailableView(
                    "Chưa có từ",
                    systemImage: "text.book.closed",
                    description: Text(
                        isInbox
                            ? "Chụp trang để thêm từ vào kho tạm."
                            : "Từ chưa phân loại nằm trong kho tạm; chụp nhanh (không chọn collection) để dồn về đó."))
                    .listRowSeparator(.hidden)
            } else {
                ForEach(model.vocabulary) { entry in
                    vocabRow(entry)
                }
            }
        }
        .navigationTitle(overview?.name ?? "Collection")
        .toolbar { toolbarContent }
        .onAppear { reloadList() }
        .alert("Đổi tên collection", isPresented: $showRename) {
            TextField("Tên mới", text: $renameText)
            Button("Lưu") {
                _ = try? model.renameCollection(
                    id: collectionID, name: renameText)
            }
            Button("Huỷ", role: .cancel) {}
        }
        .alert(deleteAlertTitle, isPresented: $showDeleteConfirm) {
            if wordCount > 0 {
                Button("Chuyển rồi xoá") {
                    moveSheetIntention = .deleteCollection
                }
                Button("Huỷ", role: .cancel) {}
            } else {
                Button("Xoá", role: .destructive) {
                    _ = try? model.deleteCollection(
                        id: collectionID, moveTo: nil)
                    dismiss()
                }
                Button("Huỷ", role: .cancel) {}
            }
        } message: {
            if wordCount > 0 {
                Text(
                    "Collection còn \(wordCount) từ. Chọn collection đích để chuyển chúng sang, rồi xoá — lịch ôn không bị reset.")
            }
        }
        .sheet(item: $moveSheetIntention) { intention in
            CollectionMoveSheet(
                title: moveTitle(for: intention),
                excludedID: collectionID,
                onCommit: { commitMove(to: $0, intention: intention) })
        }
    }

    private var deleteAlertTitle: String {
        wordCount > 0 ? "Xoá collection" : "Xoá collection này?"
    }

    private func moveTitle(for intention: MoveIntention) -> String {
        switch intention {
        case .batch: "Chuyển từ"
        case .deleteCollection: "Chuyển rồi xoá"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .bottomBar) {
                Button("Chuyển (\(selectedIDs.count) từ)") {
                    moveSheetIntention = .batch(itemIDs: Array(selectedIDs))
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            // Kho tạm: chế độ "Sắp xếp" để chọn nguyên lô theo thời điểm thêm (J6).
            if isInbox {
                Button(isSelecting ? "Xong" : "Sắp xếp") {
                    isSelecting.toggle()
                    if !isSelecting { selectedIDs = [] }
                }
            }
            Menu {
                Button("Đổi tên") {
                    renameText = overview?.name ?? ""
                    showRename = true
                }
                if !isInbox {
                    Button("Xoá", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private func vocabRow(_ entry: VocabRepository.VocabularyListEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelecting {
                Image(systemName: selectedIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        selectedIDs.contains(entry.id)
                            ? Color.accentColor : .secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.term)
                        .font(.headline)
                    Text(entry.pos)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cefr = entry.cefr, !cefr.isEmpty {
                        Text(cefr.uppercased())
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.12)))
                    }
                }
                if let ipa = entry.ipa, !ipa.isEmpty {
                    Text("/\(ipa)/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(entry.meaningVI)
                    .font(.subheadline)
                Text(entry.example)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelecting else { return }
            if selectedIDs.contains(entry.id) {
                selectedIDs.remove(entry.id)
            } else {
                selectedIDs.insert(entry.id)
            }
        }
    }

    private func reloadList() {
        model.loadVocabulary(
            collectionID: collectionID,
            order: isInbox ? .byDateAdded : .byTerm)
    }

    private func commitMove(to targetID: String, intention: MoveIntention) {
        switch intention {
        case let .batch(itemIDs):
            _ = try? model.moveItems(
                fromCollectionID: collectionID,
                itemIDs: itemIDs,
                toCollectionID: targetID)
            isSelecting = false
            selectedIDs = []
            reloadList()
        case .deleteCollection:
            _ = try? model.deleteCollection(
                id: collectionID, moveTo: targetID)
            dismiss()
        }
    }
}

/// Đích của một lần "chuyển từ" — chuyển lô (kho tạm) hoặc chuyển rồi xoá.
private enum MoveIntention: Identifiable {
    case batch(itemIDs: [String])
    case deleteCollection

    var id: String {
        switch self {
        case .batch: "batch"
        case .deleteCollection: "delete"
        }
    }
}

/// Sheet chọn collection đích (hoặc tạo mới ngay) cho thao tác chuyển từ.
private struct CollectionMoveSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let excludedID: String
    let onCommit: (String) -> Void

    @State private var newCollectionName = ""
    @State private var showCreate = false

    private var candidates: [AppModel.CollectionOverview] {
        model.collections.filter { $0.id != excludedID }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Chuyển tới") {
                    ForEach(candidates) { collection in
                        Button {
                            onCommit(collection.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(collection.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(collection.totalItems) từ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Tạo collection mới", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
            }
            .alert("Tạo collection", isPresented: $showCreate) {
                TextField("Tên collection", text: $newCollectionName)
                Button("Tạo") {
                    let newID: String? =
                        (try? model.createCollection(name: newCollectionName))
                        ?? nil
                    if let newID {
                        onCommit(newID)
                        dismiss()
                    }
                    newCollectionName = ""
                }
                Button("Huỷ", role: .cancel) {}
            }
        }
    }
}