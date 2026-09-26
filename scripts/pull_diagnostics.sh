#!/usr/bin/env bash
# pull_diagnostics.sh — kéo Documents/Diagnostics/ (DebugTrace, ADR-037) từ
# simulator hoặc máy thật về .tmp/diagnostics/<ts>/ để đọc bằng
# scripts/diag_summary.py. Chỉ có gì khi app build DEBUG (fen build bằng
# Xcode Run là Debug).
#
#   scripts/pull_diagnostics.sh sim              # simulator đang boot
#   scripts/pull_diagnostics.sh device            # máy thật đang cắm dây/trong cùng mạng
#   scripts/pull_diagnostics.sh device <udid>     # chỉ định máy khi cắm nhiều máy
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.reado.app"
MODE="${1:-}"
OUT="$ROOT/.tmp/diagnostics/$(date -u +%Y%m%dT%H%M%SZ)"

if [[ "$MODE" != "sim" && "$MODE" != "device" ]]; then
  echo "Dùng: scripts/pull_diagnostics.sh [sim|device] [udid]" >&2
  exit 1
fi

mkdir -p "$OUT"

if [[ "$MODE" == "sim" ]]; then
  CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE_ID" data)"
  SRC="$CONTAINER/Documents/Diagnostics"
  if [[ ! -d "$SRC" ]]; then
    echo "Không thấy $SRC — app đã phân tích lần nào trên simulator booted chưa?" >&2
    exit 1
  fi
  cp -R "$SRC" "$OUT/"
else
  UDID="${2:-}"
  if [[ -z "$UDID" ]]; then
    echo "Danh sách máy đang thấy:" >&2
    xcrun devicectl list devices
    echo "Chạy lại: scripts/pull_diagnostics.sh device <udid> ở trên." >&2
    exit 1
  fi
  xcrun devicectl device copy from \
    --device "$UDID" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "Documents/Diagnostics" \
    --destination "$OUT"
fi

echo "Đã kéo về: $OUT"
echo "Xem tóm tắt: python3 scripts/diag_summary.py \"$OUT\""
