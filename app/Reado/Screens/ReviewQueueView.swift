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
        }
        .task { await loadQueue() }
    }

    // MARK: — Empty / Done

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Không có gì cần ôn", systemImage: "checkmark.circle")
        } description: {
            Text("Tất cả thẻ đã được ôn rồi. Bạn có thể chụp trang mới (FR-01).")
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Xong rồi!")
                .font(.title2.bold())
            Text("Bạn đã ôn hết \(items.count) thẻ hôm nay.")
                .foregroundStyle(.secondary)
            Button("Đóng") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .background(Capsule().fill(Color(.systemGray5)))
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
                .foregroundStyle(.white)
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
            try await model.loadReviewQueue()
            self.items = model.reviewItems
            if let first = items.first,
               let snap = model.reviewSnapshots[first.cardID] {
                lastSnapshot = snap
            }
        } catch {
            // reviewError đã set trong model.
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
    var buttonBackground: Color {
        switch self {
        case .again: .red
        case .hard: .orange
        case .good: .blue
        case .easy: .green
        }
    }
}
