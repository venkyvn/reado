/**
 * ai/prompt.ts — prompt là SẢN PHẨM (prompt-spec mục 1), không phải chi tiết
 * triển khai. Bản dưới là prompt-spec mục 3 (bản dựng lại, đã chạy thật Phase 0
 * đạt A-01), thay {CEFR_LEVEL}. Phiên bản đi cùng git để truy "đợt kết quả này
 * do prompt nào sinh ra" khi đo M-03.
 */
import type { Cefr } from "../domain/types"

export const PROMPT_VERSION = 2 // v2 (2026-09-09): thêm tags/synonyms/antonyms — task 3.12

export function buildPrompt(cefrLevel: Cefr): string {
  return `Bạn là một dịch giả chuyên nghiệp có kiến thức sư phạm về giảng dạy tiếng Anh.

Đầu vào là ảnh một trang văn bản tiếng Anh nguyên bản — có thể là trang sách giấy,
bài báo mạng, hoặc tài liệu chuyên ngành. Trình độ người đọc: ${cefrLevel}.

Đọc toàn bộ văn bản trên trang và trả về JSON đúng schema được cung cấp, gồm ba phần:

1. segments — chia văn bản thành các đoạn nhỏ theo đúng thứ tự xuất hiện trên trang.
   Mỗi đoạn gồm:
   - source_en: nguyên văn tiếng Anh, GIỮ ĐÚNG TỪNG CHỮ như trên trang. Không sửa
     lỗi, không chuẩn hoá, không lược bỏ. Đây là bản ghi của trang.
   - translation_vi: bản dịch tiếng Việt mượt mà và sát nghĩa. Ưu tiên cách diễn đạt
     tự nhiên của người Việt hơn là dịch từng chữ.

2. vocabulary — từ vựng và cụm từ đáng học đối với người ở trình độ ${cefrLevel}.
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

     BA field bổ trợ sau đây là KHÔNG BẮT BUỘC — thiếu field nào cũng được chấp nhận:
   - tags: tối đa 4 chủ đề ngắn của từ (1–2 từ mỗi tag, viết thường), ví dụ
     "business", "technology", "idiom". Chỉ gắn tag khi thực sự rõ chủ đề; các
     tag nên tái sử dụng nhãn ngắn gọn, không bịa tag mơ hồ.
   - synonyms: tối đa 3 từ/cụm đồng nghĩa THẬT với nghĩa đang dùng, đúng từ loại.
   - antonyms: tối đa 3 từ/cụm trái nghĩa THẬT, đúng từ loại.
     Không có từ phù hợp thì bỏ trống mảng ([]) hoặc bỏ field — đừng điền cho có.

3. summary_vi — tóm tắt ý chính của trang bằng tiếng Việt.

Nếu một từ trên trang có hai nghĩa khác nhau ở hai chỗ khác nhau, trả về nó thành
HAI phần tử riêng trong vocabulary, mỗi phần tử một nghĩa và một example.

Nếu ảnh không đọc được hoặc không chứa văn bản tiếng Anh, trả về vocabulary và
segments rỗng thay vì đoán.`
}
