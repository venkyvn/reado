#!/usr/bin/env bash
# test.sh — build/test chuẩn duy nhất của Reado (CLAUDE.md §2 + §7).
#   scripts/test.sh                                   # build + toàn bộ test (mặc định)
#   scripts/test.sh build                              # chỉ build
#   scripts/test.sh test -only-testing:ReadoTests/LeechTests
#   scripts/test.sh test-without-building              # chạy lại test, không build lại
#   scripts/test.sh kit                                # ReadoKit trên macOS — không simulator, chạy nhanh
# Log đầy đủ: /tmp/build.log (kit: /tmp/build-kit.log) · xcresult: .tmp/results/last.xcresult (kit: kit.xcresult)
set -euo pipefail

ACTION="${1:-test}"
[[ $# -gt 0 ]] && shift

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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

SIM_NAME="iPhone 18 Pro"
RESULT="$ROOT/.tmp/results/last.xcresult"
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
  grep -E "error:|Testing failed|Executed [0-9]+ tests|\*\* (BUILD|TEST) [A-Z]+ \*\*" /tmp/build-kit.log | tail -n 40
  [[ -d "$KIT_RESULT" ]] && summarize_result "$KIT_RESULT"
  exit $KIT_STATUS
fi

rm -rf "$RESULT"

# Tiền kiểm: test file thiếu 1 trong 4 dấu vết pbxproj sẽ bị Xcode skip ngầm (CLAUDE.md §7).
# pbxproj_tool.py quy ước chạy từ gốc repo (Path.cwd() cho git ls-files + tìm pbxproj).
(cd "$ROOT" && python3 scripts/pbxproj_tool.py check)

if [[ "$ACTION" != "build" ]]; then
  UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for runtime_devices in data["devices"].values():
    for d in runtime_devices:
        if d["name"] == name:
            print(d["udid"])
            sys.exit(0)
sys.exit("Không thấy simulator: " + name)
' "$SIM_NAME")"
  echo "Simulator: $SIM_NAME ($UDID) — boot nếu cần…"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
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
  "$ACTION" "$@" > /tmp/build.log 2>&1
STATUS=$?
set -e

grep -E "error:|Testing failed|Executed [0-9]+ tests|\*\* (BUILD|TEST) [A-Z]+ \*\*" /tmp/build.log | tail -n 40

if [[ "$ACTION" != "build" && -d "$RESULT" ]]; then
  summarize_result "$RESULT"
fi

exit $STATUS
