import Foundation
import ReadoKit
import XCTest

/// ocr-quality-r1 T4 (ADR-064) — 4 ca từ plan: `tbe` (nghi ngờ), `Nescafé`
/// (bỏ qua vì viết hoa đầu), `B12` (bỏ qua vì có số), `serendipity` (hợp lệ).
final class VocabSuspicionTests: XCTestCase {
    /// Từ điển giả — chỉ "serendipity" hợp lệ, mọi từ khác bị `isKnownWord`
    /// báo không nhận ra (giống `UITextChecker` thật gặp từ lạ/OCR rác).
    private func isKnownWord(_ word: String) -> Bool {
        word == "serendipity"
    }

    func testUnknownWordIsSuspicious() {
        XCTAssertTrue(VocabSuspicion.isSuspicious(term: "tbe", isKnownWord: isKnownWord))
    }

    func testCapitalizedWordSkipped() {
        XCTAssertFalse(VocabSuspicion.isSuspicious(term: "Nescafé", isKnownWord: isKnownWord))
    }

    func testWordWithNumberSkipped() {
        XCTAssertFalse(VocabSuspicion.isSuspicious(term: "B12", isKnownWord: isKnownWord))
    }

    func testKnownWordNotSuspicious() {
        XCTAssertFalse(VocabSuspicion.isSuspicious(term: "serendipity", isKnownWord: isKnownWord))
    }

    /// Cụm nhiều từ: từng từ đều hợp lệ → cụm không nghi ngờ.
    func testMultiWordPhraseAllKnownNotSuspicious() {
        XCTAssertFalse(
            VocabSuspicion.isSuspicious(term: "serendipity serendipity", isKnownWord: isKnownWord))
    }

    /// Cụm nhiều từ: 1 từ không hợp lệ → cả cụm nghi ngờ.
    func testMultiWordPhraseOneUnknownIsSuspicious() {
        XCTAssertTrue(
            VocabSuspicion.isSuspicious(term: "serendipity tbe", isKnownWord: isKnownWord))
    }

    func testEmptyTermNotSuspicious() {
        XCTAssertFalse(VocabSuspicion.isSuspicious(term: "", isKnownWord: isKnownWord))
    }
}
