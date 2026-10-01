import ReadoKit
import XCTest

/// reencounter-r1 T1 (FR-22) — `EncounterMatcher` là hàm thuần → lane `kit`.
final class EncounterMatcherTests: XCTestCase {

    private func entry(_ term: String, id: String? = nil) -> EncounterLexiconEntry {
        EncounterLexiconEntry(
            vocabItemID: id ?? "id-\(term)", term: term, pos: "noun", ipa: nil,
            meaningVI: "nghĩa", collectionID: "c1", collectionName: "Sách A")
    }

    private func found(_ terms: [String], in text: String) -> [String] {
        let matcher = EncounterMatcher(lexicon: terms.map { entry($0) })
        return matcher.matches(in: text).map { String(text[$0.range]) }
    }

    func testMatchesSingleWordCaseInsensitiveKeepingOriginalText() {
        XCTAssertEqual(found(["serendipity"], in: "What a Serendipity it was."), ["Serendipity"])
    }

    func testWordBoundaryNoMatchInsideLongerWord() {
        XCTAssertEqual(found(["cat"], in: "A category of cat."), ["cat"])
        XCTAssertEqual(found(["cat"], in: "Concatenate the catalog."), [])
    }

    func testNoLemmatize() {
        XCTAssertEqual(found(["run"], in: "He runs and ran, running daily."), [])
    }

    func testPhraseMatchesAcrossWhitespaceIncludingNewline() {
        XCTAssertEqual(found(["take off"], in: "The plane will take off soon."), ["take off"])
        XCTAssertEqual(found(["take off"], in: "The plane will take\noff soon."), ["take\noff"])
    }

    func testPunctuationBreaksPhrase() {
        XCTAssertEqual(found(["take off"], in: "Please take, off the lid."), [])
        XCTAssertEqual(found(["take off"], in: "Please take. Off we go."), [])
    }

    func testLongerPhraseWinsOverlappingShorterOne() {
        // "a b" bắt đầu trước nhưng "b c d" dài hơn và chồng lên → cụm dài thắng.
        XCTAssertEqual(found(["a b", "b c d"], in: "x a b c d y"), ["b c d"])
    }

    func testPhraseBeatsItsOwnWord() {
        XCTAssertEqual(found(["take", "take off"], in: "take off now"), ["take off"])
        XCTAssertEqual(found(["take", "take off"], in: "take it"), ["take"])
    }

    func testNonOverlappingMatchesAreAllReturnedInTextOrder() {
        XCTAssertEqual(
            found(["beta", "alpha"], in: "alpha then beta then alpha again"),
            ["alpha", "beta", "alpha"])
    }

    func testHyphenatedWordIsOneToken() {
        XCTAssertEqual(found(["well-known"], in: "A well-known fact."), ["well-known"])
        XCTAssertEqual(found(["known"], in: "A well-known fact."), [],
                       "`known` không khớp bên trong `well-known`")
    }

    func testPossessiveSuffixIsABoundaryNotPartOfTheWord() {
        let text = "The author's book"
        let matcher = EncounterMatcher(lexicon: [entry("author")])
        let matches = matcher.matches(in: text)
        XCTAssertEqual(matches.map { String(text[$0.range]) }, ["author"])
    }

    func testPossessiveDoesNotCreateStrayWordS() {
        XCTAssertEqual(found(["s"], in: "The author's book"), [])
    }

    func testApostropheInsideWordAndCurlyApostrophe() {
        XCTAssertEqual(found(["don't"], in: "Don’t go."), ["Don’t"])
        XCTAssertEqual(found(["o'clock"], in: "At five o'clock."), ["o'clock"])
    }

    func testSameTermManyRowsGivesOneMatchWithAllEntriesInLexiconOrder() {
        let lexicon = [entry("bank", id: "b1"), entry("bank", id: "b2"), entry("river", id: "r1")]
        let matcher = EncounterMatcher(lexicon: lexicon)
        let matches = matcher.matches(in: "The bank by the river.")
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].entries.map(\.vocabItemID), ["b1", "b2"])
        XCTAssertEqual(matches[0].tokenCount, 1)
    }

    func testTokenCountForPhrase() {
        let matcher = EncounterMatcher(lexicon: [entry("take off")])
        XCTAssertEqual(matcher.matches(in: "take off")[0].tokenCount, 2)
    }

    func testEmptyInputs() {
        XCTAssertTrue(EncounterMatcher(lexicon: []).isEmpty)
        XCTAssertEqual(EncounterMatcher(lexicon: []).matches(in: "anything"), [])
        XCTAssertEqual(found(["alpha"], in: ""), [])
        XCTAssertEqual(found(["alpha"], in: "   ...  "), [])
    }

    func testUnicodeLettersAreWordCharacters() {
        XCTAssertEqual(found(["café"], in: "A café nearby."), ["café"])
    }

    // MARK: — vocabItemIDs (ghi `seen` khi lưu trang)

    func testVocabItemIDsAreUniqueInFirstSeenOrderAcrossTexts() {
        let matcher = EncounterMatcher(lexicon: [
            entry("alpha", id: "a"), entry("beta", id: "b"), entry("gamma", id: "g"),
        ])
        let ids = matcher.vocabItemIDs(in: [
            "beta, then alpha and beta again.", "Alpha once more. Delta is unknown.",
        ])
        XCTAssertEqual(ids, ["b", "a"])
    }

    func testVocabItemIDsIncludeEveryRowOfAMultiRowTerm() {
        let matcher = EncounterMatcher(lexicon: [
            entry("bank", id: "b1"), entry("bank", id: "b2"),
        ])
        XCTAssertEqual(matcher.vocabItemIDs(in: ["The bank."]), ["b1", "b2"])
    }

    func testVocabItemIDsEmptyWhenNothingMatches() {
        let matcher = EncounterMatcher(lexicon: [entry("alpha", id: "a")])
        XCTAssertEqual(matcher.vocabItemIDs(in: ["nothing here", ""]), [])
        XCTAssertEqual(matcher.vocabItemIDs(in: []), [])
    }
}
