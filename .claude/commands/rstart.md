---
description: Bootstrap session Reado — prefix + brief + repo map; không code
argument-hint: "[FR hoặc task-id — tuỳ chọn]"
---

Bootstrap session Reado, Turn-1 (AGENTS.md §0–§1). **Đừng code, đừng `/rplan` hộ** — chỉ gợi.

1. `CLAUDE.md` đã ở prefix — không đọc lại nếu đã load. Câu mở: `CLAUDE.md` mục 5.
2. Đọc `docs/session-brief.md` §1–3.
3. Chạy `python3 scripts/repo_map.py` (stdout). Cấm `glob **/*.swift`.
4. Nếu `$ARGUMENTS` → `grep -n "$ARGUMENTS" ROADMAP.md`; không thì grep ROADMAP mục 3 cho task tiếp (cấm read nguyên ROADMAP).
5. Tóm tắt ≤ 8 dòng: (a) HEAD + test từ brief, (b) task tiếp, (c) chỗ chờ fen, (d) có cần `/rplan` không (đụng hợp đồng → có; bug UI đã có FR → có thể skip).
6. Dừng. Fen chọn task rồi mới `/rplan` hoặc (đủ điều kiện AGENTS.md §1) code.
