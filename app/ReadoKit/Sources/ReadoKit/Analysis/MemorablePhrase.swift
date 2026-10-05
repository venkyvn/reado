import Foundation

/// Cụm EN–VI "đáng nhớ" của một trang — hiện ở banner "Đã lưu" (engagement-r1 T7, FR-02/ADR-068).
/// Chọn từ `segments[].phrases` đã có (prompt-v6) bằng heuristic thuần, KHÔNG đổi prompt:
/// bản dịch là thứ để học văn phong (vision #2) — cụm gắn với từ vừa lưu là chỗ bám tốt nhất.
public enum MemorablePhrase {

    /// Cụm ĐẦU TIÊN (theo thứ tự trang) có EN chứa một từ vừa lưu — so theo chữ, không phân biệt hoa
    /// thường, không lemmatize, cụm nhiều chữ vẫn khớp; không có thì cụm EN nhiều chữ nhất (hoà → đứng
    /// trước). Cụm có `en` hoặc `vi` rỗng bị bỏ. Không có cụm nào → nil.
    public static func pick(
        from segments: [PageAnalysis.Segment], savedTerms: [String]
    ) -> PageAnalysis.Phrase? {
        let candidates = segments.flatMap(\.phrases).filter {
            !words($0.en).isEmpty && !$0.vi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard var best = candidates.first else { return nil }
        let terms = savedTerms.map(words).filter { !$0.isEmpty }
        if let hit = candidates.first(where: { phrase in
            let haystack = " " + words(phrase.en) + " "
            return terms.contains { haystack.contains(" " + $0 + " ") }
        }) {
            return hit
        }
        var bestCount = wordCount(best.en)
        for phrase in candidates.dropFirst() where wordCount(phrase.en) > bestCount {
            best = phrase
            bestCount = wordCount(phrase.en)
        }
        return best
    }

    /// Chữ thường, ký tự không phải chữ/số thành khoảng trắng, gộp khoảng trắng — để so `" " + a + " "`.
    private static func words(_ text: String) -> String {
        let mapped = text.lowercased().unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : " "
        }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    private static func wordCount(_ text: String) -> Int {
        words(text).split(separator: " ").count
    }
}
