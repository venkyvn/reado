import ReadoKit
import XCTest

/// apple-ai-r1 T3 (ADR-063) — luật bảo thủ của `OCRFixApplier`: chỉ khôi phục
/// chữ in, không viết lại câu. Mọi ca ở đây test THUẦN (không gọi model).
final class OCRFixApplierTests: XCTestCase {
    func testAppliesAtEveryWholeWordOccurrence() {
        // Đủ dài để 2 từ bị đụng không vượt ngưỡng 15% (giả lập trang thật,
        // không phải mẩu text ngắn — ngưỡng tính theo TỔNG số từ trang).
        let text = "tbe cat sat on tbe mat near the old wooden door by the quiet garden wall."
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "tbe", right: "the")], to: text)
        XCTAssertEqual(
            outcome.text,
            "the cat sat on the mat near the old wooden door by the quiet garden wall.")
        XCTAssertEqual(outcome.applied, [OCRFix(wrong: "tbe", right: "the")])
        XCTAssertTrue(outcome.rejected.isEmpty)
    }

    func testWholeWordBoundaryDoesNotTouchSubstringMatches() {
        // "he" KHÔNG phải một từ riêng trong "the"/"other"/"theme" — không được đụng.
        let text = "the other theme remains."
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "he", right: "be")], to: text)
        XCTAssertEqual(outcome.text, text)
        XCTAssertEqual(outcome.rejected.map(\.reason), [.notFound])
    }

    func testAppliesEvenWhenPunctuationIsAttached() {
        let text = "Well, tbe, point still stands firmly here today."
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "tbe", right: "the")], to: text)
        XCTAssertEqual(outcome.text, "Well, the, point still stands firmly here today.")
    }

    func testNotFoundWhenWrongIsAbsent() {
        let outcome = OCRFixApplier.apply(
            [OCRFix(wrong: "correlatd", right: "correlated")], to: "correlated words")
        XCTAssertEqual(outcome.rejected.map(\.reason), [.notFound])
        XCTAssertTrue(outcome.applied.isEmpty)
    }

    func testIdenticalIsRejected() {
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "same", right: "same")], to: "the same word")
        XCTAssertEqual(outcome.rejected.map(\.reason), [.identical])
    }

    func testEmptyIsRejected() {
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "", right: "x")], to: "some text")
        XCTAssertEqual(outcome.rejected.map(\.reason), [.empty])
        let outcome2 = OCRFixApplier.apply([OCRFix(wrong: "x", right: "  ")], to: "some text x")
        XCTAssertEqual(outcome2.rejected.map(\.reason), [.empty])
    }

    func testContainsNewlineIsRejected() {
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "a\nb", right: "ab")], to: "a\nb text")
        XCTAssertEqual(outcome.rejected.map(\.reason), [.containsNewline])
    }

    func testTooManyWordsIsRejected() {
        let outcome = OCRFixApplier.apply(
            [OCRFix(wrong: "one two three four", right: "fixed")],
            to: "one two three four words")
        XCTAssertEqual(outcome.rejected.map(\.reason), [.tooManyWords])
    }

    func testWordCountChangedIsRejected() {
        // 1 từ → 3 từ, delta = 2 > 1.
        let outcome = OCRFixApplier.apply(
            [OCRFix(wrong: "cat", right: "the small cat")], to: "the cat sat")
        XCTAssertEqual(outcome.rejected.map(\.reason), [.wordCountChanged])
    }

    func testValidSplitMergeIsApplied() {
        let text = "I need some thing special today for the long trip ahead of us this week"
        let outcome = OCRFixApplier.apply(
            [OCRFix(wrong: "some thing", right: "something")], to: text)
        XCTAssertEqual(
            outcome.text,
            "I need something special today for the long trip ahead of us this week")
        XCTAssertEqual(outcome.applied, [OCRFix(wrong: "some thing", right: "something")])
    }

    func testEditTooLargeIsRejected() {
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "big", right: "large")], to: "a big dog")
        XCTAssertEqual(outcome.rejected.map(\.reason), [.editTooLarge])
    }

    func testSmallEditIsApplied() {
        let text = "a rnodern city rises above the old quiet valley today"
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "rnodern", right: "modern")], to: text)
        XCTAssertEqual(outcome.text, "a modern city rises above the old quiet valley today")
        XCTAssertEqual(outcome.applied, [OCRFix(wrong: "rnodern", right: "modern")])
    }

    func testNewlinesArePreservedAroundFixes() {
        let text = "tbe first line of the old story continues quietly\n\ntbe second paragraph begins here with more words today"
        let outcome = OCRFixApplier.apply([OCRFix(wrong: "tbe", right: "the")], to: text)
        XCTAssertEqual(
            outcome.text,
            "the first line of the old story continues quietly\n\nthe second paragraph begins here with more words today")
    }

    func testMoreThanThirtyFixesRejectsEverything() {
        let fixes = (0..<31).map { OCRFix(wrong: "w\($0)", right: "x\($0)") }
        let outcome = OCRFixApplier.apply(fixes, to: "w0 w1 some text")
        XCTAssertEqual(outcome.text, "w0 w1 some text")
        XCTAssertTrue(outcome.applied.isEmpty)
        XCTAssertTrue(outcome.rejected.allSatisfy { $0.reason == .tooMany })
        XCTAssertEqual(outcome.rejected.count, 31)
    }

    func testTouchingMoreThanFifteenPercentOfWordsRejectsEverything() {
        // 10 từ trong text, mỗi fix 1 từ — 2 fix hợp lệ chạm 2/10 = 20% > 15%.
        let text = "aaa bbb ccc ddd eee fff ggg hhh iii jjj"
        let fixes = [OCRFix(wrong: "aaa", right: "aba"), OCRFix(wrong: "bbb", right: "bcb")]
        let outcome = OCRFixApplier.apply(fixes, to: text)
        XCTAssertEqual(outcome.text, text)
        XCTAssertTrue(outcome.applied.isEmpty)
        XCTAssertTrue(outcome.rejected.allSatisfy { $0.reason == .tooMany })
    }

    func testEditDistanceBasicPairs() {
        XCTAssertEqual(OCRFixApplier.editDistance("the", "the"), 0)
        XCTAssertEqual(OCRFixApplier.editDistance("tbe", "the"), 1)
        XCTAssertEqual(OCRFixApplier.editDistance("rnodern", "modern"), 2)
        XCTAssertEqual(OCRFixApplier.editDistance("", "abc"), 3)
        XCTAssertEqual(OCRFixApplier.editDistance("abc", ""), 3)
    }
}
