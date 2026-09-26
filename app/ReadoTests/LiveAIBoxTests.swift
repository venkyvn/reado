import ReadoKit
import UIKit
import XCTest

/// Test opt-in, KHÔNG chạy mặc định (skip nếu thiếu env) — bằng chứng end-to-end
/// thật cho luồng OCR (Vision) → AI-Box (FR-21), khác với AnalysisTests (stub
/// URLProtocol, không đụng mạng). Chạy tay:
///
///   TEST_RUNNER_READO_LIVE_AIBOX_KEY="<key>" scripts/test.sh test \
///     -only-testing:ReadoTests/LiveAIBoxTests
///
/// `TEST_RUNNER_` là prefix xcodebuild chuyển env vào process chạy test.
/// Không bao giờ hardcode key ở đây hay commit key vào scheme.
final class LiveAIBoxTests: XCTestCase {
    func testOCRThenAIBoxProducesVocabulary() async throws {
        guard let key = ProcessInfo.processInfo.environment["READO_LIVE_AIBOX_KEY"],
              !key.isEmpty
        else {
            throw XCTSkip("Thiếu READO_LIVE_AIBOX_KEY — bỏ qua test gọi mạng thật.")
        }

        let image = Self.renderPageImage(text: Self.samplePage)
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return XCTFail("không render được ảnh test")
        }

        let client = OpenAICompatClient(
            baseURL: AnalysisAgentStore.aiboxBaseURL,
            model: AnalysisAgentStore.aiboxModel,
            agentID: "live-test",
            apiKey: key,
            ocr: PageOCR.live)

        let started = Date()
        let result = try await client.analyze(
            image: jpeg, imageMime: "image/jpeg", cefr: "B1", imageHash: "live-test")
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertFalse(result.segments.isEmpty, "OCR + AI-Box phải trả ít nhất 1 segment")
        XCTAssertFalse(result.vocabulary.isEmpty, "AI-Box phải trả ít nhất 1 từ vựng")
        // Đo thật 2026-09-26 (tắt suy nghĩ + stream): 15–18s cho trang tương tự.
        // Nới tới 60s cho test — mạng CI/máy dev chậm hơn môi trường đo.
        XCTAssertLessThan(elapsed, 60, "Quá chậm — enable_thinking có bị tắt đúng không?")
        print("LiveAIBoxTests: \(elapsed)s, \(result.vocabulary.count) từ, \(result.segments.count) đoạn")
    }

    /// Vẽ một trang text đơn giản (nền trắng, chữ đen) — đủ để Vision OCR đọc
    /// được và AI-Box có nội dung tiếng Anh thật để dịch/trích từ.
    private static func renderPageImage(text: String) -> UIImage {
        let size = CGSize(width: 1000, height: 1400)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle,
            ]
            let rect = CGRect(x: 60, y: 60, width: size.width - 120, height: size.height - 120)
            text.draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        }
    }

    private static let samplePage = """
        The old lighthouse stood on the cliff, battered by winter storms. Each \
        morning the keeper climbed its winding stairs to trim the flame, a task \
        that had shaped his life for over forty years.

        He rarely spoke to the villagers below, who regarded him with a mixture \
        of curiosity and reluctant admiration. Rumours drifted up the path like \
        fog: that he had once been a sailor, that he had lost a brother to the \
        sea.
        """
}
