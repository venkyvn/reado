---
description: Đóng task Reado: verify test → hỏi approve → commit + cập nhật session-brief/journal/ROADMAP (AGENTS.md §3)
argument-hint: "[mô tả task vừa xong]"
---

Chốt task Reado vừa xong, theo AGENTS.md §3a — kiểm từng bước, không chạy tay:

1. **Verify bằng chứng thật:** chạy `xcodebuild ... test` (CLAUDE.md §2). Chỉ công nhận "xong" khi thấy `** TEST SUCCEEDED **` + ghi số test + sim (iPhone 18 Pro).
2. **Hỏi owner approve** — một câu duy nhất, kèm số test + commit sắp tạo.
3. **Sau khi approve:** commit `feat(scope): tiếng Việt — tóm tắt` (+ co-authored line), chỉ stage file thuộc `app/` (docs/config không thuộc git).
4. Cập nhật `docs/session-brief.md` (§1 tình trạng + mục "đã xong" + HEAD hash) và append 3–5 dòng `docs/journal/YYYY-MM-DD.md`.
5. Nếu task đổi trạng thái ROADMAP/PROJECT → cập nhật (đánh ✅ kèm bằng chứng, không xoá dòng cũ).
6. Kết phiên — không dồn việc vào session đang phình.