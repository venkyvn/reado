import Foundation

/// Prompt cho FR-02 (SD 7.5: prompt sống trong ReadoKit kèm `PROMPT_VERSION`).
/// Proxy ghi `prompt_version` vào `analysis_events` (SD 4.1/4.3) để đối chiếu chất
/// lượng khi prompt đổi (M-03). ĐÂY LÀ BẢN DỰNG LẠI từ prompt-spec mục 3 — KHÔNG phải
/// bằng chứng A-02 (baseline owner chưa dán, rulebook mục 8). Chỉ dùng để chạy thử A-01.
public enum Prompt {
    /// Bump mỗi lần đổi prompt — proxy ghi vào analysis_events; app không tự suy ra.
    public static let version = 1

    /// Prompt text gửi kèm ảnh. CEFR chèn ở chỗ `{CEFR_LEVEL}` đúng prompt-spec mục 3.
    public static func text(cefrLevel: String) -> String {
        """
        Bạn là một dịch giả chuyên nghiệp có kiến thức sư phạm về giảng dạy tiếng Anh.

        Đầu vào là ảnh một trang văn bản tiếng Anh nguyên bản — có thể là trang sách giấy,
        bài báo mạng, hoặc tài liệu chuyên ngành. Trình độ người đọc: \(cefrLevel).

        Đọc toàn bộ văn bản trên trang và trả về JSON đúng schema được cung cấp, gồm ba phần:

        1. segments — chia văn bản thành các đoạn nhỏ theo đúng thứ tự xuất hiện trên trang.
           Mỗi đoạn gồm:
           - source_en: nguyên văn tiếng Anh, GIỮ ĐÚNG TỪNG CHỮ như trên trang. Không sửa
             lỗi, không chuẩn hoá, không lược bỏ. Đây là bản ghi của trang.
           - translation_vi: bản dịch tiếng Việt mượt mà và sát nghĩa. Ưu tiên cách diễn đạt
             tự nhiên của người Việt hơn là dịch từng chữ.

        2. vocabulary — từ vựng và cụm từ đáng học đối với người ở trình độ \(cefrLevel).
           Bỏ qua những từ quá cơ bản so với trình độ đó. Mỗi phần tử gồm:
           - term: từ hoặc cụm từ, GIỮ ĐÚNG DẠNG XUẤT HIỆN trên trang. Gặp
             "weathered the storm" thì trả về đúng vậy, không đưa về nguyên thể.
           - pos: một trong noun | verb | adj | adv | phrase | other. Không bao giờ để trống;
             không xác định được thì dùng "other".
           - ipa: phiên âm IPA của term.
           - meaning_vi: nghĩa tiếng Việt trong ĐÚNG NGỮ CẢNH của trang này. Nếu từ có nhiều
             nghĩa, chỉ trả nghĩa đang được dùng ở đây.
           - cefr: một trong A2 | B1 | B2 | C1.
           - example: câu chứa term, TRÍCH NGUYÊN VĂN từ trang. Đây là ràng buộc bắt buộc:
             không được tự đặt câu, không được sửa câu, không được ghép câu. Câu này phải
             xuất hiện y nguyên trong một phần tử source_en ở trên.

        3. summary_vi — tóm tắt ý chính của trang bằng tiếng Việt.

        Nếu một từ trên trang có hai nghĩa khác nhau ở hai chỗ khác nhau, trả về nó thành
        HAI phần tử riêng trong vocabulary, mỗi phần tử một nghĩa và một example.

        Nếu ảnh không đọc được hoặc không chứa văn bản tiếng Anh, trả về vocabulary và
        segments rỗng thay vì đoán.

        Chỉ trả về JSON hợp lệ, không kèm giải thích hay markdown.
        """
    }
}