---
description: Tư vấn kỹ thuật cho một idea thô của fen. Không plan, không code. Fen không phải chuyên gia — giải thích đơn giản.
argument-hint: "[idea hoặc công nghệ fen thấy]"
model: opus
---

Fen đưa idea, **không** phải yêu cầu đã chốt. Coi mọi công nghệ / cách làm fen nhắc ("dùng X để…") là giả thuyết. **Đừng code, đừng ghi file, đừng `/rplan` hộ.**

1. **Vấn đề gốc:** idea này giải quyết vấn đề gì của Reado? Chưa rõ → hỏi fen triệu chứng thật (ví dụ, ảnh, trang nào) rồi dừng. Grep `docs/investigations/*/README.md`, `docs/decisions-log.md`, `docs/journal/` xem vấn đề này đã từng được đo / điều tra / quyết định chưa.
2. **Bằng chứng hiện có:** vấn đề lớn cỡ nào, đo bằng gì (diagnostics, test, số đo, `file:line`). Chưa có số → đề xuất cách đo rẻ nhất.
3. **≥ 3 phương án:** luôn gồm "không làm gì" và ít nhất một phương án **không** dùng công nghệ fen nhắc. Mỗi phương án: lợi ích, chi phí, rủi ro, bao nhiêu % thiết bị chạy được, có trái ADR / NG / luật cứng (`CLAUDE.md` §4) nào không.
4. **Kiểm "hype":** với công nghệ fen nhắc — chạy trên thiết bị / iOS nào, ổn định chưa (beta? API mới?), giới hạn thật (context, tốc độ, quyền, entitlement), có thêm dependency không, có trái mục "Đã chốt" ở `CLAUDE.md` §5 không.
5. **Khuyến nghị:** một hướng, kèm lý do, **tiêu chí thành công** và **tiêu chí dừng** đo được — đặt TRƯỚC khi làm.
6. Tiếng Việt đơn giản, ví dụ đời thường; thuật ngữ giữ tiếng Anh. Kết bằng **1 câu hỏi** để fen chốt hướng. Fen chốt → `/rplan` (dùng lại kết luận này ở bước 0, không đánh giá lại).
