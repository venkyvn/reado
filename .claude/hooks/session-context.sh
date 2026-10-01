#!/usr/bin/env bash
# SessionStart hook — nạp trạng thái session Reado (HEAD, branch, môi trường, kết quả
# test máy sinh, plan đang open, brief §1–2) vào context tự động, khỏi cần agent tự
# đọc lại mỗi lần (CLAUDE.md §7). Mọi dòng ở đây là máy đọc/sinh ra, không viết tay.
set -euo pipefail
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

echo "## Reado — trạng thái lúc mở session"
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'không đọc được')"
echo "HEAD: $(git log -1 --oneline 2>/dev/null || echo 'không đọc được git log')"
echo
echo "5 commit gần nhất:"
git log --oneline -5 2>/dev/null || echo "không đọc được git log"

echo
if command -v xcrun >/dev/null 2>&1; then
  echo "Môi trường: Mac, build/test được."
else
  echo "Môi trường: cloud, KHÔNG build/test iOS, không ghi \"xong\" cho task cần build (CLAUDE.md §7)."
fi

CHANGES="$(git status --short 2>/dev/null | head -20 || true)"
if [[ -n "$CHANGES" ]]; then
  echo
  echo "Thay đổi chưa commit:"
  echo "$CHANGES"
fi

for name in last-summary kit-summary; do
  path=".tmp/results/${name}.txt"
  if [[ -f "$path" ]]; then
    echo
    echo "Kết quả test gần nhất ($path):"
    cat "$path"
  fi
done

OPEN_PLANS="$(grep -l '\*\*Trạng thái:\*\* open' docs/plans/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null || true)"
if [[ -n "$OPEN_PLANS" ]]; then
  echo
  echo "Plan đang open:"
  echo "$OPEN_PLANS"
fi

echo
if [[ -f docs/session-brief.md ]]; then
  SECTION12="$(awk '/^## 1\./{p=1} /^## 3\./{p=0} p' docs/session-brief.md)"
  SIZE12="$(printf '%s' "$SECTION12" | wc -c | tr -d ' ')"
  if (( SIZE12 > 8192 )); then
    echo "⚠️ docs/session-brief.md §1–2 đã ${SIZE12} byte (ngân sách ~8192) — gọn lại, chuyển nội dung khớp sang docs/journal/ (xem /raudit)."
    echo
  fi
  echo "$SECTION12"
fi
