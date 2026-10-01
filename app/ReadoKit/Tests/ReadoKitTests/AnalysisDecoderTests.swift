import Foundation
import XCTest
import ReadoKit

/// FR-02: decoder schema (prompt-spec #4), verify engine (mục 6). Chạy offline —
/// stub URLProtocol, không mạng thật.
final class AnalysisDecoderTests: XCTestCase {

    // MARK: - Decoder (FR-02: JSON đúng schema → PageAnalysis; sai → lỗi, không lưu)

    func testNormalizerKeepsPageWhenOneWordIsOff() throws {
        let raw: [String: Any] = [
            "segments": [
                ["source_en": "Hello world.", "translation_vi": "Chào thế giới."],
                ["source_en": "  ", "translation_vi": "bỏ"],
            ],
            "vocabulary": [
                [
                    "term": "world",
                    "pos": "adjective",
                    "meaning_vi": "thế giới",
                    "cefr": "B2+",
                    "example": "Hello world.",
                ],
                [
                    "term": "broken",
                    "pos": "noun",
                    "meaning_vi": " ",
                    "example": "Hello world.",
                ],
            ],
            "summary_vi": "Một lời chào.",
        ]
        let normalized = try AnalysisResponseNormalizer.normalize(AnalysisFixtures.jsonData(raw))
        let analysis = try AnalysisResponseDecoder.decode(normalized)
        XCTAssertEqual(analysis.segments.count, 1)
        XCTAssertEqual(analysis.vocabulary.count, 1)
        XCTAssertEqual(analysis.vocabulary[0].term, "world")
        XCTAssertEqual(analysis.vocabulary[0].pos, "other")
        XCTAssertNil(analysis.vocabulary[0].cefr)
    }

    func testNormalizerEmptyPageIsNotEnglish() {
        let raw: [String: Any] = [
            "segments": [],
            "vocabulary": [["term": "x", "pos": "noun", "meaning_vi": "", "example": ""]],
        ]
        XCTAssertThrowsError(try AnalysisResponseNormalizer.normalize(AnalysisFixtures.jsonData(raw))) { error in
            guard case AnalysisError.notEnglishText = error else {
                return XCTFail("mong đợi notEnglishText, nhận \(error)")
            }
        }
    }

    func testAgentKeyCheckerAccepts200AndRejects401() async {
        StubURLProtocol.handler = { request in
            let ok = request.url?.path.hasSuffix("/models") == true
                && request.value(forHTTPHeaderField: "Authorization") == "Bearer good-key"
            let status = ok ? 200 : 401
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let session = StubURLProtocol.makeSession()
        let good = await AgentKeyChecker.check(
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
            apiKey: "good-key",
            session: session)
        XCTAssertEqual(good, .valid)
        let bad = await AgentKeyChecker.check(
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
            apiKey: "bad-key",
            session: session)
        XCTAssertEqual(bad, .invalid("Key không được chấp nhận"))
    }

    func testDecoderValidResponseMapsAllThreeGroups() throws {
        let analysis = try AnalysisResponseDecoder.decode(AnalysisFixtures.jsonData(AnalysisFixtures.validResponseJSON()))
        XCTAssertEqual(analysis.segments.count, 1)
        XCTAssertEqual(analysis.segments[0].sourceEN, "The old lighthouse stood on the cliff, battered by winter storms.")
        XCTAssertEqual(analysis.vocabulary.count, 1)
        XCTAssertEqual(analysis.vocabulary[0].term, "battered")
        XCTAssertEqual(analysis.vocabulary[0].pos, "adj")
        XCTAssertEqual(analysis.vocabulary[0].cefr, "B2")
        XCTAssertEqual(analysis.summaryVI, "Mô tả ngọn hải đăng cổ trên vách đá.")
    }

    func testDecoderMissingRequiredFieldThrowsSchemaViolation() {
        var json = AnalysisFixtures.validResponseJSON()
        json.removeValue(forKey: "segments")
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(AnalysisFixtures.jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderInvalidPOSThrows() {
        var json = AnalysisFixtures.validResponseJSON()
        var vocab = (json["vocabulary"] as! [[String: Any]])[0]
        vocab["pos"] = "gerund"  // enum chỉ có noun|verb|adj|adv|phrase|other
        json["vocabulary"] = [vocab]
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(AnalysisFixtures.jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderInvalidCEFRThrows() {
        var json = AnalysisFixtures.validResponseJSON()
        var vocab = (json["vocabulary"] as! [[String: Any]])[0]
        vocab["cefr"] = "ZZ"
        json["vocabulary"] = [vocab]
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(AnalysisFixtures.jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderEmptyExampleThrows() {
        var json = AnalysisFixtures.validResponseJSON()
        var vocab = (json["vocabulary"] as! [[String: Any]])[0]
        vocab["example"] = "   "
        json["vocabulary"] = [vocab]
        XCTAssertThrowsError(try AnalysisResponseDecoder.decode(AnalysisFixtures.jsonData(json))) { error in
            guard case AnalysisError.schemaViolation = error else {
                return XCTFail("mong đợi schemaViolation, nhận \(error)")
            }
        }
    }

    func testDecoderWithoutVerificationUsesVerifyEngine() throws {
        // Proxy contract cộng thêm `verification`; decode raw không có field đó
        // → VerifyEngine đối chiếu example với segments (SD 7.3, không verify hai lần).
        let json = AnalysisFixtures.validResponseJSON()
        let bytes = try JSONSerialization.data(withJSONObject: json)
        let analysis = try AnalysisResponseDecoder.decode(bytes)
        XCTAssertEqual(analysis.vocabulary[0].verification, .verified)
    }

    // MARK: - VerifyEngine (prompt-spec mục 6)

    func testVerifyThreeBranches() throws {
        let pageText =
            "The old lighthouse stood on the cliff and weathered the winter storms bravely."
        // verified: example có thật trên trang và chứa term.
        XCTAssertEqual(
            VerifyEngine.verify(
                term: "weathered",
                example: "weathered the winter storms bravely",
                pageText: pageText),
            .verified)
        // suspect: example có thật nhưng KHÔNG chứa term.
        XCTAssertEqual(
            VerifyEngine.verify(
                term: "lighthouse",
                example: "weathered the winter storms bravely",
                pageText: pageText),
            .suspect)
        // unverified: example không xuất hiện trên trang.
        XCTAssertEqual(
            VerifyEngine.verify(
                term: "lighthouse",
                example: "a sentence invented by the AI",
                pageText: pageText),
            .unverified)
    }
}
