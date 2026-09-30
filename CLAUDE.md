# CLAUDE.md — Reado

> Entry point duy nhất cho Claude Code. Đọc hết file này trước khi làm việc.
> Cách làm việc (workflow, đọc file, bẫy build): §7. Trạng thái session: `docs/session-brief.md`.

## 1. Reado là gì

- iOS native (SwiftUI), app **học từ vựng từ sách thật**: chụp trang → trích xuất từ mới theo ngữ cảnh → ôn tập bằng FSRS.
- Local-first: SQLite on-device (Q-02), một người dùng (NG-05). AI qua **proxy hybrid** (Q-03):
  proxy Gemini mặc định, BYOK OpenAI-compat ở Keychain khi cần.
- Scheduling dùng thư viện `swift-fsrs` pin commit `4fbaf20`, `FSRSDefaults.defaultWv6` (21 trọng số).
- Owner = fen. R1 là MVP một user; success metric M-07: bỏ luồng chat Gemini thủ công.

## 2. Quickstart

- Build & test — **chỉ** dùng script (đã gom 3 cờ cache + tự boot simulator + lọc log):
  ```bash
  scripts/test.sh                                            # build + toàn bộ test
  scripts/test.sh build                                      # chỉ build
  scripts/test.sh test -only-testing:ReadoTests/<Class>       # 1 lớp test khi đang sửa; full trước /rhandoff
  scripts/test.sh kit                                        # chỉ ReadoKit trên macOS (~10s, không simulator) — logic thuần
  ```
  Log đầy đủ ở `/tmp/build.log`, kết quả ở `.tmp/results/last.xcresult` (lane `kit`: `/tmp/build-kit.log`, `.tmp/results/kit.xcresult`) — cần chi tiết thì đọc các file đó, không đọc nguyên.
- Proxy: `cd proxy && python3 -m unittest -q`.
- CI: `.github/workflows/ci.yml` (ADR-047) gọi lại đúng các lệnh trên; CI đặt `READO_SIM_NAME="iPhone 17 Pro"` vì runner chưa có iPhone 18 Pro. Log/xcresult của lượt hỏng ở artifact của run.
- **Cấm `swift build`** (đụng cache `~/Library`).
- Số test xanh / HEAD gần nhất: `docs/session-brief.md` §1 — không ghi vào file này.

## 3. Sơ đồ docs

| Doc | Đọc khi nào |
|---|---|
| `docs/specs/vision.md` | 6 nguyên lý — đọc ở mỗi `/rplan` + resolver mọi chỗ mơ hồ |
| `docs/specs/prd.md` | FR/NFR/M/A, R1/R2 scope, bảng "Đã chốt" |
| `docs/specs/solution-design.md` | "Thế nào" của R1: kiến trúc, DDL, ranh giới transaction |
| `docs/specs/db.md` | Dialect SQLite R1 (tầng A) + sync Later (tầng B) |
| `docs/specs/journeys.md` | Các lối đi UI (J1–J6), Học/Ôn/Trộn |
| `docs/research/tech-stack.md` | Vì sao chọn stack (RQ), các quyết định đảo |
| `docs/research/vocabulary.md` | Structure + card design + import — schema logic vocab |
| `docs/research/review.md` | Scheduling FSRS + multi-client sync + rich-vocab cram |
| `docs/agent/agent-rulebook.md` | Index: đụng X thì grep file Y — không phải kho luật đầy đủ |
| `docs/agent/plan-template.md` | Khung `/rplan` — Spec / HLD / Tasks |
| `docs/agent/prompt-spec.md` | FR-02 prompt + output schema |
| `docs/agent/coding-conventions.md` | Quy ước code Swift |
| `docs/decisions-log.md` | ADR — thứ tự quyết định và vì sao |
| `docs/session-brief.md` | Bàn giao session — đọc ở Turn 1 session mới |
| `ROADMAP.md` | Tracker tiến độ + checklist theo FR (file lớn — Grep) |
| `docs/idea.md` | Ý tưởng gốc của owner, giữ làm provenance |
| `design-system/reado/MASTER.md` | Token/vật liệu UI (FROZEN liquid-glass) |
| `ref/pvo/` | Mô hình PVO — R2, **không đọc để build R1** |
| `docs/journal/`, `docs/investigations/` | Nhật ký theo ngày · bundle điều tra (đọc khi truy vết) |

## 4. Luật cứng

| Luật | Chi tiết |
|---|---|
| Không `unique` trên vocab_items | Chống trùng là việc tầng extract (FR-10), không phải DB |
| FSRS phải dùng thư viện | Cấm tự viết — `swift-fsrs` pin `4fbaf20`, `defaultWv6` |
| FR-07 / FR-13 là bia mộ | Cấm implement, cấm xoá dòng bia mộ khỏi docs |
| Không ảnh trang vào SQLite | NFR-04 — chỉ segments JSON |
| `cards.state` có 4 giá trị | `new`/`learning`/`review`/`relearning` — không gộp |
| `review_logs` snapshot TRƯỚC khi chấm | Update `cards` + insert `review_logs` CÙNG 1 transaction |
| Timestamp UTC `Z` + uuid có gạch | ISO-8601 hậu tố `Z`; uuid TEXT thường có gạch nối; `fsrs_params` TEXT JSON |
| `FSRSDefaults.defaultWv6` | 21 trọng số, không dùng constructor mặc định (v5) |
| Không thêm dependency | Chỉ thêm khi thực sự cần, owner xác nhận |

## 5. Đã chốt / còn mở

Danh sách này là nguồn duy nhất. Agent và command không chép lại số Q.

- **Chốt, không hỏi lại:** Q-01 iOS native · Q-02 local SQLite · Q-03 proxy hybrid · Q-06 không lemmatize · Q-08 "đã thuộc" = `stability >= 21` · Q-09 so khớp theo collection · Q-10 10 phiên đọc mỗi collection có tên · Q-12 tắt steps.
- **Chốt thêm 2026-09-24:** ngưỡng leech FR-19 = **6** lần Again. Không gộp với Q-08.
- **Mở — phải HỎI owner:** Q-11 (jitter hai chế độ R2, chốt trước Phase 4).

## 6. Xử lý mơ hồ

1. Chiếu vào 6 nguyên lý `docs/specs/vision.md` → mỗi nguyên lý có "Chống lại".
2. Kiểm non-goals (NG-01..09) + bảng "Đã chốt" (`CLAUDE.md` §5 và spec liên quan). Dòng đã chốt sai → BÁO LẠI, không sửa.
3. Vẫn mơ hồ + đụng dữ liệu/lịch ôn → hỏi owner đúng câu còn mở ở mục 5 (Q-11). Ngưỡng leech đã chốt = 6. Thiếu hợp đồng / ranh giới → `/rplan` hoặc hỏi, không tự lấp.
4. Chỉ là chi tiết hiển thị → chọn cách đơn giản nhất, ghi lại lựa chọn.

## 7. Cách làm việc

**Workflow**
- Đầu session: `/rstart`. Task nhỏ (bug UI, copy, test bổ sung khi FR/journey đã chốt) → code luôn, nói 1 câu lý do skip plan.
- Đụng hợp đồng (schema, FR mới, transaction, protocol module, Q mở) → `/rplan` (hoặc plan mode) trước, owner confirm rồi mới code.
- Xong task → `/rhandoff`. 1 task tầng 2 / session; context dài → `/rhandoff` rồi `/clear`.

**Đọc file**
- `docs/research/{vocabulary,review}.md`: đọc mục **TL;DR** đầu file trước, chỉ nhảy vào mục chi tiết khi cần.
- File lớn — Grep trước, Read có offset/limit, không đọc nguyên: `ROADMAP.md`, `docs/specs/{prd,journeys,db,solution-design,sync-server-ddl}.md`, `docs/research/{vocabulary,review,tech-stack}.md`, `docs/agent/prompt-spec.md`, `docs/decisions-log.md`.
- Bản đồ Swift: `python3 scripts/repo_map.py` (`--root app/ReadoKit/Sources --limit 40` để hẹp). Không in ra file docs.
- Index "đụng X → grep Y": `docs/agent/agent-rulebook.md`.

**Log chẩn đoán** (ADR-037, `DebugTrace` — chỉ bản DEBUG, fen build Xcode Run là Debug)
- Fen cắm điện thoại/mở simulator → `scripts/pull_diagnostics.sh device` (hoặc `sim`) rồi `python3 scripts/diag_summary.py <thư mục in ra>`. Đọc bản tóm tắt này trước, không mở thẳng `events.jsonl`/`analysis.json`.
- Mỗi lần phân tích một thư mục ở `Documents/Diagnostics/analyses/` (ảnh + OCR + từng hàng kèm lý do ngắt đoạn + response + lỗi), giữ 30 lần gần nhất. Ngoại lệ NFR-04 chỉ áp cho log DEBUG này.

**pbxproj** — synchronized folders (objectVersion 70, ADR-046), cấm edit tay/đọc nguyên `project.pbxproj` (hook chặn):
- Thêm/xoá/di chuyển file Swift = tạo/xoá/`git mv` trong `app/Reado/**` hoặc `app/ReadoTests/**`; Xcode tự nhận, không đụng pbxproj. Đổi target/build setting/package → nhờ fen làm trong Xcode.
- Cổng `python3 scripts/pbxproj_tool.py check` (`scripts/test.sh` tự chạy): còn synchronized folders, không exception set, không fileRef `.swift` kiểu cũ. `list` xem cấu trúc.
- Bẫy: file nằm trong thư mục là được compile, **kể cả file chưa track git** — file nháp để ngoài `app/`.
- Chạy xcodebuild tự re-sort pbxproj → trước commit chỉ giữ hunk thật.

**Hooks** (`.claude/hooks/`)
- `guard.py` (PreToolUse) chặn: edit tay `project.pbxproj`, `swift build`/`swift test`, `xcodebuild` gọi trần (không qua `scripts/test.sh`).
- `session-context.sh` (SessionStart) tự nạp HEAD + thay đổi chưa commit + `docs/session-brief.md` §1–2 vào context khi mở/`/clear`/`/compact` — đỡ phải tự đọc lại.

**Bẫy build**
- Simulator: **iPhone 18 Pro**. `Reado.xcodeproj` objectVersion 70 (synchronized folders); local package dùng `XCSwiftPackageProductDependency`.
- `ISO8601FormatStyle()` trần không parse nổi — compose đủ field (`ISOTimestamp.swift`).
- SQLite `COLLATE NOCASE` chỉ gập ASCII — gập tiếng Việt ở tầng app (FR-20).
- TOCropViewController từ SPM từ xa — build đầu cần mạng.
- `scripts/test.sh` tự boot simulator (`simctl bootstatus -b`) trước khi gọi xcodebuild — simulator ở trạng thái `Shutdown` từng làm `xcodebuild test` treo vô thời hạn vì boot ngầm không đáng tin. Vẫn treo > 10 phút sau khi đã boot → kill, báo owner chạy tay trong Terminal.
- Không chạy được simulator → không bịa số test, không ghi "xong".
