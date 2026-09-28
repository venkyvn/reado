> 📍 **Tracker tiến độ HIỆN HÀNH — thế hệ v2 (iOS native), kế nhiệm `MVP_PLAN.md`.**
> File này là nguồn duy nhất về *"đang tới đâu, làm gì tiếp, kiểm gì thì xong"*.
> Nguồn về *"xây cái gì, vì sao"* vẫn là bộ docs sản phẩm (`CLAUDE.md` → `docs/`).
> Tracker thế hệ PWA (09-08..09-09) đã chuyển vào
> `mvp-plan-pwa-gen.md` (đã xoá, ADR-044) — mọi tham chiếu
> "MVP_PLAN mục N" trong tài liệu cũ trỏ về đó, KHÔNG theo task trong đó nữa.

# ROADMAP — Reado: tracker tiến độ & checklist (v2)

| Field | Value |
|---|---|
| Created | 2026-09-18 |
| Last updated | 2026-09-24 |
| Thế hệ | v2 — native iOS + local-first SQLite + proxy hybrid (chốt 2026-09-17) |
| Tiền nhiệm | `MVP_PLAN.md` (PWA-gen) → `mvp-plan-pwa-gen.md` (đã xoá, ADR-044) |
| Phase hiện tại | **Phase 3 — đang chạy.** Đã xong 3.1 FR-16 Export (`d23e19a`) + 3.2 FR-19 Leech (`7ea032e`) + 3.3 FR-04 Capture failure (`fb7f53a`, 91/91 test) + 3.6 FR-14 Daily Progress (`7263fb1`, 98/98) + 3.7 FR-15 Settings (`e1f5d5a`, 107/107) + 3.5 FR-08 + FR-17 (`0a5de27`, 122/122) + 3.9 FR-18 (`5060ada`, 129/129) + **3.10 FR-20 (`602ded5`, 141/141)** + **3.12 Reminder (`caa958f`, 148/148)** + **shortcut Home FR-17 (`a48b1e6`, 158/158)** + **T0 cửa Dữ liệu (`2907666`)** + **T1 J2 hub + FR-05/06 (`a7a2e15`, 165/165)** + **T2 J-R1-P heatmap (`55c2685`, 171/171)**. Toàn bộ task không-gate-Q-*/proxy đã cạn. **Q-06/08/09 đã chốt 2026-09-22 (ADR-032).** Còn chặn: 3.8 (chỉ còn dữ liệu thật) · ngưỡng leech FR-19 (số lapse) · 3.11 (0.7 proxy + 1.5 adapter) · 3.13 (dữ liệu thật) · cram FR-18 (R2) · "Từ session collect thêm" (xem §4) |
| Nguồn nội dung | [docs/prd.md](docs/specs/prd.md) (FR-01..FR-21) · [docs/research/tech-stack.md](docs/research/tech-stack.md) · [docs/agent-rulebook.md](docs/agent/agent-rulebook.md) (mục 6: walking skeleton) · [docs/journeys.md](docs/specs/journeys.md) (J1–J6 + J-R1-*, thứ tự prompt UI) · [docs/session-brief.md](docs/session-brief.md) |

---

## 0. Cách dùng file này

1. **Bootstrap session mới:** `CLAUDE.md` → `/rstart` (session-brief) → file này
   (nếu task đụng tiến độ) → làm việc → cập nhật mục 2 và mục 6 **cuối mỗi session**. Đừng tin trí nhớ.
2. **Trạng thái item:** `⬜` chưa làm · `🔄` đang làm (kèm ngày + người) · `✅` xong (kèm ngày + bằng
   chứng) · `⛔` blocked (kèm lý do) · `📌` quyết định đã chốt.
3. **Không xoá dòng đã xong** — đánh dấu ✅ giữ nguyên để truy vết, đúng quy ước bia mộ của repo.
4. **"Xong" phải có bằng chứng thật**: lệnh đã chạy, kết quả, link file. Không ghi "xong" không bằng chứng.
5. **Mâu thuẫn docs vs file này:** về *tiến độ điều hành*, file này thắng; về *spec sản phẩm*, docs
   thắng. Thấy mâu thuẫn → ghi vào mục 4, đừng im lặng sửa.
6. **Nhật ký (mục 6) là append-only** — không sửa dòng cũ.
7. **Trạng thái theo máy:** bản đồ máy cụ thể (code về chưa, env nào) nằm ở
   [docs/session-brief.md](docs/session-brief.md) — file này chỉ ghi trạng thái *sản phẩm*, không ghi máy.

### Hợp đồng test (kế thừa từ tracker PWA, vẫn hiệu lực)

- **Mode:** off — không TDD strict. **Decision:** mỗi FR chỉ xong khi **toàn bộ** criteria
  Given/When/Then của nó trong PRD pass (acceptance criteria là test case — kho luật mục 4).
- **Verification:** mỗi task ở mục 3 ghi rõ bằng chứng phải có trước khi đánh ✅; với code Swift:
  `xcodebuild test` + build sạch; với proxy: chạy thật từ ngoài máy (không được chỉ localhost).

---

## 1. Quyết định đã chốt — thế hệ v2

| # | Vấn đề | Quyết định (2026-09-17 trừ khi ghi khác) | Hệ quả trực tiếp |
|---|---|---|---|
| Q-01 | Platform | 📌 **Native iOS (SwiftUI)**. Không Android, không PWA sản phẩm. `web/` chỉ là prototype journeys | Code đi vào `app/` (Xcode). PWA hiện có trong `app/` sẽ được dọn đi ở task 1.1 |
| Q-02 | Dữ liệu | 📌 **Local-first, SQLite trên máy**. Dashboard sản phẩm = Later | Offline review miễn phí (NFR-03). DDL theo [docs/db.md](docs/specs/db.md) tầng A |
| Q-03 | API key | 📌 **Hybrid:** proxy Reado (key `.env` server) = mặc định; user thêm agent OpenAI-compat + key **Keychain**, chọn active cho FR-02 (FR-21) | Key sản phẩm không nằm trên client; key user không plaintext, không lên server. Proxy phải **hosted HTTPS** |
| Q-12 | Learning steps trong ngày | 📌 **Tắt** (2026-09-08, giữ) | Interval tính theo ngày; `state='learning'` không xuất hiện ở R1 |
| — | FSRS | 📌 **`swift-fsrs`** với **`FSRSDefaults.defaultWv6`** (21 trọng số). `FSRS()` không tham số = FSRS-5 — silent breakage (NG-09: không tự viết SRS) | Weight v6 + `fsrs_version` ghi vào DB |
| — | Capture | 📌 **Camera / picker hệ thống**, không custom viewfinder; NFR-08 ≤ 3 thao tác từ mở app tới chụp | FR-01 làm theo thế |
| — | Data type | 📌 uuid `TEXT` chữ thường có gạch nối · timestamp `TEXT` ISO-8601 **UTC hậu tố `Z`** · `fsrs_params` `TEXT` JSON + cột `fsrs_version` | Mapping đầy đủ: tech-stack mục 7.2 |
| — | Schema | 📌 `cards.state` có **bốn** giá trị; `review_logs` lưu snapshot **TRƯỚC** khi chấm, cùng transaction với update `cards`; **KHÔNG** có `unique` trên `vocab_items` | Chống trùng ở FR-10 lúc trích xuất |
| — | Slice build đầu | 📌 **Walking skeleton** = FR-01, FR-02, FR-03, FR-09, FR-11, FR-12 + `is_default` của FR-17 (kho luật mục 6). FR-21 **sau** skeleton | Phase 2 của file này |
| — | Tombstones | 📌 FR-07 và FR-13 đã bỏ (không implement, không xoá dòng); NG-07 một input path là ảnh chụp; NG-08 không hỏi ngữ pháp | Dính tới là dừng |
| — | Reminder | 📌 Không Web Push (tech-stack mục 8.3). R1 nhắc ôn = **local notification** trên máy (owner chốt 2026-09-18); APNs khi Later cần nhắc lúc app không mở | Task 3.12 |
| — | Gập hoa thường tiếng Việt (FR-20) | 📌 **Hạ chữ thường Unicode, GIỮ dấu** (owner chốt 2026-09-24): `"SÁCH"≈"sách"`, `"Đá"≈"đá"`, nhưng `"Đá" ≠ "Đã"` — dùng chung `normalizedTerm` lúc trim/insert (SQLite NOCASE chỉ gập ASCII) | Khớp collection FR-20 + cảnh báo trùng term |
| — | Proxy framework | 📌 **Python + `google-genai`** — owner duyệt đề xuất 6.2 ngày 2026-09-18 (framework cụ thể kiểu FastAPI chốt trong SD 0.6) | Task 0.7 |
| Q-10 | Buffer cuộn + session collection | 📌 **10 phiên đọc gần nhất PER NAMED COLLECTION** vào bảng `reading_sessions` (text + dịch + summary), để đọc lại trang cuối — chốt 2026-09-18 ([ADR-029](docs/decisions-log.md#adr-029--q-10-10-phiên-đọc-bền-per-collection-có-tên-đảo-v03-buffer-trôi), đảo v0.3 buffer-trôi). **Kho tạm KHÔNG lưu phiên**; phiên thứ 11 trôi (trim trong transaction) | Task 3.4 (FR-05/06) |
| Q-06 | Lemmatize ở FR-10 | 📌 **Không lemmatize** — mỗi word form một dòng (`running` ≠ `run`, `took` ≠ `take`). Chốt 2026-09-22 (ADR-032) | `term_normalized` giữ nguyên form, khớp FR-20 |
| Q-08 | Ngưỡng "đã thuộc" (FR-10) | 📌 **FSRS `stability ≥ 21 ngày`** = Anki "mature" (interval ≥ 21 ngày). Chốt 2026-09-22 (ADR-032), không đo bằng số lần | Bộ lọc FR-10: `state='review'` + `stability >= 21` |
| Q-09 | Phạm vi so khớp "đã thuộc" | 📌 **Theo collection**, không toàn cục — nghĩa mới của từ cũ vẫn thêm khi sang sách khác. Chốt 2026-09-22 (ADR-032) | Truy vấn FR-10 scope theo collection đang chụp |

**Chốt product-behavior cho UI ôn tập** (đối chiếu lại khi SD, không mù quáng):
UI-1 song ngữ **xen kẽ theo đoạn** (ADR-007) · card duyệt **rút gọn mở inline** (ADR-008) ·
📌 vuốt TRÁI = **Again(1)** · PHẢI = **Good(3)**, Hard/Easy là nút, chạm lật, undo nổi 1 bước, đủ 4 mức (ADR-025 — chốt 2026-09-18 theo journeys mục 4, **thay** ADR-009) ·
rich vocab **4 tags / 3 synonyms / 3 antonyms** cột JSON (ADR-010, RV-1) ·
export/import là phao cứu sinh nên làm sớm trong R1 (tinh thần cũ, scope v2 ở PRD mục 10).
Các ADR thuần PWA-tech (016 shadcn · 017 zustand · 018 i18n · 021 lazy · 022 a11y web) **không** chuyển sang SwiftUI — quyết định lại lúc SD, không chép tự động.

**CHƯA CHỐT — không tự quyết, không lấp:**
Q-11 stability jitter hai chế độ R2 (chốt trước Phase 4) ·
ngưỡng leech FR-19 = 6 (owner chốt 2026-09-24, không gộp Q-08) ·
hosting vendor proxy (chốt lúc deploy — HTTPS + không cold-start 30s) · model Gemini (chốt ở 0.8, bước A-01/A-02).
`settings.timezone` đã có trên schema (seed từ device, task 1.3) — không còn thiếu.
(Đã đóng 09-17/09-18: Q-01/02/03 pivot · local-vs-APNs = local cho R1 · framework proxy = Python · encrypted.txt = xoá · chỗ đặt code PWA cũ.
Đã đóng 2026-09-22: Q-06 không lemmatize · Q-08 stability ≥ 21 · Q-09 theo collection.)

---

## 2. Bản đồ trạng thái (đọc nhanh nhất)

| Thứ | Trạng thái | Ghi chú |
|---|---|---|
| Bộ docs sản phẩm v2 (vision, PRD v0.9 → FR-21, tech-stack, db, journeys, prompt-spec) | ✅ Đồng bộ 2026-09-17/18 | PRD nghỉ ở v0.9; chờ bổ sung khi code (chủ yếu FR-20/FR-21 chi tiết) |
| Tracker: thay MVP_PLAN bằng ROADMAP (file này) | ✅ 2026-09-18 | Bản PWA-gen đã vào `mvp-plan-pwa-gen.md` (đã xoá, ADR-044) |
| ADR cho pivot Q-01/Q-02/Q-03 | ✅ 2026-09-18 — owner duyệt OK hết (task 0.2 đóng) | `docs/decisions-log.md` cuối file có **ADR-026..028** (ghi bổ sung sau 029..031) — bản ghi pivot v2 hoàn chỉnh |
| Solution design v2 (proxy contract, DDL, transaction, adapter) | ✅ 2026-09-18 — owner duyệt **6/6 đề xuất 12.1** (task 0.6) | File v2 tại chỗ `docs/specs/solution-design.md` (status v1.0); bản PWA → `docs/archive/solution-design-pwa-gen.md` (đã xoá, ADR-044); mọi chỗ MỞ gắn nhãn kèm mốc chốt (mục 12.2) |
| Proxy Reado (Python hosted) | ⬜ Chưa có | Task 0.7; chưa chốt hosting vendor + model |
| Kiểm chứng A-01/A-02 trên kiến trúc v2 (ảnh thật qua proxy) | ⛔ Chưa chạy — chờ prompt baseline | Task 0.8; prompt baseline owner còn trống (kho luật mục 8) |
| Code iOS (Xcode project + SwiftUI) | ✅ Nền móng 2026-09-18 — 1.1–1.4 | `app/` = `Reado.xcodeproj` + `ReadoKit` (Swift package) + `ReadoTests`; PWA cũ đã xoá theo lệnh owner; 51/51 test xanh (2026-09-19, Simulator) |
| Walking skeleton ngoài nền móng (1.5 adapter FR-21, FR-01/02/03/09 shell UI) | 🔄 FR-01 ✅ (`8a743f8`) · FR-02 phần local ✅ mock (`e5fba85`) · FR-03/09 ✅ (`cd85123`, 56/56) | 1.5 chờ code — owner giao agent khác (2026-09-18); FR-02 bỏ được rào "proxy chưa có" nhờ mock (owner chốt 19-09), bằng chứng thật vẫn chờ 0.7 |
| `web/` prototype (Vite + React 19, journeys J1–J6) | ❌ Đã xoá cùng pivot (128ae52) | Thiết kế UI sống ở [docs/specs/journeys.md](docs/specs/journeys.md) + `design-system/reado`; task 1.6 chờ định nghĩa lại |
| Walking skeleton (FR-01/02/03/09/11/12 + is_default) | ⬜ | Phase 2 — DoD: owner chạy end-to-end thật trên iPhone, kể cả ôn offline |
| Phần còn lại của R1 | ⬜ | Phase 3 — thứ tự: phao cứu sinh + dữ liệu tích luỹ trước |
| R2 | ⬜ Cổng cứng: R1 dùng hằng ngày ≥ 4 tuần + owner GO | Phase 4 — chốt Q-11 trước |
| Later (sync, dashboard, multi-user) | ⬜ Chưa mở | [docs/multi-client-sync.md](docs/research/review.md) + [docs/sync-server-ddl.md](docs/specs/sync-server-ddl.md) giữ làm Note |

---

## 3. Checklist theo phase

> Ký hiệu cột Phụ thuộc: số = task trong file này; OW = cần owner. Mỗi ✅ phải kèm bằng chứng.

### Phase 0 — Tiền đề & gate (không GO chưa code sản phẩm)

| # | Task | Phụ thuộc | Trạng thái | Bằng chứng "xong" |
|---|---|---|---|---|
| 0.1 | Mang code iOS + `web/` prototype về máy làm việc, hoặc chỉ định việc khác | OW | ⛔ chờ owner | Thư mục/code hiện diện trên máy; session-brief cập nhật |
| 0.2 | Ghi ADR cho pivot: đảo ADR-001 (iOS native), ADR-002 (local-first SQLite, BE đầy → Later), ADR-003 (hybrid BYOK) vào decisions-log | OW duyệt | ✅ 2026-09-18 — owner duyệt **OK hết** | ADR-026..028 trong `docs/decisions-log.md` (cuối file, sau 029..031), mỗi ADR có "Thay thế đã loại"; chữ ký owner qua hỏi-đáp 2026-09-18 |
| 0.3 | Owner dán prompt baseline thủ công → mở khoá A-02 | OW | ⛔ chặn đường | Prompt nguyên văn vào prompt-spec mục 2 (chỗ trống hết trống) |
| 0.4 | Cách xử lý `qr/v2/encrypted.txt` | OW | ✅ 2026-09-18 — owner chốt **xoá luôn** | Đã xoá `qr/v2/encrypted.txt` (85KB, chunk RD32 `reado-docs.tar.bz2` 01/19) + `qr/v2/restore.py` (tool giải gói đi kèm); quyết định ghi mục 4 + nhật ký mục 6 |
| 0.5 | Chốt nhóm còn mở phục vụ SD: hosting vendor · model Gemini · local-vs-APNs (nếu reminder ∈ R1) · framework proxy | OW | ✅ 2026-09-18 — chốt 2, defer 2 | **Chốt:** framework proxy = Python + `google-genai` (duyệt đề xuất 6.2); R1 nhắc ôn = **local notification** (APNs Later). **Defer có quyết định:** hosting vendor → chốt lúc deploy (HTTPS + không cold-start 30s); model → chốt ở 0.8. Đã ghi mục 1 + tech-stack mục 11 |
| 0.6 | **Solution design v2**: thay `docs/specs/solution-design.md` tại chỗ (bản PWA → `docs/archive/solution-design-pwa-gen.md` (đã xoá, ADR-044)). Nội dung: module iOS, hợp đồng proxy API, DDL SQLite từng cột (bổ sung `settings.timezone`), ranh giới transaction, adapter Keychain/URLSession; coding-conventions Swift thay bản TS | 0.5, 1.3 | ✅ 2026-09-18 — owner duyệt **6/6 đề xuất 12.1** (hỏi-đáp trong session) | `docs/specs/solution-design.md` bản v2 thay tại chỗ (status v1.0); mục 12.1 = 6 đề xuất đã duyệt, mục 12.2 = chỗ MỞ kèm mốc; chữ ký owner qua hỏi-đáp 2026-09-18 |
| 0.7 | **Proxy Reado** theo đề xuất 6.2 tech-stack: Python + `google-genai`, HTTPS hosted, structured output, `image_hash` làm idempotency key, ghi `analysis_events`, xác minh `example` khi active = `reado_proxy` | 0.5, 0.6 | ⬜ | App gọi thật từ ngoài máy qua HTTPS, trả item `verified/suspect/unverified` đúng schema |
| 0.8 | Script kiểm chứng **A-01 + A-02** trên v2: vài ảnh sách thật qua proxy, so structured output với prompt baseline owner → Go/No-Go vào Phase 1 | 0.3, 0.7 | ⛔ chặn bởi 0.3 | Kết quả so sánh ghi mục 6 + nhật ký; owner chấm GO ở mục 2 |

### Phase 1 — Nền móng iOS (sau GO Phase 0)

| # | Task | Phụ thuộc | Trạng thái | Bằng chứng "xong" |
|---|---|---|---|---|
| 1.1 | Chốt nơi để code PWA cũ (archive thư mục nào) rồi dọn `app/` thành project iOS | OW, 0.1 | ✅ 2026-09-18 | Owner chốt **xoá thẳng** thay vì archive (hỏi+chốt 2026-09-18): phần PWA (src/e2e/dist/husky/…) đã xoá; bản commit cuối `cbdaf43` + git history giữ nguyên để phục hồi; 6 file dirty mất theo quyết định owner; `core.hooksPath` đã unset. `app/Reado.xcodeproj` + `ReadoKit` sống |
| 1.2 | Xcode project + SwiftUI scaffold; coding-conventions Swift (bản TS cũ → archive) | 1.1 | ✅ 2026-09-18 | `app/Reado.xcodeproj` (viết tay objectVersion 60) + `Reado/` (App/Model/RootView) build sạch trên Simulator iPhone 18 Pro (iOS 26.5→27 SDK) — bằng chứng: `xcodebuild test` chạy tới ưng; conventions: `docs/agent/coding-conventions.md` bản Swift, TS cũ → `docs/archive/coding-conventions-pwa-gen.md` |
| 1.3 | SQLite: DDL từ [docs/db.md](docs/specs/db.md) tầng A + migration + seed collection mặc định (`is_default`); dialect đúng (uuid TEXT, ts `Z`, fsrs_params TEXT JSON); bổ sung `settings.timezone` | 1.2, 0.6 | ✅ 2026-09-18 — SD (0.6) sẽ đối chiếu lại | `app/ReadoKit/Database/` (SQLiteDatabase wrapper C API no-dep + Migration v1 7 bảng + Seeder 1 transaction). Tests: 11/11 `MigrationAndSeedTests` (FK ON, 4-state CHECK, không-unique vocab, seed idempotent, name NOCASE, timezone vào settings). `settings.timezone` seed từ device |
| 1.4 | Tích hợp `swift-fsrs` với `defaultWv6` + unit test: bốn state, log = snapshot TRƯỚC, queue hai nhánh (mới bị hạn mức / ôn lại không) | 1.2 | ✅ 2026-09-18 | Pin commit `4fbaf20` (tag v5.0.0 không có defaultWv6); `ReadoKit/Review/` (ReviewScheduler + CardSnapshot + ReviewService + ReviewQueue ĐỀ XUẤT — ghi nhận mục 4). Tests 21/21: weights=21 & engine v6, Q-12 steps tắt → state=review, snapshot TRƯỚC, lapses, version-guard, fuzz=0 deterministic, queue 2 nhánh, record/undo/rollback transaction. `xcodebuild test` **40/40 pass** (2026-09-18 15:36) |
| 1.5 | Nền tảng adapter FR-21: Keychain lưu key user (ghi-only, không lọt UI), URLSession, protocol chung cho proxy + OpenAI-compat — **flow UI để sau skeleton** | 0.6, 1.2 | ⬜ — chờ code (owner giao agent khác, 2026-09-18) | Adapter chạy đúng contract SD; key không bao giờ hiện/ghi ra log |
| 1.6 | `web/` prototype: chạy lại + đồng bộ với journeys v2 (J1–J6) — prototype, không phải sản phẩm | 0.1 | ⬜ | `npm run dev` chạy; journeys đúng bản v2 |

### Phase 2 — Walking skeleton (DoD chung: owner test end-to-end thật trên iPhone — chụp → phân tích → duyệt & sửa → lưu → ôn, kể cả bật airplane)

> Kèm **Home shell tối thiểu** (navigation + CTA vào hàng đợi) — Home đầy đủ theo
> journeys prompt #1 (số due/new tách, backlog, streak, shortcut collection) xong ở task 3.6/3.5.

| # | Task (FR) | Phụ thuộc | Trạng thái | Bằng chứng "xong" |
|---|---|---|---|---|
| 2.1 | FR-01 Page Capture: camera/picker hệ thống, ≤3 thao tác, tạo collection ngay trong flow | 1.2 | ✅ 2026-09-19 — commit `8a743f8`, 40/40 test xanh; J1 "≤3 thao tác" chờ owner chụp thật (2.6) | Toàn bộ criteria FR-01 pass; owner chụp thật thấy ≤3 thao tác |
| 2.2 | FR-02 AI Analysis qua proxy (+ idempotent retry, example-verify nhánh `reado_proxy`) | 0.7, 2.1 | 🔄 2026-09-19 — phần local xong, chạy mock (proxy 0.7 chưa có) | Criteria FR-02 pass; kết quả thật từ proxy, chạy lại không double-charge. **Đã có (local):** Prompt+PROMPT_VERSION, AnalysisResponseDecoder (schema #4), ReadoProxyClient (multipart + X-Reado-Image-Hash), map error envelope, verify fallback, flow AppModel/AnalysisView, 11 test mới (51/51 xanh, commit `e5fba85`). **Còn:** bằng chứng thật — chờ 0.7 |
| 2.3 | FR-03 + FR-09 Duyệt & sửa trước khi lưu — UI theo ADR-007/008 (xen kẽ đoạn, card inline, unverified lên đầu) | 2.2 | ✅ 2026-09-19 — owner approve + commit `cd85123`; owner sửa thử 1 phiên thật (2.6) | Criteria FR-03/FR-09 pass; owner sửa thử 1 phiên thật (2.6). `ReviewDraft` + `ReviewDraftBuilder` (sort unverified/suspect lên đầu + bỏ chọn sẵn, validate/normalize khi chốt) + `AnalysisView` viết lại (card inline 6 field, checkbox, badge, thoát cảnh báo mất kết quả, auto-trigger analyze) + `AppModel.saveSelection(drafts:)` thay `saveAnalysis` + `discardAnalysis()` + 5 test mới → **56/56 xanh (iPhone 18 Pro, 2026-09-19 19:01, commit `cd85123`)** |
| 2.4 | Phần `is_default` của FR-17 — collection mặc định nhận từ chưa phân loại | 1.3 | ✅ 2026-09-20 — commit `7ca9d2f`, 59/59 test xanh | Lưu không chọn collection → về mặc định, không null. `VocabRepository.saveCapture(on:collectionID:nil)` đọc `is_default=1`; test `testSaveCaptureWithoutCollectionGoesToDefaultInbox` |
| 2.5 | FR-11 + FR-12: hàng đợi hai nhánh, chấm vuốt **trái = Again(1) / phải = Good(3), Hard/Easy là nút** (ADR-025), undo nổi, log snapshot TRƯỚC trong transaction | 1.4 | ✅ 2026-09-20 — commit `7ca9d2f`, 59/59 test xanh | Criteria FR-11/FR-12 pass; undo kéo về đúng snapshot. `ReviewQueue.loadFullQueue` 2 nhánh (new quota + due không giới hạn) + `ReviewQueueView` (vuốt trái/phải + nút Hard/Easy + undo 1 bước) + `AppModel.loadReviewQueue/grade/undoReview` |
| 2.6 | Owner test end-to-end + offline (DoD chung của Phase) | 2.1..2.5 | ✅ 2026-09-24 — owner test trên iPhone thật, pass | Walking skeleton toàn bộ pass: J1 capture ≤3 thao tác · FR-02 mock chạy · FR-03/09 vocab picker + edit · FR-11/12 queue/grade/undo · ôn tập offline. **Phase 2 closed** |

### Phase 3 — R1 còn lại (thứ tự: phao cứu sinh + dữ liệu tích luỹ trước; mỗi dòng = chốt criteria tương ứng của PRD)

| # | Task (FR) | Vì sao vị trí này | Trạng thái |
|---|---|---|---|
| 3.1 | FR-16 Data Export (CSV theo collection + JSON FSRS state/log; **không** xuất key) | Phao cứu sinh — R1 sai hướng vẫn cứu được dữ liệu | ✅ 2026-09-24 — 55/55 test xanh iPhone 18 Pro, commit `d23e19a`. ExportService (TSV 7 cột Anki-compatible + JSON FSRS backup machines-wide, NFR-07 chặn key) + ExportView (chọn collection, share sheet) + ExportTests 12 test + RootView CTA Dữ liệu |
| 3.2 | FR-19 Leech: đếm lapse tích luỹ + ra khỏi hàng đợi (luồng sinh lại thẻ để sau) | Đếm phải chạy từ R1, không thì mất lịch sử | ✅ 2026-09-24 — commit `7ea032e`, 70/70 test xanh iPhone 18 Pro. `LeechService` (suspend khi `lapses >= leech_lapses`, `unsuspend`/`deleteCard`/`fetchLeeches`, idempotent) + hook `AppModel.grade` + `Seeder.defaultLeechLapses` **TẠM 6 chờ Q-08** (PRD FR-19 chưa chốt). UI sinh lại thẻ chờ task sau |
| 3.3 | FR-04 Capture failure handling | Sát capture, dễ kế thừa 2.1 | ✅ 2026-09-24 — commit `fb7f53a` (+ `1364be4` fix build), 91/91 test xanh iPhone 18 Pro. G1 ảnh mờ → CTA "Chụp lại"; G2 không phải tiếng Anh → "không hỗ trợ" + "không tính phí", không bịa dữ liệu. `AnalysisError.suggestsRecapture` + `AppModel.analysisFailure`/`prepareRecapture()` + `AnalysisView.failureView` + RootView onDismiss. Kèm sửa bug tiền-ẩn: `d23e19a` mất PBXFileReference AnalysisTests.swift → 16 test FR-02/FR-03 skip ngầm, khôi phục → 91/91 |
| 3.6 | FR-14 Daily Progress (số đến hạn + streak) | Không chặn Q-*; đòn bẩy thói quen — đưa số due/new + streak lên Home ngay | ✅ 2026-09-24 — 98/98 test xanh iPhone 18 Pro, commit `7263fb1`. `DailyProgressService` (dueToday quota-aware + backlog riêng + streak theo DayBoundary + leech loại) + `AppModel.dailyProgress` + RootView header + 7 test |
| 3.7 | FR-15 Settings (`cefr_level` + `daily_new_limit`; `request_retention` để mặc định **không** mở) | Không chặn Q-*; cần trước khi bật FR-10 thật | ✅ 2026-09-24 — 107/107 test xanh iPhone 18 Pro, commit `e1f5d5a`. `SettingsService` (load/update 3 núm + validate 0–999/0–23 + chỉ chạm cột học tập) + `SettingsView` (CEFR + hạn mức + giờ chuyển ngày + bảng FSRS chỉ-đọc) + gear CTA + 9 test |
| 3.5 | FR-08 danh sách từ (lọc theo collection; lọc CEFR/trạng thái = R2) + phần còn lại FR-17 (kho tạm xếp thời gian, chọn lô chuyển collection) | Collection là trục chính; không chặn Q-* | ✅ 2026-09-24 — 122/122 test xanh iPhone 18 Pro, commit `0a5de27`. `listVocabulary` (đủ trường, `.byTerm` không gộp cùng-term khác-pos / `.byDateAdded` kho tạm) + `CollectionDetailView` (thay scaffold) + tạo/đổi tên/xoá collection (`CollectionError`) + kho tạm "Sắp xếp" chuyển lô giữ FSRS. Shortcut Home (tối đa 2) làm riêng sau 3.12 — commit `a48b1e6` |
| 3.9 | FR-18 Ba chế độ ôn theo phạm vi + số nợ ngoài phạm vi nhìn thấy (cram = R2) | Đóng vòng giá trị collection; không chặn Q-* | ✅ 2026-09-24 — 129/129 test xanh iPhone 18 Pro, commit `5060ada`. `scope: Set<String>?` (nil = tất cả) qua new/due/loadFullQueue + `dueOutsideScopeCount` (nợ = due review/relearning ngoài phạm vi); `daily_new_limit` toàn cục trước lọc; UI `ScopePickerSheet` + banner nợ + empty-state J5; 7 test `ScopedReviewTests`. Cram R2 chưa làm |
| 3.10 | FR-20 CSV Import — scope v2: **CSV gộp, không JSON** (cập nhật lại docs/vocabulary.md cho khớp khi làm: bỏ nhánh JSON, giữ atomic/remap/preview) | Đi cùng phao cứu sinh; scope đã chốt | ✅ 2026-09-24 — 141/141 test xanh iPhone 18 Pro, commit `602ded5`. `CSVImport` (parse tab/comma quote-aware, delimiter-detect từ header, map cột theo tên; khớp collection **không hoa thường giữ dấu** qua `fold`=trim+`lowercased()` Unicode, trống→kho tạm, lạ→tạo mới; card `new`/due hôm nay mirror `saveCapture`; trùng term→cảnh báo không tự loại; atomic 1 transaction) + `ImportView` (fileImporter + preview sửa field/bỏ dòng + "Gộp (N)") + ExportView section "Nhập" + 12 test `CSVImportTests` |
| 3.12 | Reminder ôn tập (nếu ∈ R1 — chốt local vs APNs ở 0.5) | Q-05 đã chốt **local** (0.5) — chỉ còn code | ✅ 2026-09-24 — 148/148 test xanh iPhone 18 Pro, commit `caa958f`. `LearningSettings` + `reminderEnabled`/`reminderMinutes` (default tắt/20:00) + Migration v2 (2 cột `settings`) + `ReminderService` (time/describe thuần) + `NotificationScheduler` (UNCalendarNotificationTrigger lặp hằng ngày) + SettingsView section "Nhắc ôn tập" (Toggle + wheel 15') + ReadoApp khôi phục lịch lúc khởi động + 7 test `ReminderTests` |
| 3.4 | FR-05 Buffer cuộn ~10 trang + FR-06 tóm tắt trang | Q-10 **đã chốt** (ADR-029) — làm như T1 (J2 hub + sessions) | ✅ 2026-09-22 — commit `a7a2e15`, 165/165 test iPhone 18 Pro. `ReadingSessionRepository` (codec `{source_en,translation_vi}`, `listSessions` mới-trước, `insertInsideTransaction` chèn cùng transaction #4); `saveCapture` ghi phiên chỉ cho collection có tên + trim 10; `AnalysisView` picker đích; `CollectionDetailView` (J2 hub) ôn scoped + chụp vào bộ + list phiên → `ReadingSessionView` (ADR-007 xen kẽ + ADR-030 nút ẩn/hiện dịch + FR-06 summary gập). ⚠️ **Chưa làm "Từ session collect thêm"** — xem §4 |
| 3.8 | FR-10 Lọc "đã thuộc" lúc trích xuất | Q-06/Q-08/Q-09 **đã chốt** (ADR-032, 2026-09-22). Còn chờ dữ liệu thật trước khi bật — không hỏi lại ba Q | ⬜ chưa code |
| 3.11 | FR-21 đầy đủ: list agent OpenAI-compat + add key Keychain + chọn active cho FR-02 | Sau skeleton (PRD mục 10); còn chờ 0.7 proxy + 1.5 adapter | ⬜ |
| 3.13 | Đo + ghi nhận NFR-01/NFR-02 (chưa chốt ngưỡng) + kiểm M-07 bằng dữ liệu thật | R1 chỉ đo, R2 mới chốt ngưỡng; M-07 cần dữ liệu thật → cuối | ⬜ |

### Phase 4 — R2 (cổng cứng: R1 đã dùng hằng ngày ≥ 4 tuần + owner GO; chốt **Q-11** trước)

- `word_relations` + hai chế độ ôn **Phân biệt** / **Gợi nhớ theo nhóm** (xử lý Q-11: log ≠ dịch chuyển lịch?)
- Chế độ **cram** của FR-18 · lọc từ vựng nâng cao FR-08 · cảnh báo trang trôi FR-05
- Thống kê tiến bộ theo thời gian · chốt ngưỡng NFR-01/NFR-02 bằng số liệu thật
- Chỉnh prompt/schema theo M-03 (calibrate A-02) · optimizer FSRS (py-fsrs, job ngoài request) nếu cần
- **Động lực học (brainstorm 2026-09-26, chưa chốt)** — xem `docs/plans/motivation-r1.md` cho phần đã chốt (ý 1+2+3+4+7):
  - Mốc đọc lại: ≥80% từ của một phiên đọc đã thuộc (Q-08) → gợi ý đọc lại trang đó qua `ReadingSessionView` (ẩn dịch, ADR-030)
  - Huy hiệu mốc streak 7/30/100 ngày trên heatmap `StreakCalendarView` — **không** streak freeze (đã cấm, J-R1-P)
  - Nhắc thông minh: nội dung `NotificationScheduler` cụ thể hoá ("N thẻ đến hạn, M thẻ sắp quên") thay câu chung
  - Dự báo 7 ngày: biểu đồ nhỏ số thẻ đến hạn các ngày tới, dựng từ `due_at` đã có
  - Bản đồ trí nhớ: mỗi từ một chấm màu theo retrievability suy từ `stability`/`fsrs_params`, không thêm cột

### Later — chưa mở, không thiết kế trước

Multi-user/auth (NG-05) · dashboard sản phẩm + sync đa thiết bị (nền: [multi-client-sync](docs/research/review.md) + [sync-server-ddl](docs/specs/sync-server-ddl.md)) · secondary segment (PRD mục 4).

### 3bis. Đối chiếu journey ↔ task (nguồn: [docs/journeys.md](docs/specs/journeys.md))

Thứ tự code trong các phase trên **bám theo journeys**: vòng skeleton sống trong J1 (lối tắt capture) và J3/J4 (nhánh hằng ngày); J2 hub mở ra sau khi skeleton chạy; J6 và các J-R1-* theo đúng thứ tự prompt UI (mục 5 của doc). **Mỗi task khi code mở journey tương ứng làm kịch bản kiểm, cạnh GWT của FR.**

| Journey | Hình dạng | Task trong ROADMAP | Khi nào |
|---|---|---|---|
| Home (prompt #1) | ≤2 shortcut collection (FR-17), số due/new tách + backlog riêng + streak (FR-14), CTA capture/học/ôn/Dữ liệu | shell tối thiểu: Phase 2; full: 3.6 (+ 3.5 phần shortcut) | shell sớm nhất, chi tiết ở 3.6 |
| J1 — Capture nhanh | Camera → vocab picker → kho tạm, **không** hỏi collection, không ép đọc song ngữ | 2.1 + 2.2 + 2.3 + 2.4 | Phase 2 |
| J2 — Đọc chủ động (hub) | Collection hub: capture + **10 session chọn được** + kho vocab theo collection + ôn collection này | 3.4 (FR-05/06) + 3.5 (FR-08) + phần FR-17 còn lại | Phase 3 |
| J3 — Học mới | Nhánh `new` bị `daily_new_limit`; hết hạn mức → về Home, backlog nhãn riêng | 2.5 + 3.6 (FR-14) | Phase 2 (queue), 3.6 (số Home) |
| J4 — Ôn đến hạn | Nhánh due không bị hạn mức; cùng card UI với J3 | 2.5 | Phase 2 |
| J5 — Trộn / phạm vi | Ba chế độ scope, nợ ngoài phạm vi **nhìn thấy**; KHÔNG cram | 3.9 (FR-18) | Phase 3 |
| J6 — Tổ chức kho tạm | Move lô sang collection có tên, FSRS giữ nguyên; **không bắt buộc** để J3/J4 chạy | 3.5 (phần FR-17) — sau happy path 1–5 | Phase 3 |
| J-R1-S — Settings học tập | CEFR + `daily_new_limit` + quản lý shortcut (FR-17) + agent phân tích trang (FR-21); **không** login, **không** đặt export/import ở đây | 3.7 (FR-15) + 3.5 (FR-17) + 3.11 (FR-21) | Phase 3 |
| J-R1-D — Dữ liệu CSV | Xuất CSV theo collection + JSON FSRS; nhập CSV **preview rồi gộp** | 3.1 (FR-16) + 3.10 (FR-20) | Phase 3 (sớm — phao cứu sinh) |
| J-R1-P — Lịch streak | Lens của FR-14, heatmap 18 tuần; **không** bắt buộc ở R1 | 3.6 (sau số Home) | Phase 3 — tuỳ owner |
| J7–J9 | Login / account / cá nhân hoá | — | Later — **không** prompt UI ở R1 |

---

## 4. Mâu thuẫn & ghi nhận (thêm dòng khi thấy; không im lặng sửa docs)

| Ngày | Ghi nhận | Hướng xử lý |
|---|---|---|
| 2026-09-26 | `docs/ux/visual-redesign-plan.md` §3 + comment `ReviewQueueView` ("Hết thẻ hôm nay không nảy vào — chống gamification") diễn giải vision #6 (Journey Over Summary) thành "chống gamification" nói chung. Vision #6 thật ra chống *tóm tắt thay đọc*, không cấm ghi nhận tiến bộ | Owner 2026-09-26 chủ động muốn khuyến khích (animation streak/mastery) → ADR-038 đảo phần diễn giải UX; rào giữ: chỉ ăn mừng **tiến bộ đo được** (thẻ ôn, từ thuộc Q-08, streak FR-14) — không điểm ảo, không đổi màu nút grade (§3 giữ nguyên). Chi tiết `docs/plans/motivation-r1.md` |
| 2026-09-18 | ⚠️→✅ **Chuẩn vuốt chấm (đã chốt):** ADR-009/024 (PWA) ghi *trái = Easy(4)*; [docs/journeys.md](docs/specs/journeys.md) mục 4 "Gesture" (v2) ghi *trái = Again, Hard/Easy là nút* | **Owner chốt 2026-09-18 theo journeys** → ghi ADR-025 (đảo ADR-009); task 2.5 theo chốt mới; ADR-024 "cả hai mặt" giữ tới khi owner đổi |
| 2026-09-18 | `PROJECT.md` miêu tả `web/` + `app/Reado.xcodeproj` như đã tồn tại — **máy này** chưa có (`app/` còn là PWA; không có `web/`). PROJECT.md đi theo gói docs v2 từ máy kia | Đã ghi session-brief mục 2; task 0.1. Chưa sửa PROJECT.md vì nó đúng với máy nguồn |
| 2026-09-18 | `README.md` vẫn miêu tả thế hệ PWA (v0.6, walking skeleton PWA) | Đã cắm banner lỗi thời trên đầu README trỏ sang PROJECT.md + ROADMAP này |
| 2026-09-18 | Header `docs/research/review.md` vẫn ghi "Q-01 PWA … còn nguyên hiệu lực" — lỗi thời sau pivot | Đã cắm update note trong header; phân tích sync vẫn là nền Later |
| 2026-09-18 | Prompt baseline của owner vẫn trống trong v2 (dù PWA-gen từng ghi "đã dán đủ") | Task 0.3 — chờ owner; KHÔNG dùng prompt dựng lại làm bằng chứng A-02 |
| 2026-09-18 | `docs/research/vocabulary.md` ghi nhận cả JSON + TSV, nhưng PRD v2 mục 10 chốt FR-20 = **CSV gộp, không JSON** | Task 3.10 cập nhật plan khi làm; không sửa trước |
| 2026-09-18 | ⚠️→✅ **BÁO LẠI (đã chốt 2026-09-24):** DDL `idx_collections_name ... COLLATE NOCASE` của SQLite **chỉ gập ASCII** (A-Z/a-z) — "Sách mới" ≠ "sÁch mỚI" ở tầng DB. FR-20 "khớp không hoa thường" với tiếng Việt phải do app chuẩn hoá lúc trim/insert | Giữ DDL nguyên; test dùng cặp ASCII + cặp "Đá"/"Đã" (giữ dấu). **Owner chốt khi làm 3.10: gập = hạ chữ thường Unicode, GIỮ dấu** (`normalizedTerm`) — ghi mục 1 |
| 2026-09-18 | **swift-fsrs pin `4fbaf20`:** `log.scheduledDays` trong `RecordLogItem` là nhịp **CŨ** (`last.scheduledDays`) — nhịp mới nằm ở `item.card.scheduledDays`. ts-fsrs convention log = nhịp mới | ReadoKit lấy `ReviewOutcome.scheduledDays` từ `card` (nhịp mới) cho cả `cards.scheduled_days` lẫn `review_logs.scheduled_days`; ghi conventions mục 4+9 |
| 2026-09-18 | Query shape của `ReviewQueue` (`newCardIDs(quota:)` / `dueCardIDs(dueBeforeIso:)` / `newIntroducedCount(dayStartIso:)`) là **đề xuất của agent** — chưa có chốt sản phẩm | Đã đánh dấu CHƯA CHỐT trong code; chốt khi làm UI 2.5 (Phase 2) |
| 2026-09-18 | Tên collection mặc định seed = **"Kho tạm"** — chi tiết hiển thị, chưa có chốt riêng | Đơn giản nhất, ghi `Seeder.defaultCollectionName`; owner đổi lúc duyệt UI Home nếu muốn |
| 2026-09-18 | `qr/v2/encrypted.txt` (85KB, chunk RD32 `reado-docs.tar.bz2` 01/19) + `restore.py` — phụ phẩm transport docs từ máy kia 09-17; root đã merge đủ nội dung | **Owner chốt xoá** 2026-09-18 → đã xoá cả 2 file (task 0.4 ✅) |
| 2026-09-18 | SD 0.6 viết khi hosting vendor + model Gemini chưa chốt cụ thể | Owner 2026-09-18: hosting chốt lúc deploy (tiêu chí mục 9), model chốt ở 0.8 — SD gắn nhãn MỞ, không lấp thầm |
| 2026-09-19 | ✅ Owner đổi phạm vi git: **chỉ track `app/`** — docs/config/`.agents/` đã gitignore + untrack (đảo chốt "track docs" sáng 19-09) | Docs vẫn sống trên đĩa máy làm việc nhưng không còn version history; thay đổi docs không commit |
| 2026-09-19 | `PROJECT.md` còn link + mô tả `web/` (đã xoá từ pivot 128ae52), dòng "solution design chưa có" lỗi thời | Đã sửa 19-09: bỏ link/dòng web/, bỏ block chạy prototype, trỏ SD v2; task 1.6 (web prototype) hết nghĩa — chờ owner chốt lại nhiệm vụ |
| 2026-09-19 | `docs/research/vocabulary.md` mục 12 còn 2 link ảnh PVO PNG chưa từng tồn tại trong repo | Owner chốt **xoá hẳn 2 dòng link** 19-09 |
| 2026-09-19 | SD 10.3 ghi MỞ "sửa lại `example` phải chấp nhận khi chưa khớp gốc — có đánh dấu hay không, **chốt lúc 2.3**" | **Chốt tại 2.3 (chọn đơn giản nhất):** giữ nguyên nhãn verification từ lúc phân tích; bấm chọn item (hoặc bỏ) chính là hành vi user chủ động — không sinh nhãn thứ hai gây nhiễu |
| 2026-09-19 | SD 10.3 liệt kê "chọn collection" trong 2.3, nhưng J1 happy path bỏ bước collection picker (đích ngầm = kho tạm) | Làm theo J1: 2.3 lưu thẳng kho tạm (`collectionID nil`); collection picker thuộc 2.4 `is_default` |

| 2026-09-24 | Ngưỡng leech FR-19 code = 6 nhưng **chưa chốt** — PRD FR-19: "ngưỡng cụ thể chưa chốt… thuộc nhóm Q-08, chốt cùng một lượt". Bản thảo đầu từng ghi "owner chốt 2026-09-20: 6" — không có bản ghi nào ủng hộ. | Giữ 6 làm placeholder 🔶 (đánh dấu TẠM trong Seeder + session-brief); chốt số thật cùng Q-08 |
| 2026-09-24 | ⚠️→✅ **Bug tiền-ẩn build:** commit `d23e19a` (FR-16) xoá mất dòng `PBXFileReference` của `AnalysisTests.swift` (giữ PBXBuildFile + group child + sources phase) → 16 test FR-02/FR-03 không biên dịch vào test bundle, **không báo lỗi build**. Mốc "70/70" (3.2) không chạy chúng; con số test thật kể từ 3.1 là 55. | Đã khôi phục file-ref (`1364be4`) → 91/91; ghi bẫy session-brief §3: file test cần đủ 4 dòng pbxproj, nghi ngờ thì `nm -gU ReadoTests.xctest` |
| 2026-09-24 | `scripts/pbxproj_tool.py` lệnh `remove` bị hỏng — hàm `remove_file` high-level (cuối file) shadow bản low-level (`remove_file(content, file_path, group_name, target, group_id)`) → TypeError "takes 4 positional arguments but 5 given" | Đã workaround (sửa tay 1 dòng pbxproj + grep-verify, ngoại lệ vì tool hỏng); nên rename/sửa tool trước lần cần gỡ file tiếp |
| 2026-09-24 | ⚠️→✅ **Cửa J-R1-D đứt dây:** ROADMAP 3.1 bằng chứng ghi "RootView CTA Dữ liệu" nhưng code chỉ khai báo `showExport` + sheet ở RootView, **không nút nào bật** — `ExportView` build + test từ 3.1 mà người dùng không với tới. Kèm mâu thuẫn thứ hai: §1 (file này) + session-brief ghi "3.4 chặn bởi Q-10 chưa chốt" dù [ADR-029](docs/decisions-log.md#adr-029--q-10-10-phiên-đọc-bền-per-collection-có-tên-đảo-v03-buffer-trôi) đã chốt Q-10 2026-09-18 | Đã vá cửa Dữ liệu (commit `2907666`: nút "Dữ liệu" RootView bottom bar · `ExportView.init(initialCollectionIDs:)` · CollectionDetailView "Xuất bộ này"). Owner chốt mở 3.4 — đã bỏ Q-10 khỏi CHƯA CHỐT §1 + thêm hàng chốt |
| 2026-09-22 | ⚠️ **J2 bước 7 "Từ session này collect thêm"** (journeys.md) cần danh sách vocab đã confirm **của đúng lần capture đó** (subset kho collection) — nhưng [db.md](docs/specs/db.md) đã chối `session_id` trên vocab_items ("không cần — phiên đọc có bảng riêng reading_sessions"), schema không có link session↔vocab | T1 chỉ làm đọc song ngữ + summary của phiên; **không** làm "từ collect session" (không tự migration mâu thuẫn với db.md). Chờ owner chốt hướng: (a) thêm `session_id` FK, (b) để R2, (c) bỏ bước khỏi J2 |
| 2026-09-22 | **Lệch mốc ngày:** git + đồng hồ máy = `2026-09-22`, nhưng các entry docs trước đó (journal/session-brief/ROADMAP) đóng dấu `2026-09-24` | BÁO LẠI, không sửa ngược lịch sử — entry mới (T1) đóng dấu đúng `2026-09-22`; owner rà lại nhãn ngày khi cần |

---

## 5. Bẫy & bài học thế hệ v2

- **`swift-fsrs`:** constructor mặc định là **FSRS-5** — phải truyền `FSRSDefaults.defaultWv6` (21 trọng số). Sai → silent breakage lịch ôn.
- **`cards.state`:** luôn đủ bốn giá trị `new/learning/review/relearning` — gộp pha là chấm sai `difficulty` và sai tích luỹ.
- **`review_logs`:** snapshot **TRƯỚC** khi chấm, chung transaction với update `cards` — mất log là mất training data vĩnh viễn, không gì báo.
- **Không thêm `unique (collection_id, term_normalized)`** — một từ nhiều nghĩa nhiều dòng; chống trùng nằm ở FR-10.
- **Timestamp:** ISO-8601 **UTC hậu tố `Z`** — giờ địa phương là loại lỗi chỉ nổ khi owner đi công tác; `settings.timezone` phải có từ SD.
- **Proxy:** phải hosted + HTTPS (không laptop-local); key sản phẩm chỉ `.env` server; `image_hash` chống gọi lặp tính phí đôi.
- **Key user:** Keychain, ghi-only — không bao giờ hiển thị, không lọt log/DOM.
- **Ảnh trang:** cấm lưu (NFR-04) — chỉ segments JSON; kỹ thuật PWA xưa (SQLite-WASM/OPFS…) KHÔNG kế thừa, bài học PWA đọc ở `mvp-plan-pwa-gen.md` (đã xoá, ADR-044) mục 5.
- **Docs là luật, tracker là tiến độ:** thấy bảng "Đã chốt" nghi sai → báo lại, không sửa.

---

## 6. Nhật ký (append-only)

| Ngày | Sự kiện | Ai | Hệ quả |
|---|---|---|---|
| 2026-09-18 | Owner yêu cầu archive tracker PWA + dựng tracker mới và plan làm lại. Agent chuyển `MVP_PLAN.md` → `docs/archive/mvp-plan-pwa-gen.md` (bia mộ cập nhật tại chỗ), tạo `ROADMAP.md` (file này) với 5 phase + Later; sửa pointer các docs cũ về archive; cập nhật README/decisions-log/multi-client-sync/session-brief/PROJECT.md | owner + agent | Nguồn tiến độ duy nhất giờ là file này + session-brief; bước tiếp: owner chọn task Phase 0 (0.1..0.8) |
| 2026-09-18 | Owner hỏi plan có theo journeys không → agent đối chiếu, thêm bảng 3bis (journey ↔ task) + ghim journeys làm nguồn; phát hiện mâu thuẫn chiều vuốt giữa ADR-009 (PWA) và journeys mục 4 | owner + agent | Owner **chốt theo journeys** (trái = Again, phải = Good) → ADR-025 ghi vào decisions-log; task 2.5 + mục 1 + mục 4 đồng bộ |
| 2026-09-18 | Owner: **"xoá hết folder app rồi code từ đầu"**. Làm rõ → chốt: xoá phần PWA trong `app/`, **giữ `app/ReadoKit`**, viết app iOS native (SwiftUI) theo kiến trúc đã chốt (Q-01/02/03, SQLite local, swift-fsrs defaultWv6, Q-12 tắt steps) | owner + agent | Bỏ qua chuyện archive PWA — xoá thẳng; ReadoKit (untracked) giữ nguyên; bắt đầu Phase 1 nền móng trước gate Phase 0 (0.2 ADR / 0.3 prompt / 0.5-0.7 SD+proxy vẫn mở) |
| 2026-09-18 | Xong nền móng iOS: `Reado.xcodeproj` (pbxproj viết tay objectVersion 60, no xcodegen) + `ReadoKit` package (CSQLite systemLibrary, no-dep) + DB v1 (7 bảng theo db.md) + Seeder + tầng Review (ReviewScheduler/Service/Queue + CardSnapshot) + 40 test | agent | `xcodebuild test` **40/40 xanh** (iPhone 18 Pro simulator) 15:36; Conventions Swift thay bản TS (TS → archive); bẫy đã gỡ: sandbox chặn cache ~/Library → full-access + DerivedData/.xcode-packages + TMPDIR vào workspace; `XCSwiftPackageProductDependency`; string "ISO" trao tay giữa app/package kill formatter khác (ISO8601FormatStyle trần không có field); NOCASE ASCII-only |
| 2026-09-18 | Owner chọn hướng gate Phase 0 → agent dựng 3 bản ghi ADR pivot vào `docs/decisions-log.md`: **ADR-026** native iOS (đảo 001) · **ADR-027** local-first SQLite trên máy, BE đầy Later (đảo 002) · **ADR-028** hybrid proxy+BYOK Keychain (đảo 003); mỗi bản ghi có "Thay thế đã loại" | agent | Gate 0.2 chuyển ⛔→🔄 (chờ chữ ký duyệt owner); bản ghi nằm cuối file (sau 029..031 — số giữ sẵn từ 09-18); header decisions-log + ROADMAP mục 2/nhật ký/session-brief/journal đã đồng bộ |

| 2026-09-18 | Owner trả lời trọn gói gate Phase 0 (hỏi-đáp trong session): duyệt ADR-026..028 OK · xoá `encrypted.txt` · hosting để MỞ (chốt lúc deploy) · model để 0.8 · reminder = local notification · duyệt proxy Python + `google-genai` · chọn việc tiếp = 0.6 SD v2 | owner | Task 0.2 ✅ · 0.4 ✅ · 0.5 ✅; bảng chốt mục 1 + tech-stack mục 11 + session-brief + journal đồng bộ; SD 0.6 bắt đầu viết |

| 2026-09-18 | Agent viết xong **draft solution design v2**: archive bia mộ PWA → `docs/archive/solution-design-pwa-gen.md`, viết v2 thay tại chỗ `docs/specs/solution-design.md` — hợp đồng proxy API (multipart + image_hash idempotency + verification per item), module iOS đối chiếu code 1.1-1.4, 7 ranh giới transaction, adapter Keychain/URLSession, mục 12.1 = 6 đề xuất mới chờ owner xác nhận, mục 12.2 = chỗ MỞ kèm mốc chốt | agent | Task 0.6 🔄 chờ duyệt owner; PRD mục 13 + ROADMAP mục 2/header + session-brief + journal đồng bộ; bước kế sau duyệt: 0.7 proxy hoặc 1.5 adapter |

| 2026-09-18 | **Owner duyệt SD v2 (6/6 đề xuất 12.1)** → task 0.6 ✅; owner chọn việc tiếp = **1.5 adapter FR-21** | owner | SD status → v1.0; session-brief + journal đồng bộ |

| 2026-09-18 | Owner đổi hướng: **dừng code bởi agent này, giao agent khác code 1.5** — phiên này chỉ chốt docs | owner | Gỡ phần code Analysis vừa viết dở (chưa compile/test, chưa nối pbxproj); 1.5 về ⬜ "chờ code"; docs giữ 0.6 ✅ + SD v1.0 làm bàn giao |

| 2026-09-19 | Kiểm định sau tái cấu trúc v2: G1/G2/G5(40/40)/G6 verify lại PASS; quét 324 link trong 24 file sống → sửa nốt link `web/` chết + bare-path trỏ file cũ; sửa `scripts/verify/check-doc-links.mjs` theo quy ước gốc-repo (resolve kép, loại thư mục đóng băng) | agent + owner | Owner chốt git **chỉ track `app/`** (untrack docs+config+`.agents/`, đảo chốt sáng); docs là bản làm việc thuần đĩa; WIP Analysis/Capture/VocabRepository/ReviewQueueView lưu ý chưa nối target |

| 2026-09-19 | **Task 2.2 FR-02 phần local xong** — Prompt + PROMPT_VERSION, AnalysisResponseDecoder (schema prompt-spec #4 + verify fallback SD 7.3), ReadoProxyClient (multipart SD 4.1, header X-Reado-Image-Hash idempotency, map error envelope → AnalysisError), AnalyzerFactory đọc settings, flow AppModel + AnalysisView (progress → 3 nhóm dữ liệu → lưu kho tạm transaction #4). **Owner chốt: proxy 0.7 chưa deploy → chạy MockAnalyzer.** 51/51 test xanh; commit `e5fba85` | agent + owner | 2.2 → 🔄 (còn thiếu "kết quả thật từ proxy" chờ 0.7); task tiếp tự nhiên = 2.3 FR-03/09 duyệt & sửa; session-brief §2.6 + journal đồng bộ |
| 2026-09-19 | **Task 2.3 FR-03/09 Duyệt & sửa trước lưu (ADR-008) xong.** `ReviewDraft` + `ReviewDraftError` + `ReviewDraftBuilder` (sort unverified/suspect lên đầu + không preselect, validate rỗng sau trim + normalize `pos→other`/`cefr` upper/`ipa nil`). `AppModel.saveSelection(drafts:)` thay `saveAnalysis` (lọc `isSelected` qua Builder trước khi `VocabRepository.saveCapture` transaction #4, đích ngầm kho tạm theo J1) + `discardAnalysis()`. `AnalysisView` viết lại: card rút gọn + checkbox tách click mở card, badge xác minh, tap mở inline 6 field, toolbar "Lưu (N)", `interactiveDismissDisabled` + alert "Bỏ kết quả?" tới khi `hasConfirmed`, `.task` auto-trigger `analyzeCurrentImage()` (lấp bẫy sheet chồng sheet). SD 10.3 MỞ đã chốt: sửa `example` **không** đổi nhãn `verification` — bấm chọn là hành vi chủ động. **56/56 test xanh (iPhone 18 Pro 2026-09-19 19:01), commit `cd85123`.** | agent + owner | 2.3 → ✅; session-brief §2.7 + ROADMAP 2.3 đồng bộ |
| 2026-09-24 | **Task 3.3 FR-04 Capture failure xong** — `AnalysisError.suggestsRecapture` (imageUnreadable/notEnglishText → chụp lại; lỗi tạm → retry) + message notEnglishText "không hỗ trợ / không tính phí" + `AppModel.analysisFailure`/`prepareRecapture()` + `AnalysisView.failureView` + RootView onDismiss mở lại chụp. 5 test mới → 91/91 xanh iPhone 18 Pro. **Kèm sửa bug tiền-ẩn:** `d23e19a` mất PBXFileReference AnalysisTests.swift → 16 test FR-02/FR-03 skip ngầm, "70/70" không chạy chúng; khôi phục (`1364be4`) → 91/91. | agent | 3.3 → ✅; 2 commit `1364be4` + `fb7f53a`; session-brief §2.6 + journal đồng bộ |
| 2026-09-24 | **Đổi thứ tự Phase 3** (owner: "lỡ code 3.4, giúp đổi thứ tự"). 3.4 nằm ngay đầu nhưng bị chặn bởi Q-10 → reorder: front-load task **không chặn Q-\*** (3.6 → 3.7 → 3.5 → 3.9 → 3.10 → 3.12), lùi 3.4/3.8/3.11/3.13 về sau theo gate tương ứng. Giữ ID 3.x nguyên để không gãy tham chiếu; cập nhật cột "Vì sao vị trí này" khớp vị trí mới | owner + agent | Bảng Phase 3 + header "Phase hiện tại" + session-brief §1/§2 đồng bộ; task tiếp thực thi = 3.6 FR-14 |
| 2026-09-24 | **Task 3.5 FR-08 + FR-17 xong** — `VocabRepository.listVocabulary`/`allCollectionSummaries`/`moveVocabularyItems`/`renameCollection`/`deleteCollection` + `CollectionError`; `CollectionDetailView` (đổi tên/xoá; kho tạm "Sắp xếp" chuyển lô giữ FSRS); Home "Tạo collection" + hiện lần-thêm-gần-nhất. 15 test mới (`VocabularyListTests`) → **122/122 xanh iPhone 18 Pro**, commit `0a5de27`. Phạm vi owner chốt a+b+c; **shortcut Home (tối đa 2) để task riêng** | agent + owner | 3.5 → ✅; header "Phase hiện tại" + session-brief §1/§2 + journal đồng bộ; task tiếp = 3.9 FR-18 |
| 2026-09-24 | **Task 3.9 FR-18 Scoped Review xong** — `ReviewQueue` + `scope: Set<String>?` (nil = tất cả) qua new/due/loadFullQueue + `dueOutsideScopeCount` (nợ = due review/relearning ngoài scope, trừ future/suspended); `daily_new_limit` TOÀN CỤC trước lọc (test khoá); UI nút "Phạm vi" → `ScopePickerSheet` multi-select + banner nợ + CTA "Ôn tất cả" + empty-state J5. 7 test `ScopedReviewTests` → **129/129 xanh iPhone 18 Pro**, commit `5060ada`. ⚠️ đã sửa bug bind SQL scope (placeholder due đứng trước scope nhưng bind sai thứ tự — test bắt). **Cram = R2 chưa làm** | agent | 3.9 → ✅; header + session-brief §1/§2 + journal đồng bộ; task tiếp = 3.10 FR-20 |
| 2026-09-24 | **Task 3.10 FR-20 CSV Import xong** — `CSVImport` (parse tab/comma quote-aware, delimiter-detect từ header, map cột theo tên; khớp collection **không hoa thường giữ dấu** qua `fold`=trim+`lowercased()` Unicode, trống→kho tạm, lạ→tạo mới; card `new`/due hôm nay mirror `saveCapture`; trùng term→cảnh báo không tự loại; atomic 1 transaction) + `ImportView` (fileImporter + preview sửa field/bỏ dòng + "Gộp (N)") + ExportView "Nhập". 12 test `CSVImportTests` → **141/141 xanh iPhone 18 Pro**, commit `602ded5`. **Owner chốt gập = hạ chữ thường Unicode, GIỮ dấu** | agent + owner | 3.10 → ✅; header + mục 1/4 + session-brief §1 + journal đồng bộ; task tiếp = 3.12 |
| 2026-09-24 | **Task 3.12 Reminder ôn tập xong** — `LearningSettings` + `reminderEnabled`/`reminderMinutes` (default tắt/20:00) + Migration v2 (2 cột `settings` default 0/1200) + `ReminderService` (time/describe thuần) + `NotificationScheduler` (UNCalendarNotificationTrigger lặp hằng ngày, requestAuth khi bật) + SettingsView "Nhắc ôn tập" (Toggle + wheel 15') + ReadoApp `.task` khôi phục lịch lúc khởi động. 7 test `ReminderTests` → **148/148 xanh iPhone 18 Pro**, commit `caa958f`. **Owner chốt = toggle + giờ nhắc trong Settings** | agent + owner | 3.12 → ✅; header + session-brief §1 + journal đồng bộ; nhánh front-load không chặn Q-* cạn — task kế = shortcut Home / gate 0.3·0.7·1.5 |
| 2026-09-24 | **Task shortcut Home (FR-17 phần còn lại) xong** — `HomeShortcutService` (ReadoKit: đọc/ghi 2 slot `settings.home_shortcut_*` theo thứ tự slot, validate `tooMany`/`duplicate`/`isInbox`/`notFound`, ghi 2 cột 1 transaction; xoá collection → `ON DELETE SET NULL` tự bỏ slot) + `HomeShortcutToggle` (Control dùng chung Hub + Settings; đủ 2 → chooser chọn shortcut để thay, không tự thay ngầm, cancel giữ nguyên) + RootView section "Đang đọc trên Home" (pin + due) mở thẳng Collection Hub + SettingsView mục "Đang đọc trên Home" (J-R1-S) + kho tạm không hiện control. 10 test `HomeShortcutTests` → **158/158 xanh iPhone 18 Pro**, commit `a48b1e6` | agent + owner | FR-17 shortcut Home → ✅; header + session-brief §1 + journal đồng bộ; nhánh front-load không chặn Q-* cạn hẳn — task kế = mở gate 0.3·0.7·1.5 |
| 2026-09-24 | **T0 — cửa Dữ liệu Home + "Xuất bộ này" xong** — review journeys phát hiện `ExportView` build + test từ 3.1 nhưng **đứt cửa vào** (RootView `showExport` + sheet, không nút bật). Vá: nút "Dữ liệu" RootView toolbar bottom (không cạnh bánh răng — NFR-08) · `ExportView.init(initialCollectionIDs:)` (rỗng = tất cả) · CollectionDetailView "Xuất bộ này" menu `⋯`. 158/158 test xanh iPhone 18 Pro, commit `2907666`. Kèm ghi nhận mâu thuẫn §4 + bỏ Q-10 khỏi CHƯA CHỐT §1 | agent + owner | Header "Phase hiện tại" + mục 1/4 + session-brief §1/§2 + journal đồng bộ; plan tiếp = T1 J2 hub + FR-05/06 → T2 J-R1-P heatmap |
| 2026-09-22 | **T1 — J2 hub + FR-05/06 phiên đọc song ngữ xong** — `ReadingSession` + `ReadingSessionRepository` (ReadoKit/Session: codec `{source_en,translation_vi}`, `listSessions` mới-trước, `insertInsideTransaction` không mở transaction riêng); `VocabRepository.saveCapture` thêm `segments`/`summaryVI` (ghi phiên CÙNG transaction #4, chỉ collection có tên, trim 10 — Q-10/ADR-029); `AnalysisView` picker đích lưu; `CollectionDetailView` (J2 hub) "Ôn bộ này" (FR-18 scoped) + "Chụp trang vào bộ này" + list "Phiên đọc (N/10)" → `ReadingSessionView` (ADR-007 xen kẽ + ADR-030 nút ẩn/hiện dịch + FR-06 summary gập). 7 test `ReadingSessionTests` → **165/165 xanh iPhone 18 Pro**, commit `a7a2e15`. ⚠️ Chưa làm "Từ session collect thêm" (lệch schema, §4) | agent | 3.4 → ✅; header + mục 1/4 + session-brief §1/§2 + journal đồng bộ; task tiếp = T2 J-R1-P heatmap |
| 2026-09-22 | **T2 — J-R1-P streak heatmap (lens FR-14) xong** — `StreakCalendarService` (ReadoKit/Progress: heatmap 18 tuần 7×18 + streak hiện tại/dài nhất; số thẻ ôn từ `review_logs` + số trang từ `reading_sessions`, gộp theo giờ chuyển ngày FR-11; `DailyProgressService.streak` delegate sang đây — MỘT logic streak cho Home + lịch, 7 test cũ guard) + `StreakCalendarView` (heatmap vừa khít phone không scroll ngang `aspectRatio 18/7`, màu = cường độ thẻ ôn, tap ô → chi tiết ngay dưới lưới, CTA còn due→Ôn / 0 due→Chụp — không Cram/share) + Home ô Streak bấm được. 6 test `StreakCalendarTests` → **171/171 xanh iPhone 18 Pro**, commit `55c2685` | agent | 3.6 (lens J-R1-P) → ✅; header + session-brief §1/§2 + journal đồng bộ; nhánh không-chặn Q-*/proxy cạn hẳn — task kế = mở gate 0.3·0.7·1.5 |
| 2026-09-24 | **Port UI lab + vá gap IA xong** — chuỗi 5 commit `6247dfe`→`9c1becc`: visual redesign (Theme tokens + `.tint` + grade ramp) → chủ đề accent (Hệ thống + 3 palette) + flip 3D thuần + `card()` ViewModifier → IA 3 tab + pin Home 5 + CEFR đa level + Ôn nhanh scope → dọn dead code + rename `HomeShortcut`→`HomePin` → vá gap 7 món theo plan (kho tạm luôn hiện Home · shutter scope `ShellRoute` + `suppressFloatShutter` · dest trên camera overlay `hitTest` pass-through · chọn tất cả duyệt từ · gỡ FSRS settings · theme mặc định Rừng cờ một lần · pin/priority/review-all throw + `.alert`). **182/182 test xanh iPhone 18 Pro** (chạy test sẵn có, không suite mới), commit `9c1becc`. ⚠️ overlay camera cần verify on-device (simulator không camera). ⚠️ Git history đã **reword toàn bộ** — hash cũ từ T2 về trước không còn resolve | agent | UI lab port + gap IA → ✅ (không ngồi task FR/Phase); header + session-brief §1/§2 + journal đồng bộ; task kế = mở gate 0.3·0.7·1.5 |
| 2026-09-28 | **repo-hygiene-r1 Phase A xong (ADR-044)** — gỡ ảnh bản quyền `ref/sample` khỏi git + `.env.example` placeholder `0fe6502`; gom thư mục gốc, xoá script Phase 0/`qr` `107bca0`; gộp `AGENTS.md` + `PROJECT.md` vào `CLAUDE.md` `7db1510`; xoá `docs/archive` + TL;DR research `dcaef1b`; lane `scripts/test.sh kit` (ReadoKit trên macOS) `9b8c169` | Claude | Full suite 256/258 xanh (2 skip opt-in), kit 4/4; Phase B (synchronized folders → chia thư mục → tách view) chờ visual-polish + cram khép — `docs/plans/repo-hygiene-r1.md` |
| 2026-09-28 | **repo-hygiene-r1 Phase B xong (B1–B3, ADR-046)** — pbxproj sang synchronized folders (objectVersion 70, `pbxproj_tool.py` chỉ còn `check`/`list`) `d8c6bb5`; chia `app/Reado` theo feature (App/Home/Capture/Analysis/Review/Library/Settings/Shared, `git mv` thuần) `ea46f05`; tách `RootView`/`AnalysisView`/`ReviewQueueView` (≤ ~400 dòng/file, di chuyển thuần + bỏ `private` chỗ extension khác file cần). Full test 263/265 bằng mốc sau mỗi bước. B4 (`AppModel`) + B5 (test → `ReadoKitTests`) hoãn tới khi vướng. Plan khép: `docs/plans/repo-hygiene-r1.md` | agent |
| 2026-09-28 | **Cram kéo về R1 (ADR-043, cram-collection-r1 Phiên A) ✅** — nút "Ôn thêm N thẻ" ở màn hết thẻ; `ReviewService.recordCram`/`undoCram` chỉ ghi log `mode='cram'`, không đổi `cards`; `newIntroducedCount` chỉ đếm `srs`; 7 test `CramReviewTests` | Claude | 263/265 xanh iPhone 18 Pro (2 skip opt-in), `** TEST SUCCEEDED **` | FR-18 tiêu chí 4 → R1; journeys J4/J5 + prd R2 list đồng bộ; Phiên B (header collection) chờ |
