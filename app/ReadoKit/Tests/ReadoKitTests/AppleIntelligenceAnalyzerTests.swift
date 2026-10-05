import Foundation
import ReadoKit
import XCTest

#if canImport(FoundationModels)
import FoundationModels
#endif

private struct FakeAppleModel: AppleAnalysisModel {
    let modelLabel = "fake-apple"
    var translateResult: Result<String, Error> = .success("bản dịch")
    var vocabularyResult: Result<String, Error> = .success("[]")
    var summaryResult: Result<String, Error> = .success("tóm tắt")
    let counter: AttemptCounter?

    func translateParagraph(_ paragraph: String, cefr: String) async throws -> String {
        counter?.increment()
        return try translateResult.get()
    }

    func extractVocabulary(pageText: String, cefr: String) async throws -> String {
        try vocabularyResult.get()
    }

    func summarize(pageText: String, cefr: String) async throws -> String {
        try summaryResult.get()
    }
}

private struct ThrowingAppleModel: AppleAnalysisModel {
    let modelLabel = "fake-apple"
    let error: Error

    func translateParagraph(_ paragraph: String, cefr: String) async throws -> String {
        throw error
    }

    func extractVocabulary(pageText: String, cefr: String) async throws -> String {
        throw error
    }

    func summarize(pageText: String, cefr: String) async throws -> String {
        throw error
    }
}

final class AppleIntelligenceAnalyzerTests: AnalysisNetworkTestCase {
    private func validVocabularyJSON() -> String {
        """
        [{"term":"battered","pos":"adj","ipa":"/ˈbætərd/","meaning_vi":"dày vò","cefr":"B2","example":"The old lighthouse stood on the cliff, battered by winter storms."}]
        """
    }

    func testAnalyzeAssemblesSegmentsVocabularySummary() async throws {
        let model = FakeAppleModel(
            translateResult: .success("Ngọn hải đăng cũ."),
            vocabularyResult: .success(validVocabularyJSON()),
            summaryResult: .success("Một ngọn hải đăng."),
            counter: nil)
        let analyzer = AppleIntelligenceAnalyzer(
            model: model, status: { .available },
            ocr: FixedPageOCR(text: "The old lighthouse stood on the cliff, battered by winter storms."))
        let result = try await analyzer.analyze(
            image: Data([0x01]), imageMime: "image/jpeg", cefr: "B2", imageHash: "h1")
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments[0].translationVI, "Ngọn hải đăng cũ.")
        XCTAssertEqual(result.vocabulary.map(\.term), ["battered"])
        XCTAssertEqual(result.summaryVI, "Một ngọn hải đăng.")
        XCTAssertEqual(result.meta.model, "fake-apple")
        XCTAssertEqual(result.meta.imageHash, "h1")
        XCTAssertEqual(result.meta.promptVersion, Prompt.version)
    }

    func testAnalyzeTextUsesPdfVersionAndSkipsOCR() async throws {
        let model = FakeAppleModel(counter: nil)
        let analyzer = AppleIntelligenceAnalyzer(
            model: model, status: { .available }, ocr: FailingPageOCR())
        let result = try await analyzer.analyzeText("Some page text.", cefr: "B2", sourceHash: "h2")
        XCTAssertEqual(result.meta.promptVersion, Prompt.pdfVersion)
        XCTAssertEqual(result.meta.imageHash, "h2")
    }

    func testMultipleParagraphsSplitOnDoubleNewline() async throws {
        let model = FakeAppleModel(translateResult: .success("dịch"), counter: nil)
        let analyzer = AppleIntelligenceAnalyzer(
            model: model, status: { .available },
            ocr: FixedPageOCR(text: "Para one line a\nline b\n\nPara two."))
        let result = try await analyzer.analyze(
            image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].sourceEN, "Para one line a line b")
        XCTAssertEqual(result.segments[1].sourceEN, "Para two.")
    }

    func testStatusUnavailableThrowsProviderErrorAndSkipsModel() async {
        let counter = AttemptCounter()
        let model = FakeAppleModel(counter: counter)
        let analyzer = AppleIntelligenceAnalyzer(
            model: model, status: { .unavailable(.notEnabled) },
            ocr: FixedPageOCR(text: "text"))
        do {
            _ = try await analyzer.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi providerError")
        } catch {
            guard case let AnalysisError.providerError(message) = error else {
                return XCTFail("mong đợi providerError, nhận \(error)")
            }
            XCTAssertTrue(message.contains("Chưa bật"))
        }
        XCTAssertEqual(counter.value, 0)
    }

    func testEmptyOCRThrowsImageUnreadable() async {
        let model = FakeAppleModel(counter: nil)
        let analyzer = AppleIntelligenceAnalyzer(
            model: model, status: { .available }, ocr: FixedPageOCR(text: "   "))
        do {
            _ = try await analyzer.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi imageUnreadable")
        } catch {
            guard case AnalysisError.imageUnreadable = error else {
                return XCTFail("mong đợi imageUnreadable, nhận \(error)")
            }
        }
    }

    func testModelErrorIsMappedThroughErrorMapper() async {
        let analyzer = AppleIntelligenceAnalyzer(
            model: ThrowingAppleModel(error: TimeoutError()), status: { .available },
            ocr: FixedPageOCR(text: "text"))
        do {
            _ = try await analyzer.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi lỗi")
        } catch {
            guard case AnalysisError.networkError = error else {
                return XCTFail("mong đợi networkError, nhận \(error)")
            }
        }
    }
}

/// apple-ai-r1 T6 — test mapper trực tiếp (không qua analyzer) cho các case
/// dựng được bằng init public. Case nào init không public (phần lớn lỗi
/// FoundationModels khác) thì KHÔNG test trực tiếp ở đây — đã mirror đúng tên
/// case theo swiftinterface thật (xem file mapper), tin vào compile-time
/// exhaustiveness (switch không có `default` cho các case chính).
final class AppleIntelligenceErrorMapperTests: XCTestCase {
    func testTimeoutErrorMapsToNetworkError() {
        guard case .networkError = AppleIntelligenceErrorMapper.map(TimeoutError()) else {
            return XCTFail("mong đợi networkError")
        }
    }

    func testAnalysisErrorPassesThrough() {
        let original = AnalysisError.notEnglishText
        guard case .notEnglishText = AppleIntelligenceErrorMapper.map(original) else {
            return XCTFail("mong đợi giữ nguyên AnalysisError")
        }
    }

    func testUnknownErrorBecomesProviderError() {
        struct Boom: Error {}
        guard case .providerError = AppleIntelligenceErrorMapper.map(Boom()) else {
            return XCTFail("mong đợi providerError")
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 27.0, macOS 27.0, *)
    func testLanguageModelErrorContextSizeExceededMapsToProviderError() throws {
        let error = LanguageModelError.contextSizeExceeded(
            .init(contextSize: 4096, tokenCount: 5000, debugDescription: "quá dài"))
        guard case .providerError = AppleIntelligenceErrorMapper.map(error) else {
            return XCTFail("mong đợi providerError")
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    func testGenerationErrorExceededContextWindowMapsToProviderError() throws {
        let error = LanguageModelSession.GenerationError.exceededContextWindowSize(
            .init(debugDescription: "quá dài"))
        guard case .providerError = AppleIntelligenceErrorMapper.map(error) else {
            return XCTFail("mong đợi providerError")
        }
    }
    #endif
}
