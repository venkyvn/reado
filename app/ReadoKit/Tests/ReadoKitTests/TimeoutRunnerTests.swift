import ReadoKit
import XCTest

/// ocr-quality-r1 T7 (ADR-065) — tách khỏi `CorrectingTextRecognizerTests.swift`
/// (đã xoá cùng nhánh sửa OCR bằng LLM) vì `TimeoutRunner` dùng chung, vẫn cần
/// cho `AppleIntelligenceAnalyzer` giới hạn thời gian gọi model AI.
final class TimeoutRunnerTests: XCTestCase {
    func testFastOperationReturnsValue() async throws {
        let value = try await TimeoutRunner.run(.seconds(1)) { 42 }
        XCTAssertEqual(value, 42)
    }

    func testSlowOperationThrowsTimeoutError() async {
        do {
            _ = try await TimeoutRunner.run(.milliseconds(50)) {
                try await Task.sleep(for: .seconds(5))
                return 1
            }
            XCTFail("mong đợi TimeoutError")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }
}
