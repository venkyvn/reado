#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// apple-ai-r1 T3 (ADR-061) — schema cho đề xuất sửa OCR. Key JSON = tên property
/// Swift (bẫy @Generable) nên không cần khớp wire snake_case ở đây — kết quả chỉ
/// đi qua `OCRFixApplier`, không qua `AnalysisResponseNormalizer`.
@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "OCR misreads found in text scanned from a printed English book page")
struct OCRFixList {
    @Guide(description: "Each misread found. Empty array if the text has no OCR errors.", .maximumCount(30))
    var fixes: [OCRFixItem]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct OCRFixItem {
    @Guide(description: "The misread word or short phrase, copied EXACTLY from the text — character for character")
    var wrong: String
    @Guide(description: "What the printed book most likely actually says at that spot")
    var right: String
}

/// Live `OCRCorrector`. Chỉ text (spike 2026-10-05 đo: ảnh+text chậm ~3x và
/// không tốt hơn text-only trên 4 trang thật — fen chốt bỏ nhánh ảnh).
///
/// **Bẫy đã gặp ở spike (T1):** đưa ví dụ cụ thể kiểu "rn/m, cl/d, l/I/1…" vào
/// instructions khiến model AFM (on-device) ĐỌC NHẦM các ví dụ đó thành lỗi
/// thật trên MỌI trang test (ví dụ đề xuất "cl" → "the" dù "cl" không hề xuất
/// hiện trong OCR) — model nhỏ lẫn giữa "mô tả loại lỗi" và "nội dung cần sửa".
/// Prompt dưới đây KHÔNG liệt kê cặp ký tự ví dụ, chỉ mô tả bằng lời + nhấn
/// mạnh luật "phải copy nguyên văn từ OCR_TEXT, tự kiểm tra trước khi báo".
/// `OCRFixApplier` là lưới an toàn thứ hai (editDistance/word-count/notFound).
@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsOCRCorrector: OCRCorrector {
    public init() {}

    public func proposeFixes(for text: String) async throws -> [OCRFix] {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: "OCR_TEXT:\n\(text)",
            generating: OCRFixList.self,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 600))
        return response.content.fixes.map { OCRFix(wrong: $0.wrong, right: $0.right) }
    }

    static let instructions = """
    You are proofreading OCR (optical character recognition) output from a scanned page of a
    printed English book. Your ONLY job is to find words where the OCR software misread the
    printed characters — for example two letters that look alike, a word wrongly split into two
    pieces, or two words wrongly merged into one.

    Do NOT change anything else:
    - do not change correct spelling, including British vs American spelling
    - do not change grammar, word choice, word order, or writing style
    - do not change punctuation or the capitalisation of words that are already correct
    - do not touch names or technical terms unless you are certain they are OCR noise

    Strict rules:
    1. "wrong" must be an EXACT substring of OCR_TEXT below, copied character for character.
       Before reporting a fix, check carefully that "wrong" really appears in OCR_TEXT. If it
       does not appear verbatim, do not report it.
    2. Never invent a "wrong" value just because it looks like a typical OCR mistake pattern —
       only report something you can actually point to in THIS text.
    3. Most pages have zero to five real misreads; many pages have none at all. When unsure,
       leave the word alone — it is always safer to report nothing than to guess.
    4. Report each distinct misread only once.

    These instructions contain no example misreads — never copy anything from this paragraph
    itself as if it were a finding.
    """
}
#endif
