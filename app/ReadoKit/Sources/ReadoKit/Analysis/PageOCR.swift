import CoreGraphics
import Foundation
import ImageIO
import Vision

/// OCR trang trên máy (Vision). Observation không theo thứ tự sách — ghép dòng
/// theo bounding box; hai cột khi có khe X rõ (trái rồi phải).
public protocol PageTextRecognizer: Sendable {
    func recognize(imageData: Data) async throws -> String

    /// Bản đầy đủ cho log chẩn đoán (ADR-037): text + observation thô + từng
    /// hàng kèm lý do ngắt đoạn. Có default impl bọc `recognize` (không có
    /// observation/lines) nên implementer cũ (test fake) không phải sửa gì.
    func recognizeDetailed(imageData: Data) async throws -> PageOCR.OCRResult
}

extension PageTextRecognizer {
    public func recognizeDetailed(imageData: Data) async throws -> PageOCR.OCRResult {
        let text = try await recognize(imageData: imageData)
        return PageOCR.OCRResult(text: text, observations: [], lines: [])
    }
}

public enum PageOCR {
    public static let live: PageTextRecognizer = PageOCRLive()

    /// Box Vision: origin dưới-trái, 0...1.
    public struct Observation: Equatable, Sendable {
        public let text: String
        public let boundingBox: CGRect
        /// `topCandidates(1).confidence` — 1.0 cho item dựng tay trong test (không qua Vision).
        public let confidence: Float

        public init(text: String, boundingBox: CGRect, confidence: Float = 1.0) {
            self.text = text
            self.boundingBox = boundingBox
            self.confidence = confidence
        }
    }

    /// Một hàng đã gộp (nhiều `Observation` cùng hàng in) — dùng cho log chẩn
    /// đoán khi chỉnh ngưỡng ngắt đoạn (`docs/decisions-log.md` ADR-037).
    public struct Line: Equatable, Sendable {
        public let text: String
        public let minX: CGFloat
        public let maxX: CGFloat
        public let yTop: CGFloat
        public let height: CGFloat
        /// true khi có `\n\n` được chèn NGAY TRƯỚC hàng này (đầu đoạn mới hoặc đầu cột mới).
        public let breakBefore: Bool
        /// "gap" | "indent" | "shortEnding" | "column" | nil (hàng đầu tiên của trang).
        public let breakReason: String?
    }

    public struct OCRResult: Equatable, Sendable {
        public let text: String
        public let observations: [Observation]
        public let lines: [Line]
        /// Tổng số candidate Vision trả về TRƯỚC lọc confidence/rỗng (ocr-line-drop:
        /// đo xem hàng mất là do Vision không thấy, hay bị lọc sau đó). 0 khi
        /// dựng bằng `detailedReadingOrder` trong test (không qua Vision thật).
        public let rawObservationCount: Int
        /// Observation bị loại vì `confidence < minConfidence` — rỗng khi dựng
        /// bằng `detailedReadingOrder` (lọc confidence chỉ xảy ra ở đường Vision thật).
        public let droppedLowConfidence: [Observation]
        /// "documents" (`RecognizeDocumentsRequest`, iOS 26+, ADR-042) | "legacy"
        /// (`VNRecognizeTextRequest` + ngắt đoạn hình học ADR-037).
        public let engine: String

        public init(
            text: String, observations: [Observation], lines: [Line],
            rawObservationCount: Int = 0, droppedLowConfidence: [Observation] = [],
            engine: String = "legacy"
        ) {
            self.text = text
            self.observations = observations
            self.lines = lines
            self.rawObservationCount = rawObservationCount
            self.droppedLowConfidence = droppedLowConfidence
            self.engine = engine
        }
    }

    public static func recognize(imageData: Data) async throws -> String {
        try await recognizeDetailed(imageData: imageData).text
    }

    public static func recognizeDetailed(imageData: Data) async throws -> OCRResult {
        // ADR-042: iOS 26+ dùng `RecognizeDocumentsRequest` (đoạn có sẵn từ Vision,
        // không rơi/gộp hàng như legacy). Lỗi hoặc rỗng → rơi về legacy chứ không
        // làm hỏng luồng phân tích.
        if #available(iOS 26.0, *),
           let result = try? await recognizeDocuments(imageData: imageData),
           !result.text.isEmpty {
            return result
        }
        return try await Task.detached(priority: .userInitiated) {
            try recognizeDetailedSync(imageData: imageData)
        }.value
    }

    @available(iOS 26.0, *)
    private static func recognizeDocuments(imageData: Data) async throws -> OCRResult {
        guard let image = cgImage(from: imageData) else {
            return OCRResult(text: "", observations: [], lines: [], engine: "documents")
        }
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.useLanguageCorrection = true
        let observations = try await request.perform(on: image)
        guard let document = observations.first?.document else {
            return OCRResult(text: "", observations: [], lines: [], engine: "documents")
        }
        let paragraphs: [[Observation]] = document.paragraphs.map { paragraph in
            paragraph.lines.map { line in
                Observation(text: line.transcript, boundingBox: line.boundingBox.cgRect)
            }
        }
        return joinParagraphs(paragraphs, rawObservationCount: paragraphs.count)
    }

    /// Testable: không gọi Vision. Đoạn đã có sẵn từ engine documents nên bỏ qua
    /// `splitColumns`/`linesWithBreaks` hình học: trong đoạn nối hàng bằng `\n`,
    /// giữa các đoạn `\n\n` (hợp đồng với prompt v5 không đổi). Hàng/đoạn rỗng bị bỏ.
    public static func joinParagraphs(
        _ paragraphs: [[Observation]], rawObservationCount: Int = 0
    ) -> OCRResult {
        var allLines: [Line] = []
        var allObservations: [Observation] = []
        var paragraphTexts: [String] = []
        for paragraph in paragraphs {
            let rows = paragraph.compactMap { obs -> Observation? in
                let text = obs.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return Observation(text: text, boundingBox: obs.boundingBox, confidence: obs.confidence)
            }
            guard !rows.isEmpty else { continue }
            for (index, row) in rows.enumerated() {
                allLines.append(Line(
                    text: row.text, minX: row.boundingBox.minX, maxX: row.boundingBox.maxX,
                    yTop: 1 - row.boundingBox.maxY, height: row.boundingBox.height,
                    breakBefore: index == 0 && !paragraphTexts.isEmpty,
                    breakReason: index == 0 && !paragraphTexts.isEmpty ? "document" : nil))
            }
            allObservations.append(contentsOf: rows)
            paragraphTexts.append(rows.map(\.text).joined(separator: "\n"))
        }
        return OCRResult(
            text: paragraphTexts.joined(separator: "\n\n"),
            observations: allObservations, lines: allLines,
            rawObservationCount: rawObservationCount, engine: "documents")
    }

    /// Testable: không gọi Vision.
    public static func readingOrder(_ items: [Observation]) -> String {
        detailedReadingOrder(items).text
    }

    /// Testable: không gọi Vision. Tách observation confidence thấp ra khỏi phần
    /// dùng để ghép hàng — ocr-line-drop: hàng mất trong `page_ocr.txt` có thể là
    /// do bước này lọc bỏ, không phải do Vision không thấy (`rawObservationCount`
    /// ở `OCRResult` phân biệt hai khả năng đó).
    public static func partitionByConfidence(_ items: [Observation]) -> (kept: [Observation], dropped: [Observation]) {
        var kept: [Observation] = []
        var dropped: [Observation] = []
        for item in items {
            if item.confidence >= minConfidence {
                kept.append(item)
            } else {
                dropped.append(item)
            }
        }
        return (kept, dropped)
    }

    /// Testable: không gọi Vision. Trả cả text lẫn từng hàng kèm lý do ngắt đoạn.
    public static func detailedReadingOrder(_ items: [Observation]) -> OCRResult {
        let usable = items.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !usable.isEmpty else { return OCRResult(text: "", observations: items, lines: []) }

        let columns = splitColumns(usable)
        var allLines: [Line] = []
        var textParts: [String] = []
        for (columnIndex, column) in columns.enumerated() {
            var lines = linesWithBreaks(in: column)
            guard !lines.isEmpty else { continue }
            if columnIndex > 0 {
                // Cột mới luôn ngăn cách bằng \n\n dù hàng đầu cột không tự thấy
                // "đoạn mới" bằng thống kê nội bộ cột đó.
                lines[0] = Line(
                    text: lines[0].text, minX: lines[0].minX, maxX: lines[0].maxX,
                    yTop: lines[0].yTop, height: lines[0].height,
                    breakBefore: true, breakReason: "column")
            }
            allLines.append(contentsOf: lines)
            textParts.append(joinedText(lines))
        }
        let text = textParts.filter { !$0.isEmpty }.joined(separator: "\n\n")
        return OCRResult(text: text, observations: items, lines: allLines)
    }

    private static func joinedText(_ lines: [Line]) -> String {
        var result = ""
        for (index, line) in lines.enumerated() {
            if index == 0 {
                result = line.text
            } else {
                result += (line.breakBefore ? "\n\n" : "\n") + line.text
            }
        }
        return result
    }

    private static let columnGap: CGFloat = 0.14
    private static let minConfidence: Float = 0.25

    // Ngưỡng ngắt đoạn trong một cột (tinh chỉnh theo log chẩn đoán thật —
    // ADR-037, `scripts/diag_summary.py`). Cột dưới `minLinesForParagraphBreaks`
    // hàng thì không đủ dữ liệu để tính median/percentile đáng tin, giữ `\n` cũ.
    private static let minLinesForParagraphBreaks = 3
    private static let gapBreakFactor: CGFloat = 1.5
    private static let indentFactorOfHeight: CGFloat = 0.8
    private static let indentReturnFactorOfHeight: CGFloat = 0.3
    private static let shortEndingFactorOfWidth: CGFloat = 0.15
    private static let sentenceEndingCharacters = Set(".?!:\"”’)")

    private static func recognizeDetailedSync(imageData: Data) throws -> OCRResult {
        guard let image = cgImage(from: imageData) else {
            return OCRResult(text: "", observations: [], lines: [])
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.015
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        let candidates: [Observation] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Observation(text: text, boundingBox: obs.boundingBox, confidence: candidate.confidence)
        }
        let (items, dropped) = partitionByConfidence(candidates)
        let result = detailedReadingOrder(items)
        return OCRResult(
            text: result.text, observations: result.observations, lines: result.lines,
            rawObservationCount: observations.count, droppedLowConfidence: dropped)
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func splitColumns(_ items: [Observation]) -> [[Observation]] {
        guard items.count >= 4 else { return [items] }
        let xs = items.map(\.boundingBox.midX).sorted()
        var bestGap: CGFloat = 0
        var split: CGFloat = 0.5
        for index in 1..<xs.count {
            let gap = xs[index] - xs[index - 1]
            if gap > bestGap {
                bestGap = gap
                split = (xs[index] + xs[index - 1]) / 2
            }
        }
        guard bestGap >= columnGap else { return [items] }
        let left = items.filter { $0.boundingBox.midX < split }
        let right = items.filter { $0.boundingBox.midX >= split }
        guard left.count >= 2, right.count >= 2 else { return [items] }
        return [left, right]
    }

    /// Gộp observation trong MỘT cột thành hàng, rồi quyết định `breakBefore`
    /// cho từng hàng (trừ hàng đầu cột — cột nối với nhau ở tầng gọi trên).
    private static func linesWithBreaks(in column: [Observation]) -> [Line] {
        let rawLines = clusterLines(column)
        guard !rawLines.isEmpty else { return [] }

        let aggregated: [(text: String, minX: CGFloat, maxX: CGFloat, yTop: CGFloat, height: CGFloat)] =
            rawLines.map { line in
                let text = line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    .map(\.text).joined(separator: " ")
                let minX = line.map(\.boundingBox.minX).min() ?? 0
                let maxX = line.map { $0.boundingBox.minX + $0.boundingBox.width }.max() ?? 0
                let top = line.map(yTop).min() ?? 0
                let height = line.map(\.boundingBox.height).reduce(0, +) / CGFloat(line.count)
                return (text, minX, maxX, top, height)
            }

        guard aggregated.count >= minLinesForParagraphBreaks else {
            return aggregated.map { line in
                Line(
                    text: line.text, minX: line.minX, maxX: line.maxX, yTop: line.yTop,
                    height: line.height, breakBefore: false, breakReason: nil)
            }
        }

        let heights = aggregated.map(\.height)
        let heightMedian = median(heights)
        let gaps: [CGFloat] = (1..<aggregated.count).map { aggregated[$0].yTop - aggregated[$0 - 1].yTop }
        let gapMedian = median(gaps)
        let leftEdge = percentile(aggregated.map(\.minX), 0.1)
        let rightEdge = percentile(aggregated.map(\.maxX), 0.9)
        let columnWidth = max(rightEdge - leftEdge, 0.01)

        var lines: [Line] = []
        for (index, line) in aggregated.enumerated() {
            guard index > 0 else {
                lines.append(Line(
                    text: line.text, minX: line.minX, maxX: line.maxX, yTop: line.yTop,
                    height: line.height, breakBefore: false, breakReason: nil))
                continue
            }
            let previous = aggregated[index - 1]
            let gap = line.yTop - previous.yTop

            var reason: String?
            if gapMedian > 0, gap > gapBreakFactor * gapMedian {
                reason = "gap"
            } else if line.minX - leftEdge > indentFactorOfHeight * heightMedian,
                      index + 1 >= aggregated.count
                        || abs(aggregated[index + 1].minX - leftEdge) < indentReturnFactorOfHeight * heightMedian
            {
                reason = "indent"
            } else if rightEdge - previous.maxX > shortEndingFactorOfWidth * columnWidth,
                      let lastChar = previous.text.last, sentenceEndingCharacters.contains(lastChar)
            {
                reason = "shortEnding"
            }

            lines.append(Line(
                text: line.text, minX: line.minX, maxX: line.maxX, yTop: line.yTop,
                height: line.height, breakBefore: reason != nil, breakReason: reason))
        }
        return lines
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private static func percentile(_ values: [CGFloat], _ p: CGFloat) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, max(0, Int((CGFloat(sorted.count - 1) * p).rounded())))
        return sorted[index]
    }

    private static func clusterLines(_ items: [Observation]) -> [[Observation]] {
        let sorted = items.sorted { yTop($0) < yTop($1) }
        var lines: [[Observation]] = []
        for item in sorted {
            if var last = lines.last, sameLine(last, item) {
                last.append(item)
                lines[lines.count - 1] = last
            } else {
                lines.append([item])
            }
        }
        return lines
    }

    private static func sameLine(_ line: [Observation], _ item: Observation) -> Bool {
        let heights = line.map(\.boundingBox.height) + [item.boundingBox.height]
        let meanHeight = heights.reduce(0, +) / CGFloat(heights.count)
        let threshold = max(0.018, meanHeight * 0.65)
        return abs(yTop(line[0]) - yTop(item)) < threshold
    }

    /// Origin Vision dưới-trái → y nhỏ = phía trên trang.
    private static func yTop(_ item: Observation) -> CGFloat {
        1 - item.boundingBox.origin.y - item.boundingBox.height
    }
}

private struct PageOCRLive: PageTextRecognizer {
    func recognize(imageData: Data) async throws -> String {
        try await PageOCR.recognize(imageData: imageData)
    }

    func recognizeDetailed(imageData: Data) async throws -> PageOCR.OCRResult {
        try await PageOCR.recognizeDetailed(imageData: imageData)
    }
}
