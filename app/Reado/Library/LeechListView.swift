import ReadoKit
import SwiftUI

/// FR-19 — "Từ hay quên" (home-eevas-r1 T3): màn tối thiểu cho các card bị `LeechService`
/// suspend (quên ≥ 6 lần, `Seeder.defaultLeechLapses`, CLAUDE.md §5). Hai hành động — "Đưa lại
/// hàng đợi" (unsuspend) hoặc "Xoá hẳn" (xoá cả vocab_item, CASCADE). KHÔNG sinh lại thẻ / sửa
/// tay ở đây — phạm vi khác (đụng hợp đồng prompt).
struct LeechListView: View {
    @Environment(AppModel.self) private var model
    @State private var pendingDelete: LeechCard?

    var body: some View {
        List {
            if model.leeches.isEmpty {
                ContentUnavailableView(
                    "Không còn từ hay quên", systemImage: "checkmark.circle")
            } else {
                Section {
                    ForEach(model.leeches) { card in
                        row(card)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { pendingDelete = card } label: {
                                    Label("Xoá", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { model.requeueLeech(card) } label: {
                                    Label("Đưa lại hàng đợi", systemImage: "arrow.uturn.backward")
                                }
                                .tint(Color.accentColor)
                            }
                            .contextMenu {
                                Button { model.requeueLeech(card) } label: {
                                    Label("Đưa lại hàng đợi", systemImage: "arrow.uturn.backward")
                                }
                                Button(role: .destructive) { pendingDelete = card } label: {
                                    Label("Xoá hẳn", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Những từ bạn quên từ 6 lần trở lên được tạm cất khỏi hàng ôn.")
                }
            }
        }
        .navigationTitle("Từ hay quên")
        .shellScrollChrome()
        .confirmationDialog(
            "Xoá hẳn từ này? Lịch ôn và lần gặp lại cũng mất.",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Xoá", role: .destructive) {
                if let card = pendingDelete {
                    model.deleteLeechWord(card)
                }
                pendingDelete = nil
            }
            Button("Huỷ", role: .cancel) { pendingDelete = nil }
        }
    }

    private func row(_ card: LeechCard) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VocabSummary(term: card.term, meaning: card.meaningVI, example: card.example)
            Text("Quên \(card.lapses) lần")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
        }
    }
}
