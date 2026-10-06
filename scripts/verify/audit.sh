#!/usr/bin/env bash
# audit.sh — kiểm docs/workflow mà máy kiểm được (thay pipeline viết tay của /raudit). Read-only.
#   scripts/verify/audit.sh        # in PROBLEM:/WARN: từng dòng + một dòng tổng kết; exit 1 nếu có PROBLEM
# guard.py chạy script này trước mỗi `git commit` — exit 1 thì commit bị chặn.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PROBLEMS=0
WARNS=0
problem() { echo "PROBLEM: $*"; PROBLEMS=$((PROBLEMS + 1)); }
warn() { echo "WARN: $*"; WARNS=$((WARNS + 1)); }

# 1. Link + anchor sống (journal/archive không quét — cố ý).
if command -v node >/dev/null 2>&1; then
  if ! node scripts/verify/check-doc-links.mjs >/tmp/audit-links.out 2>&1; then
    problem "check-doc-links.mjs exit khác 0 — $(grep -c '^ •' /tmp/audit-links.out) mục (xem: node scripts/verify/check-doc-links.mjs)"
  fi
else
  warn "không có node — bỏ qua check-doc-links.mjs"
fi

# 2. Slash lệnh còn đủ.
for c in rstart ridea rplan rhandoff; do
  [[ -f ".claude/commands/$c.md" ]] || problem "thiếu .claude/commands/$c.md"
done

# 3–4. Tên lệnh cũ + dấu vết tool cũ trên file sống (docs/ trừ journal, plan đã đóng, ADR bất biến).
LIVE=(CLAUDE.md README.md ROADMAP.md docs app/ReadoKit/CLAUDE.md)
EXCL=(--exclude-dir=journal --exclude-dir=done --exclude-dir=investigations --exclude=decisions-log.md --exclude=workflow-docs-r1.md)
if grep -rnE '/reado-start|/reado-plan|/reado-handoff' "${EXCL[@]}" "${LIVE[@]}" >/tmp/audit-old.out 2>/dev/null; then
  problem "tên lệnh cũ (đổi sang /rstart /rplan /rhandoff): $(head -1 /tmp/audit-old.out | cut -c1-120)"
fi
if grep -rniE 'dsh|deepseek|cursorignore|danger-full-access|smart_glob' "${EXCL[@]}" "${LIVE[@]}" >/tmp/audit-old.out 2>/dev/null; then
  problem "dấu vết tool cũ: $(head -1 /tmp/audit-old.out | cut -c1-120)"
fi

# 5. Plan: dòng 3, closed ngoài done/, untracked.
PLAN_RE='^> \*\*Trạng thái:\*\* (open|closed) \([0-9]{4}-[0-9]{2}-[0-9]{2}\) - .+'
for f in docs/plans/*.md; do
  [[ -e "$f" ]] || continue
  s="$(sed -n 3p "$f")"
  if ! echo "$s" | grep -qE "$PLAN_RE"; then
    problem "$f dòng 3 sai/thiếu dạng '> **Trạng thái:** open|closed (YYYY-MM-DD) - …'"
  elif echo "$s" | grep -q '^> \*\*Trạng thái:\*\* closed'; then
    problem "$f đã closed mà còn ngoài docs/plans/done/ (dùng scripts/close_plan.sh)"
  fi
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || git diff --cached --name-only | grep -qx "$f" \
    || problem "$f chưa vào git (untracked)"
done
for f in docs/plans/done/*.md; do
  [[ -e "$f" ]] || continue
  sed -n 3p "$f" | grep -q '^> \*\*Trạng thái:\*\* open' && warn "$f nằm trong done/ nhưng dòng 3 còn 'open'"
done

# 6. Token MASTER còn trong code (khớp nguyên từ -w). Chỉ quét thư mục source — app/ReadoKit/.build rất lớn.
SRC=(app/Reado app/ReadoKit/Sources app/ReadoTests)
while read -r t; do
  n="${t%()}"
  grep -rqwF --include='*.swift' "$n" "${SRC[@]}" || grep -rqE --include='*.swift' "(let|var|func|case) ${n#*.}\b" "${SRC[@]}" || problem "MASTER nhắc $t, không còn trong code Swift"
done < <(grep -oE '(Theme|Typo|Spacing|Radius|Motion|Haptics|ShellTabBar|AppTheme)\.[A-Za-z]+|chromeGlass|cardShadow|card\(\)|revealTransition|appErrorAlert|Pill|IconTile|VocabSummary' design-system/reado/MASTER.md | sort -u)

# 7. Index ADR đủ; ADR-NEW- chỉ ở nhánh.
for n in $(grep -oE '^## ADR-[0-9]+' docs/decisions-log.md | grep -oE '[0-9]+'); do
  grep -qE "^\| $n \|" docs/decisions-log.md || problem "ADR-$n chưa có trong index đầu docs/decisions-log.md"
done
if [[ "$(git branch --show-current 2>/dev/null)" == "main" ]] && grep -qE '^## ADR-NEW-[a-z0-9]' docs/decisions-log.md; then
  warn "còn ADR-NEW-<slug> trên main — đánh số thật + cập nhật index"
fi

# 8. Ngân sách.
SIZE12="$(awk '/^## 1\./{p=1} /^## 3\./{p=0} p' docs/session-brief.md | wc -c | tr -d ' ')"
(( SIZE12 > 3072 )) && problem "docs/session-brief.md §1–2 ${SIZE12} byte (ngân sách 3072)"
CSIZE="$(wc -c < CLAUDE.md | tr -d ' ')"
(( CSIZE > 7500 )) && warn "CLAUDE.md ${CSIZE} byte (> 7500) — gọn lại, đừng thêm 'Chốt thêm…' vào đó"
J="docs/journal/$(date +%F).md"
if [[ -f "$J" ]]; then
  JL="$(wc -l < "$J" | tr -d ' ')"
  (( JL > 8 )) && warn "$J ${JL} dòng (/rhandoff dặn ≤ 5 dòng mỗi task)"
fi

# 9. guard.py còn đúng bảng case. READO_SKIP_COMMIT_AUDIT chặn đệ quy (guard chạy audit ở mỗi git commit).
if ! READO_SKIP_COMMIT_AUDIT=1 python3 scripts/verify/test_guard.py >/tmp/audit-guard.out 2>&1; then
  problem "scripts/verify/test_guard.py fail — $(grep -c '^LỆCH' /tmp/audit-guard.out) case lệch"
fi

echo "audit: ${PROBLEMS} PROBLEM, ${WARNS} WARN"
(( PROBLEMS == 0 ))
