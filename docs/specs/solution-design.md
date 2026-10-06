# Solution Design v2 — Reado R1 (iOS native, local-first)

| Field | Value |
|---|---|
| Status | **v1.0 — owner duyệt 2026-09-18** (6/6 đề xuất mục 12.1 OK, hỏi-đáp trong session; ROADMAP task 0.6 ✅). Mọi chỗ MỞ gắn nhãn, không chỗ nào bị lấp thầm. **Toàn bộ "hợp đồng proxy API" (mục 4) và mọi đoạn nhắc `reado_proxy`/proxy dưới đây là bia mộ từ 2026-10-01 — ADR-049 bỏ proxy, không viết lại, chỉ ghi chú này** |
| Created | 2026-09-18 |
| Last updated | 2026-10-06 (workflow-docs-r1 T8 — mục 4 proxy thành bia mộ, đoạn proxy còn lại đổi sang hiện trạng) |
| Related | [prd.md](docs/specs/prd.md) (FR/NFR/M/A) · [prompt-spec.md](docs/agent/prompt-spec.md) (hợp đồng AI) · [db.md](docs/specs/db.md) (DDL tầng A) · [research/tech-stack.md](docs/research/tech-stack.md) (vì sao chọn stack) · [research/vocabulary.md](docs/research/vocabulary.md) (schema logic) · [research/review.md](docs/research/review.md) (FSRS) · [journeys.md](docs/specs/journeys.md) (J1–J6) · [coding-conventions.md](docs/agent/coding-conventions.md) (bản Swift) · [decisions-log.md](docs/decisions-log.md) (ADR) · [ROADMAP.md](ROADMAP.md) (tracker) |
| Phạm vi | Trả lời "thế nào" cho **R1**: module iOS, DDL & ranh giới transaction, adapter AI (Keychain/URLSession), capture. Không lặp lại spec — mỗi quyết định trỏ về FR/NFR nguồn |
| Tiền nhiệm | Bản PWA-gen (2026-09-08) → solution-design-pwa-gen.md (đã xoá, ADR-044) — bia mộ, không làm nền cho work mới |

**Tài liệu này tự chứa.** Nó giả định đã đọc nhóm docs ở bảng trên. Thứ gì docs kia đã
chốt thì doc này chỉ trỏ tới, không tranh luận lại; thứ gì còn mở thì ghi rõ **"MỞ"**
kèm mốc chốt, không tự điền. Code nền móng đã tồn tại (ROADMAP 1.1–1.4 ✅, 40 test xanh):
SD này **đối chiếu** phần đã có và **thiết kế** phần chưa có.

---

## 1. Doc này trả lời câu hỏi gì

[PRD mục 13](docs/specs/prd.md#13-out-of-scope) đẩy kiến trúc kỹ thuật ra ngoài với điều kiện
Q-01 → Q-03 phải chốt trước. Ba câu đó đã chốt 2026-09-17 (ADR-026..028) và được ghi
nhận hoàn chỉnh 2026-09-18. Doc này là bản đồ cho hai mốc:

- **Phase 1 (nốt):** task 1.5 — adapter AI nền tảng (mục 7 của doc này) + `web/`
  prototype journeys (1.6) nếu code về máy.
- **Phase 2:** walking skeleton — `chụp → phân tích → duyệt & sửa → lưu → ôn` với
  FR-01 → FR-02 → FR-03 → FR-09 → FR-11 + FR-12 + `is_default` của FR-17 (slice chốt
  ở mục 10 của doc này). FR-21 UI (thêm/chọn agent) là R1 nhưng **sau** skeleton — đi
  agent mặc định trước (lúc đó là proxy — bia mộ, ADR-049).

## 2. Nền quyết định đã chốt (không tranh luận lại)

> Ảnh chụp lúc nghiên cứu. Quyết định hiện hành: CLAUDE.md §5 + index ADR (`docs/decisions-log.md`).

| # | Quyết định | Nguồn |
|---|---|---|
| Q-01 | **Native iOS (SwiftUI)**; không Android, không PWA sản phẩm; `web/` = prototype chỉ | ADR-026 (đảo ADR-001) |
| Q-02 | **Local-first, SQLite trên máy**; dashboard/auth/sync = Later; FSRS chỉ chạy trên máy | ADR-027 (đảo ADR-002) |
| Q-03 | **BYOK OpenAI-compat (Keychain) + Apple Intelligence on-device**; không proxy (bản "hybrid" của ADR-028 là bia mộ) | ADR-049, 063 |
| Q-12 | Learning steps **tắt** — `enable_short_term = 0`; interval theo ngày | archive-roadmap-2026-09 §1 |
| — | FSRS = **`swift-fsrs` pin `4fbaf20` + `FSRSDefaults.defaultWv6`** (21 trọng số); `fsrs_version = 'fsrs-6'` ghi kèm | archive-roadmap-2026-09 §1, tech-stack 3 |
| — | Dữ liệu: uuid `TEXT` chữ thường có gạch nối · timestamp `TEXT` ISO-8601 **UTC `Z`** · `fsrs_params` `TEXT` JSON | tech-stack 7.2, db.md A.1 |
| — | `cards.state` **bốn** giá trị; `review_logs` = ảnh chụp **TRƯỚC** khi chấm, cùng transaction với `cards`; **KHÔNG** unique trên `vocab_items` | CLAUDE.md §4 |
| — | Capture = **camera/picker hệ thống**, không custom viewfinder; NFR-08 ≤ 3 thao tác | archive-roadmap-2026-09 §1 |
| — | Vuốt TRÁI = Again(1), PHẢI = Good(3); Hard/Easy là nút; undo nổi 1 bước (FR-12) | ADR-025 |
| — | Song ngữ xen kẽ theo đoạn (ADR-007) + nút nhỏ ẩn/hiện bản dịch (ADR-030); card duyệt rút gọn mở inline (ADR-008) | ADR-007/008/030 |
| Q-10 | **10 phiên đọc gần nhất mỗi collection có tên** (text + dịch + summary) vào `reading_sessions`; kho tạm **không** lưu phiên | ADR-029 |
| — | Nhắc ôn R1 = **local notification** trên máy (owner chốt 2026-09-18); không Web Push; APNs cân nhắc Later | archive-roadmap-2026-09 §1 |
| — | ~~Proxy Python + `google-genai`, hosted HTTPS~~ — bia mộ, bỏ theo ADR-049 | ADR-049 |
| — | Verify `example`: chạy ở **adapter đang active** (trên máy cho mọi agent; nhánh proxy cũ đã bỏ — ADR-049) — **không verify hai lần** | tech-stack 10.4 |
| — | `image_hash` là **idempotency key** cho FR-02; `analysis_events` phía proxy là bia mộ (ADR-049) | tech-stack 10.1, archive-roadmap-2026-09 §1 |
| — | Key user → **Keychain** theo `analysis_agents.id`; ghi-only; không SQLite, không export (FR-16), không lên server Reado | db.md A.2, FR-21 |
| — | `day_cutoff_hour` mặc định **4**, chỉnh được ở Settings R1 (ADR-031); `settings.timezone` IANA từ device | ADR-031, db.md |

## 3. Kiến trúc tổng thể

```
app/Reado (SwiftUI — mỏng)
  ├── AppModel (AppContainer — mục 10)
  └── Screens (Home/Capture/Review/… theo journeys)
        │  import ReadoKit
        ▼
app/ReadoKit (Swift package — toàn bộ logic, KHÔNG import SwiftUI)
  ├── Database/   SQLiteDatabase · Migration · Seeder          [✅ 1.3]
  ├── Review/     ReviewScheduler · ReviewService · ReviewQueue [✅ 1.4]
  │               · CardSnapshot
  ├── Time/       DayBoundary                                   [✅ 1.4]
  ├── Clock · Identifier · ISOTimestamp                        [✅]
  ├── Analysis/   protocol + openai client + Apple Intelligence [✅ — mục 7]
  │               + KeychainStore + verify engine + Prompt
  ├── Vocab/      repo collections/vocab_items/settings/        [◻ Phase 2]
  │               sessions + use case capture-lưu
  └── Capture/    xử lý ảnh trước khi gửi (mục 8)               [◻ 2.1]
```

**Luật một chiều:** `Reado` (UI) import `ReadoKit`; `ReadoKit` không import SwiftUI,
không biết UX. Kiểu của thư viện ngoài (FSRS) không lọt ra API công khai của ReadoKit —
đúng như `ReadoRating`/`ReviewOutcome` đang làm. Mọi timestamps app-side đi qua `Clock`
injectable (đã có `SystemClock`/`FixedClock`) — không gọi `Date()` trần trong logic.

Hệ quả thực tế từ code 1.1–1.4: `AppModel` mở SQLite ở Application Support/
`Reado/reado.sqlite3`, chạy `Migration.run` rồi `Seeder.seed(timezone:)`. Scaffold này
đang đồng bộ trên main; khi có call network (1.5/2.2) phải đưa chúng ra khỏi main và
bọc container (mục 10).

## 4. ~~Hợp đồng proxy API~~ — bia mộ

Bỏ theo ADR-049 (2026-10-01): R1 không còn proxy Reado, app gọi thẳng agent BYOK hoặc Apple Intelligence. Bản cuối của hợp đồng:
`git show f634bf8:docs/specs/solution-design.md` (mục 4).

## 5. DDL & nguồn sự thật

**Nguồn DDL duy nhất để áp dụng = mã** `app/ReadoKit/.../Database/Migration.swift` v1
(1.3 đã dựng, đối chiếu 40 test) — khớp [db.md tầng A](docs/specs/db.md#a-r1--sqlite-trên-máy)
từng dòng: 7 bảng v1 + bảng `encounters` (migration v4, FR-22/ADR-048) + bảng
`pdf_sources` (migration v5, FR-23/ADR-058, §8b) + index, **đủ 20 cột `settings` kể cả `timezone`** (điểm "bổ sung
settings.timezone" của task 0.6 đã nằm trong migration, seed lấy `TimeZone.current`,
không tự bịa). SD **không copy DDL lần ba** — ba bản (doc, SD, code) là nguồn drift.
Mọi đổi schema tương lai đi qua migration đánh số + `PRAGMA user_version`.

Các app-rule của db.md A.2 giữ nguyên:

- `PRAGMA foreign_keys = ON` bật cho **mọi** connection (đã làm ở `SQLiteDatabase.init`).
- Seed = **một transaction** idempotent (đã làm ở `Seeder`): kho tạm `is_default=1`;
  agent placeholder (trước ADR-049 là `reado_proxy`) id `00000000-0000-4000-a000-000000000001` (app-rule:
  không xoá được); settings id=1 với timezone device, `enable_short_term=0`,
  `fsrs_version='fsrs-6'`, `active_agent_id` = placeholder.
- `COLLATE NOCASE` chỉ gập ASCII — **gập hoa thường tiếng Việt là việc tầng app** (trim +
  so khớp không dấu) khi làm FR-20. Cơ chế cụ thể: **MỞ** — ghi ở ROADMAP mục 4, chốt
  lúc 3.10. ROADMAP mục 4 đã ghi nhận; đừng im lặng "sửa" bằng cách bỏ collation.

## 6. Ranh giới transaction

Mỗi khối dưới là **một transaction** — không có trạng thái nửa chừng quan sát được:

| # | Khối | Quy tắc | Trạng thái |
|---|---|---|---|
| 1 | Chấm thẻ | `UPDATE cards` + `INSERT review_logs` cùng transaction — `ReviewService.record` | ✅ 1.4 |
| 2 | Undo (FR-12) | `DELETE` đúng dòng log vừa ghi + `UPDATE cards` về snapshot TRƯỚC, cùng transaction — `ReviewService.undo` | ✅ 1.4 |
| 3 | Seed | Một transaction, idempotent — `Seeder.seed` | ✅ 1.3 |
| 4 | Lưu capture (2.3/2.4) | `INSERT vocab_items[]` + `INSERT cards` (receptive, `state='new'`, `due_at` hôm nay) — cùng transaction; một item lỗi → rollback cả trang, không lưu bộ dở | ◻ |
| 5 | Lưu phiên đọc (3.4) | `INSERT reading_sessions` + trim còn 10 mới nhất/collection — cùng transaction; kho tạm không ghi phiên (ADR-029) | ◻ |
| 6 | FR-17 chuyển collection | `UPDATE vocab_items SET collection_id` — **không đụng cards/FSRS** (state giữ nguyên); lô lớn chia theo từ khoá, không phá bảng | ◻ |
| 7 | FR-20 gộp CSV | Một transaction; 0 dòng chọn = không ghi | ◻ sau skeleton |
| 8 | Lưu trang có từ cũ (FR-22) | `INSERT encounters(kind='seen')` cho mỗi vocab đã có trong kho — **cùng transaction** với khối 4 + 5 (`EncounterRepository.insertSeen`, không tự mở transaction; `inTransaction` không lồng được) | ✅ repository (T1) · ◻ nối vào lưu trang (T2) |
| 9 | "Nhận ra" khi đọc (FR-22) | Kiểm "đã nhận ra hôm nay chưa" + `INSERT encounters(kind='recognized')` — một transaction riêng (`EncounterRepository.recordRecognized`); không đụng `cards`/`review_logs` | ✅ T1 |
| 10 | Gộp từ trùng (FR-24) | Mọi nhóm đã chọn trong MỘT transaction — `DuplicateMerge.merge`; chuyển `review_logs`/`encounters`, thêm `seen`, xoá dòng gộp; không đụng FSRS thẻ giữ (ADR-067) | ✅ T1 + T2 |

Ràng buộc FK đã định hình sẵn ranh giới: `vocab_items ON DELETE RESTRICT` (xoá
collection phải xử lý vocab trước — rule ở PRD FR-17), `cards ON DELETE
CASCADE`, `reading_sessions ON DELETE CASCADE`, `encounters ON DELETE CASCADE`, `settings.home_shortcut_* ON DELETE
SET NULL`, `settings.active_agent_id` NOT NULL → xoá agent đang active phải fallback
placeholder **trong cùng lúc** cập nhật settings.

## 7. Adapter AI — nền tảng FR-21 (task 1.5)

### 7.1 Protocol

```swift
public protocol PageAnalyzer: Sendable {
    func analyze(
        image: Data, imageMime: String,
        cefr: String, imageHash: String
    ) async throws -> PageAnalysis

    // FR-23/ADR-058 (pdf-reader-r1 T2) — lớp chữ PDF, không OCR. sourceHash thay
    // imageHash (cùng field meta.imageHash, giá trị là hash của text). Xem §8b.
    func analyzeText(
        _ pageText: String, cefr: String, sourceHash: String
    ) async throws -> PageAnalysis
}
```

`PageAnalysis` (kiểu public của ReadoKit, không rò wire provider): `segments`,
`vocabulary: [VocabularyItemIn]` (mỗi item kèm `verification`), `summaryVI`, `meta`.
UI chỉ thấy protocol này — đổi provider phía user không đụng SwiftUI (đúng ADR-028).

### 7.2 Hai implementation

- ~~`ReadoProxyClient`~~ — bia mộ, bỏ theo ADR-049 (hợp đồng cũ: `git show f634bf8:docs/specs/solution-design.md`, mục 4).
- **`OpenAICompatClient`** — `URLSession` tới `{base_url}/chat/completions` với `model`
  trong `analysis_agents`; key đọc từ Keychain (`Authorization: Bearer …`) chỉ ngay
  trước khi ghép header — không nằm trong query, không log. Ảnh: data URI trong
  message multimodal OpenAI. `response_format`: **MỞ** — json_object vs JSON Schema
  theo provider (OpenRouter/Groq khác nhau); chốt khi làm 3.11. App tự verify `example`
  bằng engine 7.3 rồi gắn nhãn.

### 7.3 Verify engine (prompt-spec mục 6)

Một engine dùng chung trong ReadoKit: chuẩn hoá khoảng trắng/dấu câu, đối chiếu
`example` với text `segments` ghép; đầu ra ba nhãn `verified/suspect/unverified`
(suspect = gần khớp — ngưỡng "gần": **MỞ**, chốt ở 0.8 khi có số liệu thật). Chạy ở
đúng adapter đang active; không verify hai lần.

### 7.4 KeychainStore

Key user lưu theo `analysis_agents.id`; ghi-only về phía UI (đọc chỉ trong
`OpenAICompatClient`); masked ở màn list; không vào SQLite, không vào FR-16, không log.
Xoá agent → xoá key cùng lúc; xoá agent đang active → `active_agent_id` fallback về
placeholder trong cùng thao tác (không bắt buộc cùng transaction DB — Keychain ngoài DB,
nhưng thứ tự: sửa settings trước, xoá key sau khi settings đã trỏ đi nơi khác).

### 7.5 Prompt

Prompt sống trong ReadoKit (`Analysis/Prompt.swift`) kèm `PROMPT_VERSION` (int, start 1
khi có baseline chốt). Prompt baseline của owner: **MỞ — chưa có** (ROADMAP task 0.3
chặn 0.8/A-02); code dev/xác minh dùng bản dựng lại ở prompt-spec mục 3, **không** coi
là bằng chứng A-02. ATS: `base_url` bắt buộc HTTPS trừ loopback/RFC1918 (db.md A.2.2
app-rule); exemption nếu cần — cấu hình lúc làm Settings 3.11.

### 7.6 Lỗi & trạng thái (FR-02 c filter + FR-21)

401 / timeout / JSON sai schema → lỗi có mã + CTA về Settings (FR-21), **không lưu
vocab dở**. Progress rõ trong lúc chờ (FR-02). Retry = gửi lại cùng hash — an toàn vì
idempotency theo `image_hash`. `URLSession` timeout: đề xuất **60s** (NFR-01 p95 ≤ 30s + margin) — khoá khi đo thật.

## 8. Capture (FR-01)

Camera/picker **hệ thống** (`UIImagePicker`/`PhotosUI`) — không custom viewfinder.
Preview → crop/xoay trên máy → encode JPEG (WebP khi nén hơn — **MỞ**, theo đo A-06)
→ report hash → gửi. Collection picker inline, tạo mới ngay tại chỗ; không chọn → kho
tạm. NFR-08: ≤ 3 thao tác từ mở app tới chụp. Ảnh chỉ trên đường từ máy tới request —
**không persist** (NFR-04), buffer memory solution sau. Đa trang một lúc: **MỞ** (FR-01
giả định một trang/lần; hỏi owner khi chạm).

## 8b. Đọc PDF trong Reado (FR-23, ADR-058, pdf-reader-r1)

Cửa thu từ vựng thứ hai, song song §8. Không chép file PDF vào app — chỉ
security-scoped bookmark (`URL.bookmarkData`) + số trang, trong bảng `pdf_sources`
(db.md A.2).

- **Reader:** `PDFView` (PDFKit, framework hệ thống — không thêm dependency), lật
  từng trang, tự lưu `page_index` khi đổi trang (debounce).
- **Lớp chữ trước, OCR sau:** `PDFPageText.extract(page:)` lấy hàng kèm toạ độ
  (`PDFSelection`, không dùng `page.string` trần vì thiếu ranh giới đoạn/thứ tự cột),
  tự dò `\n`/`\n\n` bằng hình học như `PageOCR` đã làm (ADR-037), rồi **chấm chất
  lượng** lớp chữ (độ dài, ký tự lạ `(cid:`/`\u{FFFD}`, tỷ lệ chữ cái, tỷ lệ từ giống
  tiếng Anh). Chữ tốt → `PageAnalyzer.analyzeText` (prompt riêng, prompt-spec mục
  3b). Rác hoặc trang chỉ là ảnh → vẽ trang độ phân giải cao
  (`page.thumbnail(of:for:)`, không qua `ImageCompressor` — mức nén 1600px của
  ImageCompressor đặt ra cho thời ảnh còn upload, giờ OCR chạy trên máy) rồi đi đúng
  pipeline §8/§7 hiện có.
- **Transaction:** `pdf_sources` là một câu lệnh đơn (attach/updatePage/detach),
  không đụng transaction #4/#5 (lưu vocab + session) đã có.
- **Schema/DDL:** db.md A.2 bảng thứ 9. Prompt: prompt-spec.md mục 3b.

## 9. Thời gian & ngày học

Đã có và **bắt buộc tái sử dụng**: `Clock` injectable; `DayBoundary.window(now:,
timezone:, dayCutoffHour:)` trả `[start, end)` chuỗi ISO-8601 UTC `Z` (so sánh
lexicographic = so sánh thời gian). `settings.timezone` IANA seed từ device;
`day_cutoff_hour` mặc định 4 (ADR-031). Mọi phép "hôm nay" — hàng đợi FR-11, hạn mức
thẻ mới, streak FR-14 — đi qua DayBoundary, không dùng nửa đêm hệ thống (PRD FR-11
criterion). `due_at` lưu ISO Z; queue so `due_at <= window.end`.

## 10. Walking skeleton wiring (Phase 2)

Thứ tự theo ROADMAP 2.1→2.6. Fix dần `AppModel` scaffold trong lúc đi qua các bước:

1. **2.1 Capture** — màn Capture theo J1 + mục 8; hash + nén.
2. **2.2 Analysis** — `AppContainer` mở ReadoKit, chọn `PageAnalyzer` = agent đang active;
   gọi `analyze`, hiện progress, kết quả vào buffer in-memory (chưa lưu — FR-02).
3. **2.3 Duyệt & sửa** — item `unverified`/`suspect` lên đầu, **bỏ chọn sẵn** (FR-02/03);
   sửa field; chọn collection; commit = transaction #4. Note FR-03: sửa lại `example`
   phải chấp nhận khi chưa khớp gốc — hành vi user chủ động (đã chốt lúc 2.3: sửa example không đổi nhãn verification).
4. **2.4 `is_default`** — kho tạm luôn là collection đích khi không chọn; Home shortcut
   theo journeys.
5. **2.5 Hàng đợi + vuốt** — `ReviewQueue` hai nhánh (shape đã chốt khi task này ship); vuốt theo ADR-025; undo theo `ReviewService.undo`; lật card mở chi tiết (ADR-008).
6. **2.6 e2e** — owner chạy thật trên iPhone gồm ôn offline (NFR-03); `xcodebuild test`
   xanh là bằng chứng tối thiểu, không thay thế.

FR-09 (chọn item cho review sau save) nằm trong 2.3/2.4. Test đối chiếu trực tiếp
GWT của từng FR — acceptance criteria trong PRD là test case (ROADMAP hợp đồng test).

## 11. Đo lường (NFR-01/02)

R1 chỉ đo và ghi nhận, chưa chốt ngưỡng (PRD mục 10). Không còn telemetry tập trung (proxy bỏ — ADR-049); đo cục bộ ở app, nhật ký DEBUG qua `DebugTrace` (ADR-037).

## 12. Đề xuất mới của doc này + chỗ MỞ

### 12.1 Đề xuất của SD — **đã duyệt 6/6 (owner 2026-09-18)**

1. Hợp đồng proxy = **multipart + `X-Reado-Image-Hash`** hiện tại (mục 4.1 cũ — bia mộ, ADR-049).
2. `verification` per item do **adapter đang active** tính (proxy hoặc máy) — một engine.
3. Prompt + `PROMPT_VERSION` sống trong **ReadoKit** (mục 7.5).
4. Hash idempotency tính trên **ảnh sau crop/nén** (mục 4.2 cũ — bia mộ, ADR-049).
5. `AppContainer` actor hoá thay `AppModel` khi vào 2.2.
6. DDL giữ **một nguồn áp dụng = migration code**, docs làm bản đối chiếu (mục 5).

### 12.2 Chỗ còn mở, và chỗ doc này từng ghi mở nhưng đã đóng

Còn mở — không lấp:

| Việc | Mốc |
|---|---|
| Prompt baseline A-02 (owner dán, nguyên văn) | 0.3 — chặn 0.8 |
| ~~Hosting vendor · auth proxy · FastAPI/Flask~~ | đã đóng — proxy bỏ (ADR-049) |
| ~~Model Gemini cụ thể~~ | đã đóng — không còn proxy Gemini (ADR-049) |
| `response_format` từng provider OpenAI-compat · telemetry BYOK | 3.11 |
| Ngưỡng "gần khớp" verify · giới hạn item/trang · đa trang một lúc | 0.8 / khi chạm |
| `edited_count` FR-03 | Vẫn mở — task 2.3 không thêm cột này; code không có field |
| Q-11 (jitter R2) | `CLAUDE.md` mục 5. Leech đã chốt = 6 |

Đã đóng — đừng hỏi lại:

| Việc | Chốt |
|---|---|
| Shape query `ReviewQueue` | Task 2.5 ship (hai nhánh). FR-18 thêm `scope` sau đó |
| Gập hoa thường tiếng Việt | 2026-09-24: `lowercased()` Unicode, giữ dấu |
| Q-06 / Q-08 / Q-09 / Q-10 | `CLAUDE.md` mục 5 |

Tất cả các chỗ còn mở, nếu người implement sau "thấy hiển nhiên" thì **giá trị của
hiển nhiên không được dùng** — việc cần làm là hỏi owner.