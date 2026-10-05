import ReadoKit
import XCTest

/// engagement-r1 T7 — chọn cụm đáng nhớ cho banner "Đã lưu" (hàm thuần).
final class MemorablePhraseTests: XCTestCase {

    private func segment(_ phrases: [(String, String)]) -> PageAnalysis.Segment {
        PageAnalysis.Segment(
            sourceEN: "x", translationVI: "y",
            phrases: phrases.map { PageAnalysis.Phrase(en: $0.0, vi: $0.1) })
    }

    func testPhraseContainingSavedTermWinsOverLongerPhrase() {
        let segments = [
            segment([("a very long phrase without any match here", "dài"), ("keystone of sleep", "nền tảng")]),
        ]
        XCTAssertEqual(
            MemorablePhrase.pick(from: segments, savedTerms: ["keystone"])?.vi, "nền tảng")
    }

    func testFirstMatchingPhraseInPageOrderWins() {
        let segments = [
            segment([("first routine", "một")]),
            segment([("second routine here", "hai")]),
        ]
        XCTAssertEqual(MemorablePhrase.pick(from: segments, savedTerms: ["routine"])?.vi, "một")
    }

    func testMultiWordTermAndCaseInsensitiveAndPunctuation() {
        let segments = [segment([("Small gains, compound over years", "lợi nhỏ")])]
        XCTAssertEqual(
            MemorablePhrase.pick(from: segments, savedTerms: ["GAINS COMPOUND"])?.vi, "lợi nhỏ",
            "dấu phẩy giữa hai chữ không cản khớp cụm nhiều chữ, không phân biệt hoa thường")
        XCTAssertEqual(
            MemorablePhrase.pick(from: segments, savedTerms: ["small gains"])?.vi, "lợi nhỏ")
    }

    func testNoWordBoundaryMatchInsideLongerWord() {
        let segments = [
            segment([("category of things", "loại")]),
            segment([("a cat sat down here", "mèo")]),
        ]
        XCTAssertEqual(
            MemorablePhrase.pick(from: segments, savedTerms: ["cat"])?.vi, "mèo",
            "\"cat\" không khớp trong \"category\"")
    }

    func testNoMatchFallsBackToLongestPhraseTiePrefersEarlier() {
        let segments = [
            segment([("two words", "hai"), ("three words here", "ba a")]),
            segment([("other three words", "ba b")]),
        ]
        XCTAssertEqual(MemorablePhrase.pick(from: segments, savedTerms: ["zzz"])?.vi, "ba a")
        XCTAssertEqual(MemorablePhrase.pick(from: segments, savedTerms: [])?.vi, "ba a")
    }

    func testNoPhrasesReturnsNil() {
        XCTAssertNil(MemorablePhrase.pick(from: [], savedTerms: ["x"]))
        XCTAssertNil(MemorablePhrase.pick(from: [segment([])], savedTerms: ["x"]))
    }

    func testPhrasesWithEmptySideAreIgnored() {
        let segments = [segment([("", "trống"), ("has vi empty", "  "), ("good phrase", "tốt")])]
        XCTAssertEqual(MemorablePhrase.pick(from: segments, savedTerms: [])?.en, "good phrase")
    }
}
