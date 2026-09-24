---
description: Đóng task Reado: verify → approve → docs → khép plan → commit (AGENTS.md §3)
argument-hint: "[mô tả task vừa xong]"
---

Chốt task Reado, AGENTS.md §3a — từng bước, không chạy tay. Không copy bảng luật cứng.

1. **Verify.** Máy có Simulator: `xcodebuild` đúng `CLAUDE.md` §2. Chỉ "xong" khi `** TEST SUCCEEDED **` + số test + iPhone 18 Pro. Máy không build iOS: blocked, không ghi xong.
2. **Hỏi approve** — một câu, kèm số test (hoặc lý do chưa test) và commit sắp tạo.
3. **Docs trước commit.** Thay `docs/session-brief.md` §1 (không nối bullet cũ). Append 3–5 dòng `docs/journal/YYYY-MM-DD.md`. ROADMAP/PROJECT nếu đổi trạng thái (✅ + bằng chứng, không xoá dòng).
4. **Plan artefact.** Nếu có `docs/plans/<id>.md` cho task này: đánh task vừa xong là done, hoặc xoá file khi cả plan đóng. Đừng để plan mồ côi.
5. **Stage** `app/` + docs vừa sửa (kể `docs/plans/` nếu đụng). Docs track từ `88eeee1`.
6. **Commit** `feat(scope): tiếng Việt — tóm tắt` chỉ sau approve. HEAD brief = `git log -1 --oneline` sau commit; chưa commit thì "HEAD xem git".
7. Kết phiên — không dồn task tầng 2 tiếp theo vào session đang phình.
