import Foundation

/// apple-ai-r1 T3 (ADR-063) — một chỗ Apple Intelligence đề nghị sửa trong OCR.
/// `wrong`/`right` KHÔNG phải key/value tự do: `OCRFixApplier` chỉ chấp nhận khi
/// chúng thoả mọi luật bảo thủ bên dưới — mục tiêu là khôi phục đúng chữ sách in
/// (fen: "ưu tiên nguyên vẹn nhất câu"), không phải viết lại câu.
public struct OCRFix: Equatable, Sendable {
    public let wrong: String
    public let right: String

    public init(wrong: String, right: String) {
        self.wrong = wrong
        self.right = right
    }
}

/// Áp các đề nghị sửa OCR vào text — thi hành luật "chỉ khôi phục chữ in, không
/// đổi từ/văn phong/thứ tự". Thuần (không I/O, không async) nên test thẳng,
/// không cần model thật — xem `FoundationModelsOCRCorrector` cho phần gọi model.
public enum OCRFixApplier {
    public enum RejectReason: String, Equatable, Sendable {
        case empty, identical, containsNewline, tooManyWords, wordCountChanged,
             editTooLarge, notFound, tooMany
    }

    public struct Rejected: Equatable, Sendable {
        public let fix: OCRFix
        public let reason: RejectReason
    }

    public struct Outcome: Equatable, Sendable {
        public let text: String
        public let applied: [OCRFix]
        public let rejected: [Rejected]
    }

    /// Model đề nghị quá nhiều fix cho một trang ⇒ nghi ngờ cả loạt, loại hết
    /// thay vì cố lọc từng cái (an toàn hơn khi model "lạc đề").
    public static let maxFixes = 30
    /// Tổng số từ bị đụng (cộng dồn mọi fix được chấp nhận) vượt tỉ lệ này so
    /// với tổng số từ trang ⇒ loại hết, giữ nguyên text gốc.
    public static let maxTouchedWordRatio = 0.15

    public static func apply(_ fixes: [OCRFix], to text: String) -> Outcome {
        guard fixes.count <= maxFixes else {
            return Outcome(text: text, applied: [], rejected: fixes.map { Rejected(fix: $0, reason: .tooMany) })
        }

        struct Candidate {
            let fix: OCRFix
            let ranges: [Range<String.Index>]
        }

        var candidates: [Candidate] = []
        var rejected: [Rejected] = []

        for raw in fixes {
            let wrong = raw.wrong.trimmingCharacters(in: .whitespacesAndNewlines)
            let right = raw.right.trimmingCharacters(in: .whitespacesAndNewlines)
            let fix = OCRFix(wrong: wrong, right: right)

            if wrong.isEmpty || right.isEmpty {
                rejected.append(Rejected(fix: fix, reason: .empty))
                continue
            }
            if wrong == right {
                rejected.append(Rejected(fix: fix, reason: .identical))
                continue
            }
            if wrong.contains("\n") || right.contains("\n") {
                rejected.append(Rejected(fix: fix, reason: .containsNewline))
                continue
            }
            if wordCount(wrong) > 3 {
                rejected.append(Rejected(fix: fix, reason: .tooManyWords))
                continue
            }
            if abs(wordCount(right) - wordCount(wrong)) > 1 {
                rejected.append(Rejected(fix: fix, reason: .wordCountChanged))
                continue
            }
            let distance = editDistance(wrong, right)
            let threshold = max(1, min(3, wrong.count / 3))
            if distance > threshold {
                rejected.append(Rejected(fix: fix, reason: .editTooLarge))
                continue
            }
            let ranges = wholeWordRanges(of: wrong, in: text)
            guard !ranges.isEmpty else {
                rejected.append(Rejected(fix: fix, reason: .notFound))
                continue
            }
            candidates.append(Candidate(fix: fix, ranges: ranges))
        }

        let totalWords = max(1, wordCount(text))
        let touchedWords = candidates.reduce(0) { $0 + $1.ranges.count * wordCount($1.fix.wrong) }
        if Double(touchedWords) > maxTouchedWordRatio * Double(totalWords) {
            let allRejected =
                candidates.map { Rejected(fix: $0.fix, reason: .tooMany) }
                    + rejected.map { Rejected(fix: $0.fix, reason: .tooMany) }
            return Outcome(text: text, applied: [], rejected: allRejected)
        }

        struct Occurrence {
            let candidateIndex: Int
            let range: Range<String.Index>
        }
        var occurrences: [Occurrence] = []
        for (index, candidate) in candidates.enumerated() {
            for range in candidate.ranges {
                occurrences.append(Occurrence(candidateIndex: index, range: range))
            }
        }
        // Thay từ cuối text lên đầu — index của range chưa xử lý (nằm trước)
        // không bị lệch bởi thay thế đã làm (nằm sau).
        occurrences.sort { $0.range.lowerBound > $1.range.lowerBound }

        var result = text
        var appliedIndices: Set<Int> = []
        var frontier = text.endIndex
        for occurrence in occurrences {
            guard occurrence.range.upperBound <= frontier else { continue } // chồng lấn — bỏ qua, an toàn
            result.replaceSubrange(occurrence.range, with: candidates[occurrence.candidateIndex].fix.right)
            frontier = occurrence.range.lowerBound
            appliedIndices.insert(occurrence.candidateIndex)
        }

        let applied = appliedIndices.sorted().map { candidates[$0].fix }
        let skipped = candidates.enumerated()
            .filter { !appliedIndices.contains($0.offset) }
            .map { Rejected(fix: $0.element.fix, reason: .notFound) }

        return Outcome(text: result, applied: applied, rejected: rejected + skipped)
    }

    /// Public để test: khoảng cách Levenshtein theo Character.
    public static func editDistance(_ a: String, _ b: String) -> Int {
        EditDistance.levenshtein(Array(a), Array(b))
    }

    private static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: \.isWhitespace).count
    }

    /// Mọi chỗ khớp NGUYÊN TỪ của `needle` trong `text` — biên trái/phải không
    /// phải chữ/số/'/' (chỉ xét biên nào mà ký tự đầu/cuối `needle` là chữ/số;
    /// cho phép khớp cả cụm có dấu câu dính, ví dụ `wrong: "tbe"` khớp `"tbe,"`).
    private static func wholeWordRanges(of needle: String, in text: String) -> [Range<String.Index>] {
        guard !needle.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        let firstIsAlnum = needle.first.map { $0.isLetter || $0.isNumber } ?? false
        let lastIsAlnum = needle.last.map { $0.isLetter || $0.isNumber } ?? false
        while searchStart < text.endIndex,
              let found = text.range(of: needle, range: searchStart..<text.endIndex)
        {
            let beforeOK: Bool
            if found.lowerBound > text.startIndex {
                let before = text[text.index(before: found.lowerBound)]
                beforeOK = !(before.isLetter || before.isNumber || before == "'" || before == "\u{2019}")
            } else {
                beforeOK = true
            }
            let afterOK: Bool
            if found.upperBound < text.endIndex {
                let after = text[found.upperBound]
                afterOK = !(after.isLetter || after.isNumber || after == "'" || after == "\u{2019}")
            } else {
                afterOK = true
            }
            if (!firstIsAlnum || beforeOK), (!lastIsAlnum || afterOK) {
                ranges.append(found)
            }
            searchStart = found.upperBound
        }
        return ranges
    }
}
