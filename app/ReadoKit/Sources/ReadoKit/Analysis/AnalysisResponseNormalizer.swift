import Foundation

/// Luật chuẩn hoá response (ADR-049: trước có bản song song ở `proxy/normalize.py`,
/// giờ chỉ còn ở đây). Một từ lệch không huỷ cả trang: `pos` lạ → `other`, CEFR lạ
/// bị bỏ, từ thiếu term/nghĩa/câu bị loại. Cả trang trống (không đoạn, không từ)
/// → `notEnglishText`.
public enum AnalysisResponseNormalizer {
    private static let validPOS: Set<String> = ["noun", "verb", "adj", "adv", "phrase", "other"]
    private static let validCEFR: Set<String> = ["A2", "B1", "B2", "C1"]
    /// Prompt-v6 T3 (FR-05) — cặp cụm chạm-sáng chỉ để hiển thị, giới hạn tránh prompt
    /// trả quá nhiều cặp vụn làm rối màn đọc.
    private static let maxPhrasesPerSegment = 6

    public static func normalize(_ data: Data) throws -> Data {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw AnalysisError.schemaViolation("JSON parse failed: \(error.localizedDescription)")
        }
        guard let root = object as? [String: Any] else {
            throw AnalysisError.schemaViolation("response không phải object")
        }

        var segments: [[String: Any]] = []
        for item in root["segments"] as? [Any] ?? [] {
            guard let row = item as? [String: Any] else { continue }
            let source = text(row["source_en"])
            let translation = text(row["translation_vi"])
            if source.isEmpty || translation.isEmpty { continue }
            var clean: [String: Any] = ["source_en": source, "translation_vi": translation]
            let phrases = cleanPhrases(row["phrases"], sourceEN: source, translationVI: translation)
            if !phrases.isEmpty { clean["phrases"] = phrases }
            segments.append(clean)
        }

        var vocabulary: [[String: String]] = []
        for item in root["vocabulary"] as? [Any] ?? [] {
            guard let row = item as? [String: Any] else { continue }
            let term = text(row["term"])
            let meaning = text(row["meaning_vi"])
            let example = text(row["example"])
            if term.isEmpty || meaning.isEmpty || example.isEmpty { continue }
            var pos = text(row["pos"]).lowercased()
            if !validPOS.contains(pos) { pos = "other" }
            var clean: [String: String] = [
                "term": term,
                "pos": pos,
                "meaning_vi": meaning,
                "example": example,
            ]
            let ipa = text(row["ipa"])
            if !ipa.isEmpty { clean["ipa"] = ipa }
            let cefr = text(row["cefr"]).uppercased()
            if validCEFR.contains(cefr) { clean["cefr"] = cefr }
            vocabulary.append(clean)
        }

        if segments.isEmpty, vocabulary.isEmpty {
            throw AnalysisError.notEnglishText
        }

        let summary = text(root["summary_vi"])
        let clean: [String: Any] = [
            "segments": segments,
            "vocabulary": vocabulary,
            "summary_vi": summary,
        ]
        return try JSONSerialization.data(withJSONObject: clean)
    }

    /// Cặp cụm sai bị bỏ im lặng — đồ hiển thị (FR-05), không phải vocabulary, nên
    /// luật "không tự loại cả trang" của FR-02 không áp dụng ở đây. `en` phải là
    /// substring của `sourceEN`, `vi` của `translationVI` — so khớp qua
    /// `VerifyEngine.normalize` (case/dấu câu cong/whitespace, như đối chiếu
    /// `example`) vì AI không chắc giữ đúng case/dấu nháy gốc. Giữ nguyên text AI
    /// trả (không ghi bản normalize) để hiển thị đúng chữ trên trang.
    private static func cleanPhrases(
        _ raw: Any?, sourceEN: String, translationVI: String
    ) -> [[String: String]] {
        guard let items = raw as? [Any] else { return [] }
        let normalizedSource = VerifyEngine.normalize(sourceEN)
        let normalizedTranslation = VerifyEngine.normalize(translationVI)
        var result: [[String: String]] = []
        for item in items {
            guard result.count < maxPhrasesPerSegment,
                  let row = item as? [String: Any]
            else { continue }
            let en = text(row["en"])
            let vi = text(row["vi"])
            guard !en.isEmpty, !vi.isEmpty,
                  normalizedSource.contains(VerifyEngine.normalize(en)),
                  normalizedTranslation.contains(VerifyEngine.normalize(vi))
            else { continue }
            result.append(["en": en, "vi": vi])
        }
        return result
    }

    private static func text(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return ""
        }
    }
}
