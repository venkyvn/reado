import Foundation

/// apple-ai-r1 T6 (ADR-063) — seam cho test; live là `OnDeviceAnalysisModel`.
/// Ba primitive khớp đúng pipeline "chia nhỏ" (T1 spike 2026-10-05 chốt: một
/// lượt cho cả trang luôn vỡ context 4096 token trên on-device, chia nhỏ mới
/// chạy được). `AppleIntelligenceAnalyzer` lo việc tách đoạn + ráp lại thành
/// wire JSON {segments, vocabulary, summary_vi} rồi đi qua
/// `AnalysisResponseNormalizer`/`AnalysisResponseDecoder` CHUNG với BYOK.
public protocol AppleAnalysisModel: Sendable {
    /// Ghi vào `meta.model` (giống `OpenAICompatClient` ghi tên model BYOK).
    var modelLabel: String { get }

    /// Dịch MỘT đoạn (paragraph) sang tiếng Việt tự nhiên theo cụm/nhịp câu.
    func translateParagraph(_ paragraph: String, cefr: String) async throws -> String

    /// Từ vựng đáng học của CẢ TRANG — trả JSON string dạng mảng object
    /// `{"term","pos","ipa","meaning_vi","cefr","example"}` (snake_case, khớp
    /// trực tiếp key wire — `AppleIntelligenceAnalyzer` ráp thẳng vào
    /// `vocabulary`, không đổi tên field).
    func extractVocabulary(pageText: String, cefr: String) async throws -> String

    /// Tóm tắt ý chính cả trang, tiếng Việt, 1–2 câu.
    func summarize(pageText: String, cefr: String) async throws -> String
}
