import ReadoKit
import SwiftUI

/// FR-11/FR-12: hàng đợi hai nhánh + vuốt trái=Again(1)/phải=Good(3), Hard/Easy nút.
/// Lật card: `term` + `pos` → `meaning_vi` + IPA + câu gốc + tên collection.
struct ReviewQueueView: View {
    @Environment(AppModel.self) private var model
    @State private var state: ReviewState = .idle

    @State private var items: [ReviewItem] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false

    // Undo 1 bước (FR-12): lưu snapshot + logID vừa chấm.
    @State private var lastLogID: String?
    @State private var lastSnapshot: CardSnapshot?
    @State private var showUndoToast: Bool = false

    var body: some View {
        ZStack {
            if items.isEmpty && !model.isLoadingReview {
                emptyView
            } else if let error = model.reviewError {
                errorView(error)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Lỗi khi tải hàng đợi", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
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
                        Task { await performUndo() }
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

            Spacer(minLength: 0)

            // Bottom controls.
            if isFlipped {
                gradeButtons
            } else {
                Text("Nhấn để lật")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.35)) { isFlipped.toggle() } }
    }

    private func cardFace(item: ReviewItem, back: Bool, size: CGSize) -> some View {
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
        HStack(spacing: 16) {
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
            Task { await performGrade(rating) }
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

    private func performGrade(_ rating: ReadoRating) async {
        let item = items[currentIndex]
        guard let snapshot = lastSnapshot else { return }
        do {
            let (outcome, logID) = try await model.grade(
                cardID: item.cardID, snapshot: snapshot, rating: rating)
            lastLogID = logID
            lastSnapshot = snapshot
            showUndoToast = true
            // Chuyển sang thẻ tiếp.
            currentIndex += 1
            isFlipped = false
        } catch {
            model.reviewError = error.localizedDescription
        }
    }

    private func performUndo() async {
        guard let logID = lastLogID, let snapshot = lastSnapshot else { return }
        let item = items[currentIndex - 1]
        do {
            try await model.undoReview(cardID: item.cardID, logID: logID, snapshot: snapshot)
            showUndoToast = false
            lastLogID = nil
            lastSnapshot = nil
        } catch {
            model.reviewError = "Không hoàn tác được: \(error.localizedDescription)"
        }
    }

    private func loadQueue() async {
        do {
            let (items, initialSnapshots) = try await model.loadReviewQueue()
            self.items = items
            if let first = items.first, let snap = initialSnapshots[first.cardID] {
                lastSnapshot = snap
            }
        } catch {
            model.reviewError = error.localizedDescription
        }
    }

    private func dismiss() {
        if #available(iOS 17.0, *) {
            @Environment(\.dismiss) var dismissAction
            dismissAction()
        }
    }
}

// MARK: — ReviewItem

struct ReviewItem: Identifiable, Equatable {
    var id: String { cardID }
    let cardID: String
    let term: String
    let pos: String
    let meaningVI: String
    let ipa: String?
    let example: String
    let collectionName: String
}

extension ReadoRating {
    var label: String {
        switch self {
        case .again: "Mới"
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