import Foundation
import PDFKit

/// FR-23/ADR-058 (pdf-reader-r1 T2) — lớp chữ trước, OCR sau: đọc thẳng lớp chữ
/// của một trang PDF (nhanh, chính xác), chỉ rơi về OCR khi lớp chữ không dùng
/// được (trang chỉ là ảnh — PDF scan — hoặc lớp chữ rác do phần mềm scan tự OCR
/// hộ, kiểu `Tlie qnick brovvn`/`(cid:72)`). PDFKit là framework hệ thống, cross-
/// platform (macOS + iOS) — không cần `#if canImport` như UIKit/Vision, dùng
/// được thẳng trong lane `kit` trên macOS.
public enum PDFPageText {

    /// Vì sao một trang rơi về OCR — chỉ để debug/log, không rẽ nhánh theo giá
    /// trị cụ thể ở tầng app (mọi `.needsOCR(_)` xử lý giống nhau: vẽ ảnh + OCR).
    public enum Reason: Equatable, Sendable {
        /// Trang không có lớp chữ nào (PDF scan thật, không OCR-lót).
        case empty
        /// Có chữ nhưng quá ngắn để tin là nội dung thật (ảnh có vài ký tự rác).
        case tooShort
        /// Ký tự lỗi bảng mã (`(cid:`) hoặc ký tự thay thế (U+FFFD).
        case corruptCharacters
        /// Tỷ lệ chữ cái/khoảng trắng/dấu câu quá thấp — nhiều khả năng là rác.
        case lowLetterRatio
        /// Tỷ lệ token trông như từ tiếng Anh quá thấp.
        case lowWordRatio
    }

    public enum Result: Equatable, Sendable {
        case text(String)
        case needsOCR(Reason)
    }

    // Ngưỡng khởi đầu (T5 chỉnh lại theo PDF thật — xem docs/plans/pdf-reader-r1.md).
    public static let minimumUsableLength = 40
    public static let minimumLetterRatio = 0.85
    public static let minimumEnglishWordRatio = 0.70

    /// Đọc một trang PDF: lấy hàng kèm toạ độ (không dùng `page.string` trần —
    /// nó không có ranh giới đoạn và thứ tự có thể lộn ở trang nhiều cột), tự
    /// dựng lại `\n`/`\n\n` bằng hình học, rồi chấm chất lượng.
    public static func extract(page: PDFPage) -> Result {
        let bounds = page.bounds(for: .mediaBox)
        guard let pageSelection = page.selection(for: bounds) else { return .needsOCR(.empty) }
        let lines: [Line] = pageSelection.selectionsByLine().compactMap { lineSelection in
            guard let text = lineSelection.string, !text.isEmpty else { return nil }
            let rect = lineSelection.bounds(for: page)
            return Line(text: text, minX: rect.minX, maxX: rect.maxX, minY: rect.minY, maxY: rect.maxY)
        }
        guard !lines.isEmpty else { return .needsOCR(.empty) }

        let assembled = assembleText(lines: lines)
        if let reason = quality(of: assembled) { return .needsOCR(reason) }
        return .text(assembled)
    }

    // MARK: — Dựng text (hàm thuần — test bằng `Line` dựng tay, không cần PDFKit)

    /// Toạ độ PDF: gốc (0,0) ở GÓC DƯỚI-TRÁI trang, y tăng lên trên — ngược
    /// `yTop` của `PageOCR` (Vision, gốc trên-trái, y chuẩn hoá 0–1). `public`
    /// để test dựng `Line` tay, không cần tạo `PDFPage` thật cho mọi case.
    public struct Line: Equatable, Sendable {
        public let text: String
        public let minX: CGFloat
        public let maxX: CGFloat
        public let minY: CGFloat
        public let maxY: CGFloat

        public init(text: String, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
            self.text = text
            self.minX = minX
            self.maxX = maxX
            self.minY = minY
            self.maxY = maxY
        }
    }

    /// Ghép các hàng thành đoạn: phát hiện 2 cột (đọc hết cột trái rồi mới sang
    /// cột phải), rồi trong mỗi cột quyết định `\n` (cùng đoạn) hay `\n\n` (đoạn
    /// mới) theo khoảng cách dọc và thụt đầu dòng — cùng ý tưởng hình học với
    /// `PageOCR.linesWithBreaks` (ADR-037), viết riêng vì toạ độ PDF khác hệ với
    /// Vision (không normalize, gốc dưới-trái).
    public static func assembleText(lines: [Line]) -> String {
        let columns = splitColumns(lines)
        let paragraphs = columns.flatMap { paragraphs(in: $0) }
        return paragraphs.joined(separator: "\n\n")
    }

    /// Hai cột khi mọi hàng nằm TRỌN VẸN ở nửa trái hoặc nửa phải của khoảng X
    /// tổng, và khe trống giữa mép phải cột trái / mép trái cột phải đủ rộng
    /// (> 8% độ rộng tổng — tránh hai hàng cùng đoạn chỉ lệch chút do canh giữa).
    /// Không khớp hình dạng đó → coi là 1 cột, giữ thứ tự gốc (trên → dưới).
    private static func splitColumns(_ lines: [Line]) -> [[Line]] {
        guard lines.count > 1 else { return [lines] }
        let globalMinX = lines.map(\.minX).min() ?? 0
        let globalMaxX = lines.map(\.maxX).max() ?? 0
        let totalWidth = globalMaxX - globalMinX
        guard totalWidth > 0 else { return [sortedTopToBottom(lines)] }
        let midX = globalMinX + totalWidth / 2

        let left = lines.filter { $0.maxX <= midX }
        let right = lines.filter { $0.minX >= midX }
        guard left.count + right.count == lines.count, !left.isEmpty, !right.isEmpty else {
            return [sortedTopToBottom(lines)]
        }
        let leftEdge = left.map(\.maxX).max() ?? midX
        let rightEdge = right.map(\.minX).min() ?? midX
        guard rightEdge - leftEdge > totalWidth * 0.08 else {
            return [sortedTopToBottom(lines)]
        }
        return [sortedTopToBottom(left), sortedTopToBottom(right)]
    }

    /// PDF y tăng lên trên → "trên trang" là `maxY` lớn hơn.
    private static func sortedTopToBottom(_ lines: [Line]) -> [Line] {
        lines.sorted { $0.maxY > $1.maxY }
    }

    /// Một cột (đã sắp trên → dưới) → mảng đoạn văn, mỗi đoạn là các hàng nối
    /// bằng space rồi ghép gạch nối cuối hàng, chuẩn hoá ligature/khoảng trắng.
    private static func paragraphs(in column: [Line]) -> [String] {
        guard !column.isEmpty else { return [] }
        let gaps: [CGFloat] = (1..<column.count).map { column[$0 - 1].minY - column[$0].maxY }
        let medianGap = median(gaps.filter { $0 > 0 }) ?? 0
        let heights = column.map { $0.maxY - $0.minY }
        let lineHeight = median(heights) ?? 1
        let leftEdge = column.map(\.minX).min() ?? 0

        var result: [[String]] = [[column[0].text]]
        for index in 1..<column.count {
            let gap = column[index - 1].minY - column[index].maxY
            let indented = column[index].minX - leftEdge > 0.3 * lineHeight
            let bigGap = medianGap > 0 ? gap > 1.5 * medianGap : gap > 1.5 * lineHeight
            if bigGap || indented {
                result.append([column[index].text])
            } else {
                result[result.count - 1].append(column[index].text)
            }
        }
        return result.map { normalize(joinHyphenated($0)) }
    }

    /// Nối các hàng của một đoạn bằng space, GHÉP LẠI từ bị gạch ngang cuối
    /// hàng (ví dụ "remark-" + "able" → "remarkable") — ngoại lệ duy nhất cho
    /// luật giữ nguyên chữ, vì đây là lỗi dàn trang chứ không phải nội dung.
    private static func joinHyphenated(_ rows: [String]) -> String {
        var result = ""
        for row in rows {
            let trimmed = row.trimmingCharacters(in: .whitespaces)
            if result.hasSuffix("-"),
               let lastChar = trimmed.first, lastChar.isLowercase || lastChar.isUppercase
            {
                result.removeLast()
                result += trimmed
            } else if result.isEmpty {
                result = trimmed
            } else {
                result += " " + trimmed
            }
        }
        return result
    }

    /// Ligature → chữ rời (schema JSON/`example` trích nguyên văn không nên
    /// mang ligature mà OCR/người đọc không gõ ra được) + khoảng trắng lạ → space.
    private static func normalize(_ text: String) -> String {
        var result = text
        let ligatures: [Character: String] = [
            "\u{FB00}": "ff", "\u{FB01}": "fi", "\u{FB02}": "fl",
            "\u{FB03}": "ffi", "\u{FB04}": "ffl",
        ]
        for (ligature, expansion) in ligatures {
            result = result.replacingOccurrences(of: String(ligature), with: expansion)
        }
        result = result.replacingOccurrences(of: "\u{00A0}", with: " ")
        return result
    }

    private static func median(_ values: [CGFloat]) -> CGFloat? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    // MARK: — Chấm chất lượng (hàm thuần nhận String)

    /// `nil` = lớp chữ dùng được, đi thẳng prompt PDF. Khác `nil` = rơi về OCR.
    public static func quality(of text: String) -> Reason? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonWhitespaceCount = trimmed.filter { !$0.isWhitespace }.count
        guard nonWhitespaceCount >= minimumUsableLength else { return .tooShort }
        guard !text.contains("(cid:"), !text.contains("\u{FFFD}") else { return .corruptCharacters }

        let allowedPunctuation = Set(".,;:'\"!?()-–—…“”‘’*%$&@/")
        let letterLikeCount = text.filter {
            $0.isLetter || $0.isWhitespace || $0.isNumber || allowedPunctuation.contains($0)
        }.count
        let letterRatio = Double(letterLikeCount) / Double(text.count)
        guard letterRatio >= minimumLetterRatio else { return .lowLetterRatio }

        let tokens = text.split { !($0.isLetter) }
        guard !tokens.isEmpty else { return .lowWordRatio }
        let vowels = Set("aeiouyAEIOUY")
        let wordLikeCount = tokens.filter { token in
            token.count >= 1 && token.count <= 15 && token.contains { vowels.contains($0) }
        }.count
        let wordRatio = Double(wordLikeCount) / Double(tokens.count)
        guard wordRatio >= minimumEnglishWordRatio else { return .lowWordRatio }

        return nil
    }
}
