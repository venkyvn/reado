---
description: Bootstrap session/task Reado đúng thứ tự đọc, in trạng thái hiện tại + task tiếp theo
argument-hint: "[FR hoặc task-id — tuỳ chọn]"
---

Bootstrap một session Reado mới, đúng Turn-1 protocol (AGENTS.md §1):

1. Đọc `CLAUDE.md`.
2. Đọc `docs/session-brief.md` — chỉ §1 (tình trạng) + §2 (chờ owner).
3. Nếu có tham số `$ARGUMENTS` → `grep -n "$ARGUMENTS" ROADMAP.md`; nếu không → xác định task tiếp theo ở ROADMAP mục 3.
4. Tóm tắt cho owner ≤ 8 dòng: (a) đang ở đâu (HEAD + test xanh gần nhất), (b) task tiếp là gì, (c) chỗ nào đang chờ owner quyết định, (d) câu hỏi cần hỏi trước khi bắt đầu.
5. ĐỪNG bắt đầu code — chờ owner chọn task.