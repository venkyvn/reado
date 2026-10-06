#!/usr/bin/env bash
# test.sh — build/test chuẩn duy nhất của Reado (CLAUDE.md §2 + §7).
#   scripts/test.sh                                   # build + toàn bộ test (mặc định)
#   scripts/test.sh build                              # chỉ build
#   scripts/test.sh test -only-testing:ReadoTests/LeechTests
#   scripts/test.sh test-without-building              # chạy lại test, không build lại
#   scripts/test.sh kit                                # ReadoKit trên macOS — không simulator, chạy nhanh
# Log đầy đủ: /tmp/build.log (kit: /tmp/build-kit.log, build: /tmp/build-only.log)
# xcresult: .tmp/results/last.xcresult (kit: kit.xcresult, build: build.xcresult)
# Tóm tắt máy đọc: .tmp/results/last-summary.txt (kit: kit-summary.txt, build: build-summary.txt)
#   — thời điểm, HEAD, action, code (tree hash app/), RESULT, exit. Lane build không đụng last-*.
set -euo pipefail

ACTION="${1:-test}"
[[ $# -gt 0 ]] && shift

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/evidence.sh"
source "$ROOT/scripts/lib/sim.sh"

# write_summary <file> <action> <exit_code> [result_line] — thời điểm + HEAD + action + RESULT + exit.
write_summary() {
  local file="$1" action="$2" status="$3" result_line="${4:-}"
  {
    echo "time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "head: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "action: $action"
    echo "code: $(code_tree "$ROOT" 2>/dev/null || echo unknown)"
    echo "${result_line:-RESULT: n/a (không chạy test)}"
    echo "exit: $status"
  } > "$file"
}

# summarize_result <xcresult> — in "RESULT: passed x/y" + danh sách test hỏng.
summarize_result() {
  xcrun xcresulttool get test-results summary --path "$1" --compact 2>/dev/null | python3 -c '
import json, sys
try:
    s = json.load(sys.stdin)
except Exception:
    sys.exit(0)
result = s.get("result")
passed = s.get("passedTests")
total = s.get("totalTestCount")
failed = s.get("failedTests")
skipped = s.get("skippedTests")
print(f"RESULT: {result} — passed {passed}/{total}, failed {failed}, skipped {skipped}")
for f in s.get("testFailures", [])[:20]:
    ident = f.get("testIdentifierString") or f.get("testName")
    text = f.get("failureText", "")[:200]
    print(f"  x {ident}: {text}")
'
}

case "$ACTION" in
  build) TAG=build; LOG=/tmp/build-only.log ;;
  *)     TAG=last;  LOG=/tmp/build.log ;;
esac
RESULT="$ROOT/.tmp/results/$TAG.xcresult"
mkdir -p "$ROOT/.tmp/results"

# Lane nhanh: ReadoKit (logic thuần) trên macOS. Không cần simulator, không cần pbxproj check.
if [[ "$ACTION" == "kit" ]]; then
  KIT_RESULT="$ROOT/.tmp/results/kit.xcresult"
  rm -rf "$KIT_RESULT"
  cd "$ROOT/app/ReadoKit"
  set +e
  TMPDIR="$ROOT/.tmp" xcodebuild -scheme ReadoKit \
    -destination 'platform=macOS' \
    -derivedDataPath "$ROOT/DerivedData/kit" \
    -clonedSourcePackagesDirPath "$ROOT/.xcode-packages" \
    -resultBundlePath "$KIT_RESULT" \
    test "$@" > /tmp/build-kit.log 2>&1
  KIT_STATUS=$?
  set -e
  grep -E "error:|Testing failed|Executed [0-9]+ tests|\*\* (BUILD|TEST) [A-Z]+ \*\*" /tmp/build-kit.log | tail -n 40 || true
  KIT_RESULT_LINE=""
  if [[ -d "$KIT_RESULT" ]]; then
    KIT_SUMMARY_OUT="$(summarize_result "$KIT_RESULT" || true)"
    echo "$KIT_SUMMARY_OUT"
    KIT_RESULT_LINE="$(echo "$KIT_SUMMARY_OUT" | grep '^RESULT:' | head -1 || true)"
  fi
  [[ -n "$KIT_RESULT_LINE" ]] || KIT_RESULT_LINE="RESULT: n/a (build lỗi hoặc không có test result)"
  write_summary "$ROOT/.tmp/results/kit-summary.txt" "kit" "$KIT_STATUS" "$KIT_RESULT_LINE"
  exit $KIT_STATUS
fi

rm -rf "$RESULT"

# Tiền kiểm: pbxproj phải là synchronized folders (không exception set, không fileRef .swift kiểu cũ) — CLAUDE.md §7.
# pbxproj_tool.py quy ước chạy từ gốc repo (Path.cwd() cho git ls-files + tìm pbxproj).
(cd "$ROOT" && python3 scripts/pbxproj_tool.py check)

if [[ "$ACTION" != "build" ]]; then
  UDID="$(sim_udid)"
  echo "Simulator: $SIM_NAME ($UDID) — boot nếu cần…"
  sim_boot "$UDID"
  DEST="platform=iOS Simulator,id=$UDID"
else
  DEST="platform=iOS Simulator,name=$SIM_NAME"
fi

cd "$ROOT/app"
set +e
TMPDIR="$ROOT/.tmp" xcodebuild -project Reado.xcodeproj -scheme Reado \
  -destination "$DEST" \
  -derivedDataPath "$ROOT/DerivedData" \
  -clonedSourcePackagesDirPath "$ROOT/.xcode-packages" \
  -resultBundlePath "$RESULT" \
  "$ACTION" "$@" > "$LOG" 2>&1
STATUS=$?
set -e

grep -E "error:|Testing failed|Executed [0-9]+ tests|\*\* (BUILD|TEST) [A-Z]+ \*\*" "$LOG" | tail -n 40 || true

RESULT_LINE=""
if [[ "$ACTION" != "build" && -d "$RESULT" ]]; then
  SUMMARY_OUT="$(summarize_result "$RESULT" || true)"
  echo "$SUMMARY_OUT"
  RESULT_LINE="$(echo "$SUMMARY_OUT" | grep '^RESULT:' | head -1 || true)"
  [[ -n "$RESULT_LINE" ]] || RESULT_LINE="RESULT: n/a (build lỗi hoặc không có test result)"
fi
write_summary "$ROOT/.tmp/results/$TAG-summary.txt" "$ACTION" "$STATUS" "$RESULT_LINE"

exit $STATUS
