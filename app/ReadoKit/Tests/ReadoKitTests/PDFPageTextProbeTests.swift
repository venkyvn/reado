import CoreGraphics
import Foundation
import PDFKit
import ReadoKit
import XCTest

/// Test opt-in, KHÔNG chạy mặc định (skip nếu thiếu env) — công cụ đo cho
/// pdf-reader-r1 T5 (chưa làm, cần PDF thật — xem `docs/plans/pdf-reader-r1.md`).
/// `PDFPageText` dùng PDFKit, cross-platform (macOS+iOS) nên chạy được ở lane
/// `kit` (macOS, không cần Simulator) — nhanh hơn nhiều so với mọi probe OCR
/// khác trong repo (`OCRProbeTests` cần simulator vì dùng Vision/VisionKit).
///
/// Chạy tay, trỏ vào một PDF thật trên máy (KHÔNG commit PDF, bản quyền):
///
///   TEST_RUNNER_READO_PDF_PROBE_PATH="/duong/dan/file.pdf" \
///     scripts/test.sh kit -only-testing:ReadoKitTests/PDFPageTextProbeTests
///
/// Tuỳ chọn `TEST_RUNNER_READO_PDF_PROBE_PAGES="12,13,17,100"` (0-based, phẩy
/// cách) — mặc định lấy mẫu trải đều 12 trang trên cả cuốn.
final class PDFPageTextProbeTests: XCTestCase {
    func testExtractOnRealPDF() throws {
        guard let path = ProcessInfo.processInfo.environment["READO_PDF_PROBE_PATH"],
              !path.isEmpty
        else {
            throw XCTSkip("Thiếu READO_PDF_PROBE_PATH — bỏ qua probe PDFPageText (cần PDF thật).")
        }
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
            XCTFail("Không mở được PDF ở \(path)")
            return
        }
        let pageCount = document.pageCount
        let indices: [Int]
        if let raw = ProcessInfo.processInfo.environment["READO_PDF_PROBE_PAGES"], !raw.isEmpty {
            indices = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            let sampleCount = min(12, pageCount)
            indices = (0..<sampleCount).map { $0 * pageCount / sampleCount }
        }

        var textCount = 0
        var needsOCRCount = 0
        var reasonCounts: [String: Int] = [:]
        var lines: [String] = ["=== PDFPageText probe: \(path) — \(pageCount) trang, mẫu \(indices.count) ==="]

        for index in indices {
            guard index >= 0, index < pageCount, let page = document.page(at: index) else { continue }
            let result = PDFPageText.extract(page: page)
            switch result {
            case let .text(text):
                textCount += 1
                // CHỈ số liệu cấu trúc — không trích nguyên văn text (sách có
                // bản quyền, và gõ/in lại nhiều đã làm content-filter API chặn
                // lúc gom groundtruth T1, xem docs/journal/2026-10-05.md).
                let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
                let words = text.split(whereSeparator: \.isWhitespace)
                // Dấu hiệu lớp chữ "rác" dù qua được quality(): khoảng trắng
                // bất thường giữa ký tự trong từ (kiểu PyPDF2 từng thấy khi đọc
                // thử bằng Python) — không nên có nếu PDFKit dựng đúng.
                // Chỉ ĐẾM/VỊ TRÍ — không phải chữ gì — để không trích nguyên văn:
                // cụm ≥3 token-1-ký-tự LIÊN TIẾP (tách bằng whitespace thật qua
                // `split`, không phải regex substring — bản regex đầu tiên
                // `[a-z] [a-z] [a-z]` khớp cả "d a b" trong "read a book" tức
                // chữ cuối + từ "a" + chữ đầu từ sau, dương tính giả gần như mọi
                // trang tiếng Anh bình thường — xem docs/journal/2026-10-05.md).
                let isSingleLetter = words.map { $0.count == 1 && $0.first?.isLetter == true }
                let singleLetterTokens = isSingleLetter.filter { $0 }.count
                var clusterStarts: [Int] = []
                var runStart: Int?
                for (i, flag) in isSingleLetter.enumerated() {
                    if flag {
                        if runStart == nil { runStart = i }
                    } else {
                        if let start = runStart, i - start >= 3 { clusterStarts.append(start) }
                        runStart = nil
                    }
                }
                if let start = runStart, isSingleLetter.count - start >= 3 { clusterStarts.append(start) }
                let avgParagraphWords = paragraphs.isEmpty ? 0
                    : words.count / max(paragraphs.count, 1)
                lines.append(
                    "  [\(index)] text: paragraphs=\(paragraphs.count) words=\(words.count) "
                        + "avgWords/para=\(avgParagraphWords) singleLetterTokens=\(singleLetterTokens)/\(words.count) "
                        + "clusterStartIdx(≥3 liên tiếp)=\(clusterStarts)")
            case let .needsOCR(reason):
                needsOCRCount += 1
                let key = String(describing: reason)
                reasonCounts[key, default: 0] += 1
                lines.append("  [\(index)] needsOCR: \(reason)")
            }
        }
        lines.append("--- tổng: text=\(textCount) needsOCR=\(needsOCRCount) lý do=\(reasonCounts) ---")

        let summary = lines.joined(separator: "\n")
        print("PDFPageTextProbeTests summary:\n\(summary)")
        XCTAssertFalse(indices.isEmpty, "Không có trang nào để probe")
    }
}
