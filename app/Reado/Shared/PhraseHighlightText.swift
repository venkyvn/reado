import ReadoKit
import SwiftUI

/// FR-05 (prompt-v6 T3) — bản dịch VI của một đoạn, tô nền `accent.opacity(0.18)`
/// trên cụm VI tương ứng cụm EN đang chạm-sáng (`EncounterText`). Không tappable
/// — chạm nằm ở phía EN (`EncounterText.onPhraseTap`), bên này chỉ phản chiếu.
struct PhraseHighlightText: View {
    let text: String
    let phrases: [PhraseLocator.PhraseSpan]
    /// Cùng `phrase.phraseIndex` với `EncounterText.activePhraseIndex`.
    let activePhraseIndex: Int?
    let accent: Color

    var body: some View {
        if let activePhraseIndex, let span = phrases.first(where: { $0.phraseIndex == activePhraseIndex }) {
            Text(highlighted(span))
        } else {
            Text(text)
        }
    }

    private func highlighted(_ span: PhraseLocator.PhraseSpan) -> AttributedString {
        var result = AttributedString(text)
        guard let range = Range(span.vi, in: result) else { return result }
        result[range].backgroundColor = accent.opacity(0.18)
        result[range].foregroundColor = Color.primary
        return result
    }
}
