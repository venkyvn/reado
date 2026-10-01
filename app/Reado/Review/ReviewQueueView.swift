import ReadoKit
import SwiftUI

/// FR-11/FR-12: hàng đợi hai nhánh + vuốt trái=Again(1)/phải=Good(3), Hard/Easy nút.
/// Lật card: `term` + `pos` → `meaning_vi` + IPA + câu gốc + tên collection.
typealias ReviewItem = ReviewQueue.ReviewItem

/// `.srs` = hàng đợi đến hạn (new quota + due). `.extra` = Ôn thêm
/// (extra-review-r1, đảo ADR-011/043) — trộn thẻ mới + ôn sớm, MỌI lượt chấm
/// vẫn ghi lịch thật qua `AppModel.grade`/`undoReview`, chỉ khác nguồn hàng đợi.
enum ReviewMode { case srs, extra }

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
    /// Điểm neo = `translation` tại lần `onChanged` đầu (`minimumDistance` đã
    /// nuốt sẵn vài pt trước khi gesture bắt đầu báo) — trừ neo để thẻ đi theo
    /// tay từ 0, không nhảy một bậc lúc bắt đầu kéo (T4 shell-chrome-r1).
    @State var dragAnchor: CGSize?
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
    /// Lỗi khi chấm/hoàn tác giữa phiên (khác `model.review.error` — cái đó chỉ
    /// dành cho lỗi tải hàng đợi, không thay cả màn bằng `errorView`).
    @State var actionError: String?

    // Ăn mừng đo được (ADR-038): đếm dồn phiên + toast "Thuộc rồi!" khi vừa
    // vượt ngưỡng Q-08. Sống trong @State, mất khi rời màn — không persist.
    @State var tally = SessionTally()
    @State var showMasteredToast = false
    @State var masteredToastTerm = ""
    @State var masteredToastTask: Task<Void, Never>?

    /// Ôn thêm vào từ CTA (màn hết thẻ / header collection / Home); đổi phạm
    /// vi thì về `.srs`.
    @State var mode: ReviewMode = .srs

    // FR-18: phạm vi ôn (nil = tất cả) + popover picker.
    @State private var scope: Set<String>? = nil
    @State private var showScopePicker = false

    // U1 ux-polish-r1: nhãn nhịp ôn kế tiếp cho 4 nút chấm — refresh mỗi lần
    // `lastSnapshot` đổi thẻ (loadQueue/gradeNow/undo), không tính trong body.
    @State var intervalLabels: [ReadoRating: String] = [:]

    /// ux-redesign-r1 T1a: đã nạp hàng đợi lần đầu chưa — màn luôn nằm trong cover
    /// toàn màn (`RootView` + `ReviewRequest`), `onAppear` không được nạp lại làm mất `tally`.
    @State private var hasLoaded = false

    /// `initialScope` nil = tất cả collection (J2 "Ôn bộ này" truyền [id]); `initialMode`
    /// `.extra` từ nút "Ôn thêm" ở header collection / Home.
    init(initialScope: Set<String>? = nil, initialMode: ReviewMode = .srs) {
        _scope = State(initialValue: initialScope)
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Đang tải hàng đợi…")
            } else if let error = model.review.error {
                errorView(error)
            } else if items.isEmpty {
                emptyView
                    .transition(.opacity)
            } else if currentIndex < items.count {
                cardView
                    .transition(.opacity)
            } else if tally.reviewed > 0 {
                // ADR-038: vừa chấm hết phiên (srs hoặc extra — cả hai đều ghi
                // lịch thật, extra-review-r1) → màn ăn mừng tiến bộ đo được.
                SessionDoneView(
                    tally: tally,
                    streak: model.dailyProgress?.streak ?? 0,
                    extraAvailable: model.review.extraAvailableCount,
                    onExtra: {
                        // Lượt Ôn thêm kế tiếp — cùng scope, không đóng cover.
                        mode = .extra
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
        .navigationTitle(mode == .extra ? "Ôn thêm" : "Ôn tập")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Đóng", systemImage: "xmark")
                }
                .accessibilityLabel("Đóng")
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
        .alert(
            "Không lưu được",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } })
        ) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .onAppear {
            // Chỉ nạp lần đầu: scope/mode đã vào qua `init` (người gọi tự chọn,
            // Home truyền scope mặc định đã lưu), nạp lại sẽ reset con trỏ + tally.
            guard !hasLoaded else { return }
            hasLoaded = true
            Task { await loadQueue() }
        }
    }

    // MARK: — Empty / Done

    @ViewBuilder
    private var emptyView: some View {
        if mode == .extra {
            ContentUnavailableView {
                Label("Không còn thẻ để ôn thêm", systemImage: "checkmark.circle")
            } description: {
                Text("Chưa có từ mới hay thẻ nào đã học mà chưa đến hạn trong phạm vi này.")
            }
        } else if model.review.dueOutsideScope > 0, let scope = model.review.scope, !scope.isEmpty {
            // J5: hết due trong phạm vi nhưng ngoài vẫn còn — nợ phải hiện rõ.
            ContentUnavailableView {
                Label("Không còn thẻ trong phạm vi này", systemImage: "checkmark.circle")
            } description: {
                Text("Còn \(model.review.dueOutsideScope) thẻ đến hạn nằm ngoài phạm vi đã chọn.")
            } actions: {
                Button("Ôn tất cả") {
                    self.scope = nil
                    Task { await loadQueue() }
                }
                .buttonStyle(.borderedProminent)
                Button("Đổi phạm vi") { showScopePicker = true }
                    .buttonStyle(.bordered)
                extraButton
            }
        } else {
            ContentUnavailableView {
                Label("Không có gì cần ôn", systemImage: "checkmark.circle")
            } description: {
                Text(model.review.extraAvailableCount > 0
                    ? "Chưa có thẻ nào đến hạn. Bạn vẫn có thể ôn thêm từ mới hoặc ôn sớm."
                    : "Tất cả thẻ đã được ôn rồi. Bạn có thể chụp trang mới.")
            } actions: {
                extraButton
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    /// extra-review-r1: hiện khi còn từ mới hoặc thẻ ôn sớm trong phạm vi.
    /// Không còn gì → không hiện (nút vô nghĩa).
    @ViewBuilder
    private var extraButton: some View {
        if model.review.extraAvailableCount > 0 {
            Button("Ôn thêm \(min(model.review.extraAvailableCount, ReviewQueue.extraBatchSize)) thẻ") {
                mode = .extra
                Task { await loadQueue() }
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(Typo.heroSymbol)
                .foregroundStyle(Theme.ok)
            Text(mode == .extra ? "Đã ôn thêm xong" : "Hết thẻ hôm nay")
                .font(.title2.bold())
            Text(mode == .extra
                ? "Bạn đã ôn thêm \(items.count) thẻ."
                : "Bạn đã ôn hết \(items.count) thẻ hôm nay.")
                .foregroundStyle(.secondary)
            debtBanner
            Button("Đóng") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // FR-18: nợ ngoài phạm vi phải nhìn thấy (research/vocabulary.md 4.2) — khi
    // còn card due ngoài scope, đừng giấu dưới một "Hết thẻ hôm nay" không điều kiện.
    @ViewBuilder
    var debtBanner: some View {
        if model.review.dueOutsideScope > 0, let scope = model.review.scope, !scope.isEmpty {
            HStack(spacing: Spacing.row) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.due)
                Text("Còn \(model.review.dueOutsideScope) thẻ đến hạn ngoài phạm vi")
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
            if mode == .extra {
                try await model.loadExtraQueue(scope: scope)
            } else {
                try await model.loadReviewQueue(scope: scope)
            }
            self.items = model.review.items
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
               let snap = model.review.snapshots[first.cardID] {
                lastSnapshot = snap
            } else {
                lastSnapshot = nil
            }
            refreshIntervals()
        } catch {
            // review.error đã set trong model.
        }
    }
}
