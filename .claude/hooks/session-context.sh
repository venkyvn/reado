#!/usr/bin/env bash
# SessionStart hook — nạp trạng thái session Reado (HEAD, thay đổi dở, brief §1–2)
# vào context tự động, khỏi cần agent tự đọc lại mỗi lần (CLAUDE.md §7).
set -euo pipefail
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

echo "## Reado — trạng thái lúc mở session"
echo "HEAD: $(git log -1 --oneline 2>/dev/null || echo 'không đọc được git log')"

CHANGES="$(git status --short 2>/dev/null | head -20 || true)"
if [[ -n "$CHANGES" ]]; then
  echo "Thay đổi chưa commit:"
  echo "$CHANGES"
fi

echo
if [[ -f docs/session-brief.md ]]; then
  SECTION1="$(awk '/^## 1\./{p=1} /^## 2\./{p=0} p' docs/session-brief.md)"
  SIZE1="$(printf '%s' "$SECTION1" | wc -c | tr -d ' ')"
  if (( SIZE1 > 4096 )); then
    echo "⚠️ docs/session-brief.md §1 đã ${SIZE1} byte (ngân sách ~4096) — gọn lại, chuyển nội dung khớp sang docs/journal/ (xem /raudit)."
    echo
  fi
  awk '/^## 1\./{p=1} /^## 3\./{p=0} p' docs/session-brief.md
fi
