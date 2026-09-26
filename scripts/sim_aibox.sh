#!/usr/bin/env bash
# sim_aibox.sh — cài + mở Reado trên simulator, tự thêm agent AI-Box (DEBUG
# only, xem AppModel.seedDevAIBoxAgentIfNeeded) bằng key đọc từ .env, KHÔNG in
# key ra bất cứ đâu. Dùng khi muốn test luồng OCR→AI-Box trên simulator mà
# không phải gõ tay key mỗi lần cài lại app.
#
#   scripts/sim_aibox.sh              # build (nếu cần) rồi cài + mở
#   scripts/sim_aibox.sh --no-build   # dùng bản build gần nhất trong DerivedData/
#
# Key lấy từ khối CUỐI cùng có PROVIDER=apibox (hoặc dòng API_KEY cuối cùng
# nếu không thấy khối apibox) trong .env ở gốc repo — sửa hàm `pick_key` nếu
# cấu trúc .env đổi.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_NAME="iPhone 18 Pro"
BUNDLE_ID="com.reado.app"

if [[ "${1:-}" != "--no-build" ]]; then
  "$ROOT/scripts/test.sh" build
fi

APP="$(find "$ROOT/DerivedData/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "Reado.app" | head -1)"
if [[ -z "$APP" ]]; then
  echo "Không thấy Reado.app đã build — chạy lại không kèm --no-build." >&2
  exit 1
fi

KEY="$(python3 - "$ROOT/.env" <<'EOF'
import sys
path = sys.argv[1]
blocks, current = [], []
for line in open(path):
    line = line.rstrip("\n")
    if line.strip() == "" or line.strip() == "---":
        if current:
            blocks.append(current)
            current = []
        continue
    current.append(line)
if current:
    blocks.append(current)

def get(block, name):
    for line in block:
        if line.startswith(name + "="):
            return line.split("=", 1)[1].strip()
    return None

key = None
for block in blocks:
    if get(block, "PROVIDER") == "apibox":
        key = get(block, "API_KEY")
if key is None:
    for block in reversed(blocks):
        candidate = get(block, "API_KEY")
        if candidate:
            key = candidate
            break
print(key or "")
EOF
)"

if [[ -z "$KEY" ]]; then
  echo "Không tìm được API_KEY apibox trong .env — kiểm tra file, không seed agent." >&2
  exit 1
fi

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

xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
SIMCTL_CHILD_READO_DEV_AIBOX_KEY="$KEY" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
echo "Đã mở Reado trên $SIM_NAME kèm agent AI-Box (dev) — vào Cài đặt kiểm tra đã chọn agent này."
