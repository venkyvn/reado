import SwiftUI
import ReadoKit

/// FR-03 + FR-09 — Duyệt & sửa trước khi lưu (ROADMAP 2.3).
/// ADR-008: card rút gọn (term + pos + nghĩa tắt + chip trạng thái + checkbox),
/// chạm mở inline đủ 6 field sửa ngay dưới, không rời danh sách; unverified/suspect
/// xếp lên đầu (ReviewDraftBuilder) và không preselect. Lưu = transaction #4.
/// Segments/summary chỉ hiển thị (FR-05/06); vocabulary là phần được lưu (FR-02).
struct AnalysisView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drafts: [ReviewDraft] = []
    @State private var expandedIDs: Set<String> = []
    // port UI lab §5.3: bản dịch đoạn ẩn tới khi tap (EN luôn hiện).
    @State private var revealedSegments: Set<Int> = []
    @State private var showQuitWarning = false
    @State private var hasConfirmed = false
    // FR-22: từ đã có trong kho gạch chân ở đoạn gốc; chạm mở popover.
    @State private var encounterMatcher = EncounterMatcher(lexicon: [])
    @State private var encounterSelection: EncounterSelection?

    private var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    /// Dòng chữ theo tiến độ agent (FR-02) — model.capture.analysisProgress nil
    /// (chưa kịp báo) rơi về câu chung.
    private var progressTitle: String {
        switch model.capture.analysisProgress {
        case nil, .readingPage:
            "Đang đọc chữ trên máy…"
        case .waitingAgent:
            "Đang gửi cho agent…"
        case .thinking:
            "Agent đang suy nghĩ…"
        case let .writing(chars):
            "Đang viết kết quả… (\(chars) ký tự)"
        }
    }

    /// FR-09 (port UI lab §5.6): chọn/bỏ toàn bộ trong một chạm. Không tính
    /// unverified/suspect — chỉ bật/tắt card đang có.
    private var allSelected: Bool {
        !drafts.isEmpty && drafts.allSatisfy(\.isSelected)
    }

    private func setAllSelected(_ selected: Bool) {
        for index in drafts.indices { drafts[index].isSelected = selected }
    }

    /// U8 ux-polish-r1: còn card đã kiểm (verified) mà chưa chọn — nút "Chọn
    /// tất cả đã kiểm" chỉ hiện khi có việc để làm.
    private var hasUnselectedVerified: Bool {
        drafts.contains { $0.verification == .verified && !$0.isSelected }
    }

    /// Chỉ bật card verified — unverified/suspect giữ nguyên lựa chọn hiện tại
    /// (ADR-008: không tự chọn thứ chưa xác minh).
    private func selectAllVerified() {
        for index in drafts.indices where drafts[index].verification == .verified {
            drafts[index].isSelected = true
        }
        Haptics.selection()
    }

    var body: some View {
        Group {
            if model.capture.analysisFailure != nil {
                failureView
                    .transition(.opacity)
            } else if model.capture.isAnalyzing {
                // FR-02: progress rõ theo AnalysisProgress (stream) — trang dài
                // với agent tắt suy nghĩ mất ~15-30s, không để màn đứng im.
                // U7 ux-polish-r1: skeleton bên dưới gợi hình dạng kết quả sắp về.
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(progressTitle)
                            .font(.headline)
                            .contentTransition(.opacity)
                        Text("Thường mất 15–30 giây.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    AnalysisSkeleton()
                        .padding(.horizontal)
                }
                .padding(.top, Spacing.xl)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else if let result = model.capture.analysisResult {
                resultList(result)
                    .transition(.opacity)
            } else {
                ContentUnavailableView(
                    "Chưa có trang để phân tích",
                    systemImage: "photo.on.rectangle.angled")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: model.capture.isAnalyzing)
        .onAppear { encounterMatcher = model.makeEncounterMatcher() }
        .appErrorAlert()
        .sheet(item: $encounterSelection) { EncounterSheet(selection: $0) }
        .navigationTitle("Duyệt & lưu từ vựng")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.capture.analysisResult != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        quitTapped()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Đóng phiên duyệt")
                }
            }
        }
        // ux-redesign-r1 T5a: CTA chính là nút prominent ghim đáy (không còn chữ nhỏ trên toolbar).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsSaveBar {
                saveBar
            }
        }
        // FR-03: chưa confirm mà thoát → cảnh báo mất kết quả analysis.
        // Swipe sheet bị chặn tới khi đã lưu/bỏ; nút Đóng hỏi rõ ràng.
        .interactiveDismissDisabled(model.capture.analysisResult != nil && !hasConfirmed)
        .alert("Bỏ kết quả phân tích?", isPresented: $showQuitWarning) {
            Button("Bỏ kết quả", role: .destructive) {
                model.discardAnalysis()
                hasConfirmed = true
                dismiss()
            }
            Button("Ở lại", role: .cancel) {}
        } message: {
            Text("Những từ đã sửa trong phiên này chưa được lưu và sẽ mất.")
        }
        .onAppear {
            syncDraftsIfNeeded()
        }
        .onChange(of: model.capture.analysisResult) { _, _ in syncDraftsIfNeeded() }
        .task {
            // 2.2 lấp lỗ hổng flow: CaptureView chỉ hand-off ảnh (bẫy sheet chồng
            // sheet), phân tích được kích hoạt khi màn hình này xuất hiện.
            if model.capture.analysisResult == nil,
               model.capture.analysisError == nil,
               model.capture.lastCapturedImage != nil,
               !model.capture.isAnalyzing {
                await model.analyzeCurrentImage()
            }
        }
        #if DEBUG
        .task {
            // verify-nav-r1 T2 — `-ReadoScreen encounter-sheet` (RootView bật
            // `debugOpenFirstEncounter`): tự mở popover của match đầu tiên để
            // agent chụp "gạch chân + EncounterSheet" không cần chạm tay. Đợi
            // sheet ổn định (segments đã vẽ) trước khi set state.
            guard model.shell.debugOpenFirstEncounter else { return }
            try? await Task.sleep(nanoseconds: 600_000_000)
            model.shell.debugOpenFirstEncounter = false
            guard let firstSegment = model.capture.analysisResult?.segments.first,
                  let match = encounterMatcher.matches(in: firstSegment.sourceEN).first
            else { return }
            encounterSelection = EncounterSelection(
                surface: String(firstSegment.sourceEN[match.range]), entries: match.entries)
        }
        #endif
    }

    // MARK: - Lỗi (FR-04)

    /// FR-04: phân biệt loại lỗi để gợi ý CTA đúng — ảnh mờ / không phải tiếng
    /// Anh gợi ý **chụp lại** (ảnh khác); lỗi tạm (mạng/schema/provider/rate-limit)
    /// cho **thử lại** cùng ảnh.
    @ViewBuilder
    private var failureView: some View {
        if let failure = model.capture.analysisFailure {
            switch failure {
            case .imageUnreadable:
                ContentUnavailableView {
                    Label("Ảnh không đọc được", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(failure.errorDescription ?? "Ảnh quá mờ hoặc không đọc được.")
                } actions: {
                    Button("Chụp lại") { recapture() }
                        .buttonStyle(.borderedProminent)
                    Button("Đóng", role: .cancel) { model.discardAnalysis(); dismiss() }
                }
            case .notEnglishText:
                ContentUnavailableView {
                    Label("Không phải tiếng Anh", systemImage: "globe")
                } description: {
                    Text(failure.errorDescription ?? "Trang không phải tiếng Anh.")
                } actions: {
                    Button("Chụp trang khác") { recapture() }
                        .buttonStyle(.borderedProminent)
                    Button("Đóng", role: .cancel) { model.discardAnalysis(); dismiss() }
                }
            default:
                ContentUnavailableView {
                    Label("Không phân tích được trang", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(failure.errorDescription ?? "Đã có lỗi xảy ra.")
                } actions: {
                    Button("Thử lại") {
                        Task { await model.analyzeCurrentImage() }
                    }
                    .buttonStyle(.borderedProminent)
                    // FR-21 GWT cuối: lỗi agent (401/timeout/base URL sai…) đưa
                    // thẳng về Cài đặt thay vì để user tự đoán phải sửa gì.
                    Button("Mở Cài đặt") {
                        model.discardAnalysis()
                        model.shell.pendingSettingsNavigation = true
                        dismiss()
                    }
                    Button("Đóng", role: .cancel) { model.discardAnalysis(); dismiss() }
                }
            }
        } else {
            // Fallback: lỗi không định danh — không nên tới đây.
            ContentUnavailableView {
                Label("Không phân tích được trang", systemImage: "exclamationmark.triangle")
            } description: {
                Text(model.capture.analysisError ?? "Đã có lỗi xảy ra.")
            } actions: {
                Button("Thử lại") {
                    Task { await model.analyzeCurrentImage() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func recapture() {
        model.prepareRecapture()
        dismiss()
    }

    // MARK: - Flow

    private func syncDraftsIfNeeded() {
        guard let result = model.capture.analysisResult, drafts.isEmpty else { return }
        // port UI lab §5.5: preselect = verified && cefr ∈ settings.cefrLevels.
        let levels = model.loadLearningSettings()?.cefrLevels.map(\.rawValue)
        drafts = ReviewDraftBuilder.drafts(
            from: result.vocabulary,
            selectedLevels: levels.map(Set.init),
            excludingMature: model.matureKeysForCapture())
    }

    private func quitTapped() {
        if model.capture.analysisResult != nil, !hasConfirmed {
            showQuitWarning = true
        } else {
            dismiss()
        }
    }

    /// Nút Lưu chỉ hiện khi đang xem kết quả (không phải lỗi/đang phân tích/chưa có trang).
    private var showsSaveBar: Bool {
        model.capture.analysisFailure == nil
            && !model.capture.isAnalyzing
            && model.capture.analysisResult != nil
    }

    private var saveBar: some View {
        Button {
            save()
        } label: {
            Text("Lưu \(selectedCount) từ vào \(destinationName)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedCount == 0)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.background)
        .overlay(alignment: .top) { Divider() }
    }

    private func save() {
        do {
            // FR-05/06: segments + summary đi theo phiên đọc khi lưu vào collection
            // có tên; kho tạm không lưu phiên (kho chứa từ chưa phân loại).
            // ADR-053: đích đổi được ngay ở đầu màn này (`CollectionDestinationPicker`),
            // mặc định = bộ chọn lúc chụp (`analysisTargetCollectionID`).
            let result = model.capture.analysisResult
            let saved = try model.saveSelection(
                drafts,
                collectionID: model.capture.analysisTargetCollectionID,
                segments: result?.segments ?? [],
                summaryVI: result?.summaryVI ?? "")
            guard saved > 0 else {
                // Không ghi được từ nào (kho chưa mở) — đừng đóng phiên duyệt như thể đã lưu.
                model.alertMessage = "Không lưu được từ nào. Hãy thử lại."
                Haptics.error()
                return
            }
            // Thành công: không alert chặn — `saveSelection` đã đặt `shell.saveConfirmation`,
            // RootView đọc ở onDismiss của sheet này rồi hiện banner "Đã lưu N từ vào X · Xem".
            hasConfirmed = true
            Haptics.success()
            dismiss()
        } catch {
            model.report(error, while: "lưu từ vựng")
            Haptics.error()
        }
    }

    /// Tên đích lưu cho nút Lưu và dòng "Lưu vào" (kho tạm hoặc tên collection).
    private var destinationName: String {
        if let id = model.capture.analysisTargetCollectionID,
           let collection = model.collections.first(where: { $0.id == id }) {
            return collection.name
        }
        return "Kho tạm"
    }

    // MARK: - Kết quả

    private func resultList(_ result: PageAnalysis) -> some View {
        List {
            // ADR-053: đổi đích ngay ở đầu màn duyệt (trước: chỉ đọc, "Đổi bộ ở màn chụp" là ngõ cụt).
            Section {
                CollectionDestinationPicker {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "tray.and.arrow.down")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text("Lưu vào")
                            .foregroundStyle(.secondary)
                        Text(destinationName)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: Spacing.sm)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Đổi nơi lưu, hiện \(destinationName)")
            }

            // FR-05 (ADR-007): song ngữ — EN luôn hiện, VI mở khi tap (port §5.3).
            if !result.segments.isEmpty {
                Section("Đoạn gốc") {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { index, seg in
                        SegmentBlock(
                            segment: seg,
                            isRevealed: revealedSegments.contains(index),
                            matcher: encounterMatcher,
                            onSelect: { encounterSelection = $0 },
                            onTap: { toggleSegment(index) })
                    }
                }
            }

            // FR-03/FR-09: duyệt + chọn + sửa 6 field inline (ADR-008).
            if !drafts.isEmpty {
                Section {
                    // Chọn/bỏ tất cả — để trong Section (header List nuốt tap).
                    // U8: "Chọn tất cả đã kiểm" chỉ bật verified, giữ nguyên
                    // lựa chọn của unverified/suspect (ADR-008).
                    HStack {
                        Button(allSelected ? "Bỏ chọn" : "Chọn tất cả") {
                            setAllSelected(!allSelected)
                        }
                        Spacer()
                        if hasUnselectedVerified {
                            Button("Chọn tất cả đã kiểm", action: selectAllVerified)
                        }
                    }
                    .buttonStyle(.borderless)
                    ForEach(Array(drafts.enumerated()), id: \.element.id) { index, _ in
                        ReviewCardRow(
                            draft: $drafts[index],
                            isExpanded: expandedIDs.contains(drafts[index].id),
                            onToggleExpand: { toggleExpand(drafts[index].id) })
                            // U8: vuốt phải để bấm chọn nhanh, không cần mở card.
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    drafts[index].isSelected.toggle()
                                    Haptics.selection()
                                } label: {
                                    Label(
                                        drafts[index].isSelected ? "Bỏ chọn" : "Chọn",
                                        systemImage: drafts[index].isSelected
                                            ? "circle" : "checkmark.circle")
                                }
                                .tint(drafts[index].isSelected ? Color(.systemGray) : Color.accentColor)
                            }
                    }
                } header: {
                    HStack {
                        Text("Từ vựng")
                        Spacer()
                        Text("Đã chọn \(selectedCount)/\(drafts.count)")
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : Motion.reveal, value: selectedCount)
                    }
                }
            }

            if !result.summaryVI.isEmpty {
                Section("Ý chính") {
                    Text(result.summaryVI)
                }
            }
        }
    }

    private func toggleExpand(_ id: String) {
        Motion.run(reduceMotion: reduceMotion) {
            if expandedIDs.contains(id) {
                expandedIDs.remove(id)
            } else {
                expandedIDs.insert(id)
            }
        }
    }

    private func toggleSegment(_ index: Int) {
        Motion.run(reduceMotion: reduceMotion) {
            if revealedSegments.contains(index) {
                revealedSegments.remove(index)
            } else {
                revealedSegments.insert(index)
            }
        }
    }
}
