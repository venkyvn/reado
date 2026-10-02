import XCTest
import ReadoKit

/// prompt-v6 T3 (FR-05) — `PhraseLocator.spans` định vị cặp cụm EN↔VI thành
/// `Range<String.Index>` trên chuỗi gốc, theo luật gập của `VerifyEngine.normalize`.
final class PhraseLocatorTests: XCTestCase {

    private func segment(
        source: String, translation: String, phrases: [(String, String)]
    ) -> PageAnalysis.Segment {
        PageAnalysis.Segment(
            sourceEN: source, translationVI: translation,
            phrases: phrases.map { PageAnalysis.Phrase(en: $0.0, vi: $0.1) })
    }

    func testExactMatch() {
        let seg = segment(
            source: "Sleep is the keystone of every good routine.",
            translation: "Giấc ngủ là nền tảng của mọi thói quen tốt.",
            phrases: [("keystone of every good routine", "nền tảng của mọi thói quen tốt")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(String(seg.sourceEN[spans[0].en]), "keystone of every good routine")
        XCTAssertEqual(String(seg.translationVI[spans[0].vi]), "nền tảng của mọi thói quen tốt")
    }

    func testCaseInsensitive() {
        let seg = segment(
            source: "A resilient mind recovers quickly.",
            translation: "Một tâm trí kiên cường hồi phục nhanh.",
            phrases: [("RESILIENT MIND", "tâm trí kiên cường")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(String(seg.sourceEN[spans[0].en]), "resilient mind")
    }

    func testCurlyQuoteMatchesStraightQuoteNeedle() {
        let seg = segment(
            source: "It\u{2019}s a small win every day.",
            translation: "Đó là một chiến thắng nhỏ mỗi ngày.",
            phrases: [("it's a small win", "một chiến thắng nhỏ")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertEqual(spans.count, 1)
    }

    func testExtraWhitespaceInSourceStillMatches() {
        let seg = segment(
            source: "A phone  alarm\ncan act as a cue.",
            translation: "Một chuông điện thoại có thể làm tín hiệu gợi nhắc.",
            phrases: [("phone alarm", "chuông điện thoại")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(String(seg.sourceEN[spans[0].en]), "phone  alarm")
    }

    func testVietnameseDiacriticsAreNotFolded() {
        // "ban" (needle) không được khớp vào "bán" trong bản dịch — fold không bỏ dấu.
        let seg = segment(
            source: "She sells books every morning.",
            translation: "Cô ấy bán sách mỗi sáng.",
            phrases: [("books", "ban sách")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertTrue(spans.isEmpty)
    }

    func testWordBoundaryRequiredOnEnglishSide() {
        // "in" không khớp bên trong "within" — phải tìm lần khớp có biên từ thật (không có ở đây).
        let seg = segment(
            source: "Stay within the plan.",
            translation: "Hãy ở trong kế hoạch.",
            phrases: [("in", "trong")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertTrue(spans.isEmpty)
    }

    func testWordBoundarySkipsToNextOccurrence() {
        // "cue" khớp giữa "rescue" trước — phải bỏ qua, tìm lần khớp đứng riêng.
        let seg = segment(
            source: "A rescue plan needs a clear cue to start.",
            translation: "Một kế hoạch giải cứu cần một tín hiệu rõ ràng để bắt đầu.",
            phrases: [("cue", "tín hiệu")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(String(seg.sourceEN[spans[0].en]), "cue")
    }

    func testNotFoundIsDroppedSilently() {
        let seg = segment(
            source: "Hello world.",
            translation: "Chào thế giới.",
            phrases: [("goodbye", "tạm biệt")])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertTrue(spans.isEmpty)
    }

    func testOverlappingPhrasesLaterOneDropped() {
        let seg = segment(
            source: "Small gains compound over the years.",
            translation: "Những thành quả nhỏ cộng dồn qua nhiều năm.",
            phrases: [
                ("gains compound", "thành quả nhỏ cộng dồn"),
                ("compound over", "cộng dồn qua"),
            ])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].phraseIndex, 0)
    }

    func testEmptyPhrasesReturnsEmpty() {
        let seg = segment(source: "Hello world.", translation: "Chào thế giới.", phrases: [])
        XCTAssertTrue(PhraseLocator.spans(for: seg).isEmpty)
    }

    func testPhraseIndexKeepsOriginalOrder() {
        let seg = segment(
            source: "Sleep well and eat well.",
            translation: "Ngủ ngon và ăn ngon.",
            phrases: [
                ("eat well", "ăn ngon"),
                ("sleep well", "ngủ ngon"),
            ])
        let spans = PhraseLocator.spans(for: seg)
        XCTAssertEqual(spans.map(\.phraseIndex), [0, 1])
    }
}
