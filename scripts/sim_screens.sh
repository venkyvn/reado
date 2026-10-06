#!/usr/bin/env bash
# sim_screens.sh — cài + mở Reado trên simulator kèm dữ liệu mẫu (DEBUG only, xem
# AppModel.seedDevDemoCSVIfNeeded) và chụp màn hình light + dark để so trước/sau
# (docs/plans/done/visual-polish-r1.md). Không cần key nào. Ảnh ra .tmp/screens/ (ngoài git).
#
#   scripts/sim_screens.sh                 # build rồi cài + mở (giữ dữ liệu cũ)
#   scripts/sim_screens.sh --fresh         # gỡ app trước → DB mới → seed lại CSV mẫu
#   scripts/sim_screens.sh --no-build      # dùng bản build gần nhất trong DerivedData/
#   scripts/sim_screens.sh list            # in tên các màn `open` nhận (đọc từ DebugLaunch.swift)
#   scripts/sim_screens.sh shot <tên>      # chụp <tên>-light.png + <tên>-dark.png màn hiện tại
#   scripts/sim_screens.sh size <cỡ>       # Dynamic Type: extra-extra-large | large | ... (xcrun simctl ui)
#   scripts/sim_screens.sh open <màn> [--theme forest|sepia|indigo|system]
#                                      [--seed demo|demo-reviewed|demo-dups|demo-streak|empty] [--alert dup-name|pin-limit]
#                                      [--fixture <file.json>] [--agent] [--fresh] [--no-build]
#                                      [--pdf <file.pdf>] [--pdf-page <N>]
#                                      [--apple-ai available|off|nodevice]
#                                           # verify-nav-r1: mở THẲNG một màn qua launch argument
#                                           # DEBUG-only (`DebugLaunch`, `RootView.applyDebugScreenIfNeeded`)
#                                           # — không cần chạm tay. Màn hợp lệ: xem `DebugLaunch.Screen`
#                                           # (danh sách đầy đủ: `scripts/sim_screens.sh list`).
#                                           # Gõ sai tên màn → app tự alert "Launch arg lạ", không đứng im.
#                                           # `--agent` seed sẵn một agent AI-Box với key GIẢ (không kiểm tra, không gọi mạng)
#                                           # để `activeAgentReady` = true — mở camera/luồng chụp không cần key thật.
#                                           # Không có `--agent` thì app coi như chưa có agent (bấm chụp ra form thêm agent).
#                                           # `--fixture` đổi JSON cho màn analysis-fixture* (mặc định
#                                           # scripts/fixtures/analysis-demo.json; analysis-empty.json = rỗng sau FR-10).
#                                           # `--seed` chỉ có tác dụng khi kho ĐANG TRỐNG (seed-once, như CSV cũ)
#                                           # — đổi seed thì luôn kèm `--fresh`. `demo-reviewed` dựng lịch ôn giả
#                                           # (`DevSeed.gradeHistory`) cho CTA "Ôn thêm" + heatmap nhiều mức màu.
#                                           # `--pdf` (pdf-nav-r1): dùng file PDF THẬT trên máy thay PDF fixture 2
#                                           # trang cho 3 màn pdf-reader* — KHÔNG commit file đó (xem .gitignore
#                                           # `/*.pdf`). `--pdf-page N` mở sẵn đúng trang N (1-based).
#                                           # `--apple-ai` (apple-ai-r1 T7): ghi đè trạng thái Apple Intelligence ở
#                                           # màn settings — simulator không bật/tắt Apple Intelligence thật được.
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
source "$ROOT/scripts/lib/sim.sh"
FIXTURE="$ROOT/scripts/fixtures/demo-vocab.csv"
ANALYSIS_FIXTURE="$ROOT/scripts/fixtures/analysis-demo.json"
OUT="$ROOT/.tmp/screens"

SUB="${1:-}"
case "$SUB" in
  list)
    # Tên màn mà DebugLaunch.parseScreen nhận (nguồn thật — không chép tay vào header).
    sed -n '/private static func parseScreen/,/^    }/p' "$ROOT/app/ReadoKit/Sources/ReadoKit/Shell/DebugLaunch.swift" \
      | sed -nE 's/^ *case ((".*")(, ".*")*):.*/\1/p' | tr -d '"' | sed 's/, /|/g'
    echo 'collection:<id|tên>'
    exit 0
    ;;
  shot)
    UDID="$(sim_udid)"
    NAME="${2:?Thiếu tên ảnh — vd: scripts/sim_screens.sh shot before-home}"
    mkdir -p "$OUT"
    ORIGINAL="$(xcrun simctl ui "$UDID" appearance)"
    for mode in light dark; do
      xcrun simctl ui "$UDID" appearance "$mode"
      sim_shot "$UDID" "$OUT/$NAME-$mode.png"  # đợi appearance đổi xong + khung đã vẽ
      echo "$OUT/$NAME-$mode.png"
    done
    xcrun simctl ui "$UDID" appearance "$ORIGINAL"
    exit 0
    ;;
  size)
    UDID="$(sim_udid)"
    SIZE="${2:?Thiếu cỡ chữ — vd: extra-extra-large hoặc large}"
    xcrun simctl ui "$UDID" content_size "$SIZE"
    exit 0
    ;;
  open)
    SCREEN="${2:?Thiếu tên màn — vd: scripts/sim_screens.sh open home (danh sách: scripts/sim_screens.sh list)}"
    shift 2
    ;;
  *)
    # Không có lệnh con: cài + mở app, giữ nguyên màn mặc định (không truyền -ReadoScreen).
    SCREEN=""
    ;;
esac

THEME=""
SEED=""
ALERT=""
WITH_AGENT=0
FRESH=0
BUILD=1
PDF_FIXTURE=""
PDF_PAGE=""
APPLE_AI=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme) THEME="${2:?Thiếu giá trị cho --theme}"; shift 2 ;;
    --seed) SEED="${2:?Thiếu giá trị cho --seed}"; shift 2 ;;
    --alert) ALERT="${2:?Thiếu giá trị cho --alert}"; shift 2 ;;
    --fixture) ANALYSIS_FIXTURE="${2:?Thiếu giá trị cho --fixture}"; shift 2 ;;
    --agent) WITH_AGENT=1; shift ;;
    --fresh) FRESH=1; shift ;;
    --no-build) BUILD=0; shift ;;
    --pdf) PDF_FIXTURE="${2:?Thiếu đường dẫn cho --pdf}"; shift 2 ;;
    --pdf-page) PDF_PAGE="${2:?Thiếu số trang cho --pdf-page}"; shift 2 ;;
    # apple-ai-r1 T7 — available|off|nodevice, AppModel.applyDevAppleAIOverrideIfNeeded đọc.
    --apple-ai) APPLE_AI="${2:?Thiếu giá trị cho --apple-ai (available|off|nodevice)}"; shift 2 ;;
    *) echo "Tham số lạ: $1" >&2; exit 2 ;;
  esac
done
# App đọc file qua đường dẫn tuyệt đối (simulator dùng chung ổ đĩa với máy chủ).
case "$ANALYSIS_FIXTURE" in
  /*) ;;
  *) ANALYSIS_FIXTURE="$ROOT/$ANALYSIS_FIXTURE" ;;
esac
if [[ -n "$PDF_FIXTURE" ]]; then
  case "$PDF_FIXTURE" in
    /*) ;;
    *) PDF_FIXTURE="$ROOT/$PDF_FIXTURE" ;;
  esac
  if [[ ! -f "$PDF_FIXTURE" ]]; then
    echo "Không thấy file PDF: $PDF_FIXTURE" >&2
    exit 2
  fi
fi
if [[ -n "$SEED" && "$FRESH" == 0 ]]; then
  echo "Lưu ý: --seed chỉ áp khi kho trống — kèm --fresh nếu muốn chắc seed mới." >&2
fi

UDID="$(sim_udid)"
if [[ "$BUILD" == 1 ]]; then
  "$ROOT/scripts/test.sh" build
fi
APP="$(app_path)"
install_app "$UDID" "$APP" --grant $([[ "$FRESH" == 1 ]] && echo --fresh)

LAUNCH_ARGS=()
[[ -n "$SCREEN" ]] && LAUNCH_ARGS+=(-ReadoScreen "$SCREEN")
[[ -n "$THEME" ]] && LAUNCH_ARGS+=(-ReadoTheme "$THEME")
[[ -n "$SEED" ]] && LAUNCH_ARGS+=(-ReadoSeed "$SEED")
[[ -n "$ALERT" ]] && LAUNCH_ARGS+=(-ReadoAlert "$ALERT")
AGENT_NOTE=""
if [[ "$WITH_AGENT" == 1 ]]; then
  AGENT_NOTE=" (có agent giả)"
  # AppModel.seedDevAIBoxAgentIfNeeded (DEBUG) đọc biến này, thêm agent không qua kiểm key.
  export SIMCTL_CHILD_READO_DEV_AIBOX_KEY="dev-dummy-key"
else
  unset SIMCTL_CHILD_READO_DEV_AIBOX_KEY
fi
PDF_NOTE=""
if [[ -n "$PDF_FIXTURE" ]]; then
  PDF_NOTE=" (pdf $PDF_FIXTURE)"
  # RootView.debugPDFFixtureURL (pdf-nav-r1) đọc biến này thay PDF fixture 2 trang.
  export SIMCTL_CHILD_READO_DEV_PDF_FIXTURE="$PDF_FIXTURE"
else
  unset SIMCTL_CHILD_READO_DEV_PDF_FIXTURE
fi
if [[ -n "$PDF_PAGE" ]]; then
  PDF_NOTE="$PDF_NOTE (trang $PDF_PAGE)"
  export SIMCTL_CHILD_READO_DEV_PDF_PAGE="$PDF_PAGE"
else
  unset SIMCTL_CHILD_READO_DEV_PDF_PAGE
fi
APPLE_AI_NOTE=""
if [[ -n "$APPLE_AI" ]]; then
  APPLE_AI_NOTE=" (apple-ai $APPLE_AI)"
  export SIMCTL_CHILD_READO_DEV_APPLE_AI="$APPLE_AI"
else
  unset SIMCTL_CHILD_READO_DEV_APPLE_AI
fi
# --terminate-running-process: launch trước đó (nếu còn sống) không đọc argv
# mới — phải buộc khởi động lại để `-ReadoScreen` mới có hiệu lực.
SIMCTL_CHILD_READO_DEV_DEMO_CSV="$FIXTURE" \
SIMCTL_CHILD_READO_DEV_ANALYSIS_FIXTURE="$ANALYSIS_FIXTURE" \
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" ${LAUNCH_ARGS[@]+"${LAUNCH_ARGS[@]}"} >/dev/null
# Đợi app mở + điều hướng xong (khung ổn định) rồi mới trả lời — `shot` ngay sau đó không còn ảnh trắng.
mkdir -p "$OUT"
sim_shot "$UDID" "$OUT/.ready.png"
rm -f "$OUT/.ready.png"
if [[ -n "$SCREEN" ]]; then
  echo "Đã mở màn '$SCREEN'${THEME:+ (theme $THEME)}${SEED:+ (seed $SEED)}${ALERT:+ (alert $ALERT)}${AGENT_NOTE}${PDF_NOTE}${APPLE_AI_NOTE} trên $SIM_NAME — chụp: scripts/sim_screens.sh shot after-<tên>"
else
  echo "Đã mở Reado trên $SIM_NAME kèm dữ liệu mẫu (36 từ, 3 bộ Demo). Điều hướng tới màn cần chụp rồi: scripts/sim_screens.sh shot before-<màn>"
fi
