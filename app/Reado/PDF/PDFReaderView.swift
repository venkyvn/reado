import PDFKit
import ReadoKit
import SwiftUI

/// FR-23/ADR-058 (pdf-reader-r1) — đọc một file PDF ngay trong Reado. T3: đọc
/// + nhớ trang. CTA "Phân tích trang này" (T4) CHƯA có ở task này — thanh đáy
/// chỉ hiện số trang.
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

    private var collectionName: String {
        model.collections.first { $0.id == collectionID }?.name ?? "Bộ"
    }

    var body: some View {
        content
            // Gotcha `reado-ui`: màn push qua `navigationDestination` không tự
            // thừa hưởng `safeAreaInset` của `ShellTabBar` xuyên `TabView` —
            // phải tự chừa, không thì PDFView lấp xuống tận đáy, đẩy
            // `bottomBar` ra sau thanh tab (đã xem tay bằng nền đỏ để xác nhận).
            .safeAreaPadding(.bottom, ShellTabBar.reservedHeight)
            .navigationTitle(collectionName)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .onAppear { open(force: false) }
            .onDisappear { closeDocument(savingCurrentPage: true) }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePicked(result)
            }
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
                initialPageIndex: currentPageIndex,
                onPageChanged: { index in
                    currentPageIndex = index
                    scheduleSavePage(index)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
    }

    private var bottomBar: some View {
        HStack {
            Text("Tr. \(currentPageIndex + 1) / \(max(pageCount, 1))")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
            Spacer()
            // T4 (pdf-reader-r1): CTA "Phân tích trang này" vào đây.
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
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
        case let .success((doc, url, pageIndex)):
            activeURL = url
            document = doc
            pageCount = doc.pageCount
            currentPageIndex = pageIndex
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

    private func handlePicked(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first else { return }
        guard model.attachPDFOrAlert(url: url, collectionID: collectionID) else { return }
        currentPageIndex = 0
        open(force: true)
    }
}

/// `PDFView` (PDFKit) bọc trong `UIViewRepresentable` — lật trang kiểu sách
/// (`usePageViewController`), theo dõi `.PDFViewPageChanged` để báo trang hiện
/// tại ra ngoài cho `PDFReaderView` lưu lại.
private struct PDFPageView: UIViewRepresentable {
    let document: PDFDocument
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
