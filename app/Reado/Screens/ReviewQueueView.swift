import ReadoKit
import SwiftUI

/// FR-11/FR-12: hàng đợi hai nhánh + vuốt trái=Again(1)/phải=Good(3), Hard/Easy nút.
/// Lật card: `term` + `pos` → `meaning_vi` + IPA + câu gốc + tên collection.
typealias ReviewItem = ReviewQueue.ReviewItem

/// `.srs` = hàng đợi đến hạn (đổi lịch FSRS). `.cram` = ôn thêm thẻ đã học mà
/// CHƯA đến hạn (ADR-011/043) — chấm + log `mode='cram'`, không đổi lịch.
enum ReviewMode { case srs, cram }

struct ReviewQueueView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var items: [ReviewQueue.ReviewItem] = []
    @State private var currentIndex: Int = 0
    @State private var flipDegrees: Double = 0

    // Vuốt Tinder (ADR-033): thẻ bám theo tay + tilt + fly-off. Mapping giữ ADR-025.
    @State private var dragOffset: CGSize = .zero
    @State private var isCommitting = false
    /// Haptic ngưỡng chỉ kêu một lần mỗi lần vượt, không kêu lại mỗi frame kéo.
    @State private var didPassThreshold = false

    /// Mặt đang hiện — true khi lật đủ 90° để lộ mặt sau (nghĩa + nút chấm).
    private var isFlipped: Bool { flipDegrees >= 90 }

    // Undo 1 bước (FR-12): lưu snapshot + logID vừa chấm.
    @State private var lastLogID: String?
    @State private var lastSnapshot: CardSnapshot?
    @State private var undoSnapshot: CardSnapshot?
    @State private var showUndoToast: Bool = false
    @State private var isLoading = true

    // Ăn mừng đo được (ADR-038): đếm dồn phiên + toast "Thuộc rồi!" khi vừa
    // vượt ngưỡng Q-08. Sống trong @State, mất khi rời màn — không persist.
    @State private var tally = SessionTally()
    @State private var showMasteredToast = false
    @State private var masteredToastTerm = ""
    @State private var masteredToastTask: Task<Void, Never>?

    /// ADR-043: Cram chỉ vào từ màn hết thẻ; đổi phạm vi thì về `.srs`.
    @State private var mode: ReviewMode = .srs

    // FR-18: phạm vi ôn (nil = tất cả) + popover picker.
    @State private var scope: Set<String>? = nil
    @State private var showScopePicker = false

    // U1 ux-polish-r1: nhãn nhịp ôn kế tiếp cho 4 nút chấm — refresh mỗi lần
    // `lastSnapshot` đổi thẻ (loadQueue/gradeNow/undo), không tính trong body.
    @State private var intervalLabels: [ReadoRating: String] = [:]

    /// Mở sẵn phạm vi (J2 "Ôn bộ này") — nil = tất cả collection. `showsCloseButton`
/// false khi nhúng làm TAB (không nút "Đóng"); sheet "Ôn bộ này" để true.
    private let showsCloseButton: Bool

    init(initialScope: Set<String>? = nil, showsCloseButton: Bool = true) {
        _scope = State(initialValue: initialScope)
        self.showsCloseButton = showsCloseButton
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
            // Vào lại màn (đổi tab) luôn về hàng đợi đến hạn — Cram chỉ đi từ màn hết thẻ.
            mode = .srs
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
    private var debtBanner: some View {
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
    private var masteredToastBanner: some View {
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

    // MARK: — Card

    private var cardView: some View {
        let item = items[currentIndex]
        return VStack(spacing: Spacing.lg) {
            debtBanner
            masteredToastBanner

            // Progress: thanh + "n/N" (thanh ẩn khỏi VoiceOver — chữ đã đọc đủ).
            HStack(spacing: Spacing.row) {
                ProgressView(value: Double(currentIndex), total: Double(max(items.count, 1)))
                    .accessibilityHidden(true)
                Text("\(currentIndex + 1)/\(items.count)")
                    .font(Typo.meta)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                if mode == .cram {
                    Text("Ôn thêm")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .accessibilityLabel("Chế độ ôn thêm, không đổi lịch")
                }
                // FR-12: undo nút nổi 1 bước.
                if showUndoToast {
                    Button("Hoàn tác") {
                        performUndo()
                    }
                    .buttonStyle(.bordered)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)

            Spacer(minLength: 0)

            // Card body. Thẻ kế nằm dưới, phóng dần khi thẻ trên bị kéo — cảm giác chồng bài.
            GeometryReader { geo in
                ZStack {
                    if currentIndex + 1 < items.count {
                        cardFace(item: items[currentIndex + 1], back: false, size: geo.size)
                            .scaleEffect(0.96 + 0.04 * swipeProgress)
                            .offset(y: 14 * (1 - swipeProgress))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    // .id: thẻ mới không kế thừa offset của thẻ vừa bay ra.
                    faceStack(item: item, size: geo.size)
                        .id(item.cardID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .overlay(swipeStamp)
                        // Xoay trước, kéo sau. Ngược lại rotationEffect xoay quanh tâm
                        // gốc (chưa offset) và thẻ đi theo cung tròn, lệch khỏi tay.
                        // Neo tâm: neo dưới đáy + offset đủ sẽ làm thẻ chạy nhanh hơn ngón tay.
                        .rotationEffect(.degrees(dragAngle))
                        .offset(dragOffset)
                }
            }
            .padding(.horizontal, Spacing.md)
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .gesture(swipeGesture)
            // Tap chỉ thuộc vùng thẻ. Đặt trên VStack cha sẽ khiến nút chấm/
            // Hoàn tác có thể đồng thời kích hoạt flip.
            .onTapGesture {
                guard !isCommitting else { return }
                flipCard()
            }
            .frontGradeActions(enabled: !isFlipped, grade: performGrade)
            .accessibilityAction(named: Text(isFlipped ? "Hiện mặt trước" : "Lật thẻ")) {
                flipCard()
            }

            Spacer(minLength: 0)

            // Bottom controls.
            if isFlipped {
                gradeButtons
                    .revealTransition()
            } else {
                Text("Chạm để lật · trái Quên · phải Được")
                    .foregroundStyle(.secondary)
                    .font(Typo.meta)
                    .revealTransition()
            }
        }
    }

    /// U1: nạp lại nhãn nhịp ôn cho thẻ đang đứng ở `lastSnapshot`.
    private func refreshIntervals() {
        // Cram không đổi lịch → nhãn "ôn lại sau …" sẽ sai, ẩn hẳn.
        guard mode == .srs else { intervalLabels = [:]; return }
        intervalLabels = lastSnapshot.map { model.intervalLabels(for: $0) } ?? [:]
    }

    private func flipCard() {
        let target: Double = flipDegrees == 0 ? 180 : 0
        // Reduce Motion: đổi mặt tức thì, không quay 3D.
        Motion.run(reduceMotion: reduceMotion,
                   .spring(response: 0.4, dampingFraction: 0.8)) {
            flipDegrees = target
        }
        Haptics.selection()
    }

    /// Hai mặt thẻ, đổi đúng mốc 90° (không crossfade).
    private func faceStack(item: ReviewQueue.ReviewItem, size: CGSize) -> some View {
        ZStack {
            cardFace(item: item, back: false, size: size)
                .rotation3DEffect(.degrees(flipDegrees),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(flipDegrees < 90 ? 1 : 0)
            cardFace(item: item, back: true, size: size)
                .rotation3DEffect(.degrees(flipDegrees - 180),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(flipDegrees >= 90 ? 1 : 0)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isCommitting, !reduceMotion else { return }
                dragOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height * SwipeMotion.verticalDamp)
                let passed = abs(value.translation.width) >= SwipeCommit.threshold
                if passed, !didPassThreshold {
                    Haptics.threshold()
                }
                didPassThreshold = passed
            }
            .onEnded { value in
                guard !isCommitting else { return }
                // Ngưỡng theo điểm thoát dự đoán: hất nhanh dưới 110pt vẫn chấm.
                let predicted = value.predictedEndTranslation.width
                guard let rating = SwipeCommit.rating(predictedWidth: predicted) else {
                    snapBack()
                    return
                }
                if reduceMotion {
                    performGrade(rating)
                } else {
                    commitSwipe(rating, predictedWidth: predicted)
                }
            }
    }

    /// 0…1 theo quãng kéo ngang. Stamp, thẻ kế, và haptic cùng một thước.
    private var swipeProgress: CGFloat {
        min(abs(dragOffset.width) / SwipeCommit.threshold, 1)
    }

    /// Tilt theo tay: ~1° mỗi 15pt, kẹp ±12° để thẻ không xoay quá giả.
    private var dragAngle: Double {
        min(max(Double(dragOffset.width) / SwipeMotion.pointsPerDegree,
                -SwipeMotion.maxTilt),
            SwipeMotion.maxTilt)
    }

    /// Stamp "Quên"/"Được" hiện theo hướng kéo, đậm dần tới ngưỡng chấm.
    @ViewBuilder
    private var swipeStamp: some View {
        if swipeProgress > 0.02 {
            ZStack {
                if dragOffset.width < 0 {
                    badgeLabel(stampText(.again), color: Theme.danger)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .rotationEffect(.degrees(-10))
                } else {
                    badgeLabel(stampText(.good), color: Theme.ok)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .rotationEffect(.degrees(10))
                }
            }
            .padding(Spacing.lg)
            .opacity(swipeProgress)
        }
    }

    /// U1: nhãn stamp kèm nhịp ôn khi có sẵn — "Quên · 1 ngày" thay vì trơ "Quên".
    private func stampText(_ rating: ReadoRating) -> String {
        guard let hint = intervalLabels[rating] else { return rating.label }
        return "\(rating.label) · \(hint)"
    }

    private func badgeLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(color, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 2))
    }

    private func commitSwipe(_ rating: ReadoRating, predictedWidth: CGFloat) {
        isCommitting = true
        Haptics.action()
        let dir = SwipeCommit.direction(predictedWidth: predictedWidth)
        // Giữ height đang damp — lấy translation.height thô sẽ làm thẻ nhảy dọc lúc bay.
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: dir * SwipeMotion.flyDistance, height: dragOffset.height)
        } completion: {
            isCommitting = false
            // gradeNow, không performGrade: cờ vừa hạ, đọc lại @State trong cùng lượt có thể vẫn thấy true.
            gradeNow(rating)
        }
    }

    private func snapBack() {
        didPassThreshold = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            dragOffset = .zero
        }
    }

    private func cardFace(item: ReviewQueue.ReviewItem, back: Bool, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.systemBackground))
                .cardShadow()
            if !back {
                // FR-12: mặt trước = term + pos.
                VStack(spacing: Spacing.row) {
                    Text(item.term)
                        .font(Typo.cardTerm)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                    Pill(text: item.pos, tone: .neutral)
                    // ADR-040: nghe cách đọc — không luyện nói, không chấm.
                    SpeakButton(term: item.term)
                }
                .padding(Spacing.lg)
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        backFaceContent(item)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    backFaceContent(item)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// FR-12: mặt sau = meaning_vi, IPA, câu gốc, tên collection.
    private func backFaceContent(_ item: ReviewQueue.ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            // Nhắc lại từ: đáp án (nghĩa) là dòng to nhất, từ chỉ là ngữ cảnh.
            Text(item.term)
                .font(Typo.rowTitle)
                .foregroundStyle(.secondary)
            Text(item.meaningVI)
                .font(Typo.cardAnswer)
            HStack(spacing: Spacing.sm) {
                if let ipa = item.ipa, !ipa.isEmpty {
                    Text("/\(ipa)/").font(Typo.rowSubtitle).foregroundStyle(.secondary)
                }
                SpeakButton(term: item.term)
            }
            Text(item.example)
                .font(.body)
                .italic()
            Divider()
            Text(item.collectionName)
                .font(Typo.meta)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        // Cùng khung với mặt trước, neo trên-trái thay vì trôi giữa thẻ.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: — Grade buttons (ADR-025: TRÁI=Again(1), PHẢI=Good(3); Hard/Easy nút)

    private var gradeButtons: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.row),
                        GridItem(.flexible(), spacing: Spacing.row),
                    ],
                    spacing: Spacing.row
                ) {
                    gradeButton(.again)
                    gradeButton(.hard)
                    gradeButton(.good)
                    gradeButton(.easy)
                }
            } else {
                HStack(spacing: Spacing.row) {
                    gradeButton(.again)
                    gradeButton(.hard)
                    gradeButton(.good)
                    gradeButton(.easy)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.lg)
    }

    private func gradeButton(_ rating: ReadoRating) -> some View {
        let hint = intervalLabels[rating]
        return Button {
            performGrade(rating)
        } label: {
            VStack(spacing: Spacing.tight) {
                Text(rating.label)
                    .font(.subheadline.weight(.semibold))
                if let hint {
                    Text(hint)
                        .font(.caption2)
                        .monospacedDigit()
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(rating.buttonBackground)
            .foregroundStyle(rating.buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .accessibilityLabel(hint.map { "\(rating.label), ôn lại sau \($0)" } ?? rating.label)
    }

    private func performGrade(_ rating: ReadoRating) {
        // Nút và action vẫn bấm được trong lúc thẻ bay — chặn chấm đè.
        guard !isCommitting else { return }
        Haptics.action()
        gradeNow(rating)
    }

    private func gradeNow(_ rating: ReadoRating) {
        guard currentIndex < items.count else { return }
        // Thả offset ngay, ngoài animation đổi thẻ — thẻ sau không trượt từ vị trí kéo.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragOffset = .zero
            didPassThreshold = false
        }
        let item = items[currentIndex]
        guard let snapshot = lastSnapshot else { return }
        let gradedSnapshot = snapshot
        do {
            let result = mode == .cram
                ? try model.gradeCram(
                    cardID: item.cardID, snapshot: gradedSnapshot, rating: rating)
                : try model.grade(
                    cardID: item.cardID, snapshot: gradedSnapshot, rating: rating)
            // Lưu snapshot/log của thẻ vừa chấm để undo (FR-12) — tách khỏi lastSnapshot.
            lastLogID = result.logID
            undoSnapshot = gradedSnapshot
            if mode == .srs {
                tally.record(rating: rating, crossed: result.crossedMastery, term: item.term)
            }
            Motion.run(reduceMotion: reduceMotion) {
                showUndoToast = true
            }
            if result.crossedMastery {
                showMasteredToast(term: item.term)
            }
            withAnimation(.spring(response: 0.3)) {
                currentIndex += 1
                flipDegrees = 0
            }
            // Nạp snapshot cho thẻ mới hiện (để chấm tiếp).
            if currentIndex < items.count,
               let nextSnap = model.reviewSnapshots[items[currentIndex].cardID] {
                lastSnapshot = nextSnap
                refreshIntervals()
            } else {
                // Vừa chấm hết hàng đợi — nạp lại streak/tiến độ trước khi
                // SessionDoneView hiện, nếu không streak vẫn là số lúc mở màn
                // (chưa tính lượt ôn vừa xong).
                model.reloadOverview()
            }
        } catch {
            // AppModel đã set reviewError.
        }
    }

    /// Toast "Thuộc rồi!" (ADR-038) — cùng cơ chế `Motion.run`/transition với
    /// `showUndoToast`, tự ẩn sau 2s (huỷ tác vụ cũ nếu chấm liên tiếp mastered).
    private func showMasteredToast(term: String) {
        masteredToastTerm = term
        masteredToastTask?.cancel()
        Motion.run(reduceMotion: reduceMotion) {
            showMasteredToast = true
        }
        masteredToastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            Motion.run(reduceMotion: reduceMotion) {
                showMasteredToast = false
            }
        }
    }

    private func performUndo() {
        guard let logID = lastLogID, let snapshot = undoSnapshot else { return }
        // Thẻ vừa chấm là items[currentIndex - 1] (đã tăng index sau grade).
        let prevIndex = currentIndex - 1
        guard prevIndex >= 0, prevIndex < items.count else { return }
        let item = items[prevIndex]
        do {
            if mode == .cram {
                try model.undoCram(cardID: item.cardID, logID: logID)
            } else {
                try model.undoReview(cardID: item.cardID, logID: logID, snapshot: snapshot)
            }
            // Quay lại thẻ trước.
            withAnimation(.spring(response: 0.3)) {
                currentIndex = prevIndex
                flipDegrees = 0
                dragOffset = .zero
                didPassThreshold = false
            }
            if mode == .srs { tally.undoLast() }
            Motion.run(reduceMotion: reduceMotion) {
                showUndoToast = false
                showMasteredToast = false
            }
            masteredToastTask?.cancel()
            lastLogID = nil
            // lastSnapshot giữ nguyên (snapshot của thẻ vừa undo để có thể grade lại).
            refreshIntervals()
        } catch {
            // AppModel đã set reviewError.
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

/// FR-18: picker phạm vi ôn — tất cả / một / vài collection (multi-select).
/// nil = tất cả; Set 1 phần tử = một; Set nhiều = trộn (J5).
private struct ScopePickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var scope: Set<String>?
    let onApply: () -> Void

    @State private var isAll: Bool
    @State private var selected: Set<String>

    init(scope: Binding<Set<String>?>, onApply: @escaping () -> Void) {
        _scope = scope
        self.onApply = onApply
        let current = scope.wrappedValue
        _isAll = State(initialValue: current == nil)
        _selected = State(initialValue: current ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isAll = true
                        selected = []
                        Haptics.selection()
                    } label: {
                        HStack {
                            Label("Tất cả bộ", systemImage: "square.stack.3d.up")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isAll {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                Section("Hoặc trộn một / vài bộ") {
                    ForEach(model.collections) { collection in
                        Button {
                            if selected.contains(collection.id) {
                                selected.remove(collection.id)
                            } else {
                                selected.insert(collection.id)
                            }
                            isAll = false
                            Haptics.selection()
                        } label: {
                            HStack {
                                Text(collection.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if collection.dueNow > 0 {
                                    Text("\(collection.dueNow) đến hạn")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if selected.contains(collection.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Phạm vi ôn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Áp dụng") {
                        // Bỏ chọn hết ≡ tất cả (không sinh Set rỗng).
                        scope = (isAll || selected.isEmpty) ? nil : selected
                        dismiss()
                        onApply()
                    }
                }
            }
        }
    }
}

private extension View {
    /// Action Quên/Được chỉ khi mặt trước — mặt sau đã có bốn nút, tránh trùng rotor.
    @ViewBuilder
    func frontGradeActions(
        enabled: Bool,
        grade: @escaping (ReadoRating) -> Void
    ) -> some View {
        if enabled {
            self
                .accessibilityAction(named: Text("Quên")) { grade(.again) }
                .accessibilityAction(named: Text("Được")) { grade(.good) }
        } else {
            self
        }
    }
}

/// Cảm giác kéo — không thuộc quyết định chấm (cái đó là `SwipeCommit`).
private enum SwipeMotion {
    static let verticalDamp: CGFloat = 0.35
    static let flyDistance: CGFloat = 720
    static let maxTilt: Double = 12
    /// ~1° mỗi 15pt.
    static let pointsPerDegree: Double = 15
}

extension ReadoRating {
    var label: String {
        switch self {
        case .again: "Quên"
        case .hard: "Khó"
        case .good: "Được"
        case .easy: "Dễ"
        }
    }
    /// Confidence ramp đơn sắc — bỏ đèn giao thông (vision "Journey Over Summary"):
    /// chỉ Easy nổi bật (accent filled); Again đỏ nhạt (nghĩa "sai", không phải
    /// tone game); Hard/Good trung tính.
    var buttonBackground: Color {
        switch self {
        case .again: Theme.danger.opacity(0.12)
        case .hard: Theme.surfaceStrong
        case .good: Color.accentColor.opacity(0.18)
        case .easy: Color.accentColor
        }
    }
    var buttonForeground: Color {
        switch self {
        case .again: Theme.danger
        case .hard: .primary
        case .good: Color.accentColor
        // Accent dark mode là bản nhạt — chữ trắng trên đó gần như không đọc được.
        case .easy: Color(.systemBackground)
        }
    }
}
