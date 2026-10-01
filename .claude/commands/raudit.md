---
description: Audit docs — link/anchor hỏng, slash lệnh, protocol lệch. Không sửa trừ khi fen bảo vá.
---

Audit repo Reado (read-only trừ khi fen nói "vá"). Cwd = gốc repo (`CLAUDE.md` nằm đó).

1. **Link + anchor sống:** `node scripts/verify/check-doc-links.mjs`  
   Exit 1 = PROBLEMS. Journal/archive không quét (cố ý). File mồ côi = cảnh báo, không fail.
2. **Slash lệnh:** xác nhận tồn tại `.claude/commands/rstart.md`, `rplan.md`, `rhandoff.md`. Thiếu = PROBLEM.
3. **Tên lệnh cũ:** `grep -n '/reado-start\|/reado-plan\|/reado-handoff'` trên file sống (`CLAUDE.md`, `README.md`, `ROADMAP.md`, `docs/` trừ `journal/`, `.claude/`). Trúng = PROBLEM (đổi sang `/rstart` `/rplan` `/rhandoff`). Journal giữ nguyên.
4. **Dấu vết tool cũ:** `grep -rniE 'dsh|deepseek|cursorignore|danger-full-access|smart_glob'` trên cùng tập file sống. Trúng = PROBLEM.
5. **Kích thước `session-brief.md` §1:** `awk '/^## 1\./{p=1} /^## 2\./{p=0} p' docs/session-brief.md | wc -c`. Vượt 4096 byte = PROBLEM (gợi ý: chuyển bullet đã khớp sang `docs/journal/`, chỉ giữ 1 dòng + con trỏ). Cũng kiểm mỗi plan ở `docs/plans/*.md` có dòng trạng thái (`> **...KHÉP...**` hoặc tương đương) ở gần đầu file không — thiếu = cảnh báo (không PROBLEM).
6. **Tóm tắt ≤ 10 dòng:** số PROBLEMS, orphans đáng ngờ (`plan-template` phải được CLAUDE.md trỏ), lệnh cũ, dấu vết tool cũ, lệnh slash có đủ không, §1 brief có vượt ngân sách không. **Không** sửa file. Fen bảo vá thì mới edit.
