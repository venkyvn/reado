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

    /// Dòng chữ theo tiến độ agent (FR-02) — model.analysisProgress nil (proxy
    /// không stream, hoặc chưa kịp báo) rơi về câu chung.
    private var progressTitle: String {
        switch model.analysisProgress {
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
            if model.analysisFailure != nil {
                failureView
                    .transition(.opacity)
            } else if model.isAnalyzing {
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
            } else if let result = model.analysisResult {
                resultList(result)
                    .transition(.opacity)
            } else {
                ContentUnavailableView(
                    "Chưa có trang để phân tích",
                    systemImage: "photo.on.rectangle.angled")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: model.isAnalyzing)
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
                    // FR-21 GWT cuối: lỗi agent (401/timeout/base URL sai…) đưa
                    // thẳng về Cài đặt thay vì để user tự đoán phải sửa gì.
                    Button("Mở Cài đặt") {
                        model.discardAnalysis()
                        model.pendingSettingsNavigation = true
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
            Haptics.success()
        } catch {
            saveAlert = .failure(error.localizedDescription)
            Haptics.error()
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

// MARK: - Card duyệt (ADR-008)

/// Một dòng trong danh sách duyệt: checkbox (FR-09) + thông tin tắt + chip trạng
/// thái xác minh (FR-02); chạm card mở inline 6 field (FR-03). Thiết kế hàng tách
/// bấm chọn với bấm mở — checkbox KHÔNG nằm trong vùng mở card.
private struct ReviewCardRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var draft: ReviewDraft
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.row) {
                selectButton
                Button {
                    onToggleExpand()
                } label: {
                    summaryLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(draft.term), \(draft.meaningVI)")
                .accessibilityValue(isExpanded ? "Đang mở" : "Đang thu gọn")
                .accessibilityHint(isExpanded ? "Thu gọn thông tin" : "Mở để sửa thông tin")
            }

            if isExpanded {
                editor
                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 44)
                    .revealTransition()
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// FR-09: chọn item thành review card. Unverified/suspect không preselect —
    /// bấm chọn nghĩa là user chủ động giữ (FR-02/03).
    private var selectButton: some View {
        Button {
            draft.isSelected.toggle()
            Haptics.selection()
        } label: {
            Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(
                    draft.isSelected ? Color.accentColor : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            draft.isSelected ? "Bỏ chọn \(draft.term)" : "Chọn \(draft.term) để ôn tập")
        .accessibilityValue(draft.isSelected ? "Đã chọn" : "Chưa chọn")
        .accessibilityAddTraits(draft.isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var summaryLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                summaryText
                HStack {
                    VerificationBadge(status: draft.verification)
                    Spacer()
                    expandChevron
                }
            }
        } else {
            HStack(alignment: .top, spacing: Spacing.sm) {
                summaryText
                Spacer(minLength: Spacing.xs)
                VerificationBadge(status: draft.verification)
                expandChevron
            }
        }
    }

    /// Cùng khối `VocabSummary` với row Kho. Mở card thì IPA + ví dụ ẩn (editor bên dưới
    /// đã có đủ field), chỉ còn từ + nghĩa.
    private var summaryText: some View {
        VocabSummary(
            term: draft.term,
            pos: draft.pos,
            cefr: draft.cefr,
            ipa: isExpanded ? "" : draft.ipa,
            meaning: draft.meaningVI,
            example: isExpanded ? "" : draft.example)
    }

    private var expandChevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .frame(width: 44, height: 44)
            .animation(
                reduceMotion ? nil : Motion.reveal,
                value: isExpanded)
    }

    /// FR-03: sửa được mọi field ngay dưới card, không rời danh sách.
    private var editor: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
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
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                editorField("Phiên âm (IPA)") {
                    TextField("VD: /ˈwɪndɪŋ/", text: $draft.ipa)
                }
                // ADR-040: nghe cách đọc từ đang sửa — không luyện nói, không chấm.
                SpeakButton(term: draft.term)
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .font(.subheadline)
                .padding(Spacing.sm)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(segment.sourceEN)
                    .font(.callout)
                    .foregroundStyle(.primary)
                if isRevealed {
                    Text(segment.translationVI)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .revealTransition()
                } else {
                    Label("Dịch", systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.tight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Chip trạng thái xác minh (FR-02) — unverified đỏ (ADR-008), suspect cam.
private struct VerificationBadge: View {
    let status: PageAnalysis.VerificationStatus

    var body: some View {
        switch status {
        case .verified:
            Pill(text: "Đã kiểm", systemImage: "checkmark.circle.fill", tone: .ok)
        case .suspect:
            Pill(text: "Cần xem", systemImage: "exclamationmark.triangle.fill", tone: .warn)
        case .unverified:
            Pill(text: "Chưa xác minh", systemImage: "questionmark.circle", tone: .danger)
        }
    }
}

/// U7 ux-polish-r1: placeholder hình dạng card duyệt trong lúc chờ agent —
/// đỡ màn trắng đứng im, không đoán trước nội dung thật. Nhấp nháy nhẹ, tôn
/// Reduce Motion (đứng yên).
private struct AnalysisSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in row }
        }
        .opacity(dim ? 0.45 : 1)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                dim = true
            }
        }
    }

    // Hình dạng skeleton (frame/radius/khe) mô phỏng row thật — ngoại lệ của thang Spacing/Radius.
    private var row: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.surfaceStrong)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceStrong)
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceStrong)
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
            }
        }
    }
}