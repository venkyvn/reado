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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []

    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var moveSheetIntention: MoveIntention?
    @State private var showExport = false

    // J2 hub: ôn bộ này (scoped). Chụp đi qua FloatShutter nổi ở RootView (port
    // UI lab §6) — không còn sheet capture/analysis riêng trong Hub.
    @State private var showReview = false

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
                    // FR-17: kho tạm không hiện control "Hiện trên Home" (J2).
                    if !isInbox {
                        HomePinToggle(collectionID: collectionID)
                    }
                }

                // J2 hub: hành động nhanh — ôn phạm vi bộ này. Chụp dùng
                // FloatShutter nổi (port UI lab §6), không CTA "Chụp thêm phiên".
                Section {
                    Button {
                        showReview = true
                    } label: {
                        Label("Ôn bộ này", systemImage: "brain.head.profile")
                    }
                }
            }

            sessionsSection

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
        .onAppear {
            reloadList()
            // port UI lab §6: chụp bằng shutter nổi prefilt vào đúng bộ đang mở.
            model.shutterTargetCollectionID = collectionID
        }
        .onDisappear {
            if model.shutterTargetCollectionID == collectionID {
                model.shutterTargetCollectionID = nil
            }
        }
        .onChange(of: model.dataRevision) {
            // Lưu từ shutter (port §5.7) bump overview → hub đang mở tự refresh.
            reloadList()
        }
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
        .sheet(isPresented: $showExport) {
            NavigationStack { ExportView(initialCollectionIDs: [collectionID]) }
        }
        .sheet(isPresented: $showReview, onDismiss: {
            reloadAfterSession()
        }) {
            NavigationStack { ReviewQueueView(initialScope: [collectionID]) }
        }
    }

    private var deleteAlertTitle: String {
        wordCount > 0 ? "Xoá collection" : "Xoá collection này?"
    }

    // J2 hub: danh sách phiên đọc song ngữ (tối đa 10, mới nhất trước). Kho tạm
    // không lưu phiên (Q-10/ADR-029) nên không hiện section này.
    @ViewBuilder
    private var sessionsSection: some View {
        if !isInbox {
            Section {
                if model.sessions.isEmpty {
                    Text("Chưa có phiên đọc. Chụp trang vào bộ này để lưu bản song ngữ (giữ tối đa 10 phiên).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.sessions) { session in
                        NavigationLink {
                            ReadingSessionView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    session.createdAt.formatted(
                                        date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                if let summary = session.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Phiên đọc (\(model.sessions.count)/10)")
            }
        }
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
                    Motion.run(reduceMotion: reduceMotion) {
                        isSelecting.toggle()
                        if !isSelecting { selectedIDs = [] }
                    }
                }
            }
            Menu {
                Button("Đổi tên") {
                    renameText = overview?.name ?? ""
                    showRename = true
                }
                // J-R1-D/J2 #9: xuất đúng collection đang đứng (chọn sẵn phạm vi).
                Button("Xuất bộ này") {
                    showExport = true
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
                    .contentTransition(.symbolEffect(.replace))
                    .transition(.opacity.combined(with: .offset(x: -12)))
            }
            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Text(entry.term).font(.headline)
                        vocabBadges(entry)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.term).font(.headline)
                        vocabBadges(entry)
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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelecting else { return }
            toggleSelection(entry.id)
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: isSelecting)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.term), \(entry.meaningVI)")
        .accessibilityValue(
            isSelecting
                ? (selectedIDs.contains(entry.id) ? "Đã chọn" : "Chưa chọn")
                : "")
        .accessibilityHint(isSelecting ? "Chạm hai lần để đổi trạng thái chọn" : "")
        .accessibilityAddTraits(isSelecting ? .isButton : [])
        .accessibilityAddTraits(
            isSelecting && selectedIDs.contains(entry.id) ? .isSelected : [])
        .accessibilityAction {
            guard isSelecting else { return }
            toggleSelection(entry.id)
        }
    }

    private func vocabBadges(_ entry: VocabRepository.VocabularyListEntry) -> some View {
        HStack(spacing: 6) {
            Text(entry.pos)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let cefr = entry.cefr, !cefr.isEmpty {
                Text(cefr.uppercased())
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.level.opacity(0.12)))
            }
        }
    }

    private func toggleSelection(_ id: String) {
        Motion.run(reduceMotion: reduceMotion) {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
        }
        Haptics.selection()
    }

    private func reloadList() {
        model.loadVocabulary(
            collectionID: collectionID,
            order: isInbox ? .byDateAdded : .byTerm)
        model.loadSessions(collectionID: collectionID)
    }

    /// Sau một sheet (ôn) đóng lại — refresh từ, phiên, overview.
    private func reloadAfterSession() {
        reloadList()
        model.reloadOverview()
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