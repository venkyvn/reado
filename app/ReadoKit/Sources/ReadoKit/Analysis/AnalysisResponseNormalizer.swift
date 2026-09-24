import Foundation

/// Cùng luật với `proxy/normalize.py`. Một từ lệch không huỷ cả trang:
/// `pos` lạ → `other`, CEFR lạ bị bỏ, từ thiếu term/nghĩa/câu bị loại.
/// Cả trang trống (không đoạn, không từ) → `notEnglishText`.
public enum AnalysisResponseNormalizer {
    private static let validPOS: Set<String> = ["noun", "verb", "adj", "adv", "phrase", "other"]
    private static let validCEFR: Set<String> = ["A2", "B1", "B2", "C1"]

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

        var segments: [[String: String]] = []
        for item in root["segments"] as? [Any] ?? [] {
            guard let row = item as? [String: Any] else { continue }
            let source = text(row["source_en"])
            let translation = text(row["translation_vi"])
            if source.isEmpty || translation.isEmpty { continue }
            segments.append(["source_en": source, "translation_vi": translation])
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
