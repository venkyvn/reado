---
description: Audit docs — link/anchor hỏng, slash lệnh, protocol lệch. Không sửa trừ khi fen bảo vá.
model: haiku
---

Audit repo Reado (read-only trừ khi fen nói "vá"). Cwd = gốc repo.

1. Chạy `scripts/verify/audit.sh` (link/anchor, slash lệnh, tên lệnh cũ + dấu vết tool cũ, dòng 3 mọi plan + plan closed ngoài `done/` + plan untracked, token MASTER, index ADR, ngân sách brief/`CLAUDE.md`/journal, `test_guard.py`). Exit 1 = có PROBLEM.
2. Tóm tắt ≤ 10 dòng: số PROBLEM/WARN, từng dòng PROBLEM, orphans đáng ngờ (`node scripts/verify/check-doc-links.mjs` in mục "File mồ côi"; `plan-template` phải được `CLAUDE.md` trỏ). **Không** sửa file — fen bảo vá thì mới edit.
