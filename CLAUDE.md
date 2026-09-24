# CLAUDE.md — Reado

> Entry point duy nhất cho Claude Code (và bất kỳ agent nào). Đọc hết file này trước khi làm việc.
> DSH (DeepSeek Harness) là tool chính — xem `AGENTS.md` bên cạnh file này.

## 1. Reado là gì

- iOS native (SwiftUI), app **học từ vựng từ sách thật**: chụp trang → trích xuất từ mới theo ngữ cảnh → ôn tập bằng FSRS.
- Local-first: SQLite on-device (Q-02), một người dùng (NG-05). AI qua **proxy hybrid** (Q-03):
  proxy Gemini mặc định, BYOK OpenAI-compat ở Keychain khi cần.
- Scheduling dùng thư viện `swift-fsrs` pin commit `4fbaf20`, `FSRSDefaults.defaultWv6` (21 trọng số).
- Owner = fen. R1 là MVP một user; success metric M-07: bỏ luồng chat Gemini thủ công.

## 2. Quickstart

- **KHÔNG dùng `swift build`** — cache đụng `~/Library`. Luôn dùng `xcodebuild` với 3 cờ cache gom vào workspace (xem AGENTS.md).
- Build & test:
  ```bash
  cd app
  TMPDIR="$PWD/../.tmp" xcodebuild -project Reado.xcodeproj -scheme Reado \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
    -derivedDataPath "$PWD/../DerivedData" -clonedSourcePackagesDirPath "$PWD/../.xcode-packages" test
  ```
- Mốc khoẻ đã ghi: **182/182 test xanh** trên iPhone 18 Pro tại `9c1becc`. Máy không build iOS thì không chạy lại và không ghi số mới.
- **Chống đốt token khi build:** `xcodebuild` luôn `| tee /tmp/build.log | grep -E "error:|warning:|TEST.*passed|TEST.*failed|BUILD" | tail -n 60` — không ném raw log vào context. Chỉ `grep` trong `/tmp/build.log` khi cần. Chi tiết: `AGENTS.md §2` + `§4`.

## 3. Sơ đồ docs

| Doc | Đọc khi nào |
|---|---|
| `docs/specs/vision.md` | 6 nguyên lý — resolver mọi chỗ mơ hồ |
| `docs/specs/prd.md` | FR/NFR/M/A, R1/R2 scope, bảng "Đã chốt" |
| `docs/specs/solution-design.md` | "Thế nào" của R1: kiến trúc, DDL, ranh giới transaction |
| `docs/specs/db.md` | Dialect SQLite R1 (tầng A) + sync Later (tầng B) |
| `docs/specs/journeys.md` | Các lối đi UI (J1–J6), Học/Ôn/Trộn |
| `docs/research/tech-stack.md` | Vì sao chọn stack (RQ), các quyết định đảo |
| `docs/research/vocabulary.md` | Structure + card design + import — schema logic vocab |
| `docs/research/review.md` | Scheduling FSRS + multi-client sync + rich-vocab cram |
| `docs/agent/agent-rulebook.md` | Kho luật đầy đủ — mở khi task chạm điều khoản |
| `docs/agent/prompt-spec.md` | FR-02 prompt + output schema |
| `docs/agent/coding-conventions.md` | Quy ước code Swift |
| `docs/decisions-log.md` | ADR — thứ tự quyết định và vì sao |
| `docs/session-brief.md` | Bàn giao session — đọc ở Turn 1 session mới |

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
2. Kiểm non-goals (NG-01..09) + bảng "Đã chốt" (`docs/agent/agent-rulebook.md`). Dòng đã chốt sai → BÁO LẠI, không sửa.
3. Vẫn mơ hồ + đụng dữ liệu/lịch ôn → hỏi owner đúng câu còn mở ở mục 5 (Q-11). Ngưỡng leech đã chốt = 6.
4. Chỉ là chi tiết hiển thị → chọn cách đơn giản nhất, ghi lại lựa chọn.