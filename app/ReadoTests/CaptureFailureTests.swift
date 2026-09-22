import Foundation
import XCTest
import ReadoKit

/// FR-04 — Capture failure handling: ảnh mờ/không đọc được → báo cụ thể + gợi ý
/// chụp lại, không bịa dữ liệu; trang không phải tiếng Anh → báo không hỗ trợ,
/// không tính phí. Tầng testable nằm ở ReadoKit (error enum); nhánh UI
/// (AppModel/AnalysisView) sống ở app target (không có test host). Map error
/// envelope → AnalysisError test ở AnalysisTests (cạnh StubURLProtocol).
final class CaptureFailureTests: XCTestCase {

    // MARK: - AnalysisError message (FR-04 criteria đọc được, không parse chuỗi)

    func testImageUnreadableMessageSuggestsRecapture() {
        let message = AnalysisError.imageUnreadable.errorDescription ?? ""
        XCTAssertTrue(
            message.contains("chụp lại"),
            "G1: phải gợi ý chụp lại, nhận: \(message)")
    }

    func testNotEnglishMessageReportsUnsupportedAndNoCharge() {
        let message = AnalysisError.notEnglishText.errorDescription ?? ""
        XCTAssertTrue(
            message.contains("không hỗ trợ"),
            "G2: phải báo không hỗ trợ, nhận: \(message)")
        XCTAssertTrue(
            message.contains("không tính phí"),
            "G2: phải nói rõ không tính phí lần gọi, nhận: \(message)")
    }

    // MARK: - Hướng CTA theo loại lỗi (FR-04: chụp lại vs thử lại)

    func testSuggestsRecaptureOnlyForImageAndLanguageFailures() {
        XCTAssertTrue(AnalysisError.imageUnreadable.suggestsRecapture)
        XCTAssertTrue(AnalysisError.notEnglishText.suggestsRecapture)
        // Lỗi tạm → retry cùng ảnh là hợp lý, không ép chụp lại.
        XCTAssertFalse(AnalysisError.networkError("timeout").suggestsRecapture)
        XCTAssertFalse(AnalysisError.schemaViolation("x").suggestsRecapture)
        XCTAssertFalse(AnalysisError.providerError("x").suggestsRecapture)
        XCTAssertFalse(AnalysisError.rateLimited.suggestsRecapture)
        XCTAssertFalse(AnalysisError.invalidResponse("x").suggestsRecapture)
        XCTAssertFalse(AnalysisError.idempotencyMissing.suggestsRecapture)
    }
}