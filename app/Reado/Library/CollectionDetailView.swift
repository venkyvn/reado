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
    @State private var showPinChooser = false
    // FR-23/ADR-058 (pdf-reader-r1 T3) — chọn file PDF để gắn/đổi cho bộ này.
    @State private var showPDFPicker = false

    // J2 hub: ôn bộ này (scoped) mở phiên ôn toàn màn qua `startReview` (RootView giữ
    // cover). Chụp đi qua nút chụp trong thanh tab (port UI lab §6) — không còn
    // sheet capture/analysis riêng trong Hub.
    @Environment(\.startReview) private var startReview

    private var overview: AppModel.CollectionOverview? {
        model.collections.first { $0.id == collectionID }
    }
    private var isInbox: Bool { overview?.isDefault ?? false }
    private var wordCount: Int { overview?.totalItems ?? 0 }

    var body: some View {
        List {
            if let overview {
                Section {
                    CollectionStatsHeader(
                        overview: overview,
                        nextDue: model.library.collectionNextDue,
                        dots: model.library.masteryDots,
                        now: model.clock.now,
                        onReview: {
                            startReview(ReviewRequest(scope: [collectionID], mode: .srs))
                        },
                        onCram: {
                            startReview(ReviewRequest(scope: [collectionID], mode: .extra))
                        })
                }
            }

            pdfSourceSection

            sessionsSection

            if model.library.vocabulary.isEmpty {
                ContentUnavailableView(
                    "Chưa có từ",
                    systemImage: "text.book.closed",
                    description: Text(
                        isInbox
                            ? "Chụp trang để thêm từ vào kho tạm."
                            : "Từ chưa phân loại nằm trong kho tạm; chụp nhanh (không chọn bộ) để dồn về đó."))
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(model.library.vocabulary) { entry in
                        vocabRow(entry)
                    }
                } header: {
                    Text("Từ vựng · \(model.library.vocabulary.count)")
                }
            }
        }
        .shellScrollChrome()
        .navigationTitle(overview?.name ?? "Bộ")
        .toolbar { toolbarContent }
        .onAppear {
            reloadList()
            // port UI lab §6: nút chụp trong thanh tab prefill vào đúng bộ đang mở.
            model.shell.shutterTargetCollectionID = collectionID
        }
        .onDisappear {
            if model.shell.shutterTargetCollectionID == collectionID {
                model.shell.shutterTargetCollectionID = nil
            }
        }
        .onChange(of: model.dataRevision) {
            // Lưu từ nút chụp (ADR-053) hoặc đóng cover ôn (`RootView` gọi
            // `reloadOverview`) bump overview → hub đang mở tự refresh.
            reloadList()
        }
        // FR-17: chooser "đã đủ 5 pin" — gắn ngoài Menu để không biến mất cùng menu.
        .homePinChooser(collectionID: collectionID, isPresented: $showPinChooser)
        .alert("Đổi tên bộ", isPresented: $showRename) {
            TextField("Tên mới", text: $renameText)
            Button("Lưu") {
                model.renameCollectionOrAlert(id: collectionID, name: renameText)
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
                    if model.deleteCollectionOrAlert(id: collectionID, moveTo: nil) {
                        dismiss()
                    }
                }
                Button("Huỷ", role: .cancel) {}
            }
        } message: {
            if wordCount > 0 {
                Text(
                    "Bộ còn \(wordCount) từ. Chọn bộ đích để chuyển chúng sang, rồi xoá — lịch ôn không bị reset.")
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
        // FR-23/ADR-058 — "Gắn PDF…"/"Đổi PDF…" ở menu ⋯ mở picker này; gắn lại
        // (đổi file) là UPSERT ghi đè, trang đang đọc về 0 (`attachPDFOrAlert`).
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first else { return }
            if model.attachPDFOrAlert(url: url, collectionID: collectionID) {
                Haptics.success()
            }
        }
    }

    private var deleteAlertTitle: String {
        wordCount > 0 ? "Xoá bộ" : "Xoá bộ này?"
    }

    // FR-23/ADR-058 (pdf-reader-r1 T3) — hàng "Đọc PDF · tr. N" đặt TRÊN danh
    // sách session, không phải CTA chính (ADR-052: Hub chỉ có 1 CTA chính —
    // "Ôn bộ này"/"Ôn thêm" ở `CollectionStatsHeader`). Chưa gắn PDF → không
    // hiện hàng, chỉ có mục "Gắn PDF…" trong menu ⋯.
    @ViewBuilder
    private var pdfSourceSection: some View {
        if let source = model.library.pdfSource {
            Section {
                NavigationLink(value: ShellRoute.pdfReader(collectionID)) {
                    HStack(spacing: Spacing.row) {
                        IconTile(systemImage: "doc.text")
                        VStack(alignment: .leading, spacing: Spacing.tight) {
                            Text(source.displayName)
                                .font(Typo.rowSubtitle)
                                .lineLimit(1)
                            Text(
                                source.pageIndex == 0
                                    ? "Đọc từ đầu"
                                    : "Đọc PDF · tr. \(source.pageIndex + 1)")
                                .font(Typo.meta)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // J2 hub: danh sách phiên đọc song ngữ (tối đa 10, mới nhất trước). Kho tạm
    // không lưu phiên (Q-10/ADR-029) nên không hiện section này.
    @ViewBuilder
    private var sessionsSection: some View {
        if !isInbox {
            Section {
                if model.library.sessions.isEmpty {
                    Text("Chưa có phiên đọc. Chụp trang vào bộ này để lưu bản song ngữ (giữ tối đa 10 phiên).")
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.library.sessions) { session in
                        NavigationLink {
                            ReadingSessionView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(
                                    session.createdAt.formatted(
                                        date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                if let summary = session.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(Typo.meta)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Phiên đọc (\(model.library.sessions.count)/10)")
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
                // FR-17: kho tạm không ghim được (J2).
                if !isInbox {
                    HomePinMenuButton(
                        collectionID: collectionID, onFull: { showPinChooser = true })
                }
                // FR-23/ADR-058: kho tạm không gắn được PDF (không có phiên đọc,
                // Q-10 — không có "trang đang đọc" để nhớ). Nhãn đổi theo đã-gắn
                // chưa, cùng một picker (`showPDFPicker`).
                if !isInbox {
                    Button(model.library.pdfSource == nil ? "Gắn PDF…" : "Đổi PDF…") {
                        showPDFPicker = true
                    }
                    if model.library.pdfSource != nil {
                        Button("Gỡ PDF", role: .destructive) {
                            model.detachPDFOrAlert(collectionID: collectionID)
                        }
                    }
                }
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
        HStack(alignment: .top, spacing: Spacing.row) {
            if isSelecting {
                Image(systemName: selectedIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        selectedIDs.contains(entry.id)
                            ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .transition(.opacity.combined(with: .offset(x: -12)))
            }
            VocabSummary(
                term: entry.term,
                pos: entry.pos,
                cefr: entry.cefr ?? "",
                ipa: entry.ipa ?? "",
                meaning: entry.meaningVI,
                example: entry.example)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs)
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
        model.loadNextDue(collectionID: collectionID)
        model.loadMasteryDots(collectionID: collectionID)
        // FR-23: kho tạm không gắn PDF — không đọc, tránh hiện nhầm hàng cũ
        // của Hub trước đó (LibraryState còn lại giữa hai lần mở Hub khác nhau).
        if isInbox {
            model.library.pdfSource = nil
        } else {
            model.loadPDFSource(collectionID: collectionID)
        }
    }

    private func commitMove(to targetID: String, intention: MoveIntention) {
        switch intention {
        case let .batch(itemIDs):
            // Chuyển lỗi → giữ nguyên lựa chọn để thử lại (đã báo người dùng).
            if model.moveItemsOrAlert(
                fromCollectionID: collectionID,
                itemIDs: itemIDs,
                toCollectionID: targetID)
            {
                isSelecting = false
                selectedIDs = []
            }
            reloadList()
        case .deleteCollection:
            if model.deleteCollectionOrAlert(id: collectionID, moveTo: targetID) {
                dismiss()
            }
        }
    }
}
