import ReadoKit
import XCTest

final class AppleIntelligenceStatusTests: XCTestCase {
    override func tearDown() {
        AppleIntelligence.statusOverride = nil
        super.tearDown()
    }

    func testStatusOverrideIsRespected() {
        AppleIntelligence.statusOverride = .available
        XCTAssertEqual(AppleIntelligence.status(needsVietnamese: true), .available)

        AppleIntelligence.statusOverride = .unavailable(.notEnabled)
        XCTAssertEqual(AppleIntelligence.status(needsVietnamese: false), .unavailable(.notEnabled))
    }

    func testIsAvailable() {
        XCTAssertTrue(AppleIntelligenceStatus.available.isAvailable)
        XCTAssertFalse(AppleIntelligenceStatus.unavailable(.osTooOld).isAvailable)
    }

    func testReasonVICoversEveryReason() {
        let reasons: [AppleIntelligenceStatus.Reason] = [
            .osTooOld, .deviceNotEligible, .notEnabled, .modelNotReady,
            .vietnameseUnsupported, .pccUnavailable,
        ]
        for reason in reasons {
            XCTAssertNotNil(AppleIntelligenceStatus.unavailable(reason).reasonVI, "thiếu copy cho \(reason)")
        }
        XCTAssertNil(AppleIntelligenceStatus.available.reasonVI)
    }
}
