import ReadoKit
import SwiftUI

/// FR-11/FR-12: hàng đợi hai nhánh + vuốt trái=Again(1)/phải=Good(3), Hard/Easy nút.
/// Lật card: `term` + `pos` → `meaning_vi` + IPA + câu gốc + tên collection.
typealias ReviewItem = ReviewQueue.ReviewItem

struct ReviewQueueView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var items: [ReviewQueue.ReviewItem] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false

    // Undo 1 bước (FR-12): lưu snapshot + logID vừa chấm.
    @State private var lastLogID: String?
    @State private var lastSnapshot: CardSnapshot?
    @State private var undoSnapshot: CardSnapshot?
    @State private var showUndoToast: Bool = false
    @State private var isLoading = true

    // FR-18: phạm vi ôn (nil = tất cả) + popover picker.
    @State private var scope: Set<String>? = nil
    @State private var showScopePicker = false

    /// Mở sẵn phạm vi (J2 "Ôn bộ này") — nil = tất cả collection.
    init(initialScope: Set<String>? = nil) {
        _scope = State(initialValue: initialScope)
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Đang tải hàng đợi…")
            } else if let error = model.reviewError {
                errorView(error)
            } else if items.isEmpty {
                emptyView
            } else if currentIndex < items.count {
                cardView
            } else {
                doneView
            }
        }
        .navigationTitle("Ôn tập")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Đóng") { dismiss() }
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
                Task { await loadQueue() }
            }
        }
        .task { await loadQueue() }
    }

    // MARK: — Empty / Done

    @ViewBuilder
    private var emptyView: some View {
        if model.dueOutsideScope > 0, let scope = model.reviewScope, !scope.isEmpty {
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
            }
        } else {
            ContentUnavailableView {
                Label("Không có gì cần ôn", systemImage: "checkmark.circle")
            } description: {
                Text("Tất cả thẻ đã được ôn rồi. Bạn có thể chụp trang mới (FR-01).")
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.ok)
            Text("Xong rồi!")
                .font(.title2.bold())
            Text("Bạn đã ôn hết \(items.count) thẻ hôm nay.")
                .foregroundStyle(.secondary)
            debtBanner
            Button("Đóng") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // FR-18: nợ ngoài phạm vi phải nhìn thấy (research/vocabulary.md 4.2) — khi
    // còn card due ngoài scope, đừng giấu dưới một "Xong rồi" không điều kiện.
    @ViewBuilder
    private var debtBanner: some View {
        if model.dueOutsideScope > 0, let scope = model.reviewScope, !scope.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.due)
                Text("Còn \(model.dueOutsideScope) thẻ đến hạn ngoài phạm vi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Ôn tất cả") {
                    self.scope = nil
                    Task { await loadQueue() }
                }
                .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Theme.due.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 8))
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
        return VStack(spacing: 24) {
            debtBanner

            // Progress.
            HStack {
                Text("\(currentIndex + 1)/\(items.count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                // FR-12: undo nút nổi 1 bước.
                if showUndoToast {
                    Button("Hoàn tác") {
                        performUndo()
                    }
                    .buttonStyle(.bordered)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            // Card body.
            GeometryReader { geo in
                ZStack {
                    cardFace(item: item, back: false, size: geo.size)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0),
                                          axis: (x: 0, y: 1, z: 0))
                        .opacity(isFlipped ? 0 : 1)
                    cardFace(item: item, back: true, size: geo.size)
                        .rotation3DEffect(.degrees(isFlipped ? 0 : -180),
                                          axis: (x: 0, y: 1, z: 0))
                        .opacity(isFlipped ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
            .gesture(swipeGesture)

            Spacer(minLength: 0)

            // Bottom controls.
            if isFlipped {
                gradeButtons
            } else {
                Text("Chạm để lật · vuốt trái/phải để chấm nhanh")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.35)) { isFlipped.toggle() } }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                guard isFlipped else { return }
                let dx = value.translation.width
                if dx < -60 {
                    // Vuốt trái = Again(1) — ADR-025.
                    performGrade(.again)
                } else if dx > 60 {
                    // Vuốt phải = Good(3).
                    performGrade(.good)
                }
            }
    }

    private func cardFace(item: ReviewQueue.ReviewItem, back: Bool, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            if !back {
                // FR-12: mặt trước = term + pos.
                VStack(spacing: 12) {
                    Text(item.term)
                        .font(.system(size: 28, weight: .bold))
                    Text(item.pos)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.surface))
                }
            } else {
                // FR-12: mặt sau = meaning_vi, IPA, câu gốc, tên collection.
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.meaningVI)
                        .font(.headline)
                    if let ipa = item.ipa {
                        Text(ipa).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(item.example)
                        .font(.body)
                        .italic()
                    Divider()
                    Text(item.collectionName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: — Grade buttons (ADR-025: TRÁI=Again(1), PHẢI=Good(3); Hard/Easy nút)

    private var gradeButtons: some View {
        HStack(spacing: 12) {
            gradeButton(.again)
            gradeButton(.hard)
            gradeButton(.good)
            gradeButton(.easy)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func gradeButton(_ rating: ReadoRating) -> some View {
        Button {
            performGrade(rating)
        } label: {
            Text(rating.label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(rating.buttonBackground)
                .foregroundStyle(rating.buttonForeground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func performGrade(_ rating: ReadoRating) {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        guard let snapshot = lastSnapshot else { return }
        let gradedSnapshot = snapshot
        do {
            let logID = try model.grade(
                cardID: item.cardID, snapshot: gradedSnapshot, rating: rating)
            // Lưu snapshot/log của thẻ vừa chấm để undo (FR-12) — tách khỏi lastSnapshot.
            lastLogID = logID
            undoSnapshot = gradedSnapshot
            showUndoToast = true
            withAnimation(.spring(response: 0.3)) {
                currentIndex += 1
                isFlipped = false
            }
            // Nạp snapshot cho thẻ mới hiện (để chấm tiếp).
            if currentIndex < items.count,
               let nextSnap = model.reviewSnapshots[items[currentIndex].cardID] {
                lastSnapshot = nextSnap
            }
        } catch {
            // AppModel đã set reviewError.
        }
    }

    private func performUndo() {
        guard let logID = lastLogID, let snapshot = undoSnapshot else { return }
        // Thẻ vừa chấm là items[currentIndex - 1] (đã tăng index sau grade).
        let prevIndex = currentIndex - 1
        guard prevIndex >= 0, prevIndex < items.count else { return }
        let item = items[prevIndex]
        do {
            try model.undoReview(cardID: item.cardID, logID: logID, snapshot: snapshot)
            // Quay lại thẻ trước.
            withAnimation(.spring(response: 0.3)) {
                currentIndex = prevIndex
                isFlipped = false
            }
            showUndoToast = false
            lastLogID = nil
            // lastSnapshot giữ nguyên (snapshot của thẻ vừa undo để có thể grade lại).
        } catch {
            // AppModel đã set reviewError.
        }
    }

    private func loadQueue() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await model.loadReviewQueue(scope: scope)
            self.items = model.reviewItems
            // Đổi phạm vi giữa phiên → reset con trỏ thẻ đang ôn.
            self.currentIndex = 0
            self.isFlipped = false
            self.showUndoToast = false
            self.lastLogID = nil
            if let first = items.first,
               let snap = model.reviewSnapshots[first.cardID] {
                lastSnapshot = snap
            } else {
                lastSnapshot = nil
            }
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
                    } label: {
                        HStack {
                            Label("Tất cả collection", systemImage: "square.stack.3d.up")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isAll {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                Section("Hoặc trộn một / vài collection") {
                    ForEach(model.collections) { collection in
                        Button {
                            if selected.contains(collection.id) {
                                selected.remove(collection.id)
                            } else {
                                selected.insert(collection.id)
                            }
                            isAll = false
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
        case .good: Theme.accent.opacity(0.18)
        case .easy: Theme.accent
        }
    }
    var buttonForeground: Color {
        switch self {
        case .again: Theme.danger
        case .hard: .primary
        case .good: Theme.accent
        case .easy: .white
        }
    }
}
