import ReadoKit
import SwiftUI

/// Một từ/cụm người dùng vừa chạm trong đoạn văn — đủ để mở popover.
struct EncounterSelection: Identifiable {
    let id = UUID()
    /// Chữ đúng như trong đoạn (giữ hoa/thường gốc).
    let surface: String
    /// ≥ 1 dòng — một term nhiều nghĩa/collection thì liệt kê đủ.
    let entries: [EncounterLexiconEntry]
}

/// FR-22 — đoạn văn tiếng Anh với từ/cụm đã có trong kho được gạch chân chấm;
/// chạm vào mở popover (`EncounterSheet`). Không có từ nào khớp thì là `Text`
/// thường (không đổi hành vi so với trước).
///
/// Bẫy: link trong `Text` bị `Button` bao ngoài nuốt chạm — chỗ dùng phải bọc
/// đoạn bằng `onTapGesture`, không dùng `Button`. Chạm link đi qua `openURL`.
struct EncounterText: View {
    let text: String
    let matcher: EncounterMatcher
    let onSelect: (EncounterSelection) -> Void

    private static let scheme = "reado-term"

    var body: some View {
        let matches = matcher.matches(in: text)
        if matches.isEmpty {
            Text(text)
        } else {
            Text(attributed(matches))
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == Self.scheme,
                          let index = Int(url.lastPathComponent),
                          matches.indices.contains(index)
                    else { return .systemAction }
                    let match = matches[index]
                    onSelect(EncounterSelection(
                        surface: String(text[match.range]), entries: match.entries))
                    return .handled
                })
        }
    }

    private func attributed(_ matches: [EncounterMatch]) -> AttributedString {
        var result = AttributedString(text)
        for (index, match) in matches.enumerated() {
            guard let range = Range(match.range, in: result) else { continue }
            result[range].link = URL(string: "\(Self.scheme)://match/\(index)")
            result[range].underlineStyle = Text.LineStyle(pattern: .dot)
            result[range].foregroundColor = Color.accentColor
        }
        return result
    }
}

/// Popover (sheet nhỏ) của từ cũ: nghĩa, IPA, "đã gặp ở ‹collection›", nút
/// "Nhận ra ✓" (mỗi dòng vocab một nút; tối đa một lần / ngày học / từ).
struct EncounterSheet: View {
    let selection: EncounterSelection

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var recognized: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(selection.entries) { entry in
                        entryCard(entry)
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle(selection.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .appErrorAlert()
        .onAppear {
            recognized = Set(selection.entries.map(\.vocabItemID).filter {
                model.hasRecognizedToday($0)
            })
        }
    }

    private func entryCard(_ entry: EncounterLexiconEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(entry.term)
                    .font(.headline)
                Pill(text: entry.pos)
                Spacer()
                SpeakButton(term: entry.term)
            }
            if let ipa = entry.ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(entry.meaningVI)
                .font(.body)
            Label("Đã gặp ở \(entry.collectionName)", systemImage: "books.vertical")
                .font(.caption)
                .foregroundStyle(.secondary)
            recognizeButton(entry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .card()
    }

    @ViewBuilder
    private func recognizeButton(_ entry: EncounterLexiconEntry) -> some View {
        if recognized.contains(entry.vocabItemID) {
            Label("Đã nhận ra hôm nay", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ok)
        } else {
            Button {
                if model.recognizeWord(entry.vocabItemID) {
                    recognized.insert(entry.vocabItemID)
                    Haptics.success()
                }
            } label: {
                Label("Nhận ra ✓", systemImage: "eye")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Ghi lại là bạn nhận ra từ này khi đọc — không đổi lịch ôn")
        }
    }
}
