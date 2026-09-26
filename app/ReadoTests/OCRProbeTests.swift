import Foundation
import ReadoKit
import UIKit
import Vision
import XCTest

/// Test opt-in, KHÔNG chạy mặc định (skip nếu thiếu env) — công cụ đo cho
/// ocr-line-drop (`docs/plans/ocr-line-drop.md` T2). Chạy 4 cấu hình OCR trên
/// mỗi `page.jpg` đã kéo về bằng `scripts/pull_diagnostics.sh`, so với
/// `groundtruth.txt` (Live Text dán tay) nếu có, để trả lời:
///   (a) hàng OCR app mất là do Vision không thấy hay do lọc confidence sau đó
///       (đọc `probe.json` → `legacyFullRes.rawObservationCount` so với
///       `kept + droppedLowConfidence`, xem `PageOCR.OCRResult`);
///   (b) `RecognizeDocumentsRequest` (iOS 26+ trên SDK máy này, đoạn có sẵn —
///       không qua `PageOCR.linesWithBreaks` hình học của ADR-037) có nhận đủ
///       hàng hơn `VNRecognizeTextRequest` cũ không;
///   (c) resize về 1600px cạnh dài (FR-01) có làm rơi thêm hàng so với full-res
///       không — quyết định hướng T4 (`ImageCompressor` đang có bug scale @3x,
///       resize "1600" thực ra vẫn ra ảnh ~4800px).
///
/// Chạy tay, trỏ vào một thư mục `pull_diagnostics.sh` đã kéo về:
///
///   TEST_RUNNER_READO_OCR_PROBE_DIR="$PWD/.tmp/diagnostics/<ts>/analyses" \
///     scripts/test.sh test -only-testing:ReadoTests/OCRProbeTests
///
/// `TEST_RUNNER_` là prefix xcodebuild chuyển env vào process chạy test.
/// Ghi `probe.json` vào từng thư mục con — không sửa `page.jpg`/`ocr.json`
/// gốc. Có `groundtruth.txt` (dán tay Live Text) trong thư mục con thì probe
/// tự đếm số hàng có mặt trong groundtruth mà cấu hình đó KHÔNG nhận ra.
final class OCRProbeTests: XCTestCase {
    func testCompareEnginesOnPulledDiagnostics() async throws {
        guard let dirPath = ProcessInfo.processInfo.environment["READO_OCR_PROBE_DIR"],
              !dirPath.isEmpty
        else {
            throw XCTSkip("Thiếu READO_OCR_PROBE_DIR — bỏ qua probe OCR (cần thư mục analyses/ đã kéo về).")
        }
        let root = URL(fileURLWithPath: dirPath, isDirectory: true)
        let folders = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        guard !folders.isEmpty else {
            throw XCTSkip("Không thấy thư mục con nào trong \(dirPath).")
        }

        var summaryLines: [String] = []
        for folder in folders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let imageURL = folder.appendingPathComponent("page.jpg")
            guard let data = try? Data(contentsOf: imageURL),
                  let image = UIImage(data: data), let cgImage = image.cgImage
            else { continue }

            let groundtruth = (try? String(
                contentsOf: folder.appendingPathComponent("groundtruth.txt"), encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            var report: [String: Any] = [
                "sourcePixels": "\(cgImage.width)x\(cgImage.height)",
            ]
            var lines = ["=== \(folder.lastPathComponent) — \(cgImage.width)x\(cgImage.height) ==="]

            for (label, testImage) in [
                ("fullRes", cgImage), ("scaled1600", scaledTo1600(cgImage)),
            ] {
                let legacy = try await runLegacy(testImage)
                let doc = try await runDocuments(testImage)
                for (engine, result) in [("legacy", legacy), ("documents", doc)] {
                    let key = "\(label)_\(engine)"
                    let missing = groundtruth.map { missingSentences(text: result.text, groundtruth: $0) } ?? []
                    report[key] = [
                        "rawObservationCount": result.rawObservationCount,
                        "keptObservationCount": result.observations.count,
                        "droppedLowConfidenceCount": result.droppedLowConfidence.count,
                        "lineCount": result.lines.count,
                        "missingGroundtruthLineCount": missing.count,
                    ]
                    let missingPreview = missing.prefix(3).map { String($0.prefix(60)) }
                    lines.append(
                        "  \(key): raw=\(result.rawObservationCount) kept=\(result.observations.count) "
                            + "droppedLowConf=\(result.droppedLowConfidence.count) lines=\(result.lines.count) "
                            + "missingVsGroundtruth=\(missing.count) \(missingPreview)")
                }
            }
            try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: folder.appendingPathComponent("probe.json"))
            summaryLines.append(contentsOf: lines)
        }

        let summary = summaryLines.joined(separator: "\n")
        print("OCRProbeTests summary:\n\(summary)")
        XCTAssertFalse(summaryLines.isEmpty, "Không đọc được page.jpg nào trong \(dirPath)")
    }

    // MARK: - Cấu hình OCR

    /// Đường cũ (`PageOCR.swift`) — `VNRecognizeTextRequest` + ngắt đoạn hình học ADR-037.
    private func runLegacy(_ image: CGImage) async throws -> PageOCR.OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.015
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            let candidates: [PageOCR.Observation] = observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return PageOCR.Observation(
                    text: text, boundingBox: obs.boundingBox, confidence: candidate.confidence)
            }
            let (kept, dropped) = PageOCR.partitionByConfidence(candidates)
            let result = PageOCR.detailedReadingOrder(kept)
            return PageOCR.OCRResult(
                text: result.text, observations: result.observations, lines: result.lines,
                rawObservationCount: observations.count, droppedLowConfidence: dropped)
        }.value
    }

    /// Vision mới (iOS 26+ trên SDK này — đo thật lúc build: compiler báo
    /// `RecognizeDocumentsRequest` chỉ có từ iOS 26.0, không phải 18 như tài
    /// liệu cộng đồng), đoạn có sẵn từ Vision, không qua `PageOCR.linesWithBreaks`
    /// hình học. iOS < 26 (không áp dụng ở đây — simulator test luôn iOS mới
    /// nhất) trả kết quả rỗng.
    private func runDocuments(_ image: CGImage) async throws -> PageOCR.OCRResult {
        guard #available(iOS 26.0, *) else {
            return PageOCR.OCRResult(text: "", observations: [], lines: [])
        }
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.useLanguageCorrection = true
        let observations = try await request.perform(on: image)
        guard let document = observations.first?.document else {
            return PageOCR.OCRResult(text: "", observations: [], lines: [], rawObservationCount: 0)
        }
        let paragraphTexts = document.paragraphs.map(\.transcript)
        let text = paragraphTexts.joined(separator: "\n\n")
        // Không có bounding box/confidence per-line ở entry point này —
        // `lines`/`observations` để rỗng, chỉ text dùng để so groundtruth.
        return PageOCR.OCRResult(
            text: text, observations: [], lines: [],
            rawObservationCount: paragraphTexts.count)
    }

    private func scaledTo1600(_ image: CGImage) -> CGImage {
        let maxEdge: CGFloat = 1600
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        let longest = max(w, h)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let newW = Int(w * scale)
        let newH = Int(h * scale)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: newW, height: newH))
        let uiImage = UIImage(cgImage: image)
        let resized = renderer.image { _ in
            uiImage.draw(in: CGRect(x: 0, y: 0, width: newW, height: newH))
        }
        return resized.cgImage ?? image
    }

    /// Câu trong `groundtruth` (tách theo `. `/xuống dòng, lọc câu quá ngắn) mà
    /// KHÔNG tìm thấy (sau khi chuẩn hoá khoảng trắng) trong `text` nhận được.
    private func missingSentences(text: String, groundtruth: String) -> [String] {
        let normalizedText = normalize(text)
        let sentences = groundtruth
            .components(separatedBy: CharacterSet(charactersIn: "\n"))
            .flatMap { $0.components(separatedBy: ". ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 20 }
        return sentences.filter { !normalizedText.contains(normalize($0)) }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}
