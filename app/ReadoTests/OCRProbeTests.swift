import Foundation
import ReadoKit
import UIKit
import Vision
import VisionKit
import XCTest

/// Test opt-in, KHÔNG chạy mặc định (skip nếu thiếu env) — công cụ đo cho
/// ocr-line-drop (`docs/plans/ocr-line-drop.md` T2) + ocr-quality-r1 T2 (ADR-064,
/// thêm cấu hình `liveText` + WER/CER thật thay cho chỉ đếm câu thiếu). Chạy
/// trên mỗi `page.jpg` đã kéo về bằng `scripts/pull_diagnostics.sh`, so với
/// `groundtruth.txt` (gõ tay hoặc lấy từ nguồn số gốc — KHÔNG dùng Live Text,
/// tránh đo vòng tròn vì `liveText` chính là một cấu hình đang so) nếu có, để
/// trả lời:
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
                "scaled1600Pixels": {
                    let s = scaledTo1600(cgImage)
                    return "\(s.width)x\(s.height)"
                }(),
            ]
            var lines = ["=== \(folder.lastPathComponent) — \(cgImage.width)x\(cgImage.height) ==="]

            for (label, testImage) in [
                ("fullRes", cgImage), ("scaled1600", scaledTo1600(cgImage)),
            ] {
                let clock = ContinuousClock()
                let legacyStart = clock.now
                let legacy = try await runLegacy(testImage)
                let legacyMs = milliseconds(since: legacyStart, clock: clock)
                let docStart = clock.now
                let doc = try await runDocuments(testImage)
                let docMs = milliseconds(since: docStart, clock: clock)
                let liveStart = clock.now
                let live = try await runLiveText(testImage)
                let liveMs = milliseconds(since: liveStart, clock: clock)
                for (engine, result, ms) in [
                    ("legacy", legacy, legacyMs), ("documents", doc, docMs), ("liveText", live, liveMs),
                ] {
                    let key = "\(label)_\(engine)"
                    let missing = groundtruth.map { missingSentences(text: result.text, groundtruth: $0) } ?? []
                    let wer = groundtruth.map { wordErrorRate(hypothesis: result.text, reference: $0) }
                    let cer = groundtruth.map { characterErrorRate(hypothesis: result.text, reference: $0) }
                    report[key] = [
                        "rawObservationCount": result.rawObservationCount,
                        "keptObservationCount": result.observations.count,
                        "droppedLowConfidenceCount": result.droppedLowConfidence.count,
                        "lineCount": result.lines.count,
                        "missingGroundtruthLineCount": missing.count,
                        "missingSentences": missing,
                        "wer": wer.map { $0 as Any } ?? NSNull(),
                        "cer": cer.map { $0 as Any } ?? NSNull(),
                        "ms": ms,
                        "text": result.text,
                    ]
                    let werStr = wer.map { String(format: "%.3f", $0) } ?? "—"
                    let cerStr = cer.map { String(format: "%.3f", $0) } ?? "—"
                    lines.append(
                        "  \(key): raw=\(result.rawObservationCount) kept=\(result.observations.count) "
                            + "lines=\(result.lines.count) missingVsGroundtruth=\(missing.count) "
                            + "wer=\(werStr) cer=\(cerStr) ms=\(ms)")
                }
            }
            // Đường app thật (`PageOCR.recognizeDetailed` trên đúng bytes page.jpg) —
            // xác nhận iOS 26 đi engine documents chứ không rơi về legacy.
            let appResult = try await PageOCR.recognizeDetailed(imageData: data)
            let appMissing = groundtruth.map { missingSentences(text: appResult.text, groundtruth: $0) } ?? []
            let appWER = groundtruth.map { wordErrorRate(hypothesis: appResult.text, reference: $0) }
            let appCER = groundtruth.map { characterErrorRate(hypothesis: appResult.text, reference: $0) }
            report["app_recognizeDetailed"] = [
                "engine": appResult.engine,
                "lineCount": appResult.lines.count,
                "paragraphCount": appResult.text.components(separatedBy: "\n\n").count,
                "missingGroundtruthLineCount": appMissing.count,
                "missingSentences": appMissing,
                "wer": appWER.map { $0 as Any } ?? NSNull(),
                "cer": appCER.map { $0 as Any } ?? NSNull(),
                "text": appResult.text,
            ]
            let appWERStr = appWER.map { String(format: "%.3f", $0) } ?? "—"
            lines.append(
                "  app: engine=\(appResult.engine) lines=\(appResult.lines.count) "
                    + "missingVsGroundtruth=\(appMissing.count) wer=\(appWERStr)")
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

    /// ocr-quality-r1 T2 (ADR-064) — Live Text thật (VisionKit `ImageAnalyzer`,
    /// iOS 16+/macOS 13+). API public CHỈ có `transcript: String` — không có
    /// dòng/bbox/đoạn như `documents`/`legacy` (đã kiểm swiftinterface SDK),
    /// nên `observations`/`lines` luôn rỗng ở đây, chỉ `text` dùng để so WER.
    private func runLiveText(_ image: CGImage) async throws -> PageOCR.OCRResult {
        guard ImageAnalyzer.isSupported else {
            return PageOCR.OCRResult(text: "", observations: [], lines: [], engine: "liveText")
        }
        let analyzer = ImageAnalyzer()
        let configuration = ImageAnalyzer.Configuration([.text])
        let uiImage = UIImage(cgImage: image)
        let result = try await analyzer.analyze(uiImage, configuration: configuration)
        return PageOCR.OCRResult(text: result.transcript, observations: [], lines: [], engine: "liveText")
    }

    private func milliseconds(since start: ContinuousClock.Instant, clock: ContinuousClock) -> Int {
        let components = (clock.now - start).components
        return Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }

    /// Cùng luật gập dash/quote/gạch nối cuối hàng với `normalize(_:)` — tránh
    /// WER bị chi phối bởi khác biệt ký tự typographic/ngắt dòng, như
    /// investigation ocr-line-drop §11 đã thấy (WER 0.131 chủ yếu 1 câu thiếu,
    /// không phải lỗi chữ).
    private func wordErrorRate(hypothesis: String, reference: String) -> Double {
        let refWords = normalize(reference).split(separator: " ").map(String.init)
        guard !refWords.isEmpty else { return 0 }
        let hypWords = normalize(hypothesis).split(separator: " ").map(String.init)
        return Double(EditDistance.levenshtein(hypWords, refWords)) / Double(refWords.count)
    }

    private func characterErrorRate(hypothesis: String, reference: String) -> Double {
        let refChars = Array(normalize(reference))
        guard !refChars.isEmpty else { return 0 }
        let hypChars = Array(normalize(hypothesis))
        return Double(EditDistance.levenshtein(hypChars, refChars)) / Double(refChars.count)
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
        // scale = 1: mặc định của UIGraphicsImageRenderer là @3x → "1600px" thật ra
        // ra ~4800px (đúng bug của ImageCompressor); probe phải đo pixel thật.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: newW, height: newH), format: format)
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

    /// Gập ký tự typographic (dash/quote) + gạch nối cuối hàng để so groundtruth
    /// (Live Text ghi `true-the`, sách in em-dash) không bị nhiễu giả.
    private func normalize(_ text: String) -> String {
        var t = text.lowercased()
        for dash in ["—", "–", "‒", "―"] { t = t.replacingOccurrences(of: dash, with: "-") }
        for q in ["’", "‘", "ʼ"] { t = t.replacingOccurrences(of: q, with: "'") }
        for q in ["“", "”"] { t = t.replacingOccurrences(of: q, with: "\"") }
        t = t.replacingOccurrences(of: "-\n", with: "")
        return t.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}
