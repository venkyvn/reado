import ReadoKit
import SwiftUI

/// FR-11/FR-12: hàng đợi hai nhánh + vuốt trái=Again(1)/phải=Good(3), Hard/Easy nút.
/// Lật card: `term` + `pos` → `meaning_vi` + IPA + câu gốc + tên collection.
typealias ReviewItem = ReviewQueue.ReviewItem

/// `.srs` = hàng đợi đến hạn (đổi lịch FSRS). `.cram` = ôn thêm thẻ đã học mà
/// CHƯA đến hạn (ADR-011/043) — chấm + log `mode='cram'`, không đổi lịch.
enum ReviewMode { case srs, cram }

struct ReviewQueueView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State var items: [ReviewQueue.ReviewItem] = []
    @State var currentIndex: Int = 0
    @State var flipDegrees: Double = 0

    // Vuốt Tinder (ADR-033): thẻ bám theo tay + tilt + fly-off. Mapping giữ ADR-025.
    @State var dragOffset: CGSize = .zero
    @State var isCommitting = false
    /// Haptic ngưỡng chỉ kêu một lần mỗi lần vượt, không kêu lại mỗi frame kéo.
    @State var didPassThreshold = false

    /// Mặt đang hiện — true khi lật đủ 90° để lộ mặt sau (nghĩa + nút chấm).
    var isFlipped: Bool { flipDegrees >= 90 }

    // Undo 1 bước (FR-12): lưu snapshot + logID vừa chấm.
    @State var lastLogID: String?
    @State var lastSnapshot: CardSnapshot?
    @State var undoSnapshot: CardSnapshot?
    @State var showUndoToast: Bool = false
    @State private var isLoading = true

    // Ăn mừng đo được (ADR-038): đếm dồn phiên + toast "Thuộc rồi!" khi vừa
    // vượt ngưỡng Q-08. Sống trong @State, mất khi rời màn — không persist.
    @State var tally = SessionTally()
    @State var showMasteredToast = false
    @State var masteredToastTerm = ""
    @State var masteredToastTask: Task<Void, Never>?

    /// ADR-043: Cram chỉ vào từ màn hết thẻ; đổi phạm vi thì về `.srs`.
    @State var mode: ReviewMode = .srs

    // FR-18: phạm vi ôn (nil = tất cả) + popover picker.
    @State private var scope: Set<String>? = nil
    @State private var showScopePicker = false

    // U1 ux-polish-r1: nhãn nhịp ôn kế tiếp cho 4 nút chấm — refresh mỗi lần
    // `lastSnapshot` đổi thẻ (loadQueue/gradeNow/undo), không tính trong body.
    @State var intervalLabels: [ReadoRating: String] = [:]

    /// Mở sẵn phạm vi (J2 "Ôn bộ này") — nil = tất cả collection. `showsCloseButton`
/// false khi nhúng làm TAB (không nút "Đóng"); sheet "Ôn bộ này" để true.
    private let showsCloseButton: Bool

    /// Chế độ khi vào màn — `.cram` chỉ từ nút "Ôn thêm" ở header collection.
    private let initialMode: ReviewMode

    init(
        initialScope: Set<String>? = nil,
        showsCloseButton: Bool = true,
        initialMode: ReviewMode = .srs
    ) {
        _scope = State(initialValue: initialScope)
        _mode = State(initialValue: initialMode)
        self.showsCloseButton = showsCloseButton
        self.initialMode = initialMode
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Đang tải hàng đợi…")
            } else if let error = model.reviewError {
                errorView(error)
            } else if items.isEmpty {
                emptyView
                    .transition(.opacity)
            } else if currentIndex < items.count {
                cardView
                    .transition(.opacity)
            } else if mode == .cram {
                // Cram không có ăn mừng tiến bộ (không đổi lịch) — màn kết thúc riêng.
                doneView
                    .transition(.opacity)
            } else if tally.reviewed > 0 {
                // ADR-038: vừa chấm hết phiên → màn ăn mừng tiến bộ đo được.
                SessionDoneView(
                    tally: tally,
                    streak: model.dailyProgress?.streak ?? 0,
                    canLearnMore: (model.dailyProgress?.totalNewRemaining ?? 0) > 0,
                    onLearnMore: {
                        // Ý 3: nới hạn mức riêng hôm nay rồi nạp lại đúng hàng
                        // đợi (scope hiện tại) — quay lại cardView, không phải
                        // dismiss sheet, để thẻ new vừa nới hiện ra.
                        model.learnMore()
                        Task { await loadQueue() }
                    }
                ) {
                    dismiss()
                }
                .transition(.opacity)
            } else {
                // Vào hàng đợi mà đã hết sẵn từ đầu (chưa chấm gì phiên này) —
                // giữ màn trung tính cũ, không ăn mừng cái mình không làm.
                doneView
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: isLoading)
        .navigationTitle(mode == .cram ? "Ôn thêm" : "Ôn tập")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            // FR-18: chọn phạm vi ôn (tất cả / một / vài collection).
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showScopePicker = true
                } label: {
                    Label("Phạm vi", systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Phạm vi ôn")
            }
        }
        .sheet(isPresented: $showScopePicker) {
            ScopePickerSheet(scope: $scope) {
                mode = .srs
                Task { await loadQueue() }
            }
        }
        .onAppear {
            // Vào lại màn (đổi tab) về chế độ khởi tạo (mặc định `.srs`) — Cram chỉ đi
            // từ màn hết thẻ hoặc nút "Ôn thêm" ở header collection (initialMode).
            mode = initialMode
            // Tab Ôn đọc scope mặc định đã lưu (Ôn nhanh ở Kho). Sheet "Ôn bộ này"
            // (showsCloseButton) giữ scope truyền vào thay vì ghi đè.
            if !showsCloseButton {
                scope = model.reviewScopeDefault.scopeSet
            }
            Task { await loadQueue() }
        }
    }

    // MARK: — Empty / Done

    @ViewBuilder
    private var emptyView: some View {
        if mode == .cram {
            ContentUnavailableView {
                Label("Không còn thẻ để ôn thêm", systemImage: "checkmark.circle")
            } description: {
                Text("Chưa có thẻ nào đã học mà chưa đến hạn trong phạm vi này.")
            }
        } else if model.dueOutsideScope > 0, let scope = model.reviewScope, !scope.isEmpty {
            // J5: hết due trong phạm vi nhưng ngoài vẫn còn — nợ phải hiện rõ.
            ContentUnavailableView {
                Label("Không còn thẻ trong phạm vi này", systemImage: "checkmark.circle")
            } description: {
                Text("Còn \(model.dueOutsideScope) thẻ đến hạn nằm ngoài phạm vi đã chọn.")
            } actions: {
                Button("Ôn tất cả") {
                    self.scope = nil
                    Task { await loadQueue() }
                }
                .buttonStyle(.borderedProminent)
                Button("Đổi phạm vi") { showScopePicker = true }
                    .buttonStyle(.bordered)
                cramButton
            }
        } else {
            ContentUnavailableView {
                Label("Không có gì cần ôn", systemImage: "checkmark.circle")
            } description: {
                Text(model.crammableCount > 0
                    ? "Chưa có thẻ nào đến hạn. Bạn vẫn có thể ôn thêm — lịch ôn không bị thay đổi."
                    : "Tất cả thẻ đã được ôn rồi. Bạn có thể chụp trang mới.")
            } actions: {
                cramButton
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    /// ADR-043: vào Cram khi hết thẻ đến hạn mà phạm vi còn thẻ đã học. Không có
    /// thẻ để cram → không hiện gì (nút vô nghĩa).
    @ViewBuilder
    private var cramButton: some View {
        if model.crammableCount > 0 {
            Button("Ôn thêm \(min(model.crammableCount, ReviewQueue.cramBatchSize)) thẻ") {
                mode = .cram
                Task { await loadQueue() }
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(Typo.heroSymbol)
                .foregroundStyle(Theme.ok)
            Text(mode == .cram ? "Đã ôn thêm xong" : "Hết thẻ hôm nay")
                .font(.title2.bold())
            Text(mode == .cram
                ? "Bạn đã ôn thêm \(items.count) thẻ. Lịch ôn không bị thay đổi."
                : "Bạn đã ôn hết \(items.count) thẻ hôm nay.")
                .foregroundStyle(.secondary)
            debtBanner
            if showsCloseButton {
                Button("Đóng") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // FR-18: nợ ngoài phạm vi phải nhìn thấy (research/vocabulary.md 4.2) — khi
    // còn card due ngoài scope, đừng giấu dưới một "Hết thẻ hôm nay" không điều kiện.
    @ViewBuilder
    var debtBanner: some View {
        if model.dueOutsideScope > 0, let scope = model.reviewScope, !scope.isEmpty {
            HStack(spacing: Spacing.row) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.due)
                Text("Còn \(model.dueOutsideScope) thẻ đến hạn ngoài phạm vi")
                    .font(Typo.meta)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Ôn tất cả") {
                    self.scope = nil
                    Task { await loadQueue() }
                }
                .font(Typo.meta.weight(.semibold))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Theme.due.opacity(0.12),
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .padding(.horizontal, Spacing.md)
        }
    }

    /// ADR-038: ăn mừng tiến bộ đo được — vừa vượt ngưỡng "đã thuộc" (Q-08).
    /// Cùng cơ chế toggle với `debtBanner`/undo, tự ẩn qua `showMasteredToast(term:)`.
    @ViewBuilder
    var masteredToastBanner: some View {
        if showMasteredToast {
            HStack(spacing: Spacing.row) {
                Image(systemName: "party.popper.fill")
                    .foregroundStyle(Theme.ok)
                    .accessibilityHidden(true)
                Text("'\(masteredToastTerm)' — nhớ được 21+ ngày")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Theme.ok.opacity(0.12),
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .padding(.horizontal, Spacing.md)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Lỗi khi tải hàng đợi", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Thử lại") { Task { await loadQueue() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private func loadQueue() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if mode == .cram {
                try await model.loadCramQueue(scope: scope)
            } else {
                try await model.loadReviewQueue(scope: scope)
            }
            self.items = model.reviewItems
            // Đổi phạm vi giữa phiên → reset con trỏ thẻ đang ôn.
            self.currentIndex = 0
            self.flipDegrees = 0
            self.dragOffset = .zero
            self.isCommitting = false
            self.didPassThreshold = false
            self.showUndoToast = false
            self.lastLogID = nil
            self.tally = SessionTally()
            self.masteredToastTask?.cancel()
            self.showMasteredToast = false
            if let first = items.first,
               let snap = model.reviewSnapshots[first.cardID] {
                lastSnapshot = snap
            } else {
                lastSnapshot = nil
            }
            refreshIntervals()
        } catch {
            // reviewError đã set trong model.
        }
    }
}
