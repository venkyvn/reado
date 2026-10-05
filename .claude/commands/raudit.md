---
description: Audit docs — link/anchor hỏng, slash lệnh, protocol lệch. Không sửa trừ khi fen bảo vá.
---

Audit repo Reado (read-only trừ khi fen nói "vá"). Cwd = gốc repo (`CLAUDE.md` nằm đó).

1. **Link + anchor sống:** `node scripts/verify/check-doc-links.mjs`  
   Exit 1 = PROBLEMS. Journal/archive không quét (cố ý). File mồ côi = cảnh báo, không fail.
2. **Slash lệnh:** xác nhận tồn tại `.claude/commands/rstart.md`, `ridea.md`, `rplan.md`, `rhandoff.md`. Thiếu = PROBLEM.
3. **Tên lệnh cũ:** `grep -n '/reado-start\|/reado-plan\|/reado-handoff'` trên file sống (`CLAUDE.md`, `README.md`, `ROADMAP.md`, `docs/` trừ `journal/`, `.claude/`). Trúng = PROBLEM (đổi sang `/rstart` `/rplan` `/rhandoff`). Journal giữ nguyên.
4. **Dấu vết tool cũ:** `grep -rniE 'dsh|deepseek|cursorignore|danger-full-access|smart_glob'` trên cùng tập file sống. Trúng = PROBLEM.
5. **Kích thước `session-brief.md` §1–2:** `awk '/^## 1\./{p=1} /^## 3\./{p=0} p' docs/session-brief.md | wc -c`. Vượt 8192 byte = PROBLEM (gợi ý: chuyển bullet đã khớp sang `docs/journal/`, chỉ giữ 1 dòng + con trỏ). Cũng kiểm dòng 3 mỗi plan ở `docs/plans/*.md` (không `done/`) đúng dạng `> **Trạng thái:** open | closed (YYYY-MM-DD) - <tóm tắt>` — sai dạng/thiếu = cảnh báo (không PROBLEM); plan đã `closed` mà còn nằm ngoài `docs/plans/done/` = cảnh báo.
6. **Token MASTER còn trong code:** mỗi tên token/hàm mà `design-system/reado/MASTER.md` nhắc tới phải còn trong `app/` (dạng gọi hoặc dạng khai báo member). Không còn = PROBLEM: sửa MASTER theo code, rồi cập nhật dòng "Đối chiếu code lần cuối".
   Khớp nguyên từ (`-w`): `-F` trần để `Pill`/`card`/`Theme.du` lọt qua nhờ chuỗi con (`Pills`, `cardShadow`, `Theme.due`).
   ```bash
   grep -oE '(Theme|Typo|Spacing|Radius|Motion|Haptics|ShellTabBar|AppTheme)\.[A-Za-z]+|chromeGlass|cardShadow|card\(\)|revealTransition|appErrorAlert|Pill|IconTile|VocabSummary' design-system/reado/MASTER.md \
     | sort -u | while read -r t; do n="${t%()}"; grep -rqwF "$n" app/ || grep -rqE "(let|var|func|case) ${n#*.}\b" app/ || echo "PROBLEM: MASTER nhắc $t, không còn trong app/"; done
   ```
7. **Tóm tắt ≤ 10 dòng:** số PROBLEMS, orphans đáng ngờ (`plan-template` phải được CLAUDE.md trỏ), lệnh cũ, dấu vết tool cũ, lệnh slash có đủ không, §1 brief có vượt ngân sách không, token MASTER mất. **Không** sửa file. Fen bảo vá thì mới edit.
