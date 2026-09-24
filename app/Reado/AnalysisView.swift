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

    @State private var drafts: [ReviewDraft] = []
    @State private var expandedIDs: Set<String> = []
    // port UI lab §5.3: bản dịch đoạn ẩn tới khi tap (EN luôn hiện).
    @State private var revealedSegments: Set<Int> = []
    @State private var saveAlert: SaveAlert?
    @State private var showQuitWarning = false
    @State private var hasConfirmed = false

    private enum SaveAlert: Identifiable {
        case success(Int)
        case failure(String)

        var id: String {
            switch self {
            case let .success(count): "ok-\(count)"
            case .failure: "fail"
            }
        }
    }

    private var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    /// FR-09 (port UI lab §5.6): chọn/bỏ toàn bộ trong một chạm. Không tính
    /// unverified/suspect — chỉ bật/tắt card đang có.
    private var allSelected: Bool {
        !drafts.isEmpty && drafts.allSatisfy(\.isSelected)
    }

    private func setAllSelected(_ selected: Bool) {
        for index in drafts.indices { drafts[index].isSelected = selected }
    }

    var body: some View {
        Group {
            if model.analysisFailure != nil {
                failureView
            } else if model.isAnalyzing {
                // FR-02: progress rõ — màn hình không đứng im.
                ProgressView("Đang phân tích trang sách...")
                    .padding()
                    .frame(maxWidth: .infinity)
            } else if let result = model.analysisResult {
                resultList(result)
            } else {
                ContentUnavailableView(
                    "Chưa có trang để phân tích",
                    systemImage: "photo.on.rectangle.angled")
            }
        }
        .navigationTitle("Duyệt & lưu từ vựng")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.analysisResult != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        quitTapped()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Đóng phiên duyệt")
                }
            }
            if model.analysisResult != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu (\(selectedCount))") { save() }
                        .disabled(selectedCount == 0)
                }
            }
        }
        // FR-03: chưa confirm mà thoát → cảnh báo mất kết quả analysis.
        // Swipe sheet bị chặn tới khi đã lưu/bỏ; nút Đóng hỏi rõ ràng.
        .interactiveDismissDisabled(model.analysisResult != nil && !hasConfirmed)
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
        .onChange(of: model.analysisResult) { _, _ in syncDraftsIfNeeded() }
        .task {
            // 2.2 lấp lỗ hổng flow: CaptureView chỉ hand-off ảnh (bẫy sheet chồng
            // sheet), phân tích được kích hoạt khi màn hình này xuất hiện.
            if model.analysisResult == nil,
               model.analysisError == nil,
               model.lastCapturedImage != nil,
               !model.isAnalyzing {
                await model.analyzeCurrentImage()
            }
        }
        .alert(item: $saveAlert) { alert in
            switch alert {
            case let .success(count):
                return Alert(
                    title: Text("Đã lưu"),
                    message: Text("\(count) từ đã vào \(destinationLabel) và đến hạn ôn hôm nay."),
                    dismissButton: .default(Text("OK")) { dismiss() })
            case let .failure(message):
                return Alert(
                    title: Text("Không lưu được"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Lỗi (FR-04)

    /// FR-04: phân biệt loại lỗi để gợi ý CTA đúng — ảnh mờ / không phải tiếng
    /// Anh gợi ý **chụp lại** (ảnh khác); lỗi tạm (mạng/schema/provider/rate-limit)
    /// cho **thử lại** cùng ảnh.
    @ViewBuilder
    private var failureView: some View {
        if let failure = model.analysisFailure {
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
                    Button("Đóng", role: .cancel) { model.discardAnalysis(); dismiss() }
                }
            }
        } else {
            // Fallback: lỗi không định danh — không nên tới đây.
            ContentUnavailableView {
                Label("Không phân tích được trang", systemImage: "exclamationmark.triangle")
            } description: {
                Text(model.analysisError ?? "Đã có lỗi xảy ra.")
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
        guard let result = model.analysisResult, drafts.isEmpty else { return }
        // port UI lab §5.5: preselect = verified && cefr ∈ settings.cefrLevels.
        let levels = model.loadLearningSettings()?.cefrLevels.map(\.rawValue)
        drafts = ReviewDraftBuilder.drafts(
            from: result.vocabulary,
            selectedLevels: levels.map(Set.init),
            excludingMature: model.matureKeysForCapture())
    }

    private func quitTapped() {
        if model.analysisResult != nil, !hasConfirmed {
            showQuitWarning = true
        } else {
            dismiss()
        }
    }

    private func save() {
        do {
            // FR-05/06: segments + summary đi theo phiên đọc khi lưu vào collection
            // có tên; kho tạm không lưu phiên (kho chứa từ chưa phân loại).
            // port UI lab: đích đã chọn TỪ LÚC CHỤP (`analysisTargetCollectionID`),
            // duyệt từ chỉ đọc — không chọn lại ở đây.
            let result = model.analysisResult
            let saved = try model.saveSelection(
                drafts,
                collectionID: model.analysisTargetCollectionID,
                segments: result?.segments ?? [],
                summaryVI: result?.summaryVI ?? "")
            hasConfirmed = true
            saveAlert = .success(saved)
        } catch {
            saveAlert = .failure(error.localizedDescription)
        }
    }

    /// Nhãn đích lưu cho thông báo thành công (kho tạm hoặc tên collection).
    private var destinationLabel: String {
        if let id = model.analysisTargetCollectionID,
           let collection = model.collections.first(where: { $0.id == id }) {
            return "«\(collection.name)»"
        }
        return "kho tạm"
    }

    // MARK: - Kết quả

    private func resultList(_ result: PageAnalysis) -> some View {
        List {
            // port UI lab §5.2: đích lưu chỉ ĐỌC ở màn duyệt — chọn từ lúc chụp.
            Section {
                Label {
                    Text("Lưu vào \(destinationLabel)")
                } icon: {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(Color.accentColor)
                }
                .font(.subheadline)
            } footer: {
                Text("Đổi bộ ở màn chụp.")
            }

            // FR-05 (ADR-007): song ngữ — EN luôn hiện, VI mở khi tap (port §5.3).
            if !result.segments.isEmpty {
                Section("Đoạn gốc") {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { index, seg in
                        SegmentBlock(
                            segment: seg,
                            isRevealed: revealedSegments.contains(index),
                            onTap: { toggleSegment(index) })
                    }
                }
            }

            // FR-03/FR-09: duyệt + chọn + sửa 6 field inline (ADR-008).
            if !drafts.isEmpty {
                Section {
                    // Chọn/bỏ tất cả — để trong Section (header List nuốt tap).
                    Button(allSelected ? "Bỏ chọn" : "Chọn tất cả") {
                        setAllSelected(!allSelected)
                    }
                    ForEach(Array(drafts.enumerated()), id: \.element.id) { index, _ in
                        ReviewCardRow(
                            draft: $drafts[index],
                            isExpanded: expandedIDs.contains(drafts[index].id),
                            onToggleExpand: { toggleExpand(drafts[index].id) })
                    }
                } header: {
                    HStack {
                        Text("Từ vựng")
                        Spacer()
                        Text("Đã chọn \(selectedCount)/\(drafts.count)")
                            .foregroundStyle(.secondary)
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
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func toggleSegment(_ index: Int) {
        if revealedSegments.contains(index) {
            revealedSegments.remove(index)
        } else {
            revealedSegments.insert(index)
        }
    }
}

// MARK: - Card duyệt (ADR-008)

/// Một dòng trong danh sách duyệt: checkbox (FR-09) + thông tin tắt + chip trạng
/// thái xác minh (FR-02); chạm card mở inline 6 field (FR-03). Thiết kế hàng tách
/// bấm chọn với bấm mở — checkbox KHÔNG nằm trong vùng mở card.
private struct ReviewCardRow: View {
    @Binding var draft: ReviewDraft
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                selectButton
                Button {
                    onToggleExpand()
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(draft.term)
                                    .font(.headline)
                                Text(draft.pos)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(
                                            Theme.surfaceStrong))
                            }
                            if !draft.meaningVI.isEmpty {
                                Text(draft.meaningVI)
                                    .font(.subheadline)
                                    .lineLimit(2)
                            }
                            if !isExpanded {
                                if !draft.ipa.isEmpty {
                                    Text(draft.ipa)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if !draft.example.isEmpty {
                                    Text(draft.example)
                                        .font(.caption2)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        Spacer(minLength: 2)
                        VerificationBadge(status: draft.verification)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                editor
                    .padding(.leading, 44)
            }
        }
        .padding(.vertical, 4)
    }

    /// FR-09: chọn item thành review card. Unverified/suspect không preselect —
    /// bấm chọn nghĩa là user chủ động giữ (FR-02/03).
    private var selectButton: some View {
        Button {
            draft.isSelected.toggle()
        } label: {
            Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(
                    draft.isSelected ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            draft.isSelected ? "Bỏ chọn \(draft.term)" : "Chọn \(draft.term) để ôn tập")
    }

    /// FR-03: sửa được mọi field ngay dưới card, không rời danh sách.
    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            editorField("Từ") {
                TextField("Từ mới", text: $draft.term)
            }
            editorField("Từ loại") {
                Picker("Từ loại", selection: $draft.pos) {
                    ForEach(ReviewDraftBuilder.validPOS, id: \.self) { pos in
                        Text(pos).tag(pos)
                    }
                }
                .pickerStyle(.menu)
            }
            editorField("Phiên âm (IPA)") {
                TextField("VD: /ˈwɪndɪŋ/", text: $draft.ipa)
            }
            editorField("Nghĩa tiếng Việt") {
                TextField("Nghĩa", text: $draft.meaningVI, axis: .vertical)
                    .lineLimit(1...3)
            }
            editorField("CEFR") {
                Picker("CEFR", selection: $draft.cefr) {
                    Text("Không rõ").tag("")
                    ForEach(ReviewDraftBuilder.validCEFR, id: \.self) { cefr in
                        Text(cefr).tag(cefr)
                    }
                }
                .pickerStyle(.menu)
            }
            editorField("Câu ví dụ") {
                TextField("Câu gốc trên trang", text: $draft.example, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
    }

    private func editorField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .font(.subheadline)
                .padding(8)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// Đoạn gốc song ngữ (port UI lab §5.3) — EN luôn; VI mờ tới khi tap mở.
private struct SegmentBlock: View {
    let segment: PageAnalysis.Segment
    let isRevealed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.sourceEN)
                    .font(.callout)
                    .foregroundStyle(.primary)
                if isRevealed {
                    Text(segment.translationVI)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                } else {
                    Label("Dịch", systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Chip trạng thái xác minh (FR-02) — unverified đỏ (ADR-008), suspect cam.
private struct VerificationBadge: View {
    let status: PageAnalysis.VerificationStatus

    var body: some View {
        Group {
            switch status {
            case .verified:
                Label("Đã kiểm", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.ok)
            case .suspect:
                Label("Cần xem", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warn)
            case .unverified:
                Label("Chưa xác minh", systemImage: "questionmark.circle")
                    .foregroundStyle(Theme.danger)
            }
        }
        .font(.caption2)
    }
}