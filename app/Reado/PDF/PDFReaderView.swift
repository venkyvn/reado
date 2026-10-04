import PDFKit
import ReadoKit
import SwiftUI

/// FR-23/ADR-058+059+060 (pdf-reader-r1 T3, pdf-nav-r1) — đọc một file PDF
/// ngay trong Reado. Lật trang kiểu sách (vuốt ngang) vẫn là lối đọc chính;
/// chạm "Tr. N / M" để gõ số trang và Mục lục (outline sẵn có trong file) là
/// lối nhảy nhanh (ADR-059 — bỏ thanh kéo trang sau khi fen xem tay thấy
/// không cần, ADR-060). Chạm vào trang → ẩn/hiện cả nav bar lẫn thanh đáy để
/// tập trung đọc (ADR-060). Thanh tab luôn ẩn trong lúc đọc — xem
/// `RootView.isReadingPDF`.
struct PDFReaderView: View {
    let collectionID: String

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var document: PDFDocument?
    @State private var activeURL: URL?
    @State private var pageCount = 0
    @State private var currentPageIndex = 0
    @State private var openError: PDFOpenError?
    @State private var showFilePicker = false
    @State private var pendingSaveTask: Task<Void, Never>?
    @State private var navigator = PDFReaderNavigator()
    @State private var outlineEntries: [PDFNavigation.OutlineEntry] = []
    @State private var showOutlineSheet = false
    @State private var showGoToAlert = false
    @State private var goToPageText = ""
    /// ADR-060 — chạm vào trang để tập trung đọc: ẩn nav bar (tiêu đề + nút
    /// Mục lục) và thanh đáy (Tr. N/M + CTA) cùng lúc. Chạm lại để hiện lại.
    @State private var isChromeHidden = false
    /// ADR-060 — tông nền trang đọc (trắng/giấy nâu), lưu theo máy (không
    /// theo collection) — fen hỏi "có theme màu nâu, be để dễ đọc không".
    /// PDFKit vẽ nguyên trang PDF (không tự đổi màu theo Dark Mode), nên đây
    /// là tuỳ chọn riêng của reader, tách khỏi `AppTheme` (accent UI chrome).
    @AppStorage("readoPDFPageTint") private var pdfPageTintRaw = PDFPageTint.white.rawValue
    private var pdfPageTint: PDFPageTint { PDFPageTint(rawValue: pdfPageTintRaw) ?? .white }

    private var collectionName: String {
        model.collections.first { $0.id == collectionID }?.name ?? "Bộ"
    }

    var body: some View {
        content
            .navigationTitle(collectionName)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(PDFPageTint.allCases) { tint in
                            Button {
                                Haptics.selection()
                                pdfPageTintRaw = tint.rawValue
                            } label: {
                                Label(tint.label, systemImage: pdfPageTint == tint ? "checkmark" : tint.symbol)
                            }
                        }
                    } label: {
                        Label("Tông nền", systemImage: "paintpalette")
                    }
                }
                if !outlineEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.selection()
                            showOutlineSheet = true
                        } label: {
                            Label("Mục lục", systemImage: "list.bullet")
                        }
                    }
                }
            }
            .toolbar(isChromeHidden ? .hidden : .visible, for: .navigationBar)
            .onAppear { open(force: false) }
            .onDisappear { closeDocument(savingCurrentPage: true) }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePicked(result)
            }
            .sheet(isPresented: $showOutlineSheet) {
                PDFOutlineSheet(
                    entries: outlineEntries,
                    currentEntryID: PDFNavigation.currentEntryID(
                        in: outlineEntries, pageIndex: currentPageIndex),
                    onSelect: jump(to:))
            }
            .alert("Đi tới trang", isPresented: $showGoToAlert) {
                TextField("1–\(pageCount)", text: $goToPageText)
                    .keyboardType(.numberPad)
                Button("Huỷ", role: .cancel) {}
                Button("Đi") { submitGoToPage() }
            } message: {
                Text("Sách có \(pageCount) trang.")
            }
            #if DEBUG
            .task { await applyDebugFlagsIfNeeded() }
            #endif
    }

    @ViewBuilder
    private var content: some View {
        if let document {
            readerBody(document)
        } else if let openError {
            errorState(openError)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func readerBody(_ document: PDFDocument) -> some View {
        VStack(spacing: 0) {
            PDFPageView(
                document: document,
                navigator: navigator,
                initialPageIndex: currentPageIndex,
                onPageChanged: { index in
                    currentPageIndex = index
                    scheduleSavePage(index)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // ADR-060 — PDFKit vẽ nguyên trang PDF (trắng), không có API
                // đổi màu giấy — giả lập bằng lớp phủ `.multiply`: trang
                // trắng × tint = tint, chữ đen × tint ≈ vẫn đen, không cần vẽ
                // lại từng trang. `allowsHitTesting(false)` để không chặn
                // vuốt lật trang / chạm ẩn chrome của view bên dưới.
                .overlay {
                    if let tint = pdfPageTint.color {
                        tint.blendMode(.multiply).allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isChromeHidden.toggle()
                    }
                }
            if !isChromeHidden {
                bottomBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: — Thanh đáy (ADR-059/060): "Tr. N / M" (chạm để gõ số trang) +
    // CTA phân tích. Slider/◀▶ đã bỏ — fen xem tay thấy gõ trang + Mục lục đã
    // đủ, thanh kéo dùng không hiệu quả.

    private var bottomBar: some View {
        pageInfoRow
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.bar, ignoresSafeAreaEdges: .bottom)
    }

    private var pageInfoRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                pageNumberButton
                Spacer()
                analyzeButton
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                pageNumberButton
                analyzeButton.frame(maxWidth: .infinity)
            }
        }
    }

    private var pageNumberButton: some View {
        Button {
            goToPageText = ""
            showGoToAlert = true
        } label: {
            Text("Tr. \(currentPageIndex + 1) / \(max(pageCount, 1))")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
        }
        .accessibilityHint("Chạm để gõ số trang")
    }

    // FR-23/ADR-058 (pdf-reader-r1 T4): lớp chữ tốt hay rơi về OCR do
    // `PDFPageText`/`preparePDFAnalysis` tự quyết — người dùng chỉ bấm,
    // không tự chọn. Ẩn khi đang chờ (đã bấm rồi, tránh bấm đúp).
    private var analyzeButton: some View {
        Button("Phân tích trang này") {
            triggerAnalysis()
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.shell.pendingPDFAnalysis)
    }

    @ViewBuilder
    private func errorState(_ error: PDFOpenError) -> some View {
        ContentUnavailableView {
            Label("Không mở được PDF", systemImage: "doc.questionmark")
        } description: {
            Text(error.errorDescription ?? "")
        } actions: {
            if error.allowsPickingAgain {
                Button("Chọn lại file") { showFilePicker = true }
            }
        }
    }

    // MARK: — Mở / đóng

    /// `force: false` (mặc định `.onAppear`) không mở lại nếu đã có `document`
    /// — SwiftUI có thể gọi `onAppear` nhiều lần (ví dụ pop rồi push lại cùng
    /// instance trong một số luồng NavigationStack). `force: true` sau khi gắn
    /// lại file ở màn lỗi.
    private func open(force: Bool) {
        guard force || document == nil else { return }
        closeDocument(savingCurrentPage: false)
        switch model.openPDFDocument(collectionID: collectionID) {
        case let .success((doc, url, pageIndex, didStartAccess)):
            activeURL = didStartAccess ? url : nil
            document = doc
            pageCount = doc.pageCount
            currentPageIndex = pageIndex
            outlineEntries = PDFNavigation.outlineEntries(in: doc)
            openError = nil
        case let .failure(error):
            openError = error
        }
    }

    private func closeDocument(savingCurrentPage: Bool) {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        if savingCurrentPage, document != nil {
            model.savePDFPage(collectionID: collectionID, pageIndex: currentPageIndex)
        }
        activeURL?.stopAccessingSecurityScopedResource()
        activeURL = nil
        document = nil
        outlineEntries = []
    }

    /// Debounce 0.5s — lật trang nhanh liên tục không ghi DB mỗi hàng; `onDisappear`
    /// luôn lưu ngay một lần nữa (kể cả debounce chưa kịp chạy).
    private func scheduleSavePage(_ index: Int) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            model.savePDFPage(collectionID: collectionID, pageIndex: index)
        }
    }

    /// ADR-059 — cửa chung cho gõ trang/Mục lục: nhảy `PDFView` qua
    /// `navigator`, rồi tự cập nhật state + lưu trang như lật tay (không dựa
    /// hoàn toàn vào `.PDFViewPageChanged` có bắn hay không khi gọi `go(to:)`).
    private func jump(to index: Int) {
        let clamped = PDFNavigation.clamp(index, pageCount: pageCount)
        navigator.go(to: clamped)
        currentPageIndex = clamped
        scheduleSavePage(clamped)
    }

    private func submitGoToPage() {
        guard let index = PDFNavigation.pageIndex(fromInput: goToPageText, pageCount: pageCount) else {
            Haptics.error()
            model.alertMessage = "Số trang không hợp lệ — gõ một số từ 1 đến \(pageCount)."
            return
        }
        Haptics.selection()
        jump(to: index)
    }

    /// FR-23/ADR-058 (pdf-reader-r1 T4) — bấm "Phân tích trang này": lấy đúng
    /// `PDFPage` của trang đang đọc rồi giao cho model (chấm lớp chữ, bật
    /// `shell.pendingPDFAnalysis`; `RootView` tiêu thụ cờ đó và mở sheet).
    /// Không tự `dismiss()` ở đây — sheet phủ LÊN TRÊN, reader vẫn đứng nguyên
    /// phía dưới nên đóng sheet (Lưu / "Về trang đọc") tự lộ lại đúng chỗ.
    private func triggerAnalysis() {
        guard let document, let page = document.page(at: currentPageIndex) else { return }
        Haptics.action()
        model.preparePDFAnalysis(page: page, collectionID: collectionID)
    }

    private func handlePicked(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first else { return }
        guard model.attachPDFOrAlert(url: url, collectionID: collectionID) else { return }
        currentPageIndex = 0
        open(force: true)
    }

    #if DEBUG
    /// pdf-nav-r1 — `-ReadoScreen pdf-reader-toc`/`pdf-reader-goto` set cờ ở
    /// `ShellSignals` trước khi push reader (`RootView.openDebugPDFReader`);
    /// đợi document mở xong (0.6s, cùng nhịp các cờ debug khác) rồi mở sheet/
    /// alert tương ứng, dọn cờ ngay để không kẹt lúc pop/push lại.
    private func applyDebugFlagsIfNeeded() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
        if model.shell.debugShowPDFOutline {
            model.shell.debugShowPDFOutline = false
            showOutlineSheet = true
        }
        if model.shell.debugShowPDFGoTo {
            model.shell.debugShowPDFGoTo = false
            goToPageText = ""
            showGoToAlert = true
        }
    }
    #endif
}

/// ADR-060 — tông nền trang đọc, riêng với `AppTheme` (accent UI chrome).
/// `.white` = không phủ gì (nguyên trang PDF).
private enum PDFPageTint: String, CaseIterable, Identifiable {
    case white
    case sepia

    var id: String { rawValue }

    var label: String {
        switch self {
        case .white: "Trắng"
        case .sepia: "Giấy nâu"
        }
    }

    var symbol: String {
        switch self {
        case .white: "circle"
        case .sepia: "circle.fill"
        }
    }

    /// Màu phủ blend `.multiply` lên trang — không lấy từ `DesignSystem`
    /// (token ở đó là accent UI chrome, không phải màu giấy nội dung đọc).
    /// Một sắc độ duy nhất, không cần bản dark mode riêng vì PDFKit luôn vẽ
    /// trang trắng bất kể Appearance hệ thống.
    var color: Color? {
        switch self {
        case .white: nil
        case .sepia: Color(red: 0.94, green: 0.88, blue: 0.74)
        }
    }
}

/// `PDFView` (PDFKit) bọc trong `UIViewRepresentable` — lật trang kiểu sách
/// (`usePageViewController`), theo dõi `.PDFViewPageChanged` để báo trang hiện
/// tại ra ngoài cho `PDFReaderView` lưu lại. `navigator.pdfView` gán ở
/// `makeUIView` để gõ trang/Mục lục điều khiển được view này từ ngoài
/// (ADR-059).
private struct PDFPageView: UIViewRepresentable {
    let document: PDFDocument
    let navigator: PDFReaderNavigator
    let initialPageIndex: Int
    let onPageChanged: (Int) -> Void

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true, withViewOptions: nil)
        view.document = document
        if let page = document.page(at: initialPageIndex) {
            view.go(to: page)
        }
        navigator.pdfView = view
        context.coordinator.observe(view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context _: Context) {
        guard uiView.document !== document else { return }
        uiView.document = document
        if let page = document.page(at: initialPageIndex) {
            uiView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageChanged: onPageChanged)
    }

    final class Coordinator: NSObject {
        private let onPageChanged: (Int) -> Void
        private weak var observedView: PDFView?

        init(onPageChanged: @escaping (Int) -> Void) {
            self.onPageChanged = onPageChanged
        }

        func observe(_ view: PDFView) {
            guard observedView !== view else { return }
            if let observedView {
                NotificationCenter.default.removeObserver(
                    self, name: .PDFViewPageChanged, object: observedView)
            }
            observedView = view
            NotificationCenter.default.addObserver(
                self, selector: #selector(pageChanged),
                name: .PDFViewPageChanged, object: view)
        }

        @objc private func pageChanged() {
            guard let observedView, let page = observedView.currentPage,
                  let document = observedView.document
            else { return }
            onPageChanged(document.index(for: page))
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
