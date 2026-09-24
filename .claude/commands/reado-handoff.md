---
description: Đóng task Reado: verify test → hỏi approve → sửa doc → stage app+docs → commit (AGENTS.md §3)
argument-hint: "[mô tả task vừa xong]"
---

Chốt task Reado vừa xong, theo AGENTS.md §3a — kiểm từng bước, không chạy tay:

1. **Verify bằng chứng thật.** Máy build được Simulator: chạy đúng lệnh `xcodebuild` trong `CLAUDE.md` §2. Chỉ công nhận "xong" khi thấy `** TEST SUCCEEDED **`, và ghi số test + tên sim (iPhone 18 Pro). Máy không build iOS: dừng, nói blocked, không ghi "xong".
2. **Hỏi owner approve** — một câu duy nhất, kèm số test hoặc lý do chưa có test, và commit sắp tạo.
3. **Sửa doc trước khi commit.** Thay khối hiện tại của `docs/session-brief.md` §1 (không nối thêm bullet task cũ). Append 3–5 dòng `docs/journal/YYYY-MM-DD.md`. Nếu task đổi trạng thái ROADMAP/PROJECT → cập nhật (đánh ✅ kèm bằng chứng, không xoá dòng cũ).
4. **Stage** phần `app/` đã sửa cộng các doc vừa sửa ở bước 3. Docs được track từ `88eeee1` — không bỏ chúng khỏi commit.
5. **Commit** `feat(scope): tiếng Việt — tóm tắt` (+ co-authored line) chỉ sau approve.
6. **HEAD trong brief** lấy từ `git log -1 --oneline` sau commit. Nếu commit chưa chạy, ghi "HEAD xem git, đừng tin hash cứng".
7. Kết phiên — không dồn việc vào session đang phình.
