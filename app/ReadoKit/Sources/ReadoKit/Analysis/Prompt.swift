import Foundation

/// Prompt cho FR-02 (SD 7.5: prompt sống trong ReadoKit kèm `PROMPT_VERSION`).
/// `meta.promptVersion` đi kèm mỗi `PageAnalysis` để đối chiếu chất lượng khi
/// prompt đổi (M-03) — `analysis_events` là bia mộ proxy (ADR-049), không còn
/// nơi ghi tập trung. ĐÂY LÀ BẢN DỰNG LẠI từ prompt-spec mục 3 — KHÔNG phải
/// bằng chứng A-02 (baseline owner chưa dán, rulebook mục 8). Chỉ dùng để chạy thử A-01.
public enum Prompt {
    /// Bump mỗi lần đổi prompt — app không tự suy ra, chỉ đọc `meta.promptVersion`.
    /// v5 (ADR-037): OCR (`PageOCR.linesWithBreaks`) giờ tự dò ranh giới đoạn bằng
    /// hình học (khoảng trống dọc, thụt đầu dòng, hàng ngắn kết câu) thay vì chỉ
    /// tách theo cột — `\n\n` đáng tin hơn v4, nên đổi luật từ "đoán hộ" sang
    /// "tin OCR, chỉ sửa khi rõ ràng vô lý".
    /// v6 (ADR-055, prompt-v6 T2b): dịch theo cụm/nhịp câu — bản dịch là thứ để
    /// học văn phong, không chỉ gỡ nghĩa (vision #2). Xin thêm `segments[].phrases`
    /// (cặp cụm EN↔VI đáng học, đường ống đã có từ T2a). `vocabulary` xếp theo
    /// giá trị học giảm dần — AI chỉ xếp thứ tự đề xuất, người dùng vẫn chọn/bỏ
    /// (FR-09; `ReviewDraftBuilder` preselect `preselectLimit` item đầu).
    public static let version = 6

    /// Prompt text-mode: OCR đã chạy trên máy. `source_en` phải là substring của PAGE_OCR.
    public static func text(cefrLevel: String, pageOCR: String) -> String {
        """
        Bạn là một dịch giả chuyên nghiệp, giảng tiếng Anh cho người Việt trình độ \(cefrLevel).
        Dịch theo CỤM và theo NHỊP CÂU tiếng Việt tự nhiên — không dịch word-by-word.
        Bản dịch không chỉ để gỡ nghĩa: đặt cạnh câu gốc, nó phải cho thấy một ý tiếng Anh
        được chuyển sang tiếng Việt tự nhiên thế nào, để người đọc học được cách diễn đạt.

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
           - translation_vi: dịch CẢ paragraph sang tiếng Việt dễ hiểu với trình độ \(cefrLevel),
             theo cụm/nhịp câu tự nhiên (không word-by-word). Một segment = một khối dịch
             (EN rồi VI đi cặp). Đoạn dài: vài câu Việt trong CÙNG translation_vi — không tách
             thành nhiều segment chỉ vì dài.
           - phrases: 2–6 cặp cụm {"en": "...", "vi": "..."} ĐÁNG HỌC nhất trong đoạn — cụm mà
             cách chuyển ngữ EN→VI dạy được điều gì đó (idiom, cụm động từ, cách diễn đạt khác
             cấu trúc), KHÔNG chọn từ đơn lẻ dễ. "en" phải là cụm liền, TRÍCH NGUYÊN VĂN từ
             source_en của CHÍNH segment này; "vi" là phần tương ứng TRÍCH NGUYÊN VĂN từ
             translation_vi của CHÍNH segment này — không diễn giải lại. Đoạn quá ngắn (heading,
             câu rời) hoặc không có cụm nào đáng học: để phrases rỗng [], đừng cố bịa ra.

        2. vocabulary — từ vựng và cụm từ đáng học đối với người ở trình độ \(cefrLevel), XẾP THEO
           GIÁ TRỊ HỌC GIẢM DẦN (phần tử đầu là từ đáng lưu vào bộ ôn tập nhất; đây chỉ là đề xuất
           thứ tự, người dùng vẫn tự chọn/bỏ ở màn duyệt). Bỏ qua những từ quá cơ bản so với trình
           độ đó. Mỗi phần tử gồm:
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
        {"segments":[{"source_en":"...","translation_vi":"...","phrases":[{"en":"...","vi":"..."}]}],"vocabulary":[{"term":"...","pos":"noun","ipa":"...","meaning_vi":"...","cefr":"B2","example":"..."}],"summary_vi":"..."}

        Chỉ trả về JSON object hợp lệ bắt đầu bằng { và kết thúc bằng }. Không kèm
        giải thích, markdown, code fence hay nội dung suy luận.
        """
    }
}