import ReadoKit
import SwiftUI

// Tách từ ReviewQueueView.swift (repo-hygiene-r1 B3).

extension ReviewQueueView {
    // MARK: — Grade buttons (ADR-025: TRÁI=Again(1), PHẢI=Good(3); Hard/Easy nút)

    var gradeButtons: some View {
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

    func performGrade(_ rating: ReadoRating) {
        // Nút và action vẫn bấm được trong lúc thẻ bay — chặn chấm đè.
        guard !isCommitting else { return }
        Haptics.action()
        gradeNow(rating)
    }

    func gradeNow(_ rating: ReadoRating) {
        guard currentIndex < items.count else { return }
        // Thả offset ngay, ngoài animation đổi thẻ — thẻ sau không trượt từ vị trí kéo.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragOffset = .zero
            didPassThreshold = false
        }
        dragAnchor = nil
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
            actionError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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

    func performUndo() {
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
            actionError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
