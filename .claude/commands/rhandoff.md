---
description: Đóng task Reado: verify → approve → docs → khép plan → commit (CLAUDE.md §7)
argument-hint: "[mô tả task vừa xong]"
---

Chốt task Reado — từng bước, không chạy tay. Không copy bảng luật cứng.

1. **Verify.** Chạy `scripts/test.sh` (background), chờ xong rồi mới đọc `.tmp/results/last-summary.txt` — không tail log lúc đang chạy; fail thì chỉ `grep -E "error:" /tmp/build.log | head`. Chỉ "xong" khi summary mới có `exit: 0` và dòng `RESULT: Passed …`; số test chính thức là dòng đó. `code:` trong summary phải khớp `app/` hiện tại (hook SessionStart/`scripts/lib/evidence.sh` so; sửa `app/` sau khi test thì chạy lại). Không chạy được simulator: blocked, không ghi xong.
1b. **Review độc lập.** Gọi subagent `reado-reviewer` (input: task-id hoặc "không plan" + diff `git diff main...HEAD` và `git diff`). P0 → sửa trước khi hỏi approve rồi chạy lại bước 1; P1/P2 → liệt kê để fen chọn sửa hay ghi nợ.
2. **Hỏi approve** — một câu, kèm số test (hoặc lý do chưa test) và commit sắp tạo.
3. **Docs trước commit** (tối thiểu — mỗi lần ghi docs là một lần có thể lệch):
   - Plan `docs/plans/<id>.md`: đánh task vừa xong + bằng chứng (lệnh, kết quả).
   - Journal `docs/journal/YYYY-MM-DD.md`: append ≤ 5 dòng.
   - `docs/session-brief.md`: chỉ sửa khi mở/khép plan hoặc khi một `OW-NN` đổi (§1 một dòng mỗi plan; §1–2 ≤ 3072 byte).
   - `ROADMAP.md`: chỉ sửa khi một FR đổi trạng thái (✅ + bằng chứng, không xoá dòng).
   - Nợ xem tay mới → thêm `- [ ] QA-NN — … · máy: sim/thật · plan: …` vào `docs/qa/pending.md`.
4. **Plan artefact.** Nếu có `docs/plans/<id>.md` cho task này: đánh task vừa xong là done. Dòng 3 luôn là `> **Trạng thái:** open | closed (YYYY-MM-DD) - <tóm tắt>`. Plan đóng hẳn → sửa thành `closed (YYYY-MM-DD) - ...` rồi `git mv docs/plans/<id>.md docs/plans/done/<id>.md` (không xoá). Sửa luôn mọi con trỏ `docs/plans/<id>.md` sang `docs/plans/done/<id>.md` ở `ROADMAP.md`/`docs/session-brief.md`/plan khác đang mở (không sửa `docs/journal/`) — kiểm bằng `scripts/verify/audit.sh` (guard cũng tự chạy nó trước mỗi `git commit` — đỏ thì commit bị chặn). Plan đóng hẳn → `scripts/close_plan.sh <id> "<tóm tắt>"` (sửa dòng 3, `git mv` vào `done/`, sửa con trỏ, chạy checker). Đừng để plan mồ côi.
5. **Stage** `app/` + docs vừa sửa (kể `docs/plans/` nếu đụng). Docs track từ `88eeee1`.
6. **Commit** `feat(scope): tiếng Việt — tóm tắt` chỉ sau approve. HEAD brief = `git log -1 --oneline` sau commit; chưa commit thì "HEAD xem git".
7. Kết phiên — không dồn task tầng 2 tiếp theo vào session đang phình.
