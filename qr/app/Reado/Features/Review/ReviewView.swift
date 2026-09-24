import SwiftUI
import UIKit

struct ReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showScope = false

    var body: some View {
        let card = store.visibleQueue.first
        VStack(spacing: 14) {
            Button {
                showScope.toggle()
            } label: {
                HStack {
                    Text(store.scopeTitle).font(.headline)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Phạm vi ôn")

            if showScope {
                scopePicker
            }

            if store.scopeIds != nil {
                Text("\(store.queue.outsideDue) thẻ đến hạn ngoài phạm vi này")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let card {
                FlashCardView(
                    card: card,
                    flipped: store.flipped,
                    onFlip: {
                        withAnimation(ReadoTheme.motion(reduceMotion)) {
                            store.flipped.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )
                if store.flipped {
                    HStack(spacing: 8) {
                        gradeButton("Quên", color: ReadoTheme.again, rating: 1)
                        gradeButton("Khó", color: ReadoTheme.hard, rating: 2)
                        gradeButton("Được", color: ReadoTheme.good, rating: 3)
                        gradeButton("Dễ", color: ReadoTheme.easy, rating: 4)
                    }
                } else {
                    Text("Chạm thẻ để lật")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Undo") { try? store.undo() }
                    .disabled(store.lastUndoLogId == nil)
                    .frame(minHeight: 44)
            } else {
                emptyState
            }
            Spacer()
        }
        .padding(18)
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }

    private var scopePicker: some View {
        VStack(spacing: 0) {
            Button {
                try? store.persistReviewAll()
                showScope = false
            } label: {
                HStack {
                    Text("Tất cả kho").font(.headline)
                    Spacer()
                    Image(systemName: store.scopeIds == nil ? "circle.inset.filled" : "circle")
                        .foregroundStyle(Color.accentColor)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            ForEach(store.collections) { collection in
                Button {
                    do { try store.togglePriority(collection.id) }
                    catch { store.notify(error.localizedDescription) }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(collection.name).font(.headline)
                            Text("\(store.dueByCollection[collection.id] ?? 0) đến hạn")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: store.scopeIds?.contains(collection.id) == true ? "circle.inset.filled" : "circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
            Text("Chọn 1–3 kho ưu tiên. Tab Ôn dùng bộ này.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var emptyState: some View {
        GroupedCard {
            if store.reviewBranch == .new {
                Text("Hết hạn mức thẻ mới hôm nay. Backlog không nhồi vào queue.")
            } else if store.dueSessionDone && store.queue.outsideDue == 0 {
                Text("Đã hết thẻ đến hạn. Streak \(store.streakStats.current) — cắt ngày \(String(format: "%02d", store.settings.dayCutoffHour)):00, không nửa đêm hệ thống.")
            } else if store.queue.outsideDue > 0 {
                Text("Không còn trong phạm vi này.")
                Text("Còn \(store.queue.outsideDue) thẻ đến hạn ngoài phạm vi.")
                    .foregroundStyle(.secondary)
                Button("Ôn tất cả") { try? store.persistReviewAll() }
            } else {
                Text("Đã xong ôn hôm nay. Không kéo thẻ chưa tới hạn.")
            }
        }
    }

    private func gradeButton(_ title: String, color: Color, rating: Int) -> some View {
        Button(title) { try? store.grade(rating: rating) }
            .font(.headline)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(title)
    }
}

struct FlashCardView: View {
    var card: ReviewCardView
    var flipped: Bool
    var onFlip: () -> Void

    var body: some View {
        Button(action: onFlip) {
            VStack(spacing: 10) {
                if flipped {
                    Text(card.vocab.ipa ?? "").font(.subheadline).foregroundStyle(.secondary)
                    Text(card.vocab.meaningVi).font(.title.bold()).multilineTextAlignment(.center)
                    Text(card.vocab.example)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Eyebrow(text: card.collectionName)
                } else {
                    Text(card.vocab.term).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text(card.vocab.pos).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 260)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .buttonStyle(.plain)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .accessibilityLabel(flipped ? "Mặt sau thẻ" : "Mặt trước thẻ")
        .accessibilityValue(flipped ? "\(card.vocab.meaningVi). \(card.vocab.example)" : "\(card.vocab.term), \(card.vocab.pos)")
    }
}

#Preview {
    let store = try! AppStore(database: AppDatabase(inMemory: true))
    ReviewView().environment(store)
}
