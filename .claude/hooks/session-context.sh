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

# Bằng chứng test gắn với nội dung code (tree hash app/), không gắn với HEAD — scripts/lib/evidence.sh.
source scripts/lib/evidence.sh
now="$(code_tree . 2>/dev/null || echo '?')"
for name in last-summary kit-summary; do
  path=".tmp/results/${name}.txt"
  if [[ -f "$path" ]]; then
    echo
    echo "Kết quả test gần nhất ($path):"
    cat "$path"
    want="$(sed -n 's/^code: //p' "$path")"
    if [[ -z "$want" ]]; then
      echo "⚠️ summary cũ chưa có dòng code: — coi như chưa test"
    elif [[ "$want" != "$now" ]]; then
      echo "⚠️ code trong app/ đã đổi sau lần chạy này — coi như chưa test"
    fi
    grep -q '^exit: 0$' "$path" || echo "⚠️ lần chạy cuối không thành công"
  fi
done

echo
echo "Plan chưa vào done/:"
for f in docs/plans/*.md; do
  [[ -e "$f" ]] || continue
  s="$(sed -n 3p "$f")"
  [[ "$s" == '> **Trạng thái:** '* ]] || s="⚠️ thiếu/sai dòng trạng thái"
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || s="$s (untracked)"
  echo "- $(basename "$f"): $s"
done

echo
if [[ -f docs/session-brief.md ]]; then
  SECTION12="$(awk '/^## 1\./{p=1} /^## 3\./{p=0} p' docs/session-brief.md)"
  SIZE12="$(printf '%s' "$SECTION12" | wc -c | tr -d ' ')"
  if (( SIZE12 > 3072 )); then
    echo "⚠️ docs/session-brief.md §1–2 đã ${SIZE12} byte (ngân sách 3072) — gọn lại: mỗi plan một dòng ở §1, việc xem tay sang docs/qa/pending.md (xem /raudit)."
    echo
  fi
  echo "$SECTION12"
fi
