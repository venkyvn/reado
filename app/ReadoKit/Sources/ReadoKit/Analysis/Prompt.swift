import Foundation

/// Prompt cho FR-02 (SD 7.5: prompt sống trong ReadoKit kèm `PROMPT_VERSION`).
/// Proxy ghi `prompt_version` vào `analysis_events` (SD 4.1/4.3) để đối chiếu chất
/// lượng khi prompt đổi (M-03). ĐÂY LÀ BẢN DỰNG LẠI từ prompt-spec mục 3 — KHÔNG phải
/// bằng chứng A-02 (baseline owner chưa dán, rulebook mục 8). Chỉ dùng để chạy thử A-01.
public enum Prompt {
    /// Bump mỗi lần đổi prompt — proxy ghi vào analysis_events; app không tự suy ra.
    /// v5 (ADR-037): OCR (`PageOCR.linesWithBreaks`) giờ tự dò ranh giới đoạn bằng
    /// hình học (khoảng trống dọc, thụt đầu dòng, hàng ngắn kết câu) thay vì chỉ
    /// tách theo cột — `\n\n` đáng tin hơn v4, nên đổi luật từ "đoán hộ" sang
    /// "tin OCR, chỉ sửa khi rõ ràng vô lý".
    public static let version = 5

    /// Prompt text-mode: OCR đã chạy trên máy. `source_en` phải là substring của PAGE_OCR.
    public static func text(cefrLevel: String, pageOCR: String) -> String {
        """
        Bạn là một dịch giả chuyên nghiệp, giảng tiếng Anh cho người Việt trình độ \(cefrLevel).
        Ưu tiên bản dịch DỄ HIỂU: tiếng Việt tự nhiên, rõ ý; không dịch word-by-word.

        Đầu vào là OCR một trang (sách / báo / tài liệu), đã dò ranh giới đoạn bằng hình học
        (khoảng cách dòng, thụt đầu dòng, hàng kết câu ngắn) — không phải đoán theo nghĩa:
        - Một ký tự xuống dòng (\\n) = hết một hàng in, CÙNG một paragraph với hàng sau.
        - Hai lần xuống dòng (\\n\\n) = OCR đã xác định hết đoạn hoặc hết cột. TIN theo mặc định.
        - CHỈ bỏ qua một chỗ \\n\\n cụ thể khi nó rõ ràng vô lý (ví dụ rơi giữa câu chưa
          kết thúc) — khi đó ghép hai khối lại làm một paragraph. Không tự ý chia nhỏ
          thêm một khối chỉ vì nó dài.
        - KHÔNG tạo một segment cho mỗi hàng OCR. KHÔNG gộp cả trang thành một segment.

        PAGE_OCR:
        \(pageOCR)

        source_en và example chỉ dùng chữ có trong PAGE_OCR — không thêm, không sửa lỗi, không chuẩn hoá.
        Khi ghép hàng thành paragraph: nối bằng một space, giữ nguyên từng chữ OCR.

        Trả về JSON đúng schema, gồm ba phần:

        1. segments — mỗi phần tử = MỘT paragraph, đúng thứ tự trên trang.
           Heading, caption, hoặc câu đứng riêng có thể là segment ngắn riêng.
           Mỗi phần tử gồm:
           - source_en: nguyên văn paragraph tiếng Anh (đã ghép các hàng OCR của đoạn đó).
           - translation_vi: dịch CẢ paragraph sang tiếng Việt dễ hiểu với trình độ \(cefrLevel).
             Một segment = một khối dịch (EN rồi VI đi cặp). Đoạn dài: vài câu Việt trong CÙNG
             translation_vi — không tách thành nhiều segment chỉ vì dài.

        2. vocabulary — từ vựng và cụm từ đáng học đối với người ở trình độ \(cefrLevel).
           Bỏ qua những từ quá cơ bản so với trình độ đó. Mỗi phần tử gồm:
           - term: từ hoặc cụm từ, GIỮ ĐÚNG DẠNG XUẤT HIỆN trên trang.
           - pos: một trong noun | verb | adj | adv | phrase | other. Không bao giờ để trống;
             không xác định được thì dùng "other".
           - ipa: phiên âm IPA của term.
           - meaning_vi: nghĩa tiếng Việt dễ hiểu, ĐÚNG NGỮ CẢNH trang này — không định nghĩa từ điển khô.
           - cefr: một trong A2 | B1 | B2 | C1.
           - example: câu chứa term, TRÍCH NGUYÊN VĂN từ PAGE_OCR / source_en.

        3. summary_vi — tóm tắt ý chính của trang bằng tiếng Việt dễ hiểu.

        Nếu một từ có hai nghĩa khác nhau, trả về HAI phần tử vocabulary.

        Nếu PAGE_OCR không chứa văn bản tiếng Anh, trả về vocabulary và segments rỗng thay vì đoán.

        Output phải là đúng MỘT JSON object theo mẫu hình dạng sau:
        {"segments":[{"source_en":"...","translation_vi":"..."}],"vocabulary":[{"term":"...","pos":"noun","ipa":"...","meaning_vi":"...","cefr":"B2","example":"..."}],"summary_vi":"..."}

        Chỉ trả về JSON object hợp lệ bắt đầu bằng { và kết thúc bằng }. Không kèm
        giải thích, markdown, code fence hay nội dung suy luận.
        """
    }
}