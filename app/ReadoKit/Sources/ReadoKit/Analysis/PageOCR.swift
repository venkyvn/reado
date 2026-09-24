import CoreGraphics
import Foundation
import ImageIO
import Vision

/// OCR trang trên máy (Vision). Observation không theo thứ tự sách — ghép dòng
/// theo bounding box; hai cột khi có khe X rõ (trái rồi phải).
public protocol PageTextRecognizer: Sendable {
    func recognize(imageData: Data) async throws -> String
}

public enum PageOCR {
    public static let live: PageTextRecognizer = PageOCRLive()

    /// Box Vision: origin dưới-trái, 0...1.
    public struct Observation: Equatable, Sendable {
        public let text: String
        public let boundingBox: CGRect

        public init(text: String, boundingBox: CGRect) {
            self.text = text
            self.boundingBox = boundingBox
        }
    }

    public static func recognize(imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try recognizeSync(imageData: imageData)
        }.value
    }

    /// Testable: không gọi Vision.
    public static func readingOrder(_ items: [Observation]) -> String {
        let usable = items.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !usable.isEmpty else { return "" }
        return splitColumns(usable)
            .map(orderColumn)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static let columnGap: CGFloat = 0.14
    private static let minConfidence: Float = 0.25

    private static func recognizeSync(imageData: Data) throws -> String {
        guard let image = cgImage(from: imageData) else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.015
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        let items: [Observation] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first,
                  candidate.confidence >= minConfidence
            else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Observation(text: text, boundingBox: obs.boundingBox)
        }
        return readingOrder(items)
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

    private static func orderColumn(_ items: [Observation]) -> String {
        clusterLines(items)
            .map { line in
                line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    .map(\.text)
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
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
}
