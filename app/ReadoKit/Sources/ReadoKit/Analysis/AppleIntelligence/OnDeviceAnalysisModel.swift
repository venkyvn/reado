#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// apple-ai-r1 T6 (ADR-063) — schema CHỈ cho lượt từ vựng. Nhẹ hơn nhiều so
/// với schema FR-02 đầy đủ (không `segments`/`phrases` lồng nhau) — spike T1
/// đo overhead schema ăn ~2500 token trên schema đầy đủ; schema phẳng này ít
/// field hơn hẳn nên overhead thấp hơn, cộng với `includeSchemaInPrompt:
/// false` ở lượt gọi (không nhúng schema vào prompt) để giữ dư địa cho
/// PAGE_TEXT. Field snake_case CỐ Ý (bẫy @Generable: key JSON = tên property)
/// để ráp thẳng vào wire, không qua bước đổi tên.
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AppleWireVocabItem {
    var term: String
    @Guide(.anyOf(["noun", "verb", "adj", "adv", "phrase", "other"])) var pos: String
    var ipa: String
    var meaning_vi: String
    @Guide(.anyOf(["A2", "B1", "B2", "C1"])) var cefr: String
    var example: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AppleWireVocabList {
    @Guide(.maximumCount(20)) var vocabulary: [AppleWireVocabItem]
}

/// Live `AppleAnalysisModel` — ADR-063 R1 chốt (spike T1 2026-10-05): CHỈ
/// on-device (PCC construct crash cứng, thiếu entitlement
/// `com.apple.developer.private-cloud-compute`, fen chưa bật). Mọi lượt dùng
/// String + `.permissiveContentTransformations` (guided mode luôn vỡ context
/// trên trang sách thật — đo được ở spike), TRỪ lượt từ vựng (guided, schema
/// nhẹ, cần ép đúng enum `pos`/`cefr`).
@available(iOS 26.0, macOS 26.0, *)
public struct OnDeviceAnalysisModel: AppleAnalysisModel {
    public let modelLabel = "apple-on-device"

    public init() {}

    public func translateParagraph(_ paragraph: String, cefr: String) async throws -> String {
        let session = LanguageModelSession(model: Self.permissiveModel)
        let prompt = """
        Dịch đoạn sau sang tiếng Việt tự nhiên theo cụm và nhịp câu, phù hợp người học trình độ \(cefr) \
        — không dịch word-by-word, không thêm/bớt ý. Chỉ trả về bản dịch, không giải thích thêm, không \
        lặp lại đoạn gốc, không markdown.

        \(paragraph)
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func extractVocabulary(pageText: String, cefr: String) async throws -> String {
        do {
            return try await requestVocabulary(pageText: pageText, cefr: cefr)
        } catch {
            // Lưới an toàn: trang dài sát ngưỡng vỡ context → thử lại MỘT lần
            // với bản cắt ngắn, còn hơn hỏng cả trang vì thiếu từ vựng.
            guard isContextOverflow(error), pageText.count > 2000 else { throw error }
            return try await requestVocabulary(pageText: String(pageText.prefix(2000)), cefr: cefr)
        }
    }

    private func requestVocabulary(pageText: String, cefr: String) async throws -> String {
        let session = LanguageModelSession(model: SystemLanguageModel.default)
        let prompt = """
        Chọn từ vựng và cụm từ đáng học đối với người Việt trình độ \(cefr) trong trang sách sau, XẾP \
        THEO GIÁ TRỊ HỌC GIẢM DẦN. Bỏ qua từ quá cơ bản so với trình độ đó.
        - term: giữ ĐÚNG DẠNG xuất hiện trên trang.
        - example: câu TRÍCH NGUYÊN VĂN từ PAGE_TEXT chứa term — không bịa, không chuẩn hoá.
        - Nếu một từ có hai nghĩa khác nhau, trả về hai phần tử.

        PAGE_TEXT:
        \(pageText)
        """
        let response = try await session.respond(
            to: prompt,
            generating: AppleWireVocabList.self,
            includeSchemaInPrompt: false,
            options: GenerationOptions(samplingMode: .greedy))
        let items = response.content.vocabulary.map {
            [
                "term": $0.term, "pos": $0.pos, "ipa": $0.ipa,
                "meaning_vi": $0.meaning_vi, "cefr": $0.cefr, "example": $0.example,
            ]
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: items), as: UTF8.self)
    }

    public func summarize(pageText: String, cefr: String) async throws -> String {
        let session = LanguageModelSession(model: Self.permissiveModel)
        let prompt = """
        Tóm tắt ý chính của trang sách sau bằng tiếng Việt dễ hiểu cho người trình độ \(cefr), 1–2 câu. \
        Chỉ trả về câu tóm tắt, không giải thích thêm.

        \(pageText)
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Guardrails mềm hơn cho tác vụ BIẾN ĐỔI văn bản người dùng đưa (dịch,
    /// tóm tắt) — sách thật (bạo lực, chủ đề nhạy cảm…) dễ dính guardrail mặc
    /// định. KHÔNG áp cho lượt từ vựng (guided generation không theo chế độ
    /// này — xem cheat-sheet T1).
    private static let permissiveModel = SystemLanguageModel(
        useCase: .general, guardrails: .permissiveContentTransformations)

    private func isContextOverflow(_ error: Error) -> Bool {
        if let genError = error as? LanguageModelSession.GenerationError,
           case .exceededContextWindowSize = genError
        {
            return true
        }
        if #available(iOS 27.0, macOS 27.0, *),
           let modelError = error as? LanguageModelError,
           case .contextSizeExceeded = modelError
        {
            return true
        }
        return false
    }
}
#endif
