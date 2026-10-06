---
description: Bootstrap session Reado — prefix + brief + repo map; không code
argument-hint: "[FR hoặc task-id — tuỳ chọn]"
---

Bootstrap session Reado, Turn-1 (CLAUDE.md §7). **Đừng code, đừng `/rplan` hộ** — chỉ gợi.

1. `CLAUDE.md` đã ở prefix — không đọc lại nếu đã load. Câu mở: `CLAUDE.md` mục 5.
2. Brief §1–2 + HEAD đã được hook SessionStart nạp sẵn (khối `## Reado — trạng thái lúc mở session` đầu context); chỉ tự đọc `docs/session-brief.md` nếu không thấy khối đó.
3. Chạy `python3 scripts/repo_map.py` (stdout).
4. Nếu `$ARGUMENTS` → `grep -n "$ARGUMENTS" ROADMAP.md`; không thì grep ROADMAP mục 3 cho task tiếp (cấm read nguyên ROADMAP).
5. Tóm tắt ≤ 8 dòng: (a) HEAD + số test lấy từ summary hook nạp (`.tmp/results/{last,kit}-summary.txt`, kèm cảnh báo khớp/không khớp `code:` nếu hook có), không lấy từ brief, (b) task tiếp, (c) chỗ chờ fen, (d) có cần `/rplan` không (đụng hợp đồng → có; bug UI đã có FR → có thể skip).
6. Dừng. Fen chọn task rồi mới `/rplan` hoặc (đủ điều kiện CLAUDE.md §7) code.
