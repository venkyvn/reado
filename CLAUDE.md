# CLAUDE.md — Reado

Hook SessionStart đã nạp sẵn: HEAD, `git status`, test gần nhất, plan open, brief §1–2.

## 1. Reado là gì

- App iOS native (SwiftUI) học từ vựng từ sách thật: chụp trang hoặc mở PDF → trích từ mới theo ngữ cảnh → ôn bằng FSRS.
- Local-first: SQLite trên máy, một người dùng (Q-02, NG-05).
- AI: BYOK OpenAI-compat (key ở Keychain) hoặc Apple Intelligence on-device, mặc định khi máy hỗ trợ và chưa chọn agent. OCR: engine `liveText` (iOS 26+).
- Owner = fen: product owner, không phải chuyên gia kỹ thuật. R1 = MVP một user; metric M-07: bỏ luồng chat Gemini thủ công.

## 2. Lệnh

```bash
scripts/test.sh                # build + full test — bắt buộc trước /rhandoff
scripts/test.sh kit            # ReadoKit trên macOS, ~10s — khi đang sửa logic
scripts/test.sh test -only-testing:ReadoKitTests/<Class>   # 1 lớp, simulator
scripts/test.sh test -only-testing:ReadoTests/<Class>      # lớp cần UIKit/Vision
scripts/test.sh build
python3 scripts/repo_map.py [--root app/ReadoKit/Sources --limit 40]
```

- Kết quả: `.tmp/results/{last,kit,build}-summary.txt` theo lane; hook cảnh báo khi code đổi sau lần test. Log `/tmp/build.log` (kit: `/tmp/build-kit.log`, build: `/tmp/build-only.log`) — fail thì grep `error:`, không đọc nguyên.
- Cấm `swift build`/`swift test`, cấm `xcodebuild` trần — hook chặn; bị chặn thì đọc message, không lách.
- Sửa view → skill `reado-ui`. Debug OCR/phân tích → skill `reado-diagnostics`.

## 3. Đụng X → đọc Y

| Đụng | Đọc |
|---|---|
| Nguyên lý, chỗ mơ hồ | `docs/specs/vision.md` |
| FR/NFR, scope R1/R2 | `docs/specs/prd.md` |
| Lối đi UI (J1–J6) | `docs/specs/journeys.md` |
| Schema, dialect SQLite | `docs/specs/db.md` |
| Module, ranh giới transaction | `docs/specs/solution-design.md` §3 |
| Đọc PDF (FR-23) | ADR-058, `solution-design.md` §8b, `db.md` A.2 |
| Prompt, output schema | `docs/agent/prompt-spec.md` |
| Quy ước Swift, layout, commit | `docs/agent/coding-conventions.md` |
| Look UI, token | `design-system/reado/MASTER.md` |
| FSRS/sync · collection/import · stack | `docs/research/{review,vocabulary,tech-stack}.md` |
| Vì sao có một quyết định | `docs/decisions-log.md` (grep số ADR) |
| Tiến độ FR, task tiếp | `ROADMAP.md` |

- File lớn — Grep rồi Read có offset/limit: mọi file trong `docs/specs/` trừ `vision.md`, `docs/research/*` (đọc TL;DR đầu file trước), `prompt-spec.md`, `decisions-log.md`, `ROADMAP.md`.
- Truy vết cũ: `docs/journal/`, `docs/investigations/`. `ref/pvo/` là R2 — không đọc khi build R1.

## 4. Luật cứng

| Luật | Chi tiết |
|---|---|
| Không `unique` trên `vocab_items` | Chống trùng ở tầng extract (FR-10) |
| FSRS dùng thư viện | `swift-fsrs` pin `4fbaf20` + `FSRSDefaults.defaultWv6`; cấm tự viết, cấm `FSRS()` mặc định (v5) |
| FR-07 / FR-13 là bia mộ | Cấm implement, cấm xoá dòng bia mộ khỏi docs |
| Không ảnh trang vào SQLite | NFR-04 — chỉ segments JSON |
| Không lưu file PDF gốc | `pdf_sources` chỉ giữ bookmark + số trang (ADR-058) |
| Key API chỉ ở Keychain | Không ghi vào SQLite, plist, log |
| `cards.state` có 4 giá trị | `new`/`learning`/`review`/`relearning` |
| Chấm = 1 transaction | `UPDATE cards` + `INSERT review_logs` cùng transaction; log là snapshot TRƯỚC khi chấm |
| Timestamp, uuid | ISO-8601 UTC hậu tố `Z`; uuid TEXT có gạch; `fsrs_params` TEXT JSON |
| Logic ở ReadoKit | Không target test nào link app → logic tách được để ở ReadoKit; view chỉ giữ state SwiftUI |
| Không thêm dependency | Trừ khi thật cần và fen xác nhận |

## 5. Đã chốt / còn mở

Nguồn duy nhất cho "đã chốt chưa"; command và agent không chép lại. Doc khác ghi khác → doc kia lệch, báo fen.

Q-01 iOS native · Q-02 SQLite local · Q-06 không lemmatize · Q-08 "đã thuộc" = `stability >= 21` · Q-10 giữ 10 phiên đọc mỗi collection có tên · Q-12 tắt steps · FR-19 leech = 6 lần Again (không gộp Q-08).

| Mục | Đã chốt | ADR |
|---|---|---|
| Q-03 | AI chỉ BYOK + Apple Intelligence (R1 chỉ on-device); không proxy | 049, 063 |
| Q-09 | FR-10 so khớp toàn app, không theo collection (kèm D1–D4) | 066 |
| Q-13 | Từ khớp khoá đã thuộc gập vào nhóm riêng, không xoá | 056 |
| FR-23 | PDF đọc tại chỗ, ≤ 1 PDF mỗi bộ có tên; lớp chữ trước, OCR khi rác/scan; EPUB ngoài | 058 |
| FR-02 | OCR `liveText`; không có bước soát OCR bằng LLM | 064, 065 |
| FR-24 | Gộp từ trùng: fen duyệt từng nhóm, giữ thẻ tiến bộ nhất, không tự động | 067 |

**Mở — phải hỏi fen:** Q-11 (jitter hai chế độ R2, chốt trước Phase 4).

## 6. Xử lý mơ hồ

1. Chiếu vào 6 nguyên lý `docs/specs/vision.md` (mục "Chống lại").
2. Kiểm non-goals NG-01..09 và §5. Dòng đã chốt có vẻ sai → báo fen, không tự sửa.
3. Còn mơ hồ và đụng dữ liệu/lịch ôn → hỏi fen. Thiếu hợp đồng → `/rplan` hoặc hỏi, không tự lấp.
4. Chỉ là chi tiết hiển thị → chọn cách đơn giản nhất, ghi lại lựa chọn.

Fen nhắc một công nghệ ("dùng X để…") là giả thuyết, không phải quyết định: nêu vấn đề gốc, so ≥ 2 phương án (kể cả không làm) rồi mới hỏi chốt. Idea thô → `/ridea`.

## 7. Cách làm việc

**Workflow**
- Idea thô → `/ridea`. Fen chốt hướng → `/rplan`. Đầu session → `/rstart`.
- Task nhỏ (bug UI, copy, test bổ sung khi FR/journey đã chốt) → code luôn, nói một câu vì sao skip plan.
- Đụng hợp đồng (schema, FR mới, transaction, protocol module, Q mở) → `/rplan`, fen confirm rồi mới code.
- Mỗi session một task trong "Tầng 2" của plan. Xong → `/rhandoff`; context dài → `/rhandoff` rồi `/clear`.
- Commit chỉ sau khi fen approve; format: `docs/agent/coding-conventions.md` §7b.
- Session cloud (`claude/*`) chỉ commit code + plan; không sửa brief, journal, ROADMAP; ADR ghi `ADR-NEW-<slug>`, số thật lấy khi merge vào `main`.
- Không build/test được (cloud, simulator hỏng) → không bịa số test, không ghi "xong".

**Bẫy môi trường**
- Simulator **iPhone Air**; `scripts/test.sh` tự boot. Treo > 10 phút → kill, báo fen chạy tay.
- TOCropViewController lấy từ SPM → build đầu cần mạng.
- `project.pbxproj` dùng synchronized folders (ADR-046): cấm sửa tay, cấm đọc nguyên. Thêm/xoá/chuyển file = tạo/xoá/`git mv` trong thư mục; đổi target, build setting, package → nhờ fen làm trong Xcode.
- Mọi file trong `app/` đều được compile, kể cả file chưa track → file nháp để ngoài `app/`.
- xcodebuild tự re-sort pbxproj → trước commit chỉ giữ hunk thật.
- Secret ở `.env`: không đọc, không grep đệ quy từ gốc repo; chỉ `.env.example` hợp lệ.
- Không `find` trần trên workspace (`.build/`, `DerivedData/`) — dùng Glob hoặc `git ls-files`.
