import ReadoKit
import SwiftUI

/// FR-08 (home-eevas-r1 T4) — tìm từ xuyên mọi collection theo `term` hoặc `meaning_vi`,
/// không phân biệt hoa/thường/dấu tiếng Việt (`VocabRepository.searchVocabulary`, gập ở
/// tầng Swift — SQLite NOCASE chỉ gập ASCII). Mở từ 🔍 trên toolbar Home.
struct VocabSearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [VocabRepository.VocabularyListEntry] = []

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "Tìm từ",
                    systemImage: "magnifyingglass",
                    description: Text("Gõ từ tiếng Anh hoặc nghĩa tiếng Việt để tìm xuyên mọi bộ."))
                    .listRowSeparator(.hidden)
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(results) { entry in
                    NavigationLink(value: ShellRoute.hub(entry.collectionID)) {
                        row(entry)
                    }
                }
            }
        }
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Từ hoặc nghĩa")
        .navigationTitle("Tìm từ")
        .shellScrollChrome()
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            results = model.searchVocabulary(query)
        }
    }

    private func row(_ entry: VocabRepository.VocabularyListEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VocabSummary(
                term: entry.term,
                pos: entry.pos,
                cefr: entry.cefr ?? "",
                ipa: entry.ipa ?? "",
                meaning: entry.meaningVI,
                example: entry.example)
            Text(entry.collectionName)
                .font(Typo.meta)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.xs)
    }
}
