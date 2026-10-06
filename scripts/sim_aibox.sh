#!/usr/bin/env bash
# sim_aibox.sh — cài + mở Reado trên simulator, tự thêm agent AI-Box (DEBUG
# only, xem AppModel.seedDevAIBoxAgentIfNeeded) bằng key đọc từ .env, KHÔNG in
# key ra bất cứ đâu. Dùng khi muốn test luồng OCR→AI-Box trên simulator mà
# không phải gõ tay key mỗi lần cài lại app.
#
#   scripts/sim_aibox.sh              # build (nếu cần) rồi cài + mở
#   scripts/sim_aibox.sh --no-build   # dùng bản build gần nhất trong DerivedData/
#
# Key do scripts/lib/envkey.py chọn (khối cuối có PROVIDER=apibox, hoặc API_KEY cuối cùng).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/sim.sh"

if [[ "${1:-}" != "--no-build" ]]; then
  "$ROOT/scripts/test.sh" build
fi

APP="$(app_path)"

KEY="$(python3 "$ROOT/scripts/lib/envkey.py" "$ROOT/.env")"
if [[ -z "$KEY" ]]; then
  echo "Không tìm được API_KEY apibox trong .env — kiểm tra file, không seed agent." >&2
  exit 1
fi

UDID="$(sim_udid)"
install_app "$UDID" "$APP"
SIMCTL_CHILD_READO_DEV_AIBOX_KEY="$KEY" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
echo "Đã mở Reado trên $SIM_NAME kèm agent AI-Box (dev) — vào Cài đặt kiểm tra đã chọn agent này."
