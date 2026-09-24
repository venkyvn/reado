---
description: Audit docs — link/anchor hỏng, slash lệnh, protocol lệch. Không sửa trừ khi fen bảo vá.
---

Audit repo Reado (read-only trừ khi fen nói "vá"). Cwd = gốc repo (`CLAUDE.md` nằm đó).

1. **Link + anchor sống:** `node scripts/verify/check-doc-links.mjs`  
   Exit 1 = PROBLEMS. Journal/archive không quét (cố ý). File mồ côi = cảnh báo, không fail.
2. **Slash lệnh:** xác nhận tồn tại `.claude/commands/rstart.md`, `rplan.md`, `rhandoff.md`. Thiếu = PROBLEM.
3. **Tên lệnh cũ:** `grep -n '/reado-start\|/reado-plan\|/reado-handoff'` trên file sống (`CLAUDE.md`, `AGENTS.md`, `PROJECT.md`, `README.md`, `ROADMAP.md`, `docs/` trừ `journal/` và `archive/`, `.claude/`). Trúng = PROBLEM (đổi sang `/rstart` `/rplan` `/rhandoff`). Journal/archive giữ nguyên.
4. **Tóm tắt ≤ 10 dòng:** số PROBLEMS, orphans đáng ngờ (`plan-template` phải được CLAUDE.md trỏ), lệnh cũ, lệnh slash có đủ không. **Không** sửa file. Fen bảo vá thì mới edit.
