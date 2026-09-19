import Foundation

/// Engine xác minh `example` (FR-02, prompt-spec mục 6).
/// Đối chiếu `example` với text ghép từ `segments[].source_en`.
public enum VerifyEngine {

    /// Kết quả xác minh 1 item.
    public static func verify(
        term: String,
        example: String,
        pageText: String
    ) -> PageAnalysis.VerificationStatus {
        let normalizedPage = normalize(pageText)
        let normalizedExample = normalize(example)
        let normalizedTerm = normalize(term)

        let exampleInPage = normalizedPage.contains(normalizedExample)
        let termInExample = normalizedExample.contains(normalizedTerm)

        if exampleInPage, termInExample { return .verified }
        if exampleInPage { return .suspect }
        return .unverified
    }

    /// Xác minh cả danh sách vocab — gán nhãn lại theo pageText.
    public static func verifyAll(
        vocabulary: [PageAnalysis.VocabularyItemIn],
        segments: [PageAnalysis.Segment]
    ) -> [PageAnalysis.VocabularyItemIn] {
        let pageText = segments.map(\.sourceEN).joined(separator: " ")
        return vocabulary.map { item in
            let status = verify(
                term: item.term,
                example: item.example,
                pageText: pageText)
            return .init(
                term: item.term,
                pos: item.pos,
                ipa: item.ipa,
                meaningVI: item.meaningVI,
                cefr: item.cefr,
                example: item.example,
                verification: status)
        }
    }

    /// Chuẩn hoá theo prompt-spec mục 6.
    public static func normalize(_ string: String) -> String {
        var result = string
        // 1. NFKC (dao động hoá dấu câu cong).
        // Swift precomposedStringWithCompatibilityMapping ~= NFKC
        result = result.precomposedStringWithCompatibilityMapping
        // 2. Nháy cong / gạch ngang → thẳng.
        result = result
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
        // 3. Gộp whitespace — chỉ splitWhitespace + join.
        result = result
            .split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        // 4. Trim + lower.
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .caseInsensitive, locale: nil)
            .lowercased()
        return result
    }
}
