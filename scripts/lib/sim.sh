# sim.sh — simulator dùng chung cho test.sh, sim_screens.sh, sim_aibox.sh. Chỉ source, không chạy trực tiếp.
# Cần ROOT (gốc repo) đã được set trước khi gọi các hàm app_path/sim_shot.

SIM_NAME="${SIM_NAME:-iPhone Air}"
# com.reado.app đã bị trùng khi ký máy thật → fen đổi sang com.readoluca.app.
BUNDLE_ID="${READO_BUNDLE_ID:-com.readoluca.app}"

# sim_udid — in UDID của $SIM_NAME; lỗi (exit khác 0) nếu không có.
sim_udid() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for runtime_devices in data["devices"].values():
    for d in runtime_devices:
        if d["name"] == name:
            print(d["udid"])
            sys.exit(0)
sys.exit("Không thấy simulator: " + name)
' "$SIM_NAME"
}

# sim_boot <udid> — boot nếu cần, đợi xong (tránh xcodebuild treo vì simulator Shutdown).
sim_boot() { xcrun simctl bootstatus "$1" -b >/dev/null; }

# app_path — in đường dẫn Reado.app đã build; exit 1 nếu chưa có.
app_path() {
  local app
  app="$(find "$ROOT/DerivedData/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "Reado.app" | head -1)"
  if [[ -z "$app" ]]; then
    echo "Không thấy Reado.app đã build — chạy lại không kèm --no-build." >&2
    return 1
  fi
  echo "$app"
}

# install_app <udid> <app> [--fresh] [--grant] — boot, (gỡ app nếu --fresh), cài, (cấp quyền camera/ảnh nếu --grant
# để hộp thoại hệ thống không che màn khi chụp).
install_app() {
  local udid="$1" app="$2"; shift 2
  local fresh=0 grant=0
  for a in "$@"; do
    case "$a" in --fresh) fresh=1 ;; --grant) grant=1 ;; esac
  done
  sim_boot "$udid"
  [[ "$fresh" == 1 ]] && { xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true; }
  xcrun simctl install "$udid" "$app"
  if [[ "$grant" == 1 ]]; then
    xcrun simctl privacy "$udid" grant camera "$BUNDLE_ID" || true
    xcrun simctl privacy "$udid" grant photos "$BUNDLE_ID" || true
  fi
}

# Ngưỡng ảnh "đã vẽ": khung trắng ~76KB, màn thật ≥ 180KB (đo trên iPhone Air 1260x2736, 2026-10-06).
# Màn rất trống (< 120KB) sẽ hết hạn ~8s với cảnh báo — vẫn lưu ảnh, chỉ cần xem bằng mắt.
SHOT_MIN_BYTES="${SHOT_MIN_BYTES:-120000}"

_fsize() { stat -f%z "$1" 2>/dev/null || echo 0; }

# sim_shot <udid> <file.png> — chụp tới khi hình đã ổn: ≥ SHOT_MIN_BYTES và hai lần liên tiếp lệch ≤ 3% kích thước
# (animation nhỏ làm byte lệch nhẹ nên không so bit-exact). Tối đa ~8s; hết hạn thì giữ ảnh cuối kèm cảnh báo.
sim_shot() {
  local udid="$1" out="$2" prev=0 cur diff max i
  for i in $(seq 1 20); do
    xcrun simctl io "$udid" screenshot "$out" >/dev/null 2>&1 || true
    cur="$(_fsize "$out")"
    if (( cur >= SHOT_MIN_BYTES && prev > 0 )); then
      diff=$(( cur > prev ? cur - prev : prev - cur )); max=$(( cur > prev ? cur : prev ))
      (( diff * 100 <= max * 3 )) && return 0
    fi
    prev="$cur"
    sleep 0.4
  done
  echo "⚠️ ảnh $out chưa ổn sau ~8s (${cur} byte) — kiểm tra bằng mắt trước khi kết luận" >&2
}
