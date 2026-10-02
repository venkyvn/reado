import Foundation

/// prompt-v6 T3 (FR-05) — định vị `segment.phrases[].en`/`.vi` thành `Range<String.Index>`
/// trên `sourceEN`/`translationVI` gốc, để UI gạch chân/tô sáng đúng chữ hiển thị
/// (không phải bản đã gập). Hàm thuần, không UIKit/SwiftUI.
///
/// `AnalysisResponseNormalizer` đã đảm bảo mỗi cặp là substring sau khi gập qua
/// `VerifyEngine.normalize` (case/nháy cong/whitespace) — nhưng gập làm lệch vị
/// trí so với chuỗi gốc, nên không dùng `range(of:)` trần. Thay vào đó: dựng một
/// bảng (ký tự gập 1-1 ↔ index gốc) cho chuỗi gốc, gập needle theo CÙNG luật rồi
/// tìm khớp trên bảng đó (coi mọi dải whitespace là một khoảng trắng khi so), rồi
/// map ngược offset về `Range<String.Index>` trên chuỗi gốc.
public enum PhraseLocator {

    /// Một cặp cụm đã định vị thành công trên cả hai chuỗi.
    public struct PhraseSpan: Equatable, Sendable {
        /// Chỉ số trong `segment.phrases` — giữ để UI biết đang nói cụm nào.
        public let phraseIndex: Int
        public let en: Range<String.Index>
        public let vi: Range<String.Index>
    }

    /// Định vị toàn bộ `segment.phrases`. Cụm không tìm được (lỗi gập lệch hơn
    /// luật `normalize` xử lý được, hiếm với Latin/Việt) hoặc chồng chữ với cụm
    /// đã nhận trước thì bỏ im lặng, giữ nguyên thứ tự AI trả.
    public static func spans(for segment: PageAnalysis.Segment) -> [PhraseSpan] {
        guard !segment.phrases.isEmpty else { return [] }
        let enTable = FoldedTable(source: segment.sourceEN)
        let viTable = FoldedTable(source: segment.translationVI)
        var takenEN = Set<String.Index>()
        var takenVI = Set<String.Index>()
        var result: [PhraseSpan] = []
        for (index, phrase) in segment.phrases.enumerated() {
            guard let enRange = enTable.firstRange(ofNeedle: phrase.en, requireWordBoundary: true),
                  let viRange = viTable.firstRange(ofNeedle: phrase.vi, requireWordBoundary: false),
                  !overlaps(enRange, takenEN, in: segment.sourceEN),
                  !overlaps(viRange, takenVI, in: segment.translationVI)
            else { continue }
            mark(enRange, in: segment.sourceEN, into: &takenEN)
            mark(viRange, in: segment.translationVI, into: &takenVI)
            result.append(PhraseSpan(phraseIndex: index, en: enRange, vi: viRange))
        }
        return result
    }

    private static func overlaps(
        _ range: Range<String.Index>, _ taken: Set<String.Index>, in text: String
    ) -> Bool {
        var index = range.lowerBound
        while index < range.upperBound {
            if taken.contains(index) { return true }
            index = text.index(after: index)
        }
        return false
    }

    private static func mark(
        _ range: Range<String.Index>, in text: String, into taken: inout Set<String.Index>
    ) {
        var index = range.lowerBound
        while index < range.upperBound {
            taken.insert(index)
            index = text.index(after: index)
        }
    }

    /// Bảng ánh xạ (ký tự gập 1-1 ↔ index gốc) của một chuỗi, theo đúng luật gập
    /// `VerifyEngine.normalize`: NFKC, nháy/gạch cong → thẳng, lowercase+fold.
    /// Gộp whitespace KHÔNG làm ở bảng (để giữ ánh xạ 1-1 đơn giản) — xử lý lúc so
    /// khớp (`matchOffsets`) bằng cách coi dải whitespace liên tiếp là một khoảng
    /// trắng. `chars`/`indices` là `nil`/rỗng nếu luật gập làm một ký tự nở ra
    /// nhiều ký tự (ví dụ `ß` ở vài locale) — khi đó bỏ cả đoạn, không crash.
    private struct FoldedTable {
        let chars: [Character]
        let indices: [String.Index]
        let sourceEndIndex: String.Index
        let ok: Bool

        init(source: String) {
            var chars: [Character] = []
            var indices: [String.Index] = []
            var ok = true
            var index = source.startIndex
            while index < source.endIndex {
                let next = source.index(after: index)
                let folded = Self.fold(String(source[index..<next]))
                if folded.count > 1 { ok = false; break }
                if let character = folded.first {
                    chars.append(character)
                    indices.append(index)
                }
                index = next
            }
            self.chars = chars
            self.indices = indices
            self.sourceEndIndex = source.endIndex
            self.ok = ok
        }

        /// Gập MỘT ký tự theo đúng thứ tự luật của `VerifyEngine.normalize` (trừ
        /// bước gộp whitespace, xử lý riêng ở `matchOffsets`).
        private static func fold(_ one: String) -> String {
            var result = one.precomposedStringWithCompatibilityMapping
            result = result
                .replacingOccurrences(of: "\u{2018}", with: "'")
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: "\u{201C}", with: "\"")
                .replacingOccurrences(of: "\u{201D}", with: "\"")
                .replacingOccurrences(of: "\u{2013}", with: "-")
                .replacingOccurrences(of: "\u{2014}", with: "-")
            return result.folding(options: .caseInsensitive, locale: nil).lowercased()
        }

        /// Gập `needle` theo cùng luật ký tự rồi gộp whitespace thành một khoảng
        /// trắng + trim — chuẩn bị để so với bảng (chưa gộp whitespace).
        private static func foldNeedle(_ raw: String) -> String {
            let folded = raw.map { fold(String($0)) }.joined()
            return folded
                .split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
        }

        /// Tìm `rawNeedle` trong bảng, có biên từ (ký tự liền trước/sau không phải
        /// chữ/số) khi `requireWordBoundary` — dùng cho EN để `in` không khớp
        /// trong `within`; bản VI không ép biên từ vì dấu câu tiếng Việt không đều.
        func firstRange(
            ofNeedle rawNeedle: String, requireWordBoundary: Bool
        ) -> Range<String.Index>? {
            guard ok, !chars.isEmpty else { return nil }
            let needleChars = Array(Self.foldNeedle(rawNeedle))
            guard !needleChars.isEmpty else { return nil }
            var searchFrom = 0
            while let offsets = matchOffsets(needle: needleChars, from: searchFrom) {
                if !requireWordBoundary || hasWordBoundary(offsets) {
                    let start = indices[offsets.lowerBound]
                    let end = offsets.upperBound < indices.count
                        ? indices[offsets.upperBound]
                        : sourceEndIndex
                    return start..<end
                }
                // Biên từ không thoả (ví dụ `cue` khớp giữa `rescued`) — thử lần
                // khớp kế tiếp, không bỏ cuộc ngay (có thể có lần khớp đúng sau đó).
                searchFrom = offsets.lowerBound + 1
            }
            return nil
        }

        private func hasWordBoundary(_ offsets: Range<Int>) -> Bool {
            let beforeOK = offsets.lowerBound == 0
                || !Self.isWordCharacter(chars[offsets.lowerBound - 1])
            let afterOK = offsets.upperBound == chars.count
                || !Self.isWordCharacter(chars[offsets.upperBound])
            return beforeOK && afterOK
        }

        private static func isWordCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber
        }

        /// So khớp `needle` (đã gộp whitespace thành đúng 1 khoảng trắng) với
        /// `chars` (chưa gộp), bắt đầu tìm từ `from` — mỗi khoảng trắng trong
        /// needle khớp 1+ whitespace liên tiếp trong `chars`. Trả offset [start,
        /// end) trên `chars` của lần khớp đầu tiên kể từ `from`.
        private func matchOffsets(needle: [Character], from: Int) -> Range<Int>? {
            var start = from
            while start < chars.count {
                if let end = matches(needle, from: start) { return start..<end }
                start += 1
            }
            return nil
        }

        private func matches(_ needle: [Character], from start: Int) -> Int? {
            var hi = start
            var ni = 0
            while ni < needle.count {
                guard hi < chars.count else { return nil }
                if needle[ni] == " " {
                    guard chars[hi].isWhitespace else { return nil }
                    while hi < chars.count, chars[hi].isWhitespace { hi += 1 }
                    ni += 1
                    continue
                }
                guard chars[hi] == needle[ni] else { return nil }
                hi += 1
                ni += 1
            }
            return hi
        }
    }
}
