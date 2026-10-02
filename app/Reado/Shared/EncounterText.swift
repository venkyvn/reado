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
/// chạm vào mở popover (`EncounterSheet`). FR-05 (prompt-v6 T3) — cụm EN↔VI
/// chạm-sáng (`PhraseLocator.PhraseSpan`): gạch chân liền mảnh, chạm thì cụm
/// này và cụm VI tương ứng cùng tô nền accent. Không có từ/cụm nào thì là
/// `Text` thường (không đổi hành vi so với trước).
///
/// Bẫy: link trong `Text` bị `Button` bao ngoài nuốt chạm — chỗ dùng phải bọc
/// đoạn bằng `onTapGesture`, không dùng `Button`. Chạm link đi qua `openURL`.
/// Cụm và từ gặp lại chồng chữ: link từ gặp lại gán SAU nên đè — chạm đúng
/// chữ chồng mở popover từ cũ, không chạm-sáng cụm (ưu tiên có chủ ý).
struct EncounterText: View {
    let text: String
    let matcher: EncounterMatcher
    var phrases: [PhraseLocator.PhraseSpan] = []
    /// `phrase.phraseIndex` đang sáng — không phải chỉ số trong `phrases` (đã lọc).
    var activePhraseIndex: Int? = nil
    var accent: Color = .accentColor
    let onSelect: (EncounterSelection) -> Void
    var onPhraseTap: ((Int) -> Void)? = nil

    private static let matchScheme = "reado-term"
    private static let phraseScheme = "reado-phrase"

    var body: some View {
        let matches = matcher.matches(in: text)
        if matches.isEmpty && phrases.isEmpty {
            Text(text)
        } else {
            Text(attributed(matches))
                .environment(\.openURL, OpenURLAction { url in
                    guard let index = Int(url.lastPathComponent) else { return .systemAction }
                    switch url.scheme {
                    case Self.matchScheme:
                        guard matches.indices.contains(index) else { return .systemAction }
                        let match = matches[index]
                        onSelect(EncounterSelection(
                            surface: String(text[match.range]), entries: match.entries))
                        return .handled
                    case Self.phraseScheme:
                        guard phrases.indices.contains(index), let onPhraseTap
                        else { return .systemAction }
                        onPhraseTap(phrases[index].phraseIndex)
                        return .handled
                    default:
                        return .systemAction
                    }
                })
        }
    }

    private func attributed(_ matches: [EncounterMatch]) -> AttributedString {
        var result = AttributedString(text)
        // Cụm chạm-sáng gán TRƯỚC — chữ không chồng từ gặp lại giữ link này.
        for (phraseListIndex, span) in phrases.enumerated() {
            guard let range = Range(span.en, in: result) else { continue }
            result[range].link = URL(string: "\(Self.phraseScheme)://phrase/\(phraseListIndex)")
            result[range].foregroundColor = Color.primary
            result[range].underlineStyle = Text.LineStyle(pattern: .solid, color: Color.secondary)
            if span.phraseIndex == activePhraseIndex {
                result[range].backgroundColor = accent.opacity(0.18)
            }
        }
        // Từ gặp lại (FR-22) gán SAU — đè lên link cụm ở phần chữ trùng.
        for (index, match) in matches.enumerated() {
            guard let range = Range(match.range, in: result) else { continue }
            result[range].link = URL(string: "\(Self.matchScheme)://match/\(index)")
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
