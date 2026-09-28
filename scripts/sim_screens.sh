#!/usr/bin/env bash
# sim_screens.sh — cài + mở Reado trên simulator kèm dữ liệu mẫu (DEBUG only, xem
# AppModel.seedDevDemoCSVIfNeeded) và chụp màn hình light + dark để so trước/sau
# (docs/plans/visual-polish-r1.md). Không cần key nào. Ảnh ra .tmp/screens/ (ngoài git).
#
#   scripts/sim_screens.sh                 # build rồi cài + mở (giữ dữ liệu cũ)
#   scripts/sim_screens.sh --fresh         # gỡ app trước → DB mới → seed lại CSV mẫu
#   scripts/sim_screens.sh --no-build      # dùng bản build gần nhất trong DerivedData/
#   scripts/sim_screens.sh shot <tên>      # chụp <tên>-light.png + <tên>-dark.png màn hiện tại
#   scripts/sim_screens.sh size <cỡ>       # Dynamic Type: extra-extra-large | large | ... (xcrun simctl ui)
#
# Bẫy: alert xin quyền camera đã hiện một lần thì kẹt qua cả uninstall/relaunch và che
# ảnh chụp; cấp quyền sau đó không tắt được. Xử lý: `xcrun simctl shutdown <udid>` rồi
# chạy lại `--fresh` (script tự boot). Chạy `--fresh` từ đầu thì không gặp vì cấp quyền
# trước khi mở app.
#
# Quy ước tên: before-<màn> trước khi sửa, after-<màn> sau khi sửa (vd before-home).
# `shot` đổi appearance sang light rồi dark, chụp mỗi lần, trả về appearance ban đầu.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_NAME="iPhone 18 Pro"
BUNDLE_ID="${READO_BUNDLE_ID:-com.readoluca.app}"
FIXTURE="$ROOT/scripts/fixtures/demo-vocab.csv"
OUT="$ROOT/.tmp/screens"

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

case "${1:-}" in
  shot)
    NAME="${2:?Thiếu tên ảnh — vd: scripts/sim_screens.sh shot before-home}"
    mkdir -p "$OUT"
    ORIGINAL="$(xcrun simctl ui "$UDID" appearance)"
    for mode in light dark; do
      xcrun simctl ui "$UDID" appearance "$mode"
      sleep 3  # đợi UI đổi appearance xong mới chụp
      xcrun simctl io "$UDID" screenshot "$OUT/$NAME-$mode.png" >/dev/null
      echo "$OUT/$NAME-$mode.png"
    done
    xcrun simctl ui "$UDID" appearance "$ORIGINAL"
    exit 0
    ;;
  size)
    SIZE="${2:?Thiếu cỡ chữ — vd: extra-extra-large hoặc large}"
    xcrun simctl ui "$UDID" content_size "$SIZE"
    exit 0
    ;;
esac

FRESH=0
BUILD=1
for arg in "$@"; do
  case "$arg" in
    --fresh) FRESH=1 ;;
    --no-build) BUILD=0 ;;
    *) echo "Tham số lạ: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$BUILD" == 1 ]]; then
  "$ROOT/scripts/test.sh" build
fi

APP="$(find "$ROOT/DerivedData/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "Reado.app" | head -1)"
if [[ -z "$APP" ]]; then
  echo "Không thấy Reado.app đã build — chạy lại không kèm --no-build." >&2
  exit 1
fi

xcrun simctl bootstatus "$UDID" -b >/dev/null
if [[ "$FRESH" == 1 ]]; then
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
fi
xcrun simctl install "$UDID" "$APP"
# Cấp sẵn quyền để hộp thoại hệ thống không che màn khi chụp (không test luồng từ chối).
xcrun simctl privacy "$UDID" grant camera "$BUNDLE_ID" || true
xcrun simctl privacy "$UDID" grant photos "$BUNDLE_ID" || true
SIMCTL_CHILD_READO_DEV_DEMO_CSV="$FIXTURE" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
echo "Đã mở Reado trên $SIM_NAME kèm dữ liệu mẫu (36 từ, 3 bộ Demo). Điều hướng tới màn cần chụp rồi: scripts/sim_screens.sh shot before-<màn>"
