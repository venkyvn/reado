import ReadoKit
import XCTest

private struct FixedCorrector: OCRCorrector {
    let fixes: [OCRFix]
    let counter: AttemptCounter?

    func proposeFixes(for text: String) async throws -> [OCRFix] {
        counter?.increment()
        return fixes
    }
}

private struct FailingCorrector: OCRCorrector {
    func proposeFixes(for text: String) async throws -> [OCRFix] {
        throw AnalysisError.providerError("corrector lỗi giả lập")
    }
}

private struct SlowCorrector: OCRCorrector {
    let delay: Duration
    func proposeFixes(for text: String) async throws -> [OCRFix] {
        try await Task.sleep(for: delay)
        return [OCRFix(wrong: "tbe", right: "the")]
    }
}

final class CorrectingTextRecognizerTests: XCTestCase {
    func testAppliesFixesAndRecordsRawText() async throws {
        let original = "tbe cat sat quietly on the old rug today"
        let base = FixedPageOCR(text: original)
        let recognizer = CorrectingTextRecognizer(
            base: base, corrector: FixedCorrector(fixes: [OCRFix(wrong: "tbe", right: "the")], counter: nil))
        let result = try await recognizer.recognizeDetailed(imageData: Data())
        XCTAssertEqual(result.text, "the cat sat quietly on the old rug today")
        XCTAssertEqual(result.rawText, original)
        XCTAssertEqual(result.fixes, [OCRFix(wrong: "tbe", right: "the")])
        XCTAssertEqual(result.fixRejectedCount, 0)
        XCTAssertNil(result.fixError)
        XCTAssertNotNil(result.fixMs)
    }

    func testCorrectorErrorFallsBackToRawOCR() async throws {
        let base = FixedPageOCR(text: "original text")
        let recognizer = CorrectingTextRecognizer(base: base, corrector: FailingCorrector())
        let result = try await recognizer.recognizeDetailed(imageData: Data())
        XCTAssertEqual(result.text, "original text")
        XCTAssertTrue(result.fixes.isEmpty)
        XCTAssertNotNil(result.fixError)
    }

    func testTimeoutFallsBackToRawOCRQuickly() async throws {
        let base = FixedPageOCR(text: "original text")
        let recognizer = CorrectingTextRecognizer(
            base: base, corrector: SlowCorrector(delay: .seconds(5)), timeout: .milliseconds(100))
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await recognizer.recognizeDetailed(imageData: Data())
        let elapsed = clock.now - start
        XCTAssertEqual(result.text, "original text")
        XCTAssertNotNil(result.fixError)
        XCTAssertLessThan(elapsed, .seconds(1))
    }

    func testEmptyOCRSkipsCorrectorEntirely() async throws {
        let base = FixedPageOCR(text: "   ")
        let counter = AttemptCounter()
        let recognizer = CorrectingTextRecognizer(
            base: base, corrector: FixedCorrector(fixes: [], counter: counter))
        let result = try await recognizer.recognizeDetailed(imageData: Data())
        XCTAssertEqual(result.text, "   ")
        XCTAssertEqual(counter.value, 0)
    }

    func testBaseOCRErrorStillThrows() async {
        let recognizer = CorrectingTextRecognizer(base: FailingPageOCR(), corrector: FixedCorrector(fixes: [], counter: nil))
        do {
            _ = try await recognizer.recognizeDetailed(imageData: Data())
            XCTFail("mong đợi lỗi từ base OCR")
        } catch {
            guard case AnalysisError.providerError = error else {
                return XCTFail("mong đợi providerError, nhận \(error)")
            }
        }
    }
}

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
