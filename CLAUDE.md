# CLAUDE.md — Reado

> Entry point duy nhất cho Claude Code. Đọc hết file này trước khi làm việc.
> Cách làm việc (workflow, đọc file, bẫy build): §7. Trạng thái session: `docs/session-brief.md`.

## 1. Reado là gì

- iOS native (SwiftUI), app **học từ vựng từ sách thật**: chụp trang → trích xuất từ mới theo ngữ cảnh → ôn tập bằng FSRS.
- Local-first: SQLite on-device (Q-02), một người dùng (NG-05). AI qua **BYOK OpenAI-compat**
  ở Keychain (Q-03, đảo ADR-049 2026-10-01 — bỏ proxy Reado, không còn "hybrid") **hoặc
  Apple Intelligence** trên máy (ADR-063 2026-10-05 — không key, mặc định khi máy hỗ trợ
  và chưa chọn agent nào). OCR dùng engine `liveText` (Live Text ghép khung đoạn
  `RecognizeDocumentsRequest`, ADR-064) trên máy hỗ trợ iOS 26+; bước "soát OCR bằng
  LLM" riêng (ADR-063) đã GỠ HẲN (ADR-065 2026-10-05 — `liveText` thay thế).
- Scheduling dùng thư viện `swift-fsrs` pin commit `4fbaf20`, `FSRSDefaults.defaultWv6` (21 trọng số).
- Owner = fen. R1 là MVP một user; success metric M-07: bỏ luồng chat Gemini thủ công.

## 2. Quickstart

- Build & test — **chỉ** dùng script (đã gom 3 cờ cache + tự boot simulator + lọc log):
  ```bash
  scripts/test.sh                                            # build + toàn bộ test
  scripts/test.sh build                                      # chỉ build
  scripts/test.sh test -only-testing:ReadoKitTests/<Class>    # 1 lớp test khi đang sửa; full trước /rhandoff
  scripts/test.sh test -only-testing:ReadoTests/<Class>       # chỉ 4 lớp cần UIKit/Vision (OCR, nén ảnh)
  scripts/test.sh kit                                        # chỉ ReadoKit trên macOS (~10s, không simulator) — logic thuần
  ```
  Log đầy đủ ở `/tmp/build.log`, kết quả ở `.tmp/results/last.xcresult` (lane `kit`: `/tmp/build-kit.log`, `.tmp/results/kit.xcresult`) — cần chi tiết thì đọc các file đó, không đọc nguyên.
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
| `design-system/reado/MASTER.md` | Quyết định look + luật UI native; token ở `DesignSystem.swift` |
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

- **Chốt, không hỏi lại:** Q-01 iOS native · Q-02 local SQLite · Q-03 BYOK-only (ADR-049 2026-10-01 — "proxy hybrid" cũ là bia mộ) · Q-06 không lemmatize · Q-08 "đã thuộc" = `stability >= 21` · Q-09 so khớp **toàn app** cho FR-10 (đảo 2026-10-05, ADR-066 — bản cũ "theo collection" là bia mộ; FR-22 vốn đã toàn app từ đầu) · Q-10 10 phiên đọc mỗi collection có tên · Q-12 tắt steps.
- **Chốt thêm 2026-09-24:** ngưỡng leech FR-19 = **6** lần Again. Không gộp với Q-08.
- **Chốt thêm 2026-10-01:** bỏ proxy Reado — ADR-049.
- **Chốt thêm 2026-10-02:** Q-13 (khoá so khớp FR-10 `term_normalized+pos` không phân biệt nghĩa) — phương án **B**: item khớp khoá đã thuộc gập xuống nhóm riêng thay vì xoá khỏi màn duyệt; khoá có cả dòng đã thuộc lẫn dòng mới/chưa thuộc vẫn vào nhóm gập, liệt kê đủ nghĩa kèm mức thuộc (ADR-056).
- **Chốt thêm 2026-10-04:** đọc PDF trong Reado (FR-23) — đảo một phần NG-07, ADR-058. Không chép file (bookmark + trang trong bảng `pdf_sources`); mỗi bộ có tên gắn tối đa 1 PDF; lớp chữ PDF trước, OCR sau khi rác/scan. EPUB vẫn ngoài (NG-07 giữ phần đó).
- **Chốt thêm 2026-10-05:** Apple Intelligence — agent kind thứ hai (`apple_intelligence`,
  builtin, không key) + soát OCR trên máy (tiền xử lý, mọi agent) — ADR-063 (**bước soát
  OCR riêng này đã GỠ HẲN cùng ngày, xem ADR-065 dưới** — agent kind thì giữ). R1 chỉ
  on-device (PCC thiếu entitlement, để R2); agent Apple chia nhỏ theo đoạn thay vì một
  lượt (context 4096 token không đủ cho một lượt trên trang sách thật — đo thật ở spike).
- **Chốt thêm 2026-10-05 (ocr-quality-r1):** engine OCR mặc định đổi sang `liveText` (Live
  Text ghép khung đoạn `documents`, đo WER thấp hơn rõ rệt trên dữ liệu thật) — ADR-064.
  Sau khi `liveText` xác nhận tốt qua xem tay máy thật, **gỡ hẳn** nhánh sửa OCR bằng LLM
  (`CorrectingTextRecognizer`/`FoundationModelsOCRCorrector`/`OCRFixApplier` + toggle
  Settings) — ADR-065, cùng ngày.
- **Chốt thêm 2026-10-05 (vocab-identity-r1, ADR-066):** đảo Q-09 cho FR-10 (so khớp toàn
  app) — xem dòng Q-09 ở trên. D1 ngân sách chọn sẵn mỗi ngày = `daily_new_limit`, không
  thêm setting riêng. D2 nhóm "Đã có trong kho" gồm mọi từ đã có (đang học + đã thuộc, mọi
  collection). D3 ôn theo bộ không kéo từ gặp ở bộ khác vào — để R2. D4 gạch chân từ cũ
  trong màn đọc PDF — để sau, không làm trong plan này.
- **Chốt thêm 2026-10-05 (engagement-r1, ADR-067/068):** gộp từ trùng cũ (FR-24) do fen duyệt
  từng nhóm, giữ thẻ tiến bộ nhất, dòng gộp thành một lần `seen` có câu — không tự động. Làm ý
  1–6 của `idea/tang_gang_bo.md` (ý 7 chia sẻ để sau); dòng nhắc streak đổi sang "N/7 ngày",
  **giữ pill streak**; không đổi prompt, không đổi schema.
- **Mở — phải HỎI owner:** Q-11 (jitter hai chế độ R2, chốt trước Phase 4).

## 6. Xử lý mơ hồ

1. Chiếu vào 6 nguyên lý `docs/specs/vision.md` → mỗi nguyên lý có "Chống lại".
2. Kiểm non-goals (NG-01..09) + bảng "Đã chốt" (`CLAUDE.md` §5 và spec liên quan). Dòng đã chốt sai → BÁO LẠI, không sửa.
3. Vẫn mơ hồ + đụng dữ liệu/lịch ôn → hỏi owner đúng câu còn mở ở mục 5 (Q-11). Ngưỡng leech đã chốt = 6. Thiếu hợp đồng / ranh giới → `/rplan` hoặc hỏi, không tự lấp.
4. Chỉ là chi tiết hiển thị → chọn cách đơn giản nhất, ghi lại lựa chọn.

**Khi fen đưa idea kỹ thuật:** fen là product owner, không phải chuyên gia kỹ thuật. Fen nhắc một công nghệ / cách làm cụ thể ("dùng X để…") → coi là giả thuyết, không phải quyết định: nêu lại vấn đề gốc, so với ≥ 2 phương án khác (kể cả không làm), rồi mới hỏi chốt. "Chốt, không hỏi lại" ở §5 chỉ áp cho mục đã ghi trong §5, không áp cho idea mới. Idea còn thô → `/ridea`.

## 7. Cách làm việc

**Workflow**
- Idea thô / thấy công nghệ trên mạng → `/ridea` (tư vấn, không plan, không code); fen chốt hướng → `/rplan`; không đáng làm → dừng, ghi lý do.
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
- `guard.py` (PreToolUse) chặn: edit tay `project.pbxproj`, `swift build`/`swift test`, `xcodebuild` gọi trần (không qua `scripts/test.sh`), và Read/Grep/Edit/Write/MultiEdit/Bash chạm file secret dạng `.env`/`.env.<suffix>` (chỉ `.env.example` lọt qua).
- `session-context.sh` (SessionStart) tự nạp HEAD + thay đổi chưa commit + `docs/session-brief.md` §1–2 vào context khi mở/`/clear`/`/compact` — đỡ phải tự đọc lại.

**Bẫy build**
- Simulator: **iPhone Air**. `Reado.xcodeproj` objectVersion 70 (synchronized folders); local package dùng `XCSwiftPackageProductDependency`.
- `ISO8601FormatStyle()` trần không parse nổi — compose đủ field (`ISOTimestamp.swift`).
- SQLite `COLLATE NOCASE` chỉ gập ASCII — gập tiếng Việt ở tầng app (FR-20).
- TOCropViewController từ SPM từ xa — build đầu cần mạng.
- `scripts/test.sh` tự boot simulator (`simctl bootstatus -b`) trước khi gọi xcodebuild — simulator ở trạng thái `Shutdown` từng làm `xcodebuild test` treo vô thời hạn vì boot ngầm không đáng tin. Vẫn treo > 10 phút sau khi đã boot → kill, báo owner chạy tay trong Terminal.
- Không chạy được simulator → không bịa số test, không ghi "xong".
