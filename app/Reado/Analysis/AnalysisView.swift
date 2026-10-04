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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// ux-redesign-r1 T5b: danh sách từ (việc chính) tách khỏi trang gốc — không còn "Đoạn gốc" dài
    /// đẩy việc duyệt từ xuống dưới. Mặc định mở "Từ vựng" (Q-d).
    private enum AnalysisTab: Hashable {
        case vocab, page
    }

    @State private var drafts: [ReviewDraft] = []
    // home-eevas-r1 T2: "AI chọn sẵn N từ" — chụp số preselect NGAY LÚC drafts được dựng lần đầu,
    // không cập nhật lại ở `regroupMatureIfNeeded()` (đổi đích không đổi việc AI đã đề xuất lúc đầu).
    @State private var aiPreselectedCount = 0
    // Q-13 phương án B (ADR-056): item khớp khoá `term|pos` đã thuộc — gập xuống
    // nhóm riêng (không xoá), không preselect, không chiếm suất 5 của `drafts`.
    // Mảng riêng (không lồng trong `drafts`) để binding tới từng ô chọn vẫn hoạt
    // động — `MatureHiddenDraft.draft` là `let`, không mutate được qua index.
    @State private var matureHiddenDrafts: [ReviewDraft] = []
    @State private var matureMeaningsByID: [String: [String]] = [:]
    // Gập sẵn theo mặc định (T2 DoD) — mở ra mới thấy danh sách nghĩa trong kho.
    @State private var matureHiddenExpanded = false
    @State private var expandedIDs: Set<String> = []
    @State private var tab: AnalysisTab = .vocab
    // ADR-030 (cơ chế y hệt `ReadingSessionView`): bản dịch mặc định HIỆN, một nút đáy bật/tắt
    // toàn bộ; chạm một đoạn lật riêng đoạn đó. Bấm nút đáy xoá hết lật riêng — nếu không, sau vài
    // lần chạm lẻ thì nút không còn nói đúng trạng thái đang thấy.
    @State private var showTranslations = true
    @State private var overriddenSegments: Set<Int> = []
    @State private var showQuitWarning = false
    @State private var hasConfirmed = false
    // FR-22: từ đã có trong kho gạch chân ở đoạn gốc; chạm mở popover.
    @State private var encounterMatcher = EncounterMatcher(lexicon: [])
    @State private var encounterSelection: EncounterSelection?
    // FR-05 (prompt-v6 T3): cụm EN↔VI đang chạm-sáng — tối đa một cụm sáng trên cả màn.
    @State private var activePhrase: ActivePhrase?
    @AppStorage("appTheme") private var appTheme = AppTheme.forest.rawValue

    private struct ActivePhrase: Equatable {
        let segmentIndex: Int
        let phraseIndex: Int
    }

    /// View tự vẽ nền tô sáng — đọc trực tiếp `@AppStorage` (MASTER §Màu ngoại lệ
    /// ux-redesign-r1 T10), không `Color.accentColor` trần.
    private var accent: Color { AppTheme(rawValue: appTheme)?.accent ?? Color.accentColor }

    /// Q-13: đếm cả item chọn từ nhóm gập "Đã thuộc" — chọn ở đó tăng số trong
    /// nút "Lưu (N)" giống mọi item khác (T2 DoD).
    private var selectedCount: Int {
        drafts.filter(\.isSelected).count + matureHiddenDrafts.filter(\.isSelected).count
    }

    /// pdf-reader-r1 T4 (FR-23/ADR-058) — trang PDF scan/lớp chữ rác đã được
    /// `preparePDFAnalysis` vẽ thành ảnh (`lastCapturedImage` có giá trị,
    /// `pdfText` thì không) nên đi đúng bước OCR như ảnh chụp — chỉ khác dòng
    /// chữ để người dùng biết vì sao bước này chậm hơn PDF có lớp chữ thường.
    private var isScannedPDFPage: Bool {
        model.capture.origin == .pdf && model.capture.pdfText == nil
    }

    /// Dòng chữ theo tiến độ agent (FR-02) — model.capture.analysisProgress nil
    /// (chưa kịp báo) rơi về câu chung.
    private var progressTitle: String {
        switch model.capture.analysisProgress {
        case nil, .readingPage:
            isScannedPDFPage ? "Trang scan — đang nhận dạng chữ trên máy…" : "Đang đọc chữ trên máy…"
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
                resultView(result)
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
        // ux-redesign-r1 T5a/T5b: nút ghim đáy theo tab — "Từ vựng" là Lưu (CTA chính), "Trang" là
        // ẩn/hiện bản dịch (ADR-030).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsResult {
                switch tab {
                case .vocab:
                    // Q-13: nhóm gập "Đã thuộc" có thể còn hàng chọn được dù `drafts`
                    // (danh sách chính) rỗng — nút Lưu vẫn phải hiện để lưu được.
                    if !drafts.isEmpty || !matureHiddenDrafts.isEmpty { saveBar }
                case .page: translationBar
                }
            }
        }
        // FR-03: chưa confirm mà thoát → cảnh báo mất kết quả analysis.
        // Swipe sheet bị chặn tới khi đã lưu/bỏ; nút Đóng hỏi rõ ràng.
        // Giữ chặn kể cả khi rỗng sau FR-10: đóng bằng nút (X / Đóng) mới dọn state, vuốt thì không.
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
        // fr10-close-r1: ADR-053 cho đổi đích ngay trên màn duyệt — Q-09 so khớp
        // "đã thuộc" theo collection nên đổi đích phải tính lại nhóm gập theo bộ mới.
        .onChange(of: model.capture.analysisTargetCollectionID) { _, _ in regroupMatureIfNeeded() }
        .task {
            // 2.2 lấp lỗ hổng flow: CaptureView chỉ hand-off ảnh (bẫy sheet chồng
            // sheet), phân tích được kích hoạt khi màn hình này xuất hiện.
            // FR-23/ADR-058 (pdf-reader-r1 T4): `hasPendingPage` gồm cả
            // `capture.pdfText` — PDFReaderView hand-off y hệt CaptureView.
            if model.capture.analysisResult == nil,
               model.capture.analysisError == nil,
               model.capture.hasPendingPage,
               !model.capture.isAnalyzing {
                await model.analyzeCurrentPage()
            }
        }
        #if DEBUG
        .onAppear {
            // ux-redesign-r1 T5b — `-ReadoScreen analysis-fixture-page`: mở thẳng tab Trang.
            if model.shell.debugShowAnalysisPage {
                model.shell.debugShowAnalysisPage = false
                tab = .page
            }
            // q13-sense-filter-r1 T2 — `-ReadoScreen analysis-fixture-mature`: mở sẵn nhóm gập
            // "Đã thuộc" + chọn luôn dòng đầu, để một ảnh chụp chứng minh cả mở nhóm lẫn
            // "Lưu (N)" tăng theo lựa chọn trong nhóm đó (simulator không giả lập chạm được).
            if model.shell.debugExpandMatureHidden {
                model.shell.debugExpandMatureHidden = false
                matureHiddenExpanded = true
                if !matureHiddenDrafts.isEmpty {
                    matureHiddenDrafts[0].isSelected = true
                }
            }
        }
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
        .task {
            // prompt-v6 T3 — `-ReadoScreen phrase-highlight`: sáng sẵn cụm đầu
            // tiên có cặp cụm định vị được, để chụp trạng thái "đã chạm".
            guard model.shell.debugActivateFirstPhrase else { return }
            try? await Task.sleep(nanoseconds: 600_000_000)
            model.shell.debugActivateFirstPhrase = false
            guard let segments = model.capture.analysisResult?.segments else { return }
            for (index, seg) in segments.enumerated() {
                guard let first = PhraseLocator.spans(for: seg).first else { continue }
                revealIfNeeded(index)
                activePhrase = ActivePhrase(segmentIndex: index, phraseIndex: first.phraseIndex)
                break
            }
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
                    Button(recaptureLabel) { recapture() }
                        .buttonStyle(.borderedProminent)
                    Button("Đóng", role: .cancel) { model.discardAnalysis(); dismiss() }
                }
            case .notEnglishText:
                ContentUnavailableView {
                    Label("Không phải tiếng Anh", systemImage: "globe")
                } description: {
                    Text(failure.errorDescription ?? "Trang không phải tiếng Anh.")
                } actions: {
                    Button(recaptureLabel) { recapture() }
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
                        Task { await model.analyzeCurrentPage() }
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
                    Task { await model.analyzeCurrentPage() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    /// FR-23/ADR-058 (pdf-reader-r1 T4) — GWT 6: trang vào từ PDF thì nút khắc
    /// phục là "Về trang đọc" (đóng sheet, lộ lại `PDFReaderView` phía dưới),
    /// không phải "Chụp lại" (mở camera vô nghĩa với nguồn không phải ảnh chụp).
    /// `recapture()` tự biết không mở camera cho lối PDF (`AppModel.prepareRecapture`).
    private var recaptureLabel: String {
        model.capture.origin == .pdf ? "Về trang đọc" : "Chụp lại"
    }

    private func recapture() {
        model.prepareRecapture()
        dismiss()
    }

    // MARK: - Flow

    private func syncDraftsIfNeeded() {
        guard let result = model.capture.analysisResult, drafts.isEmpty, matureHiddenDrafts.isEmpty
        else { return }
        // port UI lab §5.5: preselect = verified && cefr ∈ settings.cefrLevels.
        let levels = model.loadLearningSettings()?.cefrLevels.map(\.rawValue)
        let draftResult = ReviewDraftBuilder.drafts(
            from: result.vocabulary,
            selectedLevels: levels.map(Set.init),
            matureSenses: model.matureSensesForCapture())
        drafts = draftResult.visible
        aiPreselectedCount = drafts.filter(\.isSelected).count
        // Q-13 phương án B (ADR-056): tách riêng thành mảng + dict để binding
        // (`$matureHiddenDrafts[index]`) đi được tới từng ô chọn — `knownMeanings`
        // tra theo id draft, hiển thị ở `MatureHiddenRow`.
        matureHiddenDrafts = draftResult.matureHidden.map(\.draft)
        matureMeaningsByID = Dictionary(
            uniqueKeysWithValues: draftResult.matureHidden.map { ($0.id, $0.knownMeanings) })
    }

    /// fr10-close-r1: đích đổi trên màn duyệt (ADR-053) → tính lại nhóm "Đã thuộc"
    /// theo bộ mới mà KHÔNG dựng lại từ AI — giữ sửa tay + lựa chọn của người dùng
    /// (`ReviewDraftBuilder.regroup`). Không chạy khi chưa có gì để tính (chưa phân
    /// tích xong, hoặc cả hai danh sách rỗng).
    private func regroupMatureIfNeeded() {
        guard model.capture.analysisResult != nil,
              !drafts.isEmpty || !matureHiddenDrafts.isEmpty
        else { return }
        let hidden = matureHiddenDrafts.map { draft in
            MatureHiddenDraft(draft: draft, knownMeanings: matureMeaningsByID[draft.id] ?? [])
        }
        let result = ReviewDraftBuilder.regroup(
            visible: drafts, matureHidden: hidden, matureSenses: model.matureSensesForCapture())
        drafts = result.visible
        matureHiddenDrafts = result.matureHidden.map(\.draft)
        matureMeaningsByID = Dictionary(
            uniqueKeysWithValues: result.matureHidden.map { ($0.id, $0.knownMeanings) })
    }

    /// Còn từ để duyệt mà chưa lưu/bỏ → chặn vuốt đóng và hỏi trước khi thoát. Không còn từ nào
    /// (T9: rỗng sau FR-10) thì chẳng có gì để mất — đóng thẳng. Nhóm gập "Đã thuộc" không tính
    /// (chưa chọn gì ở đó cũng không phải "việc đang làm" — Q-13 không preselect).
    private var hasUnsavedWork: Bool {
        model.capture.analysisResult != nil && !hasConfirmed && !drafts.isEmpty
    }

    private func quitTapped() {
        if hasUnsavedWork {
            showQuitWarning = true
        } else {
            // Dọn state (ảnh + kết quả) để lần mở camera sau không tự mở lại phân tích cũ.
            model.discardAnalysis()
            dismiss()
        }
    }

    /// Nút đáy chỉ hiện khi đang xem kết quả (không phải lỗi/đang phân tích/chưa có trang).
    private var showsResult: Bool {
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

    /// ADR-030: MỘT nút cố định dưới đáy bật/tắt toàn bộ bản dịch (mặc định hiện).
    private var translationBar: some View {
        Button {
            Motion.run(reduceMotion: reduceMotion) {
                showTranslations.toggle()
                overriddenSegments.removeAll()
                activePhrase = nil
            }
        } label: {
            Label(
                showTranslations ? "Ẩn bản dịch" : "Hiện bản dịch",
                systemImage: showTranslations ? "eye.slash" : "eye")
                .contentTransition(.symbolEffect(.replace))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.row)
        }
        .buttonStyle(.bordered)
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
            // Q-13: item chọn trong nhóm gập "Đã thuộc" lưu như mọi draft khác —
            // qua đúng `ReviewDraftBuilder.selected(_:)` (model.saveSelection).
            let saved = try model.saveSelection(
                drafts + matureHiddenDrafts,
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

    private func resultView(_ result: PageAnalysis) -> some View {
        VStack(spacing: 0) {
            resultHeader
            switch tab {
            case .vocab:
                vocabList
            case .page:
                pageView(result)
            }
        }
    }

    /// Đích lưu + chuyển tab — luôn hiện ở đầu màn, dù đang ở tab nào.
    private var resultHeader: some View {
        VStack(spacing: Spacing.sm) {
            destinationRow
            destinationConsequenceRow
            tabPicker
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    /// home-eevas-r1 T2: số từ hiện có → sau khi lưu ở bộ đích — đọc trực tiếp
    /// `model.capture.analysisTargetCollectionID` mỗi lần render nên tự cập nhật khi đổi đích
    /// (ADR-053, `CollectionDestinationPicker`), không cache riêng.
    private var targetCount: Int {
        let overview: AppModel.CollectionOverview?
        if let id = model.capture.analysisTargetCollectionID {
            overview = model.collections.first { $0.id == id }
        } else {
            overview = model.collections.first { $0.isDefault }
        }
        return overview?.totalItems ?? 0
    }

    /// Tổng item đang chọn ở cả danh sách chính và nhóm gập "Đã thuộc" (Q-13).
    private var selectedTotal: Int {
        (drafts + matureHiddenDrafts).filter(\.isSelected).count
    }

    @ViewBuilder
    private var destinationConsequenceRow: some View {
        if selectedTotal > 0 {
            Text("\(destinationName): \(targetCount) → \(targetCount + selectedTotal) từ")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : Motion.reveal, value: selectedTotal)
        }
    }

    /// ADR-053: đổi đích ngay ở đầu màn duyệt (trước: chỉ đọc, "Đổi bộ ở màn chụp" là ngõ cụt).
    private var destinationRow: some View {
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
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .card()
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Đổi nơi lưu, hiện \(destinationName)")
    }

    /// Segmented; cỡ chữ accessibility thì đổi sang menu (nhãn "Từ vựng · 12" không vừa ô segmented).
    @ViewBuilder
    private var tabPicker: some View {
        let picker = Picker("Hiển thị", selection: $tab) {
            Text("Từ vựng · \(drafts.count)").tag(AnalysisTab.vocab)
            Text("Trang").tag(AnalysisTab.page)
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    // MARK: - Tab Từ vựng

    /// FR-03/FR-09: duyệt + chọn + sửa 6 field inline (ADR-008). Q-13: nhóm gập
    /// "Đã thuộc" có thể còn hàng ngay cả khi `drafts` (danh sách chính) rỗng —
    /// vẫn hiện List (không màn trắng) để không mất đường vào nhóm gập đó.
    @ViewBuilder
    private var vocabList: some View {
        if drafts.isEmpty && matureHiddenDrafts.isEmpty {
            emptyVocabView
        } else {
            vocabRows
        }
    }

    /// J1: không còn từ đáng học sau FR-10 (đã thuộc / agent không tìm được) → nói rõ + đường đi, không
    /// để danh sách trống im lặng. Tab Trang vẫn đọc được.
    private var emptyVocabView: some View {
        ContentUnavailableView {
            Label("Không còn từ đáng học trên trang này", systemImage: "text.badge.checkmark")
        } description: {
            Text("Các từ trên trang đã thuộc rồi, hoặc không có từ nào cần thêm. Bạn vẫn có thể đọc bản dịch ở tab Trang.")
        } actions: {
            Button("Chụp lại") { recapture() }
                .buttonStyle(.borderedProminent)
            Button("Đóng", role: .cancel) {
                model.discardAnalysis()
                dismiss()
            }
        }
    }

    /// "Đã chọn X/Y" của danh sách CHÍNH — không tính nhóm gập "Đã thuộc" (đếm
    /// riêng ở header của nhóm đó), tránh X vượt Y khi người dùng chọn cả hai.
    private var visibleSelectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    private var vocabRows: some View {
        List {
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
                    VStack(alignment: .leading) {
                        Text("Đã chọn \(visibleSelectedCount)/\(drafts.count)")
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : Motion.reveal, value: visibleSelectedCount)
                        if aiPreselectedCount > 0 {
                            Label(
                                "AI chọn sẵn \(aiPreselectedCount) từ đáng học nhất — bỏ chọn từ bạn đã biết",
                                systemImage: "sparkles")
                                .font(Typo.meta)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !matureHiddenDrafts.isEmpty {
                matureHiddenSection
            }
        }
    }

    /// Q-13 phương án B (ADR-056) — nhóm gập cuối tab Từ vựng: item khớp khoá
    /// `term|pos` đã thuộc, KHÔNG bị xoá khỏi màn duyệt. Gập sẵn (T2 DoD); mở ra
    /// liệt kê đủ nghĩa trong kho kèm nghĩa AI gán cho trang này (`MatureHiddenRow`).
    private var matureHiddenSection: some View {
        Section {
            DisclosureGroup(isExpanded: $matureHiddenExpanded) {
                ForEach(Array(matureHiddenDrafts.enumerated()), id: \.element.id) { index, draft in
                    MatureHiddenRow(
                        draft: $matureHiddenDrafts[index],
                        knownMeanings: matureMeaningsByID[draft.id] ?? [])
                }
            } label: {
                Text("Đã thuộc · \(matureHiddenDrafts.count)")
                    .font(Typo.rowTitle)
            }
        }
    }

    // MARK: - Tab Trang

    /// FR-05/06 (ADR-007/030): song ngữ xen kẽ — EN + VI hiện sẵn từng đoạn, "Ý chính" thu gọn cuối.
    @ViewBuilder
    private func pageView(_ result: PageAnalysis) -> some View {
        if result.segments.isEmpty && result.summaryVI.isEmpty {
            ContentUnavailableView("Không có đoạn văn nào", systemImage: "text.alignleft")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { index, seg in
                        SegmentBlock(
                            segment: seg,
                            isRevealed: isRevealed(index),
                            matcher: encounterMatcher,
                            activePhraseIndex: activePhrase?.segmentIndex == index
                                ? activePhrase?.phraseIndex : nil,
                            accent: accent,
                            onSelect: { encounterSelection = $0 },
                            onPhraseTap: { togglePhrase(segment: index, phrase: $0) },
                            onTap: { toggleSegment(index) })
                    }
                    if !result.summaryVI.isEmpty {
                        SummaryCard(summary: result.summaryVI)
                    }
                }
                .padding(Spacing.md)
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

    private func isRevealed(_ index: Int) -> Bool {
        overriddenSegments.contains(index) ? !showTranslations : showTranslations
    }

    private func toggleSegment(_ index: Int) {
        Motion.run(reduceMotion: reduceMotion) {
            if overriddenSegments.contains(index) {
                overriddenSegments.remove(index)
            } else {
                overriddenSegments.insert(index)
            }
            // Ẩn bản dịch của đoạn đang có cụm sáng → tắt luôn highlight (không
            // còn VI để tô, sáng cụm EN một mình thì vô nghĩa).
            if !isRevealed(index), activePhrase?.segmentIndex == index {
                activePhrase = nil
            }
        }
        Haptics.selection()
    }

    /// Lật riêng đoạn `index` sang hiện, KHÔNG đổi nếu đã hiện — không phát haptics
    /// (dùng khi chạm cụm cần tự hiện bản dịch, khác chạm trực tiếp vào đoạn).
    private func revealIfNeeded(_ index: Int) {
        guard !isRevealed(index) else { return }
        if overriddenSegments.contains(index) {
            overriddenSegments.remove(index)
        } else {
            overriddenSegments.insert(index)
        }
    }

    /// FR-05 (prompt-v6 T3) — chạm cụm EN: sáng/tắt cụm này, tự hiện bản dịch
    /// đoạn nếu đang ẩn. Tối đa một cụm sáng trên cả màn (chạm cụm khác thì đổi).
    private func togglePhrase(segment index: Int, phrase: Int) {
        let target = ActivePhrase(segmentIndex: index, phraseIndex: phrase)
        Motion.run(reduceMotion: reduceMotion) {
            if activePhrase == target {
                activePhrase = nil
            } else {
                activePhrase = target
                revealIfNeeded(index)
            }
        }
        Haptics.selection()
    }
}
