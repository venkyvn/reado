#!/usr/bin/env bash
# close_plan.sh — khép một plan: dòng 3 → closed, git mv vào done/, sửa con trỏ, chạy checker link.
#   scripts/close_plan.sh <plan-id> "<tóm tắt một dòng>"
# Con trỏ được sửa ở ROADMAP.md, docs/session-brief.md, docs/qa/pending.md và các plan đang mở (không sửa journal/done).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ID="${1:?Thiếu plan-id — vd: scripts/close_plan.sh pdf-reader-r1 \"T0–T5 xong\"}"
SUMMARY="${2:?Thiếu tóm tắt một dòng}"
SRC="docs/plans/$ID.md"
DST="docs/plans/done/$ID.md"

[[ -f "$SRC" ]] || { echo "Không thấy $SRC (đã khép rồi, hoặc sai id)." >&2; exit 1; }
sed -n 3p "$SRC" | grep -q '^> \*\*Trạng thái:\*\*' || { echo "$SRC dòng 3 chưa có '> **Trạng thái:** …' — sửa tay trước." >&2; exit 1; }

TODAY="$(date +%F)"
python3 - "$SRC" "$TODAY" "$SUMMARY" <<'EOF'
import sys
path, today, summary = sys.argv[1:4]
lines = open(path, encoding="utf-8").read().split("\n")
lines[2] = f"> **Trạng thái:** closed ({today}) - {summary}"
open(path, "w", encoding="utf-8").write("\n".join(lines))
EOF

mkdir -p docs/plans/done
if git ls-files --error-unmatch "$SRC" >/dev/null 2>&1; then git mv "$SRC" "$DST"; else mv "$SRC" "$DST"; fi

python3 - "$ID" <<'EOF'
import glob, sys
pid = sys.argv[1]
old, new = f"docs/plans/{pid}.md", f"docs/plans/done/{pid}.md"
targets = ["ROADMAP.md", "docs/session-brief.md", "docs/qa/pending.md"] + glob.glob("docs/plans/*.md")
for t in targets:
    try:
        s = open(t, encoding="utf-8").read()
    except FileNotFoundError:
        continue
    if old in s:
        open(t, "w", encoding="utf-8").write(s.replace(old, new))
        print(f"sửa con trỏ: {t}")
EOF

node scripts/verify/check-doc-links.mjs >/dev/null && echo "OK: $ID đã khép → $DST (checker exit 0)" \
  || { echo "checker còn PROBLEM — chạy: node scripts/verify/check-doc-links.mjs" >&2; exit 1; }
