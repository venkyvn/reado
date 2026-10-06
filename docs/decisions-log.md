# Architecture Decision Records — Reado

> **ADR log** ghi lại các quyết định kiến trúc **đã chốt**. Mỗi quyết định có ID,
> lý do, ngày, và hệ quả. Không chứa câu hỏi hay tiến độ — xem ROADMAP.md.
> (ADR-001..ADR-024 thuộc thế hệ PWA; ADR-026..028 ghi pivot v2 — task 0.2 trong ROADMAP.)
>
> Quy ước: ADR-001 là quyết định đầu tiên. Trên nhánh (kể cả session cloud `claude/*`) ghi `ADR-NEW-<slug>` — không lấy số; khi merge vào `main` (hoặc viết thẳng trên `main`) mới lấy số tiếp theo + thêm dòng index. Thân ADR
> đã ghi **bất biến** — thêm ADR mới nếu quyết định bị đảo. **Index** ngay dưới được
> sửa: thêm dòng cho ADR mới và cập nhật cột "Trạng thái" của ADR bị đảo/sửa.

## Index (cập nhật mỗi khi có ADR mới; thân các ADR bên dưới bất biến)

Trạng thái: `hiệu lực` · `bị thay (ADR-xxx)` · `một phần (ADR-xxx)` — còn hiệu lực trừ phần ADR kia đổi · `bia mộ PWA` — thuộc thế hệ PWA, không còn áp dụng. Cột "Trạng thái" là phán đoán từ các ADR/PRD đảo nhau; nghi ngờ thì đọc thân ADR trong và sau số đó.

| ADR | Tiêu đề | Trạng thái |
|---|---|---|
| 001 | Platform: PWA mobile-first | bị thay (ADR-026) |
| 002 | Dữ liệu: Local-first, SQLite | bị thay (ADR-027) |
| 003 | API key: BYOK (Bring Your Own Key) | bị thay (ADR-028) |
| 004 | Lemmatize: Không lemmatize term_normalized | hiệu lực |
| 005 | Learning steps: Tắt ở MVP | hiệu lực |
| 006 | Buffer cuộn: 10 phiên đọc bền per collection | bị thay (ADR-029) |
| 007 | UI-1: Bản song ngữ xen kẽ theo đoạn | hiệu lực |
| 008 | UI-2: Card rút gọn mở inline | hiệu lực |
| 009 | Chuẩn tương tác ôn tập: Vuốt + chạm + undo nổi | bị thay (ADR-025) |
| 010 | Rich vocab: 3 cột TEXT JSON trên vocab_items | hiệu lực |
| 011 | Targeted review: Chấm + log mode='cram', KHÔNG đụng FSRS state | bị thay (ADR-050) |
| 012 | Import từ vựng: merge + remap id, cả JSON + TSV | hiệu lực |
| 013 | Storage: SQLite-WASM trong Web Worker | bia mộ PWA |
| 014 | Git: Commit chỉ chứa code trong app/ | bị thay (repo track toàn bộ từ 88eeee1, không có ADR riêng) |
| 015 | Sync Later: Server là source of truth | hiệu lực (Later) |
| 016 | UI Library: shadcn/ui | bia mộ PWA |
| 017 | State Management: Zustand setup architecture | bia mộ PWA |
| 018 | i18n: Setup nền tảng (tách UI strings + react-i18next) | bia mộ PWA |
| 019 | Analytics: Query script từ Node (chạy trên export JSON) | bia mộ PWA |
| 020 | Error Handling: Error Boundary + Toast notification | bia mộ PWA |
| 021 | Code Splitting: React.lazy cho screens | bia mộ PWA |
| 022 | A11y: Baseline accessibility | bia mộ PWA |
| 023 | Unified scripts: check + e2e:all | bia mộ PWA |
| 024 | Vuốt chấm mở trên CẢ hai mặt thẻ (sau khi lật xem detail) | bị thay (ADR-025) |
| 025 | Chuẩn vuốt chấm (iOS v2): trái = Again · phải = Good — đảo ADR-009 | một phần (ADR-033) |
| 026 | Platform: Native iOS (SwiftUI) — đảo ADR-001 | hiệu lực |
| 027 | Dữ liệu: local-first SQLite **trên máy**; BE đầy lùi về Later — đảo ADR-002 | hiệu lực |
| 028 | API key: hybrid — proxy mặc định + BYOK OpenAI-compat (Keychain) — đảo ADR-003 | một phần (ADR-049) |
| 029 | Q-10: 10 phiên đọc bền per collection có tên (đảo v0.3 buffer-trôi) | hiệu lực |
| 030 | Song ngữ: xen kẽ mặc định + nút nhỏ reveal | hiệu lực |
| 031 | Settings R1: `day_cutoff_hour` có núm | hiệu lực |
| 032 | FR-10 bộ lọc "đã thuộc": Q-06 / Q-08 / Q-09 | một phần (ADR-066) |
| 033 | Vuốt chấm Tinder-style trên CẢ hai mặt thẻ (iOS v2) | hiệu lực |
| 034 | A-01: OCR trên máy, một lần gọi agent text (dịch + vocab) | hiệu lực |
| 035 | Agent tooling: chỉ Claude Code; protocol gộp vào CLAUDE.md | hiệu lực |
| 036 | Camera tự vẽ bằng AVFoundation, bỏ `UIImagePickerController` | hiệu lực |
| 037 | Log chẩn đoán DEBUG (`DebugTrace`) + OCR tự ngắt đoạn + prompt v5 | một phần (ADR-055) |
| 038 | Đảo "chống gamification" thành ăn mừng tiến bộ đo được (J4/T1) | hiệu lực |
| 039 | "Học thêm 10 từ" nới hạn mức trong bộ nhớ app, N cố định (T2) | bị thay (ADR-050) |
| 040 | Nút loa đọc từ (TTS on-device) không thuộc NG-01/NG-02 (T2 ux-polish-r1) | hiệu lực |
| 041 | Onboarding = checklist 3 bước trên Home, không trang mẫu (T5 ux-polish-r1) | một phần (ADR-054) |
| 042 | OCR đổi sang `RecognizeDocumentsRequest` (iOS 26+), legacy làm fallback (ocr-line-drop) | một phần (ADR-064) |
| 043 | Cram kéo về R1: nút "Ôn thêm" ở màn hết thẻ (cram-collection-r1) | một phần (ADR-050) |
| 044 | Dọn repo: xoá docs/archive PWA-gen, script Phase 0, AGENTS/PROJECT.md (repo-hygiene-r1) | hiệu lực |
| 045 | Visual polish: hướng "native tinh chỉnh" + token Spacing/Radius/Typo (visual-polish-r1) | một phần (ADR-051) |
| 046 | pbxproj sang synchronized folders (repo-hygiene-r1 B1) | hiệu lực |
| 047 | Thứ tự thẻ mới ưu tiên bộ vừa thêm từ (new-order-r1) | một phần (ADR-050) |
| 048 | Bảng `encounters`: gặp lại từ cũ khi đọc, ngoài FSRS (reencounter-r1) | hiệu lực |
| 049 | Bỏ proxy Reado, FR-02 chỉ còn BYOK — đảo phần proxy của ADR-028/Q-03 (remove-proxy-r1) | hiệu lực |
| 050 | "Ôn thêm 20": trộn mới + ôn sớm thật, LIFO, heatmap theo phân vị — đảo ADR-011/039, sửa ADR-043/047 (extra-review-r1) | hiệu lực |
| 051 | MASTER.md viết lại thành luật UI native, khớp token thật — sửa phần "không sửa" của ADR visual-polish-r1 | hiệu lực |
| 052 | Shell 2 tab "Hôm nay · Thư viện", nút chụp trong thanh, Ôn là phiên toàn màn | hiệu lực |
| 053 | Lưu từ không chặn: banner thay alert, đổi đích được ở màn duyệt, bản dịch Analysis hiện sẵn | hiệu lực |
| 054 | Onboarding gộp vào hero Home, agent hỏng không giấu thẻ đến hạn | hiệu lực |
| 055 | prompt-v6: dịch theo cụm + `phrases` + xếp hạng vocab + preselect top 5 | hiệu lực |
| 056 | Q-13: gập item FR-10 "đã thuộc" thay vì xoá, liệt kê đủ nghĩa khi khoá lệch mức thuộc | hiệu lực |
| 057 | Header Home kiểu nút tròn tách, streak từ hàng riêng lên pill toolbar, hero số phụ | hiệu lực |
| 058 | Đọc PDF trong Reado, cửa thu từ vựng thứ hai — đảo NG-07 (pdf-reader-r1) | hiệu lực |
| 059 | Điều hướng trang + Mục lục trong PDF reader — đảo dòng "mục lục" ngoài phạm vi của FR-23 (pdf-nav-r1) | một phần (ADR-060) |
| 060 | Bỏ thanh kéo trang, thêm ẩn chrome khi chạm + tông nền đọc (tinh chỉnh ADR-059) | một phần (ADR-061/062) |
| 061 | Nhiều tông giấy + kéo thả độ đậm, cố định màu viền trang (tinh chỉnh ADR-060) | một phần (ADR-062) |
| 062 | Dọn tông nền đọc PDF ra `SettingsView`, bỏ Menu trên toolbar reader (tinh chỉnh ADR-060/061) | hiệu lực |
| 063 | Apple Intelligence: agent mặc định + soát OCR trên máy (mở rộng Q-03/ADR-049) | một phần (ADR-064/065) |
| 064 | Đổi OCR-fix mặc định TẮT; engine mặc định `liveText` (ghép Live Text + `documents`) — ocr-quality-r1 T0/T2/T3a | một phần (ADR-065) |
| 065 | Gỡ hẳn OCR-fix bằng LLM — ocr-quality-r1 T7 | hiệu lực |
| 066 | Đảo Q-09 cho FR-10: so khớp "đã thuộc" toàn app thay vì theo collection — vocab-identity-r1 T0 | hiệu lực |
| 067 | Gộp từ trùng cũ (FR-24) — engagement-r1 T0 | hiệu lực |
| 068 | Tăng gắn bó (engagement-r1): ý 1–6 của tang_gang_bo — engagement-r1 T0 | hiệu lực |
| 069 | Mô hình docs 5 tầng + 3 nguyên tắc (workflow-docs-r1) | hiệu lực |

---

## ADR-001 — Platform: PWA mobile-first

- **Ngày:** 2026-09-08
- **Quyết định:** PWA mobile-first, chấp nhận iOS không push notification thật.
- **Lý do:** React + TypeScript stack giữ nguyên; SQLite-WASM + OPFS chạy được trên
  cả desktop và mobile; không cần native binding cho R1. Push notification web kém
  tin cậy trên iOS nhưng FR-11/FR-14 vẫn hoạt động qua badge/counter trong app.
- **Hệ quả:** iOS không có push thật → nhắc ôn sẽ là notification web, kém tin cậy.
  Stack TS nên vẫn dùng `ts-fsrs` — docs chỉ đòi đổi binding khi native.
- **Thay thế đã loại:** Native app (Capacitor/React Native) — chi phí R1 tăng đáng kể,
  không cần thiết cho MVP một người dùng.

## ADR-002 — Dữ liệu: Local-first, SQLite

- **Ngày:** 2026-09-08
- **Quyết định:** Local-first, SQLite — client giữ toàn bộ DB, server (nếu có sau
  này) chỉ là relay.
- **Lý do:** Offline review miễn phí (NFR-03); không cần backend ở R1; DDL SQL thật
  thay vì API key-value; transaction ACID cho cards + review_logs.
- **Hệ quả:** DDL phải chuyển dialect từ Postgres (research docs) sang SQLite. Đa
  thiết bị → Later (docs/multi-client-sync.md).
- **Thay thế đã loại:** IndexedDB/Dexie — không phải SQL, tự viết lại join/transaction;
  query hai nhánh FR-11 phức tạp hơn nhiều.

## ADR-003 — API key: BYOK (Bring Your Own Key)

- **Ngày:** 2026-09-08
- **Quyết định:** User tự nhập API key + base URL trong app (default Gemini). Không
  proxy ở MVP.
- **Lý do:** Đơn giản nhất cho MVP một người dùng; key của chính user → NFR-07 thoả
  theo nghĩa key thuộc về chính user đó; không backend = không chi phí vận hành.
- **Hệ quả:** Key lưu local (SQLite settings), không nhúng vào bundle, ghi-only ở DOM.
  Proxy hoãn sang Later.
- **Thay thế đã loại:** Thin proxy backend — thêm chi phí vận hành, thêm attack surface,
  không cần thiết cho MVP.

## ADR-004 — Lemmatize: Không lemmatize term_normalized

- **Ngày:** 2026-09-08
- **Quyết định:** Giữ nguyên dạng từ, không lemmatize `term_normalized`. Chỉ lowercase
  + trim.
- **Lý do:** `run`/`running` là hai dòng — chấp nhận giảm độ phủ bộ lọc FR-10. Không
  thêm dependency lemmatizer. Chất lượng bộ lọc FR-10 chấp nhận giảm; Q-08/Q-09
  chốt sau khi có dữ liệu thật.
- **Hệ quả:** Một từ có thể xuất hiện nhiều dạng trong kho. Chống trùng nằm ở bộ lọc
  lúc trích xuất (FR-10), không phải ở DB (không unique constraint).

## ADR-005 — Learning steps: Tắt ở MVP

- **Ngày:** 2026-09-08
- **Quyết định:** Learning steps TẮT — thẻ mới sau lần chấm đầu đi thẳng vào review
  (interval ≥ 1 ngày). `enable_short_term: false` trong ts-fsrs.
- **Lý do:** Đơn giản hoá hàng đợi FR-11; con số FR-14 có tính nhất quán; bật lại
  được bằng setting ở R2.
- **Hệ quả:** `state='learning'` không bao giờ xuất hiện ở R1. Code R1 không bao giờ
  ghi state đó. Các cột `learning_steps` giữ nguyên hình dạng để R2 bật lại không
  cần migrate.

## ADR-006 — Buffer cuộn: 10 phiên đọc bền per collection

- **Ngày:** 2026-09-09 (đảo từ ADR-006 cũ "10 trang, xoá hết phiên")
- **Quyết định:** Lưu **chỉ text + dịch** của 10 phiên đọc gần nhất **PER COLLECTION**
  vào bảng `reading_sessions`. DB là nguồn duy nhất, buffer in-memory đã xoá.
- **Lý do:** A-08 của PRD ("người dùng không cần đọc lại trang đã đọc") bị bác bằng
  thực tế dùng thử — mở lại app thấy mất phiên chụp là mất, không phải hành vi chấp
  nhận được. Owner chốt 3 điểm: (1) ảnh VẪN cấm; (2) Collection Detail View 2 tab;
  (3) luật "lưu 1 lần" persist qua DB.
- **Hệ quả:** Migration v4 `reading_sessions`; trim 10 mới nhất/collection trong
  transaction; bỏ buffer in-memory; `ReadScreen` đọc DB + nhận `sessionId`.

## ADR-007 — UI-1: Bản song ngữ xen kẽ theo đoạn

- **Ngày:** 2026-09-08
- **Quyết định:** Bản gốc rồi bản dịch ngay dưới từng đoạn, 0 thao tác thêm.
- **Lý do:** Nguyên lý 2 của vision nói bản dịch "luôn nằm sẵn ngay cạnh bản gốc".
  Hai hướng còn lại bị loại: tap-to-reveal thêm thao tác vào đúng chỗ nguyên lý nói
  không được có ma sát; hai cột cuộn đồng bộ không khả thi ở chiều rộng điện thoại.
- **Hệ quả:** FR-05/FR-06 build theo kiểu xen kẽ. Toggle ẩn/hiện toàn bộ bản dịch
  bằng 1 thao tác.

## ADR-008 — UI-2: Card rút gọn mở inline

- **Ngày:** 2026-09-08
- **Quyết định:** Card rút gọn (term + pos + nghĩa tắt + chip trạng thái + checkbox),
  chạm mở inline đủ 6 field sửa ngay dưới, không rời danh sách. Unverified xếp
  LÊN ĐẦU + đánh dấu đỏ.
- **Lý do:** Information density cao trên mobile; không rời màn hình = giữ context;
  unverified lên đầu để owner xử lý trước.
- **Hệ quả:** FR-03/FR-09 build theo UI-2. `VocabEditScreen` dùng card rút gọn +
  inline edit.

## ADR-009 — Chuẩn tương tác ôn tập: Vuốt + chạm + undo nổi

- **Ngày:** 2026-09-09
- **Quyết định:** Vuốt TRÁI = Easy (4), vuốt PHẢI = Good (3), chạm = lật mặt sau.
  Mặt trước giữ FR-12 (chỉ term + pos). Undo NỔI 1 bước.
- **Lý do:** Owner yêu cầu chuẩn vuốt. Mặt trước giữ FR-12 đã chốt (không mở lại
  GP1 — owner chọn giữ chốt khi agent hỏi). Vuốt gọi đúng pipeline `gradeCard` →
  FSRS nhận đúng 3/4, log snapshot TRƯỚC, undo kéo về snapshot 100%.
- **Hệ quả:** `ui/swipe.ts` (hàm thuần) + 8 unit test. ReviewScreen kéo bằng pointer
  events — kéo dọc vẫn để trang cuộn, kéo dưới ngưỡng bật về KHÔNG chấm nhầm.

## ADR-010 — Rich vocab: 3 cột TEXT JSON trên vocab_items

- **Ngày:** 2026-09-08
- **Quyết định:** `tags`/`synonyms`/`antonyms` — 3 cột TEXT JSON trên `vocab_items`.
  AI sinh kèm lúc capture, user sửa được ở màn duyệt. Giới hạn 4 tags / 3 synonyms
  / 3 antonyms (RV-1).
- **Lý do:** Owner mở lại topic tag đã bị loại (tiền đề mới: 1 từ nhiều chủ đề + AI
  sinh kèm capture + user sửa được). 3 cột JSON thay vì bảng junction vì sync nhẹ,
  quy mô cá nhân.
- **Hệ quả:** Migration v3 (3 `ALTER TABLE`); prompt v2 + schema 3 props optional;
  `verify.ts` `normalizeRichField` (thiếu/sai type → `[]`); `word_relations` R2 KHÔNG
  bị huỷ — vẫn là cơ chế *luyện* cặp quan hệ.

## ADR-011 — Targeted review: Chấm + log mode='cram', KHÔNG đụng FSRS state

- **Ngày:** 2026-09-08
- **Quyết định:** Cram theo tag = chấm + log `mode='cram'`, không cập nhật `cards`.
  Buổi ôn tức thì không dịch chuyển lịch dài hạn.
- **Lý do:** Q-11 chốt một phần đi đường "chấp nhận" — đo bằng dữ liệu thật ở 3.11.
  Lọc theo tag qua `json_each`; không giới hạn `daily_new_limit`; undo = xoá log.
- **Hệ quả:** `countIntroducedNew` chỉ đếm `mode='srs'` — log cram thẻ mới KHÔNG ăn
  suất hạn mức FR-11. Log cram vẫn tham gia streak (FR-14).

## ADR-012 — Import từ vựng: merge + remap id, cả JSON + TSV

- **Ngày:** 2026-09-09
- **Quyết định:** Nhập 2 định dạng (JSON `reado-export` v1 + TSV 7 cột). Merge +
  remap id khi đụng. TSV bắt buộc chọn collection đích hoặc tạo mới trước khi nhập.
  Atomic 1 transaction.
- **Lý do:** IMP-01→IMP-04 đã chốt. Chiều ngược của FR-16 (export). Không va NG-07
  (import từ file backup ≠ input path capture).
- **Hệ quả:** Task 3.16. PRD sẽ thêm FR-20 Data Import khi owner GO.

## ADR-013 — Storage: SQLite-WASM trong Web Worker

- **Ngày:** 2026-09-08
- **Quyết định:** DB mở trong Web Worker (`storage/dbWorker.ts`). Kernel chọn:
  `opfs` → `opfs-sahpool` → `:memory:` kèm cảnh báo.
- **Lý do:** sqlite-wasm từ chối cài VFS `opfs` ở main thread (cần `Atomics.wait()`).
  VFS `opfs-sahpool` cũng cần Worker (Chrome không expose `createSyncAccessHandle`
  ngoài Worker). Mở ở main thread → âm thầm rơi `:memory:` → mất dữ liệu sau F5.
- **Hệ quả:** `AppDb` thành facade async + mutex; host production PHẢI gửi COOP/COEP;
  `journal_mode` trên OPFS là `delete`, không phải WAL — an toàn nhờ transaction.

## ADR-014 — Git: Commit chỉ chứa code trong app/

- **Ngày:** 2026-09-08
- **Quyết định:** Agent commit từng step code, commit CHỈ chứa code trong `app/`.
  Toàn bộ docs/plan ở root nằm NGOÀI git. Ngoại lệ duy nhất: `.gitignore` root.
- **Lý do:** Tránh lẫn lộn nhiều thứ khó maintain. Docs/plan là tài liệu tham khảo,
  không phải code deployable.
- **Hệ quả:** Mỗi step code xong (check xanh) → commit ngay với message chi tiết;
  KHÔNG `git add` bất kỳ file root nào.

## ADR-015 — Sync Later: Server là source of truth

- **Ngày:** 2026-09-08
- **Quyết định:** Server = source of truth cho sync đa thiết bị. DB server là bản
  chính (USN + conflict resolution); DB local là bản cache đầy đủ, ghi offline được.
  SaaS đa user, guest-first. Ảnh KHÔNG lưu. Kho tạm = con trỏ per-device. Conflict
  = LWW theo `modified_at`.
- **Lý do:** Owner vẽ hướng kiến trúc + review draft agent ngoài. Phân tích đầy đủ ở
  docs/multi-client-sync.md.
- **Hệ quả:** CHỈ cho scope Later — không đổi gì ở R1/R2. Q-02 local-first vẫn còn
  hiệu lực. MS-08/09/10 đã chốt.

## ADR-016 — UI Library: shadcn/ui

- **Ngày:** 2026-09-10
- **Quyết định:** Dùng shadcn/ui làm component library — copy-paste components, không
  runtime dependency. Kết hợp Tailwind CSS làm utility layer.
- **Lý do:** Có sẵn accessible components, touch targets ≥ 48px, dark mode miễn phí.
  Refactor toàn bộ 1 lần thay vì polish từng phần.
- **Hệ quả:** Thêm Tailwind CSS + shadcn/ui vào Vite config. Refactor CSS hiện tại
  sang utility classes. Component library phục vụ cả A11y baseline.

## ADR-017 — State Management: Zustand setup architecture

- **Ngày:** 2026-09-10
- **Quyết định:** Setup Zustand + tạo store pattern chuẩn, refactor 1-2 screen làm
  ví dụ. Ít rủi ro, không phá vỡ flow hiện tại.
- **Lý do:** R2 sẽ thêm `word_relations` + statistics + notifications — state phức tạp
  hơn. Setup architecture bây giờ để dùng dần.
- **Hệ quả:** Thêm Zustand dependency. Tạo store pattern (homeStore, reviewStore).
  Refactor HomeScreen + ReviewScreen làm ví dụ.

## ADR-018 — i18n: Setup nền tảng (tách UI strings + react-i18next)

- **Ngày:** 2026-09-10
- **Quyết định:** Tách UI strings ra file constants + thêm react-i18next, giữ tiếng
  Việt làm default. Dễ mở rộng sau, không phá vỡ gì.
- **Lý do:** Strings nằm rải rác trong component → refactor sau tốn hơn. Setup nền
  tảng bây giờ để R2 mở rộng internationalisation dễ dàng.
- **Hệ quả:** Thêm react-i18next dependency. Tạo file `locales/vi.json`. Refactor
  1-2 screen làm ví dụ.

## ADR-019 — Analytics: Query script từ Node (chạy trên export JSON)

- **Ngày:** 2026-09-10 (điều chỉnh phương án TRƯỚC khi code — chưa có gì đã chạy)
- **Quyết định:** Node script (`scripts/analytics.mjs`) chạy trên FILE EXPORT JSON
  của FR-16, xuất bảng đọc được + khối JSON ra terminal. Đủ để đo M-01/M-02/
  M-04/M-05/M-08 (thói quen ôn, hàng đợi, chất lượng chấm, tốc độ bồi kho).
- **Lý do:** DB thật nằm trong OPFS của TRÌNH DUYỆT (per-origin) — Node không đọc
  được OPFS qua đường dẫn file. Export JSON của FR-16 (items + cards + review_logs
  + settings) là ảnh chụp đầy đủ của dữ liệu thật, không có gì khác chỉnh. Script
  chạy thuần trên file đó: không cần mở app, không cần thêm code phía app.
- **Hệ quả:** `npm run analytics -- <file.json>` sau khi export trong app. GIỚI
  HẠN đã biết: bảng `analyses` (latency/token AI) KHÔNG nằm trong export — số đo
  đó xem trong màn Kiểm tra lưu trữ của app.

## ADR-020 — Error Handling: Error Boundary + Toast notification

- **Ngày:** 2026-09-10
- **Quyết định:** Thêm React Error Boundary + toast/notification system đơn giản
  (không cần library — dùng `<dialog>` hoặc state trong AppRoot).
- **Lý do:** Hiện tại nhiều lỗi nuốt bằng `console.error` mà user không thấy. Storage
  errors, reading session persist errors im lặng.
- **Hệ quả:** `ErrorBoundary` component bọc toàn app. Toast state trong AppRoot +
  `useToast()` hook. Storage errors hiển thị toast thay vì console.error.

## ADR-021 — Code Splitting: React.lazy cho screens

- **Ngày:** 2026-09-10
- **Quyết định:** Lazy load screens bằng React.lazy + Suspense. Chỉ load screen khi
  user navigate tới.
- **Lý do:** Bundle hiện tại load toàn bộ screens ngay từ đầu. Mobile performance
  improvement khi app lớn hơn.
- **Hệ quả:** `AppRoot` import screens qua `React.lazy()`. Thêm `<Suspense>` fallback.
  Không phá vỡ flow hiện tại.

## ADR-022 — A11y: Baseline accessibility

- **Ngày:** 2026-09-10
- **Quyết định:** Thêm `aria-label` cho buttons, `role` cho interactive elements,
  keyboard support cho review screen. Focus management cơ bản.
- **Lý do:** Accessibility là baseline đạo đức + luật pháp. Hiện tại owner dùng bằng
  tay trên mobile nên chưa lộ, nhưng cần baseline trước khi release.
- **Hệ quả:** Review screen hỗ trợ keyboard (Enter/Space lật, arrow keys chấm).
  Buttons có `aria-label`. Focus trap cho modals.

## ADR-023 — Unified scripts: check + e2e:all

- **Ngày:** 2026-09-10
- **Quyết định:** Thêm `npm run check` (lint + typecheck + test + build) và
  `npm run e2e:all` (chạy toàn bộ e2e suite). `npm start` = alias của `npm run dev`.
- **Lý do:** Developer velocity — verify nhanh trước khi commit. Unified e2e runner
  để chạy tất cả flow.
- **Hệ quả:** Scripts mới trong package.json. `check` chạy tuần tự, dừng nếu có lỗi.
  `e2e:all` chạy tất cả e2e scripts theo thứ tự.

## ADR-024 — Vuốt chấm mở trên CẢ hai mặt thẻ (sau khi lật xem detail)

- **Ngày:** 2026-09-10
- **Quyết định:** Chuẩn vuốt ADR-009 (trái = Dễ/Easy, phải = Tốt/Good) hoạt động
  trên CẢ mặt trước và mặt sau thẻ: sau khi chạm để lật xem detail, vuốt trái/phải
  vẫn chấm Easy/Good rồi qua thẻ kế. Áp dụng đồng bộ ReviewScreen + CramScreen.
  Lớp phủ tint + badge "Dễ"/"Tốt" render chung cho hai mặt. Chạm trên mặt sau vẫn
  không làm gì (không có cơ chế lật ngược về mặt trước — không nằm trong yêu cầu).
- **Lý do:** Owner yêu cầu: tap hiện detail xong vẫn có cơ chế vuốt đánh dấu độ
  khó dễ rồi qua từ mới. Giữ nguyên chiều mapping ADR-009 để hai mặt nhất quán
  (đổi chiều giữa hai mặt là cái bẫy chấm nhầm); 4 mức đầy đủ Lại/Khó/Tốt/Dễ vẫn
  ở 4 nút dưới thẻ.
- **Hệ quả:** Bỏ chặn `flipped` trong `onPointerDown` của cả hai màn; overlay
  tint/badge render thường trực (`zIndex: 2`, `pointerEvents: none`); hint nhỏ
  "vuốt ◀: Dễ · vuốt ▶: Tốt" ở chân mặt sau (`.review-swipe-hint`); `ui/swipe.ts`
  hàm thuần KHÔNG đổi — test vẫn pass; aria-label mặt sau bổ sung chỉ dẫn vuốt.

## ADR-025 — Chuẩn vuốt chấm (iOS v2): trái = Again · phải = Good — đảo ADR-009

- **Ngày:** 2026-09-18
- **Quyết định:** Màn ôn (J3/J4/J5): vuốt TRÁI = **Again (1)**, vuốt PHẢI = **Good (3)**;
  Hard / Easy là nút. Đủ 4 mức — không rút FSRS còn 2 giá trị. Chạm lật, undo nổi 1 bước giữ nguyên.
- **Lý do:** Bản flow spec v2 [docs/journeys.md](docs/specs/journeys.md) mục 4
  ("Gesture") viết lại chiều mapping sau pivot iOS (09-17); ADR-009 (PWA) ghi hướng khác.
  Owner chốt theo journeys ngày 2026-09-18.
- **Hệ quả:** ROADMAP task 2.5 cam theo chốt này. ADR-024 phần "vuốt hoạt động trên
  **cả hai mặt** thẻ" không bị journeys nhắc tới → giữ hiệu lực tới khi owner đổi.

## ADR-029 — Q-10: 10 phiên đọc bền per collection có tên (đảo v0.3 buffer-trôi)

- **Ngày:** 2026-09-18
- **Quyết định:** Lưu **text + dịch + summary** của **10 phiên đọc gần nhất PER NAMED
  COLLECTION** vào bảng `reading_sessions`, để đọc lại trang cuối — mục đích dễ đọc
  sách. **Kho tạm (`is_default = 1`) KHÔNG lưu phiên.** Một capture thành công = một
  session; phiên thứ 11 trôi (trim trong transaction).
- **Lý do:** Owner chốt Q-10 khi đối chiếu journeys 2026-09-18: capture vào collection
  xong mà đóng app là mất trang đã đọc — hành vi không chấp nhận được với sách (lặp
  lại đúng lý do đảo ADR-006 thế hệ PWA: assumption A-08 của PRD bị thực tế bác).
- **Hệ quả:** `db.md` tầng A thêm bảng `reading_sessions` (FK collection, cascade);
  FR-05/FR-06, NFR-04, PRD mục 10 và journey J2 cập nhật. Ảnh trang **vẫn cấm**
  tuyệt đối.

## ADR-030 — Song ngữ: xen kẽ mặc định + nút nhỏ reveal

- **Ngày:** 2026-09-18
- **Quyết định:** Bản song ngữ mặc định **xen kẽ theo đoạn, 0 thao tác** (giữ ADR-007);
  cộng một **nút nhỏ cố định phía dưới** màn đọc: 1 tap = ẩn/hiện toàn bộ bản dịch
  (FR-05 c.2). Không dùng tap-to-reveal trọn trang làm mặc định.
- **Lý do:** Owner chốt khi đối chiếu journeys (journey từng ghi tap-to-reveal —
  phương án đã bị loại ở ADR-007).
- **Hệ quả:** FR-05 c.2 và session detail của J2 build theo chuẩn này.

## ADR-031 — Settings R1: `day_cutoff_hour` có núm

- **Ngày:** 2026-09-18
- **Quyết định:** Màn Settings R1 (J-R1-S) có núm **giờ chuyển ngày**
  `day_cutoff_hour` (mặc định 04:00, 0–23) — FR-11 yêu cầu "cấu hình được".
- **Lý do:** Owner chốt khi đối chiếu journeys (journey thiếu núm này dù FR-11 và
  schema `settings` đã có cột).
- **Hệ quả:** PRD mục 10 nới FR-15 từ 2 núm lên 3; journey J-R1-S và J8 cập nhật;
  schema không đổi (cột đã có sẵn kèm CHECK).

> **ADR-026..028 — bản ghi bổ sung 2026-09-18 (task 0.2 ROADMAP).** Quyết định chốt
> 2026-09-17 (pivot v2); số đã được giữ sẵn nên ghi sau các ADR ngày 18. Nội dung
> đảo ADR-001/002/003 đúng thể thức "thêm ADR mới, không sửa ADR cũ".

## ADR-026 — Platform: Native iOS (SwiftUI) — đảo ADR-001

- **Ngày:** 2026-09-17 (bản ghi bổ sung 2026-09-18)
- **Quyết định:** Sản phẩm R1 là **app iOS native** (Swift / SwiftUI). Không ship
  Android, không ship PWA sản phẩm. `web/` (Vite + React) chỉ là clickable prototype
  theo [docs/journeys.md](docs/specs/journeys.md) — **không** port từng
  component sang SwiftUI.
- **Lý do:** (1) FR-11 nhắc ôn đi đường **APNs thật** — PWA trên iOS không push tin
  cậy (ADR-001 chính nó đã nhận). (2) Capture (NFR-08) dùng camera/picker hệ thống
  (`UIImagePicker` / `PhotosUI`) — lợi thế "hệ sinh thái crop/camera web" của ADR-001
  không còn thắng native. (3) Ràng buộc NG-09 (không tự viết SRS): nơi chạy FSRS phải
  có binding maintainable — `swift-fsrs` (FSRS-6 opt-in) trả lời thẳng trên máy.
  (4) NFR-03 ôn offline đơn giản đi hẳn: SQLite gốc trên máy, hết SQLite-WASM-trong
  Worker + COOP/COEP (nỗi đau ADR-013, thế hệ PWA).
- **Hệ quả:** Code đi vào `app/` (`Reado.xcodeproj` + `ReadoKit`); bản PWA cũ trong
  `app/` đã xoá theo lệnh owner 2026-09-18 (git history giữ commit cuối `cbdaf43`).
  Các ADR thuần PWA-tech (016 shadcn · 017 zustand · 018 i18n · 021 lazy · 022 a11y
  web) **không** chuyển sang SwiftUI — quyết định lại lúc solution design. FSRS
  binding chốt `swift-fsrs` + `FSRSDefaults.defaultWv6` (21 trọng số).
- **Thay thế đã loại:** Giữ PWA sản phẩm (ADR-001) — push kém tin cậy + storage
  WASM phụ thuộc header hosting; ship Android song song R1 — nhân đôi chi phí cho
  một sản phẩm một người dùng.

## ADR-027 — Dữ liệu: local-first SQLite **trên máy**; BE đầy lùi về Later — đảo ADR-002

- **Ngày:** 2026-09-17 (bản ghi bổ sung 2026-09-18)
- **Quyết định:** vocab · `cards` · `review_logs` nằm trong **SQLite trên thiết bị**.
  Dashboard sản phẩm (kho từ, stats học), auth và sync đa thiết bị = **Later** — cửa
  mở bằng `uuid` do client sinh, không phải bằng cách dựng BE đầy ở tuần đầu.
- **Lý do:** (1) NFR-03 (ôn offline) thoả gần như miễn phí ở R1 — hết tiền đề "mỗi
  lần chấm thẻ là một request". (2) **Một** FSRS duy nhất trên máy: FSRS là pure
  function, client tự tính lịch, không ai khác chạy scheduler. (3) R1 một người
  dùng không biện minh nổi chi phí vận hành server DB; Postgres trở lại khi Later
  mở dashboard/sync.
- **Hệ quả:** Dialect thật là SQLite (CSQLite systemLibrary, no-dep —
  `ReadoKit/Database/`); DDL theo [docs/db.md](docs/specs/db.md) tầng A (migration v1 + seeder
  dựng 2026-09-18); mapping chốt: uuid `TEXT` chữ thường · timestamp ISO-8601 UTC
  hậu tố `Z` · `fsrs_params` TEXT JSON. Cảnh báo Later: khi có bản sao `cards` trên
  server, **cấm** chạy FSRS thứ hai trên đường request (dual-FSRS) — server chỉ lưu
  snapshot đã tính, scheduler chỉ trên máy.
- **Thay thế đã loại:** BE đầy server-side ngay R1 (chốt 2026-09-08) — mỗi chấm thẻ
  là một request, offline phải vá cache/outbox + FSRS hai phía (đường A/B/C trong
  tech-stack đều hỏng cho R1); SQLite-WASM/OPFS trong Web Worker (cách ADR-002 thế
  hệ PWA từng chạy) — phụ thuộc COOP/COEP + VFS per-browser, hết lý do khi đã native.

## ADR-028 — API key: hybrid — proxy mặc định + BYOK OpenAI-compat (Keychain) — đảo ADR-003

- **Ngày:** 2026-09-17 (bản ghi bổ sung 2026-09-18)
- **Quyết định:** **Proxy Reado** (key sản phẩm ở `.env` server) là **mặc định**.
  User có thể thêm **agent OpenAI-compat** + key riêng lưu **Keychain** và chọn một
  agent **active** cho FR-02 (FR-21). Key sản phẩm không lên client; key user không
  plaintext (không SQLite, không FR-16 export), không lên server Reado.
- **Lý do:** (1) NFR-07 cấm nhúng key Gemini vào app bundle — proxy che key sản phẩm.
  (2) Telemetry M-03/M-04 (`analysis_events`) và idempotency `image_hash` cho FR-02
  cần điểm tập trung là proxy. (3) Hybrid trả quyền kiểm soát cho user (FR-21) thay
  vì khoá cứng proxy-only; lớp cô lập AI là **adapter trên iOS** (`reado_proxy` vs
  `openai_compat`) — đổi Gemini phía Reado = sửa proxy; đổi provider phía user =
  thêm hàng `analysis_agents`; SwiftUI không biết wire schema Google/OpenAI.
- **Hệ quả:** Verify `example` chạy ở adapter đang active (trên proxy cùng request,
  hoặc trên máy khi BYOK) — app luôn nhận item đã gắn nhãn `verified/suspect/
  unverified`. Keychain ghi-only, key không bao giờ hiện/ghi log. NFR-07 viết lại:
  key sản phẩm trên proxy, key user ở Keychain; network trace máy có thể thấy gọi
  `base_url` user tự khai khi active BYOK — hệ quả đã chấp nhận. Proxy phải **hosted
  + HTTPS**, không laptop-local.
- **Thay thế đã loại:** BYOK thuần (ADR-003) — trải nghiệm khoá vào key Gemini cá
  nhân + mất telemetry tập trung; proxy-only (chốt sáng 2026-09-17, bia mộ tech-stack
  mục 2.3) — khoá cứng tính mở của FR-21.

## ADR-032 — FR-10 bộ lọc "đã thuộc": Q-06 / Q-08 / Q-09

- **Ngày:** 2026-09-22
- **Quyết định:** Bộ lọc "từ đã thuộc" của FR-10 (chống trùng lúc trích xuất) chốt
  ba núm một lượt:
  - **Q-06 — Không lemmatize.** Mỗi word form là một dòng: `running` ≠ `run`,
    `took` ≠ `take`. `term_normalized` giữ nguyên form (khớp FR-20 export/import).
  - **Q-08 — "Đã thuộc" = FSRS `stability ≥ 21 ngày`.** Tương đương Anki "mature"
    (interval ≥ 21 ngày); không đo bằng số lần gặp.
  - **Q-09 — So khớp trong phạm vi một collection** (không toàn cục).
- **Lý do:** Q-06 — gộp word form dễ gộp nhầm nghĩa, bộ lọc study-session đơn giản
  hơn khi không cần luật biến hình. Q-08 — 21 ngày là mốc "chín" của Anki, là tín
  hiệu spaced-repetition chuẩn cho "thuộc thực sự"; `stability` là đại lượng native
  của FSRS nên dùng trực tiếp. Q-09 — mỗi collection ≈ một cuốn sách với vùng từ
  riêng; nghĩa mới của một surface form cũ (đã học ở sách khác) vẫn phải được thêm.
  Trùng từ giữa collection chấp nhận — mỗi từ có learning curve riêng, user thấy quen
  thì bấm Easy (owner).
- **Hệ quả:** FR-10 (task 3.8) thôi bị chặn bởi Q-06/Q-08/Q-09. Truy vấn bộ lọc:
  thẻ `state='review'` + `stability >= 21` trong `scope = collection đang chụp`.
  **Ngưỡng leech FR-19 (đếm `lapses`) VẪN MỞ** — Anki mặc định 8, code placeholder 6
  (`Seeder.defaultLeechLapses`); đừng gộp với Q-08 (đã thuộc = stability, leech =
  "sai hoài").

## ADR-033 — Vuốt chấm Tinder-style trên CẢ hai mặt thẻ (iOS v2)

- **Ngày:** 2026-09-24
- **Quyết định:** Vuốt chấm màn ôn chuyển Tinder-style: thẻ kéo theo tay, nghiêng theo
  hướng kéo, stamp "Quên" (trái, đỏ) / "Được" (phải, xanh), ngưỡng điểm-thoát-dự-đoán 110pt
  → bay ra + chấm, dưới ngưỡng bật về. Vuốt hoạt động trên **CẢ hai mặt thẻ** (kể cả chưa
  lật) — đảo đoạn "sau khi lật thẻ" của ADR-025. Mapping giữ nguyên: trái = Again(1),
  phải = Good(3); Hard/Easy là nút; tap vẫn lật.
- **Lý do:** Owner yêu cầu cải tiến cảm giác từ drag tĩnh (nhận diện sau khi thả, ngưỡng 60pt).
  ADR-024 (PWA) từng ghi "vuốt cả hai mặt", ADR-025 giữ hiệu lực "tới khi owner đổi" — owner
  chốt 2026-09-24.
- **Hệ quả:** `ReviewQueueView` thêm offset/tilt/stamp + `predictedEndTranslation`; hint mặt
  trước giờ đúng nghĩa. journeys mục 4 "Gesture" bỏ "sau khi lật thẻ".
  Hướng bay lấy cùng dấu predicted (không lấy vị trí tay lúc nhả). Xoay rồi mới offset,
  neo tâm thẻ. Thẻ kế nhô phía sau. Reduce Motion bỏ bám tay/bay; VoiceOver có action
  Quên/Được trên mặt trước. Ngưỡng nằm ở `SwipeCommit` (test được).

## ADR-034 — A-01: OCR trên máy, một lần gọi agent text (dịch + vocab)

- **Ngày:** 2026-09-24
- **Quyết định:** Reinterpret A-01. Capture vẫn là ảnh (NG-07). `openai_compat` chạy
  `VNRecognizeTextRequest` trên máy, ghép dòng theo bounding box (hai cột nếu khe X rõ),
  rồi **một** lần `chat/completions` **chỉ text** — agent làm dịch + vocab + summary.
  OCR trống / không đọc được → `AnalysisError.imageUnreadable` (FR-04), **không** gửi
  JPEG, **không** fallback ảnh. `reado_proxy` không đổi (vẫn multipart ảnh). Không thêm
  agent thứ hai; không Translation.framework; không Live Text overlay.
- **Lý do:** Owner chốt: ảnh không rời máy (NFR-04/NFR-02); A-01 nghĩa là **một lần
  phân tích** (FR-21), không bắt buộc multimodal. OCR là hạ tầng capture như crop.
- **Hệ quả:** `PageOCR` + prompt `PAGE_OCR` (`PROMPT_VERSION` 3) + `OpenAICompatClient`
  bỏ `image_url`. Model text (không-VL) dùng được. So 3–5 trang sách thật với lần gửi
  ảnh (chữ + tiền) làm sau khi T2 chạy được trên máy. PRD chữ "multimodal" chưa viết
  lại — ADR này là nguồn chốt.

## ADR-035 — Agent tooling: chỉ Claude Code; protocol gộp vào CLAUDE.md

- **Ngày:** 2026-09-26
- **Quyết định:** Bỏ DSH / Cursor. `AGENTS.md` thành stub; protocol còn giá trị (workflow, đọc file lớn, pbxproj, bẫy build) chuyển vào `CLAUDE.md` §7. Build/test chỉ qua `scripts/test.sh`. Xoá `.cursorignore`, `scripts/smart_glob.py`, các luật token kiểu DSH (cache prefix, cấm read lại, trần steps/turn).
- **Lý do:** Claude Code chỉ tự load `CLAUDE.md`; prompt cache, dedupe Read, Glob tôn trọng `.gitignore` đã do harness lo. Lệnh build lệch nhau + permission pattern hỏng làm mỗi lần build phải hỏi.
- **Hệ quả:** Bẫy cố định ở `CLAUDE.md` §7; `session-brief.md` §3 chỉ còn bẫy mới. `.claude/settings.json` allow `scripts/test.sh`, deny Read cache build.

## ADR-036 — Camera tự vẽ bằng AVFoundation, bỏ `UIImagePickerController`

- **Ngày:** 2026-09-26
- **Quyết định:** `CaptureView` không còn dùng `UIImagePickerController` (camera lẫn
  thư viện). Camera chuyển sang `CameraController` (`AVCaptureSession` +
  `AVCapturePhotoOutput`, tự vẽ preview bằng `AVCaptureVideoPreviewLayer`) với
  chrome SwiftUI thật (nút X, chip đích lưu, `+`, thư viện, shutter, flash) đè
  lên trên. Thư viện chuyển sang `PhotosPicker` (PhotosUI). Crop
  (`TOCropViewController`) hiển thị trực tiếp trong `ZStack` của `CaptureView`
  (không `.sheet`) nên full màn. `RootView`/`StreakCalendarView` mở `CaptureView`
  bằng `.fullScreenCover` thay `.sheet`.
- **Lý do:** Bug thật owner báo (2026-09-26): chụp ảnh màn đen, không có nút
  thoát khi đổi ý, chọn ảnh thư viện lần đầu đen (phải thoát vào lại mới hiện),
  khung crop đè tab bar. Đọc code: `picker.addChild(hosting)` gắn overlay
  SwiftUI làm con của `UIImagePickerController` (một `UINavigationController`)
  → hosting view (nền trong nhưng vẫn chiếm layer) đẩy lên TRÊN preview camera
  + nút Cancel/chụp hệ thống → che hết, không có đường thoát. Thư viện qua
  `UIImagePickerController` trong sheet lồng sheet là bệnh đen quen của iOS
  17+. Crop mở bằng `.sheet` không full màn nên toolbar của crop đè tab bar.
- **Hệ quả:** J1 vẫn ≤3 thao tác (chụp/chọn → crop → duyệt từ). Không thêm
  dependency (AVFoundation/PhotosUI là hệ thống, TOCropViewController đã có).
  Verify: build + 211/212 test xanh (không có logic thuần mới cho camera nên
  không thêm unit test); chrome (X/chip/+/thư viện/shutter/flash) và luồng xin
  quyền camera đã xem trên simulator (screenshot); preview + chụp thật cần máy
  thật (simulator có thể không có camera, tuỳ Mac host webcam passthrough).

## ADR-037 — Log chẩn đoán DEBUG (`DebugTrace`) + OCR tự ngắt đoạn + prompt v5

- **Ngày:** 2026-09-26
- **Bối cảnh:** Owner báo bản dịch bị chia sai đoạn (paragraph), lúc gộp nhiều
  đoạn sách làm một, lúc chia vụn — không đều giữa các lần gọi. Owner không đọc
  được OCR đã ra gì nên không tự debug được; owner build thẳng bằng Xcode Run
  lên máy cá nhân dùng hằng ngày, ~7 ngày sửa một lần.
- **Nguyên nhân:** `PageOCR.orderColumn` (trước ADR này) nối MỌI hàng trong một
  cột bằng `\n` đơn; `\n\n` chỉ xuất hiện giữa hai cột. Trang 1 cột (phổ biến
  nhất) gần như không bao giờ có `\n\n`, nên dù prompt v4 dạy "`\n\n` = đoạn
  mới", model vẫn phải tự đoán ranh giới đoạn bằng nghĩa — đoán không ổn định.
- **Quyết định:**
  1. **OCR tự dò ranh giới đoạn bằng hình học** (`PageOCR.linesWithBreaks`,
     cột ≥ 3 hàng): khoảng trống dọc > 1.5× median, hoặc thụt đầu dòng > 0.8×
     chiều cao trung vị (kèm hàng sau quay lại lề), hoặc hàng trước ngắn +
     kết câu (`. ? ! : " ” ’ )`) và cách lề phải > 15% bề rộng cột → chèn
     `\n\n`. Cột < 3 hàng giữ `\n` như cũ (không đủ dữ liệu tính median tin cậy).
  2. **Prompt v5** (`Prompt.version`): đổi luật từ "tự đoán ranh giới" sang
     "tin `\n\n` của OCR, chỉ ghép lại khi rõ ràng vô lý (rơi giữa câu)".
  3. **`DebugTrace`** (ReadoKit, `Diagnostics/`) — kho log **chỉ bản DEBUG**:
     `Documents/Diagnostics/events.jsonl` (sự kiện rời: lỗi DB, quyền camera,
     lưu collection...) và `Documents/Diagnostics/analyses/<ts>_<id8>/` (một
     thư mục mỗi lần phân tích: `page.jpg`, `page_ocr.txt`, `ocr.json` — từng
     hàng kèm lý do ngắt đoạn, `response_raw.txt`, `analysis.json`, `meta.json`
     — model/timing/lỗi). Giữ tối đa 30 thư mục gần nhất, `events.jsonl` xoay
     vòng ở 2 MB. `mergeMeta`/`event` tự redact field có tên giống secret
     (key/token/authorization/secret/password) — lưới an toàn thứ hai, không
     thay cho việc tự soát ở chỗ gọi.
  4. **Ngoại lệ NFR-04** (ảnh gốc không lưu): CHỈ trong log DEBUG, ảnh đã crop
     (không phải ảnh gốc trước crop) được giữ tạm để đối chiếu OCR, xoay vòng
     30 lần, chỉ nằm trên máy — không rời máy, không có ở bản Release.
  5. `scripts/pull_diagnostics.sh [sim|device]` kéo `Documents/Diagnostics/`
     về `.tmp/diagnostics/<ts>/`; `scripts/diag_summary.py <dir>` in tóm tắt
     (timing, số hàng OCR, chỗ ngắt đoạn kèm lý do, số segment) — đọc bản tóm
     tắt này thay vì mở từng file JSON.
- **Lý do:** Sửa gốc rễ (hình học OCR) thay vì chỉ vá prompt (model vẫn phải
  đoán, kết quả đổi theo model/lần gọi). Log là cách duy nhất để owner "cắm
  điện thoại vào" mà không cần tự đọc OCR — owner xác nhận chấp nhận đổi
  NFR-04 phạm vi hẹp (DEBUG-only, xoay vòng, không rời máy) để đổi lấy khả
  năng debug.
- **Hệ quả:** `PageOCR.Line`/`OCRResult` public — `recognizeDetailed` có default
  impl nên `FixedPageOCR` (AnalysisTests) không phải sửa. `OpenAICompatClient`
  và `ReadoProxyClient` đều mở một `DebugTrace.AnalysisSession` mỗi lần
  `analyze`. `CameraController`/`CaptureView` ghi sự kiện quyền/chụp/crop vì
  ADR-036 (camera AVFoundation) chưa test được trên máy thật. Ngưỡng ở
  `PageOCR` (gapBreakFactor/indentFactorOfHeight/shortEndingFactorOfWidth) là
  hằng số đặt tên, chỉnh lại sau khi có log thật từ owner (không đoán tiếp
  bằng mắt). Test: `PageOCRTests` (5 ca hình học mới) + `DebugTraceTests`
  (ghi file, redact, xoay vòng 30 thư mục) — 220/221 xanh (1 skip
  `LiveAIBoxTests` không có key mạng thật).

## ADR-038 — Đảo "chống gamification" thành ăn mừng tiến bộ đo được (J4/T1)

- **Ngày:** 2026-09-26
- **Bối cảnh:** `docs/ux/visual-redesign-plan.md` §3 và comment cũ ở
  `ReviewQueueView` ("Hết thẻ hôm nay không nảy vào — chống gamification")
  diễn giải vision #6 (Journey Over Summary) thành "chống gamification" nói
  chung — kéo theo màn "Hết thẻ hôm nay" chỉ hiện một dòng trung tính, không
  phản chiếu gì về buổi vừa ôn. Đọc lại vision #6: nguyên lý này chống *tóm
  tắt thay đọc* (ép người dùng nhìn số liệu thay vì đọc sách thật), không cấm
  ghi nhận tiến bộ đã đo được. Owner xác nhận 2026-09-26 muốn khuyến khích ôn
  hằng ngày (M-02/FR-14) bằng cách ăn mừng đúng những gì đã xảy ra.
- **Quyết định:** Đảo phần diễn giải UX — màn xong buổi (`SessionDoneView`,
  motivation-r1 T1) và toast lúc chấm chỉ ăn mừng **tiến bộ đo được**: số thẻ
  đã ôn, % không-Again, từ vừa "đã thuộc" (Q-08: `stability >= 21` VÀ
  `state == 'review'`, hằng số gom về `Mastery.stabilityThreshold`), streak
  hiện tại (FR-14). KHÔNG điểm/XP ảo, KHÔNG leaderboard (NG-04 giữ nguyên),
  KHÔNG đổi màu nút grade (giữ §3 — Again/Hard/Good/Easy vẫn trung tính, không
  tô kiểu game). Vào hàng đợi đã hết sẵn từ đầu (chưa chấm gì phiên này) vẫn
  giữ màn trung tính cũ — không ăn mừng cái mình không làm.
- **Lý do:** Ghi nhận đúng việc đã làm không phải là tóm tắt thay đọc; tách
  rõ "ăn mừng số đo có thật" khỏi "điểm ảo" giữ đúng cả vision #6 và M-02 mà
  không cần đổi schema/transaction.
- **Hệ quả:** `ReadoKit` thêm `Mastery` (ngưỡng + `crossed(before:after:
  stateAfter:)`) và `SessionTally` (đếm dồn phiên, undo đúng 1 bước qua stack
  entry — FR-12). `AppModel.grade` trả `GradeResult { logID, crossedMastery }`
  thay vì `String` trần — tính từ snapshot trước/sau đã có, không query DB
  thêm. `docs/ux/visual-redesign-plan.md` §3 giữ nguyên cho nút grade; chỉ
  màn xong buổi đổi diễn giải. Test: `SessionTallyTests` (mới) + suite cũ
  228 test, 227 xanh/1 skip (`LiveAIBoxTests`, không có key mạng thật).

## ADR-039 — "Học thêm 10 từ" nới hạn mức trong bộ nhớ app, N cố định (T2)

- **Ngày:** 2026-09-26
- **Bối cảnh:** `SessionDoneView` (T1, ADR-038) ăn mừng tiến bộ đo được nhưng
  chưa cho user chủ động học thêm khi vừa hết hàng đợi mà vẫn còn thẻ mới tồn
  trong kho (bị `daily_new_limit`, FR-11 chặn). Owner 2026-09-26 chốt hai câu
  hỏi mở (Q-A, Q-B) trước khi code.
- **Quyết định:**
  - **Q-A:** phần nới hạn mức giữ **trong bộ nhớ app** (`AppModel`), gắn theo
    `dayStart` (giờ chuyển ngày FR-11, không nửa đêm hệ thống) — KHÔNG lưu
    DB, KHÔNG migration, KHÔNG đổi `Migration.swift`. Thoát app mất phần nới
    chưa dùng; thẻ đã học vẫn đếm đúng vì `newIntroducedCount` suy từ
    `review_logs`, không phải một counter riêng.
  - **Q-B:** N = **10 từ cố định**, một nút "Học thêm 10 từ" — không cấu hình
    số lượng, không nhiều nút.
  - Hạn mức nới vẫn áp **toàn cục trước khi lọc phạm vi** (FR-11 criterion cũ)
    — `ReviewQueue.loadFullQueue`/`DailyProgressService.load` nhận thêm tham
    số `extraNew` cộng thẳng vào trần trước khi trừ `introduced`, không đổi
    thứ tự tính hay cách đếm.
- **Lý do:** Không schema tránh migration/sync rủi ro cho một tính năng có
  thể bỏ dở giữa ngày; N cố định giữ CTA đơn giản, đúng tinh thần "user chủ
  động, hệ thống không tự nới" (không phá cơ chế bảo vệ M-02/M-07 mà
  `daily_new_limit` tồn tại để giữ).
- **Hệ quả:** `ReviewQueue` thêm `currentDayStartIso(on:now:)` (gom logic tính
  `dayStart` dùng chung, trước đó lặp lại ở `loadFullQueue`/
  `DailyProgressService.load`) và `effectiveExtra(stored:currentDayStart:)`
  (hàm thuần, test không cần DB). `DailyProgress` thêm `totalNewRemaining`
  (tổng thẻ `state='new'` còn tồn, không áp hạn mức) để `SessionDoneView` ẩn
  CTA khi kho đã hết thẻ mới. `AppModel` giữ `extraNewQuota: (dayStart,
  count)?` riêng phiên app; `learnMore()` cộng 10 rồi `reloadOverview()`,
  view (`ReviewQueueView`) tự gọi lại `loadQueue()` để nạp đúng hàng đợi mới
  — tránh hai tác vụ async cùng ghi `reviewItems`. Test: `LearnMoreTests`
  (mới, 7 test) + suite cũ, 240 xanh/241 (1 skip `LiveAIBoxTests`).

## ADR-040 — Nút loa đọc từ (TTS on-device) không thuộc NG-01/NG-02 (T2 ux-polish-r1)

- **Ngày:** 2026-09-26
- **Bối cảnh:** Research UX (Anki/Duolingo/LingQ) cho thấy nút phát âm một từ
  là kỳ vọng cơ bản của app từ vựng. PRD liệt NG-01 "Pronunciation practice,
  speech recognition, shadowing" và NG-02 "Listening/audio content" — cần
  phân định trước khi code để không vô tình mở scope.
- **Quyết định:** Cho phép nút loa đọc **một từ** bằng `AVSpeechSynthesizer`
  on-device (offline, không lưu audio, không network) trên mặt trước thẻ ôn,
  mặt sau thẻ ôn, và card duyệt (`AnalysisView`). Ranh giới cấm giữ nguyên:
  KHÔNG ghi âm người dùng, KHÔNG nhận diện giọng nói, KHÔNG chấm điểm phát
  âm, KHÔNG luyện nói/shadowing, KHÔNG nội dung nghe (audiobook, podcast).
- **Lý do:** NG-01/02 chặn Reado biến thành app *luyện* phát âm/nghe — một
  nút TTS chỉ giúp *biết cách đọc* một từ đã trích, không luyện tập gì, không
  mở ra bề mặt sản phẩm mới (không recording UI, không so khớp âm thanh,
  không nội dung phải duy trì). Đọc từ là một phần nghĩa của từ (cùng nhóm
  với IPA đã có), không phải một job riêng.
- **Hệ quả:** `app/Reado/Pronunciation.swift` (mới) — `Pronunciation.speak(_:)`
  dùng chung `AVSpeechSynthesizer`; `SpeakButton` (44×44, icon
  `speaker.wave.2`, outline theo `visual-redesign-plan.md` §1). Gắn ở
  `ReviewQueueView.cardFace` (hai mặt) và `AnalysisView.ReviewCardRow.editor`.
  `docs/specs/prd.md` mục 3 thêm 1 dòng ghi ranh giới, không sửa dòng NG-01/02
  gốc (CLAUDE.md §4 "FR-07/FR-13 là bia mộ" — áp dụng tương tự cho các dòng
  NG đã chốt: không xoá, chỉ chú thích thêm).

## ADR-041 — Onboarding = checklist 3 bước trên Home, không trang mẫu (T5 ux-polish-r1)

- **Ngày:** 2026-09-26
- **Bối cảnh:** Research UX (U2) gợi ý "cho thấy giá trị trước khi cấu hình"
  — cách phổ biến là demo bằng trang mẫu dựng sẵn. Nhưng Reado cấm nội dung
  do app soạn sẵn (NG-03) và vision #1 (Authentic Input Over Graded Readers):
  Reado không sản xuất nội dung, không đứng cạnh người đọc bằng thứ tiếng
  Anh không ai thật sự viết ra. Đồng thời `journeys.md` J-R1-S có dòng mở
  "CEFR trống lần đầu — bắt chọn trước capture đầu … phải nhìn thấy được"
  chưa có UI nào đóng, và proxy mặc định (`proxy.reado.app`) chưa deploy nên
  agent mặc định luôn lỗi — user mới không tự biết phải thêm agent BYOK.
- **Quyết định:** Onboarding là **checklist 3 bước trên Home** (không trang
  mẫu, không nội dung soạn sẵn): (1) xác nhận CEFR đang lọc từ, (2) kết nối
  agent phân tích (mẫu AI-Box, dán key), (3) chụp trang sách thật đầu tiên.
  Mỗi bước suy trạng thái từ dữ liệu thật (agent active có key, đã có trang
  phân tích) — không lưu tiến trình riêng vào DB. Chỉ 2 cờ UserDefaults:
  `cefrConfirmed` (bấm "Đúng"/"Đổi" ở bước 1) và `dismissed` ("Ẩn hướng dẫn").
  Checklist tự ẩn khi agent sẵn sàng VÀ đã có trang đầu (user cũ không thấy).
- **Lý do:** Trang mẫu = nội dung app soạn sẵn → vi phạm NG-03 trực tiếp;
  checklist chỉ trỏ vào đúng luồng thật (CEFR/agent/chụp) không tạo bề mặt
  nội dung mới phải bảo trì. Suy trạng thái từ dữ liệu thật (không counter
  riêng) tránh lệch giữa "đã làm" và "app nghĩ đã làm".
- **Hệ quả:** `ReadoKit/Onboarding/OnboardingChecklist.swift` (mới, hàm thuần
  — test không cần DB/UI). `AppModel` thêm `activeAgentReady`/`hasFirstPage`
  + `addAgent(...)` (dùng chung với `SettingsView`). `AgentPreset`/
  `AgentFormSheet`/`KeyCheck` ở `SettingsView.swift` bỏ `private` để dùng lại.
  `OnboardingChecklistSection.swift` (mới) — Section đầu `HomeTabView`.
  `journeys.md` J-R1-S không sửa dòng cũ (bia mộ tương tự FR-07/13), thêm ghi
  chú trỏ ADR-041.

## ADR-042 — OCR đổi sang `RecognizeDocumentsRequest` (iOS 26+), legacy làm fallback (ocr-line-drop)

- **Ngày:** 2026-09-28
- **Bối cảnh:** Owner báo bản phân tích chia sai đoạn + thiếu từ trong khi Live
  Text cùng ảnh đọc đúng. Điều tra (`docs/investigations/ocr-line-drop/`) loại
  trừ: nén ảnh, lọc confidence (`dropped = 0`), DeepSeek (chỉ nhận text OCR đã
  thiếu). Gốc lỗi ở tầng OCR app: `PageOCR.sameLine` sàn `0.018` gộp hai hàng
  in liền nhau (ảnh không crop), rồi sort theo `minX` đảo chữ; và trên máy thật
  Vision legacy trả thiếu vài hàng (26 vs 30 obs trên simulator). Hàng mất/gộp
  tạo khoảng trống giả nên heuristic ngắt đoạn ADR-037 chèn `\n\n` sai — thiếu
  từ và sai đoạn là **cùng một gốc**.
- **Số đo (probe simulator, 2026-09-28, sau khi sửa probe: 1600px thật
  scale=1, `normalize` gập dash/quote):** ảnh không crop legacy thiếu 11
  câu, documents 2; ảnh crop legacy thiếu 2, documents 1. Phần thiếu còn lại
  của documents đều là nhiễu 1 ký tự ("did I" → "did |", mất dấu chấm cuối
  đoạn); documents ra đủ 8 đoạn khớp `groundtruth.txt`. 1600px thật không làm
  rơi hàng so với full-res (chênh lệch chỉ 1 ký tự).
- **Quyết định:** iOS 26+ dùng `RecognizeDocumentsRequest` (đoạn/hàng có sẵn
  từ Vision, bỏ qua `splitColumns`/`linesWithBreaks`); lỗi hoặc rỗng thì rơi
  về đường legacy. `Prompt.version` giữ 5 (hợp đồng `\n` giữa hàng, `\n\n` giữa
  đoạn không đổi). `ImageCompressor` áp `format.scale = 1` để FR-01 (≤1600px)
  được áp thật (trước đó @3x ra ~4800px, 3–5MB).
- **Hệ quả:** `PageOCR.joinParagraphs` (hàm thuần, testable),
  `OCRResult.engine` ghi vào `ocr.json` + `diag_summary.py`. Ngắt đoạn hình học
  ADR-037 chỉ còn chạy trên iOS 17–25. **Nợ biết trước:** `sameLine` legacy vẫn
  gộp nhầm hàng ở ảnh không crop — chưa sửa vì fen dùng iOS 26. Câu hỏi mở:
  chênh lệch device/simulator (26 vs 30 obs) chưa giải thích; đóng bằng cách
  chụp lại trên máy thật và đọc `engine=documents` trong `diag_summary`.

## ADR-044 — Dọn repo: xoá docs/archive PWA-gen, script Phase 0, AGENTS/PROJECT.md (repo-hygiene-r1)

- **Ngày:** 2026-09-28
- **Bối cảnh:** Repo sau pivot iOS (ADR-026..028) còn mang nhiều thứ thế hệ PWA
  và 5 file kiểu "mục lục" (`README`, `PROJECT.md`, `AGENTS.md` stub,
  `CLAUDE.md`, `agent-rulebook`). `docs/archive/*-pwa-gen.md` (~2.000 dòng)
  làm nhiễu grep của agent; `PROJECT.md` lỗi thời (còn nói MockAnalyzer, lệnh
  `xcodebuild` trần mà hook `guard.py` chặn); `scripts/verify/{verify,ab-compress}.mjs`
  là Node thời PWA; `qr/restore.py` là tool giải gói QR transport (cùng loại
  `qr/v2/restore.py` đã xoá 09-18).
- **Quyết định:** Xoá `docs/archive/` (6 file), `AGENTS.md`, `PROJECT.md`,
  `qr/`, `scripts/verify/{verify,ab-compress}.mjs`. Pointer trong docs sống
  đổi thành "(đã xoá, ADR-044)". Ảnh trang sách `ref/sample/*.png|jpg|jpeg`
  (bản quyền) gỡ khỏi git, giữ file local. `.env.example` chỉ còn placeholder.
  `idea.md` → `docs/idea.md`, `ui-lab/` → `ref/ui-lab/`.
- **Lý do:** Lịch sử vẫn nằm trong git; giữ file chết chỉ tốn context và sinh
  link lệch. Một entry point (`CLAUDE.md`) thay vì năm.
- **Hệ quả:** Khôi phục bằng git (hash có thể đổi nếu reword/rebase — tìm theo
  message `repo-hygiene-r1`):
  - `git show 7db1510:docs/archive/<file>` (agents / coding-conventions / mvp-plan /
    prd / session-brief / solution-design, mỗi file hậu tố `-pwa-gen.md`)
  - `git show 7db1510:PROJECT.md`, `git show 7db1510:AGENTS.md`
  - `git show 107bca0^:qr/restore.py`, `git show 107bca0^:scripts/verify/verify.mjs`
  Ảnh `ref/sample` vẫn còn trong lịch sử commit cũ — cần viết lại history
  (`git filter-repo`) nếu repo `venkyvn/reado` là public.
  ROADMAP.md còn pointer tới archive (dòng lịch sử) — sửa ở B5 vì file đang bị
  session khác sửa.

## ADR-043 — Cram kéo về R1: nút "Ôn thêm" ở màn hết thẻ (cram-collection-r1)

- **Ngày:** 2026-09-28
- **Bối cảnh:** Owner rảnh, mở "Ôn bộ này" mà hết thẻ đến hạn → "Không có gì cần
  ôn", ngõ cụt. `journeys.md` chỉ ghi "chưa có journey Cram cho tới khi owner nói
  'học' = ôn chưa due" — owner đã nói. ADR-011 đã chốt cơ chế (log `mode='cram'`,
  không đụng `cards`); cột + CHECK đã có từ v1 nên **không migration**.
- **Quyết định:**
  - Cram chỉ vào từ màn hết thẻ của `ReviewQueueView`, qua nút "Ôn thêm N thẻ" khi
    phạm vi còn thẻ **đã học** (`state != new`), chưa suspend, `due_at > now`.
  - Lấy sắp due trước, tối đa **20** thẻ/lượt (`ReviewQueue.cramBatchSize`).
    Thẻ `new` vẫn đi đường "Học thêm 10 từ" (ADR-039), không lẫn vào Cram.
  - Chấm = INSERT `review_logs` `mode='cram'` (`ReviewService.recordCram`), snapshot
    trước = trạng thái hiện tại, **không `UPDATE cards`**, không gọi `LeechService`,
    không toast "Thuộc rồi", ẩn nhãn nhịp ôn (không còn đúng). Undo = xoá đúng log
    cram (`undoCram`, WHERE `mode='cram'`).
  - `newIntroducedCount` chỉ đếm log `mode='srs'` — log cram không ăn hạn mức FR-11.
  - Log cram vẫn tính vào streak (ADR-011).
- **Hệ quả:** Q-11 (phần distinguish/recall của R2) không đổi — cram ở R1 đi đường
  "chấp nhận" đã chốt 2026-09-08. Sau khi cram xong không có "ôn thêm nữa": một
  lượt 20 thẻ gần due nhất, cram lại sẽ ra đúng tập cũ (lịch không đổi).

## ADR-045 — Visual polish: hướng "native tinh chỉnh" + token Spacing/Radius/Typo (visual-polish-r1)

- **Ngày:** 2026-09-28
- **Bối cảnh:** Owner thấy app "chưa chỉn chu". Soát code: spacing dùng 12 giá trị
  lệch thang (2/3/4/6/8/10/12/14/16/20/24), bo góc 6 cỡ, `.caption`+`.secondary`
  chồng 3–4 dòng mỗi row, pill/badge copy tay ≥7 chỗ (opacity 0.12/0.15/0.18),
  Home có 4 row nằm ngoài Section, emoji 🎉/🔥 làm icon.
- **Quyết định:** Giữ `List`/`Form`/`NavigationStack` native (không serif, không
  nền giấy, không màu nổi kiểu gamification — khớp "Journey Over Summary").
  Thêm `app/Reado/DesignSystem.swift`: `Spacing` (2/4/8/12/16/24/32), `Radius`
  (8/12/20, luôn `.continuous`), `Typo` (vai trò chữ → text style hệ thống, giữ
  Dynamic Type) + 3 component dùng chung `Pill`, `IconTile`, `VocabSummary`.
  Màu semantic vẫn ở `Theme`. `design-system/reado/MASTER.md` (FROZEN) không sửa;
  token Swift là bản native của nó.
- **Hệ quả:** View không viết số lẻ 3/6/7/10/14/20/28/36. Ngoại lệ có comment:
  hình học heatmap `StreakCalendarView`, skeleton `AnalysisView`, hằng số
  `ShellTabBar`, peek/xoay stamp của card Ôn, và `CaptureView` (tự vẽ, ADR-036).
  Không đụng gesture vuốt, màu nút chấm, vị trí tab bar/nút chụp. Chi tiết bảng
  đổi số: `docs/ux/visual-redesign-plan.md` §8; task: `docs/plans/visual-polish-r1.md`.

## ADR-046 — pbxproj sang synchronized folders (repo-hygiene-r1 B1)

- **Ngày:** 2026-09-28
- **Bối cảnh:** pbxproj viết tay (objectVersion 60) đòi 4 dấu vết/file Swift; thiếu 1 là Xcode skip **ngầm** (test "thừa xanh"). Đã có 1 file bị trùng (`OCRProbeTests.swift` 2 fileRef) mà không ai thấy.
- **Quyết định:** `Reado` + `ReadoTests` thành `PBXFileSystemSynchronizedRootGroup`. Fen convert bằng Xcode 27 (Xcode ghi objectVersion **70**, không phải 77 như plan). Trước khi convert phải gỡ reference trùng và 2 file có path nhiều cấp (`Capture/CaptureView.swift`, `Screens/ReviewQueueView.swift`) — Xcode từ chối nếu còn.
- **Hệ quả:** `pbxproj_tool.py` chỉ còn `check`/`list` (`add`/`remove` bỏ). `check` bắt objectVersion < 70, mất root group, fileRef `.swift` rời, exception set. Cấm exception set (file trong `membershipExceptions` bị loại khỏi target ngầm). File trong thư mục là được compile, kể cả chưa track git. Kiểm: probe test 1/1, hai probe build lỗi (thư mục gốc + thư mục con) đều FAIL đúng file, full 263/265 bằng mốc.

## ADR-047 — Thứ tự thẻ mới ưu tiên bộ vừa thêm từ (new-order-r1)

- **Ngày:** 2026-09-30
- **Bối cảnh:** `ReviewQueue.newCardIDs` xếp thẻ mới theo `ORDER BY c.due_at, c.id` — `due_at` của thẻ mới = lúc tạo (FR-09), nên từ của một collection đã bỏ dở từ lâu luôn ra trước từ của collection đang đọc hôm nay, chiếm hết `daily_new_limit`. Vision-refresh-r2 chốt: scheduler lo *khi nào* ôn, không lo *bao nhiêu* — "ưu tiên từ của thứ đang đọc, từ gặp lại nhiều lần".
- **Quyết định:** Đổi `ORDER BY` của nhánh thẻ mới thành ba khoá: (1) collection có `MAX(vocab_items.created_at)` gần nhất DESC — kể cả kho tạm; (2) trong collection đó, `term_normalized` xuất hiện ở nhiều dòng hơn (từ gặp lại) DESC; (3) `vocab_items.created_at` rồi `cards.due_at`/`id` — giữ thứ tự trang. Không đổi hạn mức, không đổi nhánh thẻ đến hạn, không đổi schema. Dùng lại index có sẵn `idx_vocab_inbox_time`/`idx_vocab_term`.
- **Hệ quả:** `DailyProgressService` gọi chung `newCardIDs` nên số Home tự khớp. Home bỏ con số tồn ("thẻ mới đang chờ") — hết hạn mức hôm nay chỉ hiện "Xong phần hôm nay", không đếm ngược nữa (khớp "không cần học hết"). `reencounter-r1` T3 sẽ cộng thêm số lần `seen` (bảng `encounters`) vào khoá thứ (2). Test: `ReviewQueueAndServiceTests` 4 case mới (bộ mới hơn trước, giữ thứ tự trang khi hết bộ mới, từ gặp lại lên trước trong bộ, scope vẫn chỉ lọc không kéo bộ ngoài phạm vi).

---

## ADR-048 — Bảng `encounters`: gặp lại từ cũ khi đọc, ngoài FSRS (reencounter-r1)

- **Ngày:** 2026-10-01
- **Bối cảnh:** Vision-refresh-r2 thêm mắt xích cuối cho vòng lặp — *nhận ra từ cũ khi đọc tiếp* (M-06) — và mức "Đã thấm" trên thang Mới · Đang học · Đã nhớ · Đã thấm. Reado chưa có chỗ ghi lần gặp lại. `review_logs` không dùng được: `mode` bị CHECK ('srs','cram','distinguish','recall'), bắt buộc `rating` 1–4 + snapshot FSRS, và ghi vào đó là làm bẩn dữ liệu huấn luyện của optimizer R2.
- **Quyết định:** Migration v3 → v4 thêm bảng `encounters (id, vocab_item_id → vocab_items ON DELETE CASCADE, kind IN ('seen','recognized'), created_at)` + `idx_encounters_item (vocab_item_id, kind)`. `seen` tự ghi khi lưu một trang có từ đã có trong kho (cùng transaction lưu vocab + phiên); `recognized` do người dùng chạm, tối đa một dòng / vocab / ngày học (cửa sổ `ReviewQueue.currentDayWindow`, giờ chuyển ngày FR-11). Matcher thuần `EncounterMatcher`: so khớp xuyên collection theo chữ, không phân biệt hoa/thường, biên từ, cụm dài thắng, `'s` là ranh giới, **không lemmatize** (Q-06). Mức "Đã thấm" = Đã nhớ (Q-08) + ≥ 1 `recognized`, tính lúc đọc, không cột. Q-09 không đổi (chỉ cho FR-10). Export JSON thêm `encounters` + `counts.encounters`, `version` giữ 1.
- **Hệ quả:** FSRS, `cards`, `review_logs` không bị đụng — "nhận ra khi đọc" không đổi lịch (khớp Retention của vision). Chuyển collection giữ lịch sử (khoá theo vocab), xoá vocab thì cascade. `EncounterRepository.insertSeen` không tự mở transaction (`inTransaction` không lồng) — T2 phải gọi trong transaction lưu trang. Số `seen` sẽ cộng vào khoá thứ (2) của `newCardIDs` ở T3 (ADR-047). Không import lại `encounters` từ backup (FR-16 vẫn không nhập JSON). T1 (dữ liệu) xong; T2 (màn đọc) và T3 (thang tiến độ) theo `docs/plans/done/reencounter-r1.md`.

---

## ADR-049 — Bỏ proxy Reado, FR-02 chỉ còn BYOK — đảo phần proxy của ADR-028/Q-03 (remove-proxy-r1)

- **Ngày:** 2026-10-01
- **Bối cảnh:** Owner thấy proxy không còn cần: `proxy.reado.app` chưa bao giờ deploy (ADR-041 đã ghi "agent mặc định luôn lỗi"), và từ ADR-034 app đã OCR trên máy rồi gọi agent **text** (BYOK OpenAI-compat) — `proxy/` (Python, gửi multipart ảnh) và `ReadoProxyClient` thành code chết, chỉ còn gây hiểu nhầm kiến trúc. R1 vẫn một user (NG-05), không có nhu cầu giấu key sản phẩm cho nhiều người dùng.
- **Quyết định:** Xoá `proxy/` và `ReadoProxyClient.swift`. FR-02 chỉ còn đi qua agent BYOK (`openai_compat`) user tự thêm. Hàng seed `analysis_agents` (`kind = 'reado_proxy'`, id cố định) **không xoá** — đổi nghĩa thành placeholder "chưa chọn agent": `AnalysisAgentStore.list()` lọc khỏi danh sách hiển thị, `AnalyzerFactory` trả `NoAgentAnalyzer` ném lỗi rõ ("Chưa có agent phân tích — thêm agent trong Cài đặt") nếu lọt vào `analyze()`. Không migration — `settings.active_agent_id` vẫn NOT NULL + khoá ngoại, CHECK cột `kind` vẫn nhận literal `'reado_proxy'` (đổi value này mới cần migration, không đáng cho một cách gọi tên).
- **Lý do:** Rebuild bảng `settings` để bỏ NOT NULL chỉ để xoá một hàng seed là rủi ro không cần — đổi nghĩa tại tầng Swift (list lọc, factory báo lỗi) đạt cùng mục đích (ẩn khỏi UI, không gọi mạng chết) mà không đụng DDL hay dữ liệu máy fen đang có.
- **Hệ quả:** `AnalysisAgent.isBuiltinProxy` → `isPlaceholder`; `Seeder.readoProxyAgentID/-Name` → `placeholderAgentID/-Name`; `StoreError.cannotDeleteProxy` → `cannotDeletePlaceholder`. `SettingsView` bỏ hẳn nhánh hiển thị "Proxy Reado" (list đã lọc, không còn ca này). `AppModel.activeAgentReady` suy trực tiếp từ `hasKey` (không cần loại trừ builtin nữa). NFR-07 chỉ còn vế key user ở Keychain — vế "key sản phẩm ở `.env` proxy" là bia mộ. `CLAUDE.md`, `prd.md` (Q-03, FR-21, NFR-07), `solution-design.md`, `db.md`, `tech-stack.md`, `journeys.md` ghi chú trỏ ADR này tại các đoạn nhắc proxy cũ — không xoá bia mộ. Test: xoá 4 test `ReadoProxyClientTests`, sửa `AnalyzerFactoryTests` theo hành vi mới — 351/353 xanh (từ 355/357, giữ 2 skip cũ).

## ADR-050 — "Ôn thêm 20": trộn mới + ôn sớm thật, LIFO, heatmap theo phân vị — đảo ADR-011/039, sửa ADR-043/047 (extra-review-r1)

- **Ngày:** 2026-10-01
- **Bối cảnh:** Owner thêm từ thoải mái mỗi ngày, học kiểu "cuốn chiếu" (từ vừa
  thêm học trước). Ba vấn đề của Cram/"Học thêm" cũ: (1) Cram chỉ ghi
  `review_logs mode='cram'`, không đổi `cards` (ADR-011) — Quên lúc cram bị bỏ
  qua, Được lúc cram làm FSRS thổi phồng `stability` ở lần srs sau (lỗi Q-11 đã
  ghi ở ADR-032/PRD mục 12); (2) Cram luôn ra đúng 20 thẻ cũ (lịch không đổi —
  ADR-043 đã ghi nhận); (3) "Học thêm 10 từ" (ADR-039, nới `daily_new_limit`
  riêng ngày) và "Ôn thêm" (ADR-043, cram) là hai nút tách rời dù cùng mục đích
  "chủ động học/ôn thêm khi rảnh". Thứ tự thẻ mới (ADR-047) cũng chỉ ưu tiên
  **bộ** vừa thêm, trong bộ vẫn FIFO theo trang — không phải "cuốn chiếu" thật.
- **Quyết định (owner chốt qua hội thoại 2026-10-01, không qua `/rplan` lưu
  file riêng — plan nằm trong phiên chat):**
  - **B1 — một lượt "Ôn thêm" 20 thẻ, MỌI mức chấm đều ghi lịch thật.** Trộn
    tối đa 10 từ mới (LIFO, bỏ qua `daily_new_limit`) + tối đa 10 thẻ đã học
    chưa đến hạn ("ôn sớm" — `due_at > window.end`); bên nào thiếu thì bên kia
    bù đủ 20 (`ReviewQueue.extraCardIDs`). Hai nhóm **xen kẽ** (cũ, mới, cũ,
    mới…, dư dồn cuối — `ReviewQueue.interleave`), không xếp hết nhóm này rồi
    mới nhóm kia. Chấm bằng đúng `ReviewService.record`/`ReviewQueue` của hàng
    đợi chính — không còn đường `recordCram`/`undoCram` chỉ-ghi-log. Ôn sớm mà
    chấm Được không thổi phồng `stability` vì FSRS tính theo `retrievability`
    thật tại thời điểm ôn (R cao do ôn sớm → S tăng ít) — sửa đúng gốc lỗi Q-11
    thay vì né nó. Loại thẻ đã có `review_logs` trong ngày học hiện tại khỏi cả
    hai nhánh — "mỗi lượt Ôn thêm ra một nhóm khác", không lôi lại thẻ vừa ôn.
  - **B2 — gộp CTA, bỏ "Học thêm 10 từ".** Một nút "Ôn thêm N thẻ" ở: màn hết
    thẻ (`ReviewQueueView`/`SessionDoneView`), header collection (chỉ hiện khi
    bộ đó hết thẻ đến hạn), và Home (dòng "Xong phần hôm nay" đổi thành CTA khi
    toàn kho còn thẻ Ôn thêm được). Xoá `AppModel.learnMore()`,
    `ReviewState.extraNewQuota`, `ReviewQueue.effectiveExtra`, tham số
    `extraNew` của `loadFullQueue`/`DailyProgressService.load`.
  - **B3 — LIFO thật trong `newCardIDs` (đảo phần "giữ thứ tự trang" của
    ADR-047).** `ORDER BY` đổi khoá cuối từ `v.created_at ASC, due_at, id`
    sang `v.created_at DESC, v.rowid ASC` — lần chụp GẦN ĐÂY NHẤT lên trước,
    kể cả giữa các lần chụp trong CÙNG một collection; cùng một lần chụp (cùng
    `created_at`) vẫn giữ thứ tự trang qua `rowid` (bảng có rowid thường, không
    `WITHOUT ROWID`). Khoá (1) "bộ vừa thêm từ gần nhất" và khoá (2) "gặp lại"
    (`seen`/trùng dòng) giữ nguyên, đứng TRƯỚC LIFO — một từ vừa gặp lại vẫn
    thắng dù trang của nó cũ hơn.
  - **B4 — heatmap chia theo tứ phân vị của chính user.** Thang cũ bão hoà ở 7
    thẻ (mức 5 = "7+"); `StreakIntensity.thresholds(from:)` tính p25/p50/p75/max
    từ các ngày CÓ ôn trong lưới 18 tuần — dưới 4 ngày có ôn thì dùng lại thang
    cố định cũ (chưa đủ dữ liệu chia phân vị có nghĩa).
  - **Chấp nhận có chủ đích:** Ôn thêm học từ mới không trần — `newIntroducedCount`
    có thể vượt `daily_new_limit` trong ngày, các phép "còn X từ mới hôm nay"
    kẹp `max(0, …)` chứ không báo lỗi. Owner: "overload quá thì thôi" — đây là
    lựa chọn chủ động của user, không phải bug.
- **Lý do:** Cùng một hành động chấm thẻ không nên có hai luật (ghi lịch thật
  / chỉ ghi log) tuỳ vào cửa vào — khó nhớ, dễ sai, và chính hai luật đó là
  nguồn gốc ba lỗi ở trên. Một đường chấm duy nhất (đã có sẵn, test kỹ ở
  `ReviewService`) rẻ hơn và đúng hơn so với vá riêng từng lỗi của đường cram.
- **Hệ quả:** `ReviewQueue` thêm `extraBatchSize`/`extraNewShare`/
  `extraReviewCardIDs`/`interleave`/`extraCardIDs`/`extraAvailableCount`/
  `loadExtraQueue`; xoá `cramBatchSize`/`cramCardIDs`/`crammableCount`/
  `loadCramQueue`/`effectiveExtra`. `hydrate` thêm `preserveOrder` (Ôn thêm giữ
  đúng thứ tự xen kẽ, không sắp lại theo `due_at` như hàng đợi chính).
  `ReviewService` xoá `recordCram`/`undoCram` — cột `review_logs.mode` + CHECK
  giữ nguyên `'srs'`/`'cram'` cho R2 (Q-11 distinguish/recall), không migration.
  `ReviewMode.cram` → `.extra` trong app target; `AppModel` xoá
  `gradeCram`/`undoCram`/`learnMore`/`effectiveExtraNew`/`learnMoreBatchSize`.
  `VocabRepository.CollectionSummary.crammableCount` giữ nguyên định nghĩa SQL
  cũ (xấp xỉ, không lọc "đã ôn hôm nay") — chỉ dùng để quyết định HIỆN CTA ở
  header, không phải nguồn thật của hàng đợi Ôn thêm. FR-11/FR-18 (prd.md),
  Cram/"Học thêm" (journeys.md) cập nhật theo B1/B2. Test: xoá
  `CramReviewTests`/`LearnMoreTests`, thêm `ExtraReviewTests` (15 test), sửa
  `ReviewQueueAndServiceTests` (3 test đổi theo LIFO B3, thêm 1 test rowid
  cùng-lần-chụp), `VocabularyListTests` (1 chỗ đối chiếu `crammableCount`) —
  329/329 xanh ở `kit`, 348/350 xanh ở suite đầy đủ (giữ 2 skip cũ).

## ADR-051 — MASTER.md viết lại thành luật UI native, khớp token thật — sửa phần "không sửa" của ADR visual-polish-r1

- **Ngày:** 2026-10-01
- **Bối cảnh:** `design-system/reado/MASTER.md` là output máy sinh của ui-ux-pro-max
  cho web (CSS, hover, `cursor:pointer`, breakpoint, GSAP, "Hero + Testimonials";
  anti-pattern "Boring design / No motivation" ngược vision). Văn bản đã lệch code:
  tint ghi cứng trong khi accent thật là `Color.accentColor` theo `AppTheme`; card ghi
  nền kem + bóng trong khi `card()` dùng `Theme.surface`, không bóng; font ghi Inter
  trong khi code dùng text style hệ thống qua `Typo`. Agent đọc MASTER sẽ code sai.
- **Quyết định:** Giữ FROZEN cho **quyết định look** (glass trên chrome, nội dung đọc
  đặc). Văn bản viết lại (≤ 80 dòng, tiếng Việt) theo từ vựng SwiftUI. Luật chỉ ghi
  tên token và khi nào dùng, không chép con số, trỏ về `DesignSystem.swift` và
  `ReadoApp.swift`. Mỗi luật kiểm được pass/fail, kèm một dòng lý do. Có thêm mục
  "Không làm" chiếu 6 nguyên lý vision, checklist chụp màn hình, và dòng "Đối chiếu
  code lần cuối". Luật icon (outline ở toolbar, filled ở trạng thái chọn và CTA) lấy
  từ `docs/ux/visual-redesign-plan.md` §1. Mục NL6 chỉ trích đúng vision ("XP, huy
  hiệu không gắn với việc đã làm"), **không** đặt trần cho phần thưởng: owner muốn
  để ngỏ phần thưởng gắn với số đo thật.
- **Hệ quả:** Xoá `design-system/reado/pages/*.md` (luật web). `/raudit` grep từng
  token mà MASTER nhắc tới. Skill `reado-ui` trỏ về MASTER kèm gotcha. Đổi MASTER khi
  code đổi token là việc bình thường; đổi look phải được owner duyệt.

## ADR-052 — Shell 2 tab "Hôm nay · Thư viện", nút chụp trong thanh, Ôn là phiên toàn màn

- **Ngày:** 2026-10-02
- **Bối cảnh:** Cấu trúc 3 tab (Home/Ôn/Kho, port UI lab 2026-09-23) chưa từng có ADR
  và lộ nhiều vấn đề qua audit `ux-redesign-r1`: `FloatShutter` đè nội dung cuối list
  (#1); nút "Về Home" của `SessionDoneView` gọi `dismiss()` trong tab không có gì để
  dismiss → nút chết (#2); đổi tab rồi quay lại Ôn làm `onAppear` nạp lại hàng đợi,
  mất màn tổng kết giữa phiên (#3); Ôn mở bằng 3 cách khác nhau (tab/sheet) với chrome
  khác nhau (#13); Home có 4–6 khối ngang hàng không có 1 CTA chính (#10); mục Dữ liệu
  nằm trên toolbar Home dù không phải việc đọc (`J-R1-D`).
- **Quyết định:** Bỏ tab Ôn. Shell còn 2 tab `AppTab.today` ("Hôm nay") và `.library`
  ("Thư viện"); nút chụp tròn glass đứng cùng hàng với capsule tab (không còn overlay
  `FloatShutter`). Ôn trở thành một phiên toàn màn (`fullScreenCover(item: $reviewRequest)`,
  `ReviewRequest { scope, mode }`), mở từ hero Hôm nay, Hub bộ, hoặc Lịch streak qua
  `EnvironmentValues.startReview` — che cả thanh tab nên không đổi tab giữa phiên được
  nữa (giải #2/#3 bằng kiến trúc, không vá riêng). Mục Dữ liệu dời vào menu ⋯ của
  Thư viện (sửa vị trí J-R1-D, không còn ở Settings/Home).
- **Hệ quả:** `app/Reado/App/RootView.swift` (`AppTab`, `reviewRequest`, `startReview`),
  `ShellTabBar`/`ShellCaptureButton` thay `FloatShutter`, `ReviewLauncher.swift` mới.
  `docs/specs/journeys.md` Phần 1 viết lại theo khung này (T11). Hướng A (giữ 3 tab,
  chỉ vá #2/#3 riêng) không chọn — chi phí sau này cao hơn vì vẫn còn 2 cửa vào Ôn.
  Verify: fen xác nhận trên máy thật 3 luồng J1 (Hôm nay/Thư viện/Hub) đều đúng
  (2026-10-02).

## ADR-053 — Lưu từ không chặn: banner thay alert, đổi đích được ở màn duyệt, bản dịch Analysis hiện sẵn

- **Ngày:** 2026-10-02
- **Bối cảnh:** Sau khi Lưu, app đổi sang tab Home + push Hub kèm alert chặn, kể cả
  khi user chụp từ tab Kho → mất định hướng (#4). Màn duyệt ghi "Đổi bộ ở màn chụp"
  nhưng không quay lại được → ngõ cụt khi chọn nhầm đích (#5). Bản dịch đoạn trong
  Analysis ẩn tới khi chạm "Dịch" từng đoạn — lệch ADR-030 (mặc định hiện + 1 nút
  ẩn/hiện toàn bộ) và nguyên lý #2 vision (#7).
- **Quyết định:** Bỏ alert chặn sau Lưu; thay bằng `ShellBanner` không chặn ("Đã lưu
  N từ vào X · Xem"), đứng nguyên chỗ đang đứng (không tự đổi tab/push) — bấm "Xem"
  mới push Hub. Đích lưu đổi được ngay ở đầu màn duyệt qua `CollectionDestinationPicker`
  (`Menu`, không sheet, để giữ ≤2 tầng modal) thay vì chỉ đọc ở màn chụp. Tab "Trang"
  của màn duyệt áp lại cơ chế `ReadingSessionView`: EN+VI hiện sẵn, một nút đáy ẩn/hiện
  toàn bộ bản dịch. ADR-036 (camera `fullScreenCover`) giữ nguyên.
- **Hệ quả:** `Analysis/AnalysisView.swift`, `Shared/CollectionDestinationPicker.swift`
  (mới), `Shared/ShellBanner.swift` (mới), `App/AppModel+Capture.swift`. Bỏ
  `pendingHubNavigationID`; giữ `pendingRecapture`/`pendingSettingsNavigation`. Lỗi lưu
  vẫn dùng alert (không phải banner). `docs/specs/journeys.md` J1/J2 viết lại theo đây
  (T11).

## ADR-054 — Onboarding gộp vào hero Home, agent hỏng không giấu thẻ đến hạn

- **Ngày:** 2026-10-02
- **Bối cảnh:** ADR-041 (checklist 3 bước CEFR/agent/chụp) dựng một section riêng
  trên Home, ngang hàng với Ôn/Kho tạm/Streak — không có 1 CTA chính nhận ra trong 1
  giây (#10); checklist bước 3 tick xanh nhưng phụ đề vẫn đọc `isEnabled` thay vì
  `isDone`, gây sai lệch hiển thị (#9). Sau khi bỏ tab Ôn (ADR-052), hero Home trở
  thành cửa ôn chính — code cũ ẩn lại checklist khi agent hỏng ở người dùng cũ
  (`OnboardingChecklist.swift`), có nguy cơ giấu mất thẻ đến hạn.
- **Quyết định:** Gộp 3 bước onboarding vào `HomeHero` làm CTA duy nhất
  (`.confirmCefr/.connectAgent/.firstCapture/.review(n)/.extra(n)/.done`), không còn
  checklist 3 hàng. **Luật ưu tiên:** trạng thái onboarding chỉ hiện khi `!hasFirstPage`
  — đã có trang thì luôn `.review/.extra/.done`, kể cả khi agent đang hỏng (key hết
  hạn); agent hỏng thể hiện bằng `agentWarning: Bool` (dòng phụ, không phải CTA) +
  chặn lúc bấm chụp (T9), không giấu thẻ đến hạn. Bỏ dòng "Ẩn hướng dẫn" của ADR-041.
- **Hệ quả:** `ReadoKit/Home/HomeHero.swift` (mới, có test), `Home/OnboardingChecklistSection.swift`
  xoá (logic chuyển vào hero), `Home/HomeTabView.swift`. Sửa ADR-041 (không còn
  checklist 3 hàng độc lập, vẫn giữ "3 bước suy từ dữ liệu thật, 2 cờ UserDefaults").
  `docs/specs/journeys.md` không đụng — onboarding không phải journey riêng, đã ghi ở
  J-R1-S "CEFR trống lần đầu" trỏ ADR này thay ADR-041.

## ADR-055 — prompt-v6: dịch theo cụm + `phrases` + xếp hạng vocab + preselect top 5

- **Ngày:** 2026-10-02
- **Bối cảnh:** Vision #2 muốn bản dịch là thứ để học văn phong (theo cụm, theo nhịp
  câu), không chỉ gỡ nghĩa — prompt v5 chỉ yêu cầu "dễ hiểu", không có cơ chế nào dạy
  cách chuyển ngữ cụm từ. FR-09 criterion 1 cũ ("mặc định chọn tất cả") khiến người
  dùng phải bỏ chọn từng từ thủ công mỗi lần duyệt — không tận dụng được việc AI biết
  ước lượng từ nào đáng học hơn ở cùng trình độ. Owner chốt 2026-09-30: N = 5, AI xếp
  hạng; 2026-10-02: model đánh giá = `qwen3.8-flash` (model cũ `deepseek-v4.1-flash`
  đã 503 model_not_found ở provider).
- **Quyết định:** `Prompt.swift` v6 (`Prompt.version = 6`): chỉ dẫn dịch theo
  cụm/nhịp câu tự nhiên; xin thêm `segments[].phrases` (2–6 cặp EN↔VI đáng học mỗi
  đoạn, đường ống nhận/lọc đã làm ở T2a — sai thì bỏ im lặng, không phải vocabulary);
  `vocabulary` xin trả về theo **giá trị học giảm dần**. `ReviewDraftBuilder.drafts`
  đổi luật preselect: verified giữ thứ tự AI, chỉ **`preselectLimit` (5) item đủ điều
  kiện đầu tiên** (verified + đúng CEFR, như cũ) được chọn sẵn — AI chỉ xếp thứ tự đề
  xuất, người dùng vẫn là người duyệt cuối (FR-09, vision #3). `scripts/prompt_eval.py`
  thêm đọc thẳng `Prompt.swift` (rút literal, khỏi chép tay `.txt`) + `--model`/
  `--base-url` ghi đè + bảng song song EN/VI/phrases/vocab để fen chấm trước khi đổi
  prompt thật — chạy trên 4 trang thật `.tmp/diagnostics/20260928T112557Z/` với
  `qwen3.8-flash`, cả 4 trang hai bản đều trả JSON hợp lệ, v6 có phrases hợp lệ.
- **Hệ quả:** `Analysis/Prompt.swift`, `Analysis/ReviewDraft.swift` (+6 test
  `ReviewDraftBuilderTests`), `scripts/prompt_eval.py`. Sửa PRD FR-09 criterion 1,
  `journeys.md` (J1 bước 4, bảng mục 1), prompt-spec §3/§7 (trỏ v6, "AI chỉ xếp thứ
  tự đề xuất"). Không đụng DDL, không đụng `AnalysisResponseNormalizer`/Decoder (T2a
  đã xong). UI chạm-sáng `phrases` là việc riêng, chưa làm (T3, `docs/plans/done/prompt-v6.md`).

## ADR-056 — Q-13: gập item FR-10 "đã thuộc" thay vì xoá, liệt kê đủ nghĩa khi khoá lệch mức thuộc

- **Ngày:** 2026-10-02
- **Bối cảnh:** Q-13 (`CLAUDE.md` §5, `docs/plans/q13-sense-filter-r1.md`) — khoá so
  khớp FR-10 `term_normalized|pos` (Q-09, trong một collection) không phân biệt
  nghĩa. `ReviewDraftBuilder.drafts(excludingMature:)` xoá hẳn item khớp khoá khỏi
  màn duyệt: từ đồng âm mang nghĩa mới (`bank` "ngân hàng" đã thuộc, trang mới dùng
  "bờ sông") bị ẩn im lặng, người dùng không có cách biết, nghĩa mới mất. Lệch spec
  phát hiện kèm: `matureKeys` ẩn cả khi chỉ một dòng cùng khoá đã thuộc, trong khi
  FR-10 GWT 3 (cũ) nói từ chưa thuộc gặp lại vẫn được đề xuất.
- **Quyết định:** Fen chốt phương án **B** trong 5 phương án đề ra (A giữ nguyên, C
  so nghĩa bằng text, D gọi AI lượt 2, E tầng `senses` mới — đều bị loại hoặc hoãn).
  Item khớp khoá đã thuộc không xoá khỏi màn duyệt — gập xuống nhóm riêng (UI: T2,
  chưa làm), không chọn sẵn, không chiếm suất `preselectLimit` (5) của danh sách
  chính. Ca lệch spec (khoá có cả dòng đã thuộc lẫn dòng mới/chưa thuộc, vd vừa lưu
  nghĩa mới): chọn **(i)** — vẫn vào nhóm gập, liệt kê **đủ** nghĩa trong kho của mọi
  dòng cùng khoá (không chỉ dòng đã thuộc) vì hệ thống không biết trang đang dùng
  nghĩa nào; không sửa thành "chỉ ẩn khi mọi dòng cùng khoá đã thuộc" (phương án (ii)
  bị bỏ).
- **Hệ quả:** `VocabRepository.matureSenses(on:collectionID:) -> [String: [String]]`
  (mới) + `matureKeys` viết lại thành wrapper của nó. `ReviewDraftBuilder.drafts`
  đổi `excludingMature: Set<String>` thành `matureSenses: [String: [String]]`, trả
  `ReviewDraftResult { visible, matureHidden: [MatureHiddenDraft] }` thay vì
  `[ReviewDraft]` phẳng — item khớp khoá rơi vào `matureHidden` kèm
  `knownMeanings`, không còn biến mất. `AppModel+Settings.matureKeysForCapture()` →
  `matureSensesForCapture()`. Sửa PRD FR-10 GWT 1 (+ GWT 3). UI section "Đã thuộc ·
  N" gập + fixture là T2, để session sau (1 task tầng 2/session) —
  `draftResult.matureHidden` tạm chưa hiển thị, `AnalysisView` vẫn dùng
  `draftResult.visible` y như hành vi trước khi đổi (không xoá, chỉ chưa có UI).
  Không đụng schema/migration, `saveCapture`, `Prompt*.swift`.

## ADR-057 — Header Home kiểu nút tròn tách, streak từ hàng riêng lên pill toolbar, hero số phụ

- **Ngày:** 2026-10-04
- **Bối cảnh:** Fen xem app eevas.top (quản lý chi tiêu, không liên quan Reado) và
  thích hàng nút tròn góc phải header Home của nó, cùng khối hero có số to + số phụ.
  Trước đó streak + "Gặp lại N từ tuần này" nằm trong một `Section` riêng
  (`statsSection`, hàng bấm được) ngay dưới hero — chiếm một hàng List riêng, còn ⚙
  là nút tròn duy nhất trên toolbar.
- **Quyết định (T1 trong `docs/plans/home-eevas-r1.md`):** Bỏ `statsSection`. Streak
  lên pill 🔥N trên `topBarTrailing` (label `.titleAndIcon`, `NavigationLink` tới
  `ShellRoute.streak` như cũ), tách khỏi ⚙ bằng `ToolbarSpacer(.fixed, …)` (iOS 26+;
  dưới đó hai nút gộp capsule, chấp nhận vì fallback hiếm) thành hai hình tròn riêng
  kiểu eevas — chỉ hiện khi đã có trang (`hasFirstPage`). `HeroCard` thêm `value`
  (số to đứng trước title, vd "12" + "thẻ đến hạn") và `metrics` (0–2 số phụ dưới
  title/subtitle): "Gặp lại tuần này" (FR-22, ẩn khi 0 — 0 trông như lỗi) và "Đã nhớ"
  (Q-08, tổng `masteredCount` mọi collection, luôn hiện kể cả 0 — số đo thật). Dòng
  nhắc giữ streak ("Hôm nay chưa ôn — 1 thẻ là giữ streak") chuyển từ `statsSection`
  thành `subtitle` của hero ở trạng thái `.review`. Không làm cấp/huy hiệu, lượt khôi
  phục streak, nền gradient, hay "tiến độ kiểu ngân sách" — đã có `MasteryRing` +
  thanh 4 màu `CollectionStatsHeader`.
- **Hệ quả:** `Home/HomeTabView.swift` (toolbar + `heroCard`, bỏ `statsSection`),
  `Shared/HeroCard.swift` (`Metric`, `value`, `metrics`, mọi call site cũ vẫn biên
  dịch nhờ default `nil`/`[]`). `journeys.md` (khung app dòng ~20, J-R1-P bước 1 +
  "Màn UI"): "hàng streak" → "pill 🔥N trên toolbar". Không đụng FSRS, schema, FR nào
  — chỉ lớp trình bày. T2 (banner bấm được), T3 (màn "Từ hay quên" FR-19), T4 (tìm từ
  FR-08) còn mở trong plan, chưa làm.
- **T3 bổ sung (2026-10-04) — màn "Từ hay quên" tối thiểu:** banner
  `"\(n) từ hay quên ›"` dưới hero Home (ẩn khi `n == 0`), dẫn tới `LeechListView`
  (danh sách card `LeechService.fetchLeeches`, mỗi dòng 2 hành động: "Đưa lại hàng
  đợi" = `LeechService.unsuspend`, "Xoá hẳn" = hàm mới `LeechService.deleteWord`
  xoá `vocab_items` CASCADE xuống cards/review_logs/encounters). Quyết định phạm
  vi: màn này CHỈ requeue/xoá — sinh lại thẻ bằng AI hay sửa tay để sau (đụng hợp
  đồng prompt, cần `/rplan` riêng). Xoá hẳn có `confirmationDialog` xác nhận
  (không phải swipe một chạm — mất cả lịch ôn và lần gặp lại). Ngưỡng hiển thị
  hardcode "6 lần" trong header danh sách — đã chốt (CLAUDE.md §5, Seeder
  `defaultLeechLapses = 6`), không đọc qua kênh AppModel riêng (chưa có, không cần
  thêm chỉ cho một dòng chữ tĩnh).
- **T4 bổ sung (2026-10-04) — 🔍 Tìm từ, tìm xuyên collection:** nút 🔍 thêm vào
  toolbar Home, giữa pill 🔥N và ⚙ (ba hình tròn tách bằng `ToolbarSpacer`), mở
  `VocabSearchView` (`ShellRoute.search`) — `.searchable` + debounce 200ms gọi
  `VocabRepository.searchVocabulary` (`AppModel.searchVocabulary`). Khớp `term`
  hoặc `meaning_vi`, không phân biệt hoa/thường/dấu: gập ở **tầng Swift**
  (`VocabRepository.searchFold` — `.folding(.diacriticInsensitive)` + replace
  thủ công `đ/Đ` → `d`, vì symbol đó không phải "d có dấu" trong Unicode) —
  KHÔNG đụng `normalizedTerm`/khoá so khớp FR-10 (vẫn giữ dấu). Thứ tự kết quả:
  prefix-match term trước, rồi contains-match term, rồi chỉ khớp nghĩa; mỗi dòng
  hiện tên collection, chạm mở collection đó (`ShellRoute.hub`). Không gộp khi
  cùng `term` khác nghĩa — giữ nguyên luật FR-08 crit 3.

## ADR-058 — Đọc PDF trong Reado, cửa thu từ vựng thứ hai — đảo NG-07 (pdf-reader-r1)

- **Ngày:** 2026-10-04
- **Bối cảnh:** NG-07 (chốt khi PRD mới sinh) cấm nhập PDF/ebook, lý do ghi là "nguồn
  nào cũng chụp được, screenshot thay thế được, thêm path thứ hai chỉ nhân đôi bề
  mặt bảo trì". Thực tế đọc PDF trên máy khác đi vòng 5 bước (mở app đọc → screenshot
  → sang Reado → chọn ảnh → crop) mỗi lần muốn phân tích một trang — ngược nguyên lý
  #3 ("một thao tác tại điểm khựng"). Fen đề xuất đọc PDF ngay trong Reado; owner
  chốt làm, với các ràng buộc dưới.
- **Quyết định:**
  1. **Đảo một phần NG-07.** PDF không còn là non-goal tuyệt đối — đọc PDF tại chỗ
     trong Reado và phân tích trang đang đọc là cửa thu từ vựng thứ hai (**FR-23**),
     song song ảnh chụp (FR-01). Phần NG-07 còn giữ: **EPUB/ebook** (không có khái
     niệm trang cố định, cần Readium hoặc WebView — thêm dependency, để ngoài R1) và
     **chép/lưu file vào app** (vẫn cấm — xem 2).
  2. **Không bao giờ chép file PDF vào app.** Reado chỉ giữ một
     *security-scoped bookmark* (iOS, `URL.bookmarkData`) trỏ tới file đang nằm
     trong Files/iCloud Drive của fen, cộng số trang đang đọc. Xoá/di chuyển file ở
     nơi khác → Reado báo lỗi, không tự nhân bản để "an toàn hơn". Giữ đúng tinh
     thần nguyên lý #5 (bề mặt bản quyền nhỏ, có giới hạn) — file nguồn còn to hơn
     cả ảnh một trang.
  3. **Mỗi bộ có tên gắn tối đa 1 PDF** (sách = bộ, giống cách Q-09 đã dùng collection
     thay "tên sách + số trang"). Kho tạm không gắn được — kho tạm không có phiên
     đọc (Q-10), không có "đang đọc tới đâu" để nhớ.
  4. **Lớp chữ PDF trước, OCR sau — không phải "cứ PDF là vẽ ảnh rồi OCR".** Phần
     lớn PDF sách/tài liệu đã có lớp chữ thật (xuất từ Word/web, không phải ảnh).
     Đọc thẳng lớp chữ đó nhanh hơn, chính xác hơn, và bỏ qua được bước OCR. Nhưng
     lớp chữ không phải lúc nào cũng tin được: PDF scan có thể tự mang theo lớp chữ
     *rác* do phần mềm scan tự OCR hộ (`Tlie qnick brovvn`, `(cid:72)`…). Reado tự
     chấm chất lượng lớp chữ mỗi trang (`PDFPageText`, 4 điều kiện: độ dài, ký tự lạ,
     tỷ lệ chữ cái, tỷ lệ từ giống tiếng Anh) — tốt thì đi prompt PDF riêng; rác hoặc
     trang chỉ là ảnh (PDF scan thật) thì vẽ trang độ phân giải cao (~300 DPI, không
     qua `ImageCompressor` — mức nén 1600px đặt ra cho thời ảnh còn phải upload, giờ
     OCR chạy trên máy, chỉ text đi ra ngoài) rồi chạy đúng pipeline OCR + prompt ảnh
     v6 đang có. Người dùng không tự chọn, không thấy khác biệt ngoài một dòng tiến
     độ "Trang scan — đang nhận dạng chữ trên máy…".
  5. **Không gửi ảnh trang cho vision LLM.** Cân nhắc rồi loại: agent BYOK của fen
     (AI-Box, model text) có thể không nhận ảnh, tốn token hơn nhiều, gửi ảnh sách ra
     ngoài trong khi Reado đang cố ý OCR trên máy, và tạo ra hai lối gọi AI khó eval
     chung. Nếu OCR-trên-máy sau này không đủ tốt, đó là quyết định riêng (ADR mới),
     không gộp vào đây.
  6. **EPUB để Later**, không làm trong R1.
- **Mặc định cho hành vi chưa ai hỏi** (đổi được sau, không cần ADR mới nếu chỉ là
  tinh chỉnh số):
  - Phân tích lại một trang đã phân tích: **cho phép**, không chặn, không đánh dấu
    "đã làm" (cần thêm cột số trang vào `reading_sessions` — Later). Từ trùng đã có
    FR-10/Q-13 gập.
  - Câu bị cắt ngang ở đầu/cuối trang (tràn sang trang khác): prompt PDF vẫn dịch
    nhưng không lấy làm `example` — không ghép nội dung hai trang.
  - Lối tắt "Đọc tiếp" trên Home và nút "Đọc lại bằng OCR" thủ công trong reader:
    **Later**, không thuộc R1.
- **Hệ quả:**
  - **Schema:** bảng thứ 9 `pdf_sources` (migration v5, `docs/specs/db.md`) —
    `collection_id` là khoá chính (ép 1 PDF/bộ), `bookmark` TEXT base64, `page_index`/
    `page_count`, `updated_at`. Không export CSV, không sync Later (bookmark chỉ
    dùng được trên máy tạo ra nó).
  - **Prompt:** `Prompt.pdfText` + `pdfVersion` riêng, tách khỏi `Prompt.text`/
    `version = 6` (ảnh). Cùng JSON schema, `VerifyEngine`/`PhraseLocator`/decoder
    dùng lại không đổi. Eval riêng (`prompt_eval.py`) trước khi fen chấp nhận
    (`docs/plans/pdf-reader-r1.md` T5), cùng cách A-02 đã làm cho prompt ảnh.
  - **FR-23** mới trong `docs/specs/prd.md` (GWT), journey **J2b** mới trong
    `docs/specs/journeys.md` (sau J2). NG-07 viết lại nội dung, giữ ID, không xoá
    dòng tombstone.
  - Chi tiết implementation: `docs/specs/solution-design.md` §8b,
    `docs/agent/prompt-spec.md` mục 3b, task breakdown ở `docs/plans/pdf-reader-r1.md`.

## ADR-059 — Điều hướng trang + Mục lục trong PDF reader — đảo dòng "mục lục" ngoài phạm vi của FR-23 (pdf-nav-r1)

- **Ngày:** 2026-10-04
- **Bối cảnh:** fen thử pdf-reader-r1 (T0–T4) với sách thật 254 trang. Reader khi đó
  chỉ có vuốt ngang từng trang (`PDFView` + `usePageViewController`) — không có cách
  nhảy nhanh tới một trang xa, không có mục lục, và `ShellTabBar` vẫn chiếm ~80pt
  chỗ đọc dù đang ở trong một PDF (không phải màn danh sách). Fen: "hỗ trợ thêm
  nhiều cách thao tác với pdf dễ hơn. hiện tại pdf thao tác khó quá.. khó chọn
  trang, đổi trang các kiểu."
- **Quyết định:**
  1. Thêm **thanh kéo (slider) + nút ◀ ▶ + chạm "Tr. N / M" để gõ số trang** vào
     thanh đáy màn đọc.
  2. Thêm **Mục lục**, đọc outline sẵn có trong file PDF (`PDFOutline`/`PDFDestination`
     hoặc `PDFActionGoTo` — PDF xuất từ EPUB hay dùng action thay destination). Không
     tự sinh mục lục từ nội dung. Việc này **đảo dòng "mục lục" trong câu "Không
     thuộc phạm vi R1"** của FR-23 — các mục khác của dòng đó (highlight, ghi chú,
     tìm kiếm chữ, bookmark nhiều chỗ) vẫn giữ ngoài phạm vi.
  3. **Ẩn `ShellTabBar`** (Hôm nay / Thư viện) khi đang ở màn đọc PDF, dùng lại cơ chế
     ẩn đã có sẵn ở `ShellTabBar` (D3, offset+opacity+`allowsHitTesting`) — không viết
     cơ chế ẩn mới.
  4. **Không làm:** đổi sang cuộn dọc liên tục, lưới ảnh thu nhỏ (thumbnail grid). Giữ
     lật ngang từng trang (`usePageViewController`) làm lối đọc chính; slider/◀▶/Mục
     lục chỉ là lối nhảy nhanh.
- **Hệ quả:**
  - Không đổi schema — `pdf_sources`/`PDFSourceRepository.updatePage` giữ nguyên,
    nhảy trang qua slider/◀▶/gõ số/Mục lục đều lưu trang qua đường đó như lật tay.
  - Không đổi prompt/`PDFPageText`/luồng phân tích T4 (FR-23 CTA "Phân tích trang
    này" không đổi hành vi).
  - FR-23 (`docs/specs/prd.md`) thêm 1 GWT điều hướng; J2b (`docs/specs/journeys.md`)
    cập nhật happy path + bảng empty/error. ADR-058 không sửa.
  - Chi tiết implementation: `docs/plans/pdf-nav-r1.md`.

## ADR-060 — Bỏ thanh kéo trang, thêm ẩn chrome khi chạm + tông nền đọc (tinh chỉnh ADR-059)

- **Ngày:** 2026-10-04
- **Bối cảnh:** fen xem tay bản build N2 của ADR-059 (slider + ◀ ▶ + gõ trang + Mục
  lục) trên simulator với PDF thật 254 trang, ngay trong cùng phiên implement. Hai
  phản hồi trực tiếp:
  1. "cái thanh ngang có vẻ k cần.. tại dùng k hiệu quả. bấm vào đi tới trang với
     cái phụ lục cx đủ hỗ trợ r" — thanh kéo + nút ◀ ▶ thừa, gõ số trang (alert) +
     Mục lục đã đủ nhảy nhanh.
  2. "có thể che cái header với footer đi để tập trung sách hơn" — muốn một chế độ
     đọc tập trung, ẩn được nav bar + thanh đáy.
  3. "có cách nào cho nó có theme màu nâu, be gì đó để dễ đọc không" — muốn tông nền
     trang ấm hơn nền trắng mặc định, giống chế độ "giấy" của app đọc sách khác.
- **Quyết định:**
  1. **Bỏ thanh kéo trang + nút ◀ ▶** khỏi thanh đáy (`PDFReaderView`). Giữ nguyên
     "Tr. N / M" (chạm để gõ số trang, alert `PDFNavigation.pageIndex(fromInput:)`)
     và Mục lục (ADR-059) làm hai lối nhảy nhanh duy nhất; vuốt ngang từng trang vẫn
     là lối đọc chính.
  2. **Chạm vào trang (không phải vuốt) → ẩn/hiện nav bar + thanh đáy cùng lúc**
     (`isChromeHidden`, `.toolbar(_:for: .navigationBar)` + `.transition` cho thanh
     đáy). Không đụng cơ chế ẩn `ShellTabBar` (D3/ADR-059) — đây là lớp ẩn RIÊNG,
     nằm trong `PDFReaderView`, tab bar vẫn luôn ẩn sẵn khi đọc PDF.
  3. **Tông nền trang đọc** (`PDFPageTint`: Trắng/Giấy nâu), chọn qua Menu trên
     toolbar (icon `paintpalette`), lưu `@AppStorage` theo máy (không theo
     collection/PDF). PDFKit vẽ nguyên trang PDF, không có API đổi màu giấy — giả
     lập bằng lớp phủ `Color.blendMode(.multiply)` phía trên `PDFView` (trắng ×
     tint = tint, chữ đen gần như không đổi), không vẽ lại từng trang. Tách khỏi
     `AppTheme` (đó là accent UI chrome, không phải màu nội dung đọc).
- **Hệ quả:**
  - `PDFNavigationTests`/`PDFNavigation` không đổi (logic gõ trang/Mục lục vẫn vậy,
    chỉ bớt một đường gọi UI). Không đổi schema/prompt.
  - `docs/specs/journeys.md` J2b bớt dòng mô tả thanh kéo, thêm "chạm vào trang để
    ẩn/hiện nav bar + thanh đáy" và tông nền đọc. `docs/specs/prd.md` FR-23 sửa GWT
    điều hướng cho khớp.
  - Tông nền trang là tuỳ chọn hiển thị thuần tuý (CLAUDE.md §6.4) — không cần Q
    mới, không ảnh hưởng dữ liệu/lịch ôn.

## ADR-061 — Nhiều tông giấy + kéo thả độ đậm, cố định màu viền trang (tinh chỉnh ADR-060)

- **Ngày:** 2026-10-04
- **Bối cảnh:** fen xem bản ADR-060 (tông nền Trắng/Giấy nâu, nhị phân) ngay trong
  phiên implement, phản hồi hai điểm:
  1. "cho 1 vài option thay vì chỉ giấy nâu. có thể kéo thả độ màu của giấy" — muốn
     nhiều tông màu hơn, và chỉnh được độ đậm liên tục thay vì bật/tắt.
  2. "khi đọc dọc thì 2 phần trên dưới đen hơi nhiều" — viền trên/dưới `PDFView`
     (khi trang không lấp hết chiều cao màn, khổ dọc) tối gần đen, đặc biệt lệch
     hẳn với trang luôn vẽ trắng.
- **Quyết định:**
  1. **`PDFPageTintHue`** (Nâu / Kem / Xanh rêu) + **`pdfPageTintIntensity`**
     (`Double`, `@AppStorage`, 0 = Trắng). Chọn một tông từ Trắng → gán đậm mặc định
     0.45; Slider "Độ đậm" (0.05…1) nằm NGAY trong cùng `Menu` (iOS hỗ trợ `Slider`
     trong `Menu` từ 16) để kéo thả tại chỗ, không cần sheet riêng. Vẫn lớp phủ
     `.multiply`, không vẽ lại trang.
  2. **`PDFView.backgroundColor` cố định một xám nhạt trung tính** (không đọc theo
     Dark Mode — mặc định PDFKit tối theo Appearance, gần đen ở Dark Mode), khớp
     nguyên tắc trang luôn vẽ trắng bất kể giao diện hệ thống (ADR-060). Áp dụng cho
     cả lớp phủ tông giấy (margin cũng bị nhân `.multiply` theo, đồng màu với trang).
- **Hệ quả:** không đổi schema/prompt/logic điều hướng. Đổi key `@AppStorage` từ
  `readoPDFPageTint` (ADR-060, enum nhị phân, chưa từng release) sang
  `readoPDFPageTintHue`/`readoPDFPageTintIntensity` — không cần migration (tính
  năng chưa ra khỏi máy dev).

## ADR-062 — Dọn tông nền đọc PDF ra `SettingsView`, bỏ Menu trên toolbar reader (tinh chỉnh ADR-060/061)

- **Ngày:** 2026-10-04
- **Bối cảnh:** fen: "đem mấy config đó ra ngoài setting luôn đi" — tông giấy +
  Slider độ đậm (ADR-061) đang nằm trong một `Menu` trên toolbar `PDFReaderView`,
  fen muốn dọn ra màn Cài đặt thay vì giữ trên toolbar đọc.
- **Quyết định:** chuyển UI chọn (Picker "Tông giấy" gộp cả "Trắng" + Slider "Độ
  đậm" khi đã chọn một tông) sang `SettingsView`, Section mới "Đọc PDF" ngay sau
  "Giao diện". `PDFReaderView` **không còn nút nào trên toolbar cho việc này** —
  chỉ còn đọc `@AppStorage` để vẽ lớp phủ. Cùng pattern `ShellTabBar` đọc chung
  `appTheme` với `SettingsView` (hai nơi cùng khai báo `@AppStorage` trỏ một key,
  không cần binding truyền tay).
- **Hệ quả:** `PDFPageTintHue` đổi từ `private` sang `internal` (cùng target
  `Reado`, `SettingsView` cần dùng). Không đổi key `@AppStorage`, không đổi logic
  phủ `.multiply`/màu viền (ADR-061) — chỉ dọn nơi hiển thị control chọn. Mục lục
  là nút duy nhất còn lại trên toolbar reader (ẩn khi PDF không có outline).

## ADR-063 — Apple Intelligence: agent mặc định + soát OCR trên máy (mở rộng Q-03/ADR-049)

- **Ngày:** 2026-10-05
- **Bối cảnh:** iOS/macOS 26+ có framework hệ thống `FoundationModels` ("Apple
  Intelligence") — model ngôn ngữ chạy trên máy, không cần key, không gửi dữ liệu
  ra ngoài. Fen muốn dùng nó cho hai việc: (1) soát lại OCR trước khi gửi agent
  phân tích (chữ Vision đọc sai do nhoè/font lạ), (2) thêm Apple Intelligence làm
  một agent phân tích, **mặc định** khi máy hỗ trợ và đã bật. Trước khi code,
  spike đo thật trên máy (4 trang diagnostics thật, xem
  `docs/plans/apple-ai-r1.md` T1) vì các giới hạn runtime (context 4096 token,
  guardrail, entitlement PCC) không đoán được từ tài liệu — phải đo.
- **Số đo spike quyết định (2026-10-05, macOS 27.0, model "AFM 3 Core", 4 trang
  diagnostics thật):**
  - **Guided generation luôn vỡ context.** `respond(generating:)` cho SCHEMA FR-02
    đầy đủ (segments lồng phrases + vocabulary + summary) tự nó ăn ~2500 token dù
    `includeSchemaInPrompt` mặc định `true` — 8/8 lượt `onDevice-G` lỗi
    "exceeds the maximum allowed context size of 4096" dù prompt gốc chỉ
    ~1450–1565 token.
  - **String + `.permissiveContentTransformations` cũng vỡ 2/4 trang** — một
    lượt DUY NHẤT cho cả trang (dịch + từ vựng + tóm tắt) không đủ chỗ ngay cả
    không guided, vì OCR một trang sách thật đã chiếm phần lớn ngân sách 4096.
  - **Chia nhỏ (dịch từng đoạn) chạy được 4/4 trang**, 17–34s/trang — cộng dồn xử
    lý được nhiều hơn một lượt đơn có thể, và ngang tầm BYOK cloud (~45s đo được ở
    diagnostics cũ).
  - **PCC (`PrivateCloudComputeLanguageModel`) crash cứng** ngay khi construct:
    `Fatal error: Missing entitlement com.apple.developer.private-cloud-compute`
    — cần fen bật capability này trong Xcode (Apple cấp quyền riêng), chưa làm
    được trong phiên này.
  - **Prompt sửa OCR bị model đọc nhầm ví dụ thành lỗi thật.** Bản nháp đầu liệt
    kê ví dụ dạng "rn/m, cl/d, l/I/1…" trong instructions — model AFM lặp lại
    CHÍNH các cặp ví dụ đó như thể tìm thấy trên trang, trên CẢ 4 trang test (ví
    dụ đề xuất `"cl" → "the"` dù "cl" không xuất hiện trong OCR). Viết lại
    instructions bỏ hẳn ví dụ dạng cặp ký tự, chỉ mô tả bằng lời + yêu cầu model
    tự kiểm tra `wrong` có thật trong văn bản trước khi báo (`FoundationModelsOCRCorrector.instructions`).
  - Dù `OCRFixApplier` (luật editDistance/word-count/whole-word) chặn được gần
    hết đề xuất bậy, **một fix vẫn lọt qua và làm WER xấu đi** (0.131 → 0.134 so
    groundtruth) trên một trang — "sửa im lặng" có rủi ro thật, không chỉ lý
    thuyết.
- **Quyết định:**
  1. **Agent Apple Intelligence R1 chỉ on-device**, không PCC (entitlement chưa
     bật — để R2). Kind DB mới `apple_intelligence`, hàng builtin id cố định
     `00000000-0000-4000-a000-000000000002`, `model = 'on_device'`.
  2. **Pipeline FR-02 cho Apple LUÔN chia nhỏ theo đoạn** (không thử một lượt rồi
     mới rơi về chia nhỏ — một lượt đơn không đáng tin trên trang sách thật theo
     số đo trên). Mỗi đoạn (`\n\n`, cùng luật tách đoạn với `Prompt.text`) dịch
     riêng (String + permissive, tự nhiên theo cụm); MỘT lượt từ vựng cho cả
     trang (guided, schema phẳng nhẹ, `includeSchemaInPrompt: false`); MỘT lượt
     tóm tắt (String). Ráp lại thành đúng wire JSON rồi đi qua
     `AnalysisResponseNormalizer`/`AnalysisResponseDecoder` CHUNG với BYOK — luật
     lọc/verify không viết lại. `phrases` để rỗng ở R1 (chưa có đường dịch song
     song cụm EN↔VI theo đoạn như prompt BYOK) — có thể làm sau, không chặn R1.
  2b. **A-01 "một lần gọi"** vẫn đúng tinh thần cho BYOK (không đổi); với Apple,
     "một lần phân tích" của người dùng = nhiều lệnh gọi model NỘI BỘ (ẩn sau
     `AppleIntelligenceAnalyzer`), không phải nhiều lần OCR hay nhiều lần tính
     phí — A-01 vốn nói về ranh giới OCR/gọi AI, không phải số round-trip tới
     model.
  3. **Sửa OCR là bước tiền xử lý trên máy, chạy với MỌI agent** (không phải
     agent thứ hai, không đổi FR-21) — `CorrectingTextRecognizer` bọc
     `PageOCR.live`, soát bằng `FoundationModelsOCRCorrector` (chỉ text, không
     ảnh — xem số đo trên), timeout 8s, **không bao giờ** ném lỗi mới (lỗi/
     timeout/rỗng → rơi về OCR gốc). `OCRFixApplier` thi hành luật bảo thủ: khớp
     NGUYÊN TỪ, tối đa 3 từ, chênh số từ ≤ 1, Levenshtein ≤
     `max(1, min(3, len(wrong)/3))`, tổng số từ bị đụng ≤ 15% trang, > 30 đề xuất
     thì loại hết. Mặc định **TẮT** (đảo 2026-10-05 cùng ngày, sau khi review
     `ocr-quality-r1` T0, ADR-064: luật "khớp nguyên từ" ở trên áp cho MỌI chỗ
     khớp trên trang chứ không chỉ chỗ model định sửa, và spike tự đo được một
     fix lọt qua làm WER xấu đi — rủi ro "sửa im lặng" không phải zero. Giữ
     nguyên tinh thần "ưu tiên nguyên vẹn nhất câu" của fen bằng cách để người
     dùng tự bật khi muốn, thay vì mặc định sửa cho mọi người), toggle bật được
     ở Settings (`ocrFixEnabled`, `UserDefaults`, hằng seed `AppleIntelligence.
     ocrFixDefault`).
  4. **Luật mặc định (FR-21 mở rộng):** Apple trở thành agent active CHỈ KHI
     **chưa chọn agent nào** (active đang là hàng placeholder — cài mới, hoặc
     vừa xoá agent BYOK đang dùng) VÀ Apple sẵn sàng (`AnalysisAgentStore.applyDefault`,
     gọi mỗi `AppModel.reloadOverview()`). Đã chủ động chọn BYOK, hoặc đã chọn
     Apple rồi sau đó Apple tạm thời không sẵn sàng (tắt Apple Intelligence
     trong Cài đặt iPhone…) → **giữ nguyên lựa chọn**, không tự nhảy — đúng FR-21
     "dùng đúng agent đã chọn". Khi đó phân tích báo lỗi rõ kèm lý do
     (`AppleIntelligenceStatus.reasonVI`), hàng Apple ở Settings mờ + lý do,
     không bấm chọn lại được nhưng vẫn hiện dấu đang chọn.
- **Đã cân nhắc:**
  - *Agent dùng PCC (cloud) thay vì on-device* — loại: crash cứng thiếu
    entitlement, không sửa được qua CLI/pbxproj, cần fen tự bật trong Xcode
    (Signing & Capabilities) rồi xin Apple duyệt. Để R2.
  - *Sửa OCR kèm ảnh (vision) thay vì chỉ text* — đo cả hai ở spike: ảnh+text
    chậm hơn ~3x và KHÔNG tốt hơn (cùng kiểu đề xuất sai do prompt, không phải
    do thiếu ảnh). Bỏ nhánh ảnh, giữ lại protocol chỗ trống nếu sau này cần.
  - *Một lượt guided cho cả trang (như BYOK)* — loại hẳn, không phải tối ưu sau:
    số đo cho thấy vỡ context gần như luôn luôn trên trang sách thật.
  - *Mặc định Apple BẬT luôn, kể cả khi đã chọn BYOK* — loại: đảo ngược lựa chọn
    chủ động của người dùng là hành vi bất ngờ, ngược nguyên lý "app không tự ý
    đổi điều người dùng đã chọn".
- **Hệ quả:**
  - **Schema:** migration v6 (`Migration.currentVersion = 6`) — CHECK
    `analysis_agents.kind` thêm `'apple_intelligence'` (rebuild bảng theo thủ
    tục SQLite chuẩn: tắt `foreign_keys` NGOÀI transaction, tạo bảng mới, copy
    dữ liệu, drop, rename, `PRAGMA foreign_key_check`, bật lại `foreign_keys`) +
    insert hàng builtin. Seeder không đổi (hàng Apple do migration tạo, chạy cho
    cả cài mới lẫn nâng cấp).
  - **ReadoKit:** thư mục mới `Analysis/AppleIntelligence/` — `OCRFix`/
    `OCRFixApplier`, `OCRCorrector`/`FoundationModelsOCRCorrector`,
    `CorrectingTextRecognizer`/`TimeoutRunner`, `AppleIntelligenceStatus`/
    `AppleIntelligence` (cổng không mang `@available`), `AppleAnalysisModel`/
    `OnDeviceAnalysisModel`, `AppleIntelligenceErrorMapper`,
    `AppleIntelligenceAnalyzer`. `FoundationModels` tự weak-link qua
    `#if canImport` (xác nhận bằng `otool -L` — `weak` trên load command, không
    cần `@_weakLinked` thủ công) — an toàn với target min iOS 17.
  - **AnalysisAgentStore:** `isAppleIntelligence`, `appleKind`, lỗi
    `.builtinAgent` (không sửa/xoá được), `list()` xếp Apple lên đầu,
    `applyDefault(appleAvailable:)`.
  - **Settings:** hàng Apple không có swipe, mờ + lý do khi không sẵn sàng;
    toggle "Sửa lỗi OCR bằng Apple Intelligence" trong section Agent (chỉ hiện
    khi máy hỗ trợ).
  - **A-02 (baseline prompt):** không áp dụng cho Apple — Apple dùng pipeline
    chia nhỏ riêng (prompt ngắn hơn nhiều, không phải `Prompt.text`), eval
    riêng nếu cần sau R1.
  - Chi tiết task breakdown: `docs/plans/apple-ai-r1.md`.

## ADR-064 — Đổi OCR-fix mặc định TẮT; engine mặc định `liveText` (ghép Live Text + `documents`) — ocr-quality-r1 T0/T2/T3a

- **Bối cảnh:** Review `apple-ai-r1` (2026-10-05) thấy `OCRFixApplier` áp fix cho MỌI chỗ khớp
  nguyên từ trên trang (không chỉ chỗ model định sửa) và "đề xuất rồi lọc" không chặn được lỗi ra
  từ thật (`"cat"` → `"car"` qua hết luật). Đồng thời Live Text (VisionKit `ImageAnalyzer`) — thứ
  fen vẫn dùng làm groundtruth thủ công — chưa từng được đo như một engine OCR thật trong app.
  Plan nháp fen đưa đã được phân tích kỹ trước khi code (`plan_ocr_quality_r1.md`).
- **Số đo (2026-10-05, fen đưa 6 ảnh thật: 3 ảnh chụp sách "The Psychology of Money" p.47–49, 3 ảnh
  chụp màn hình "The Courage to be Disliked" p.12/13/17 — groundtruth 3 trang sau lấy từ lớp chữ
  PDF gốc, không qua Live Text/OCR, tránh đo vòng tròn; xem `docs/journal/2026-10-05.md`):**
  - `OCRFixApplier`: spike trước đó đã đo một fix lọt qua làm WER xấu đi (0.131→0.134, n=1) — rủi ro
    "sửa im lặng" là thật dù số đo mỏng; lý do chính vẫn là luật áp "mọi chỗ khớp" (cấu trúc, không
    phải riêng con số WER đó).
  - `liveText` (VisionKit `ImageAnalyzer`) có WER/CER **thấp hơn rõ rệt** `documents` trên cả 3 trang
    có groundtruth, cả full-res lẫn ảnh nén 1600px — vd trang 1 full-res: WER 0.106→0.034, CER
    0.019→0.007; trang 3 gần hoàn hảo: WER 0.009→0.000. `legacy` luôn tệ nhất (WER 0.3–0.7).
  - **`ImageAnalysis.transcript` (API public) KHÔNG giữ ranh giới đoạn** — đo trên cả 3 trang:
    `documents` có 9–13 lần `\n\n` (đúng số lượt thoại), `liveText` có **0 lần**, chỉ `\n` đơn giữa
    mọi dòng. Xác nhận bằng swiftinterface SDK: `ImageAnalysis` public chỉ có `transcript: String`,
    không dòng/bbox/đoạn — không có cách lấy đoạn trực tiếp từ Live Text.
  - Độ trễ `liveText` phần lớn ngang `documents` (800–2000ms); một lần ngoại lệ 7905ms ở lượt gọi
    `ImageAnalyzer` đầu tiên trong phiên (nghi cold-start tải model — lượt sau cùng ảnh chỉ 1246ms).
  - Số từ mỗi đoạn giữa `documents` và `liveText` gần như bằng nhau trên cả 3 trang thật (lệch ≤ 1
    từ trên tổng ~120–260 từ/trang) — hai engine đọc cùng ảnh nên tỉ lệ từ mỗi đoạn ổn định.
  - Corpus còn nhỏ (6/12 trang theo kế hoạch T1, thiếu nhóm "PDF scan" thật — PDF fen đưa hoá ra có
    lớp chữ gần hết, không đại diện — và nhóm "chụp label"); fen đã chốt chấp nhận quy mô này cho
    vòng đầu, bổ sung sau nếu cần.
- **Quyết định:**
  1. **OCR-fix (Apple Intelligence soát OCR) đổi mặc định sang TẮT** (đảo ADR-063 mục 3, cùng ngày).
     `AppleIntelligence.ocrFixDefault = false` (ReadoKit, hằng duy nhất) — `AppModel+Capture.swift`
     và `SettingsView.swift` cùng đọc hằng này (trước đó là 2 literal `true` riêng, lệch nhau thì
     Settings hiện BẬT trong khi capture chạy TẮT — bug tiềm ẩn đã phát hiện khi code T0). Người
     dùng tự bật khi muốn qua Settings — giữ tinh thần "ưu tiên nguyên vẹn nhất câu" của fen, chỉ
     đổi ai là người quyết định bật.
  2. **Engine OCR mặc định đổi sang `liveText`** (chuỗi fallback: `liveText` → `documents` →
     `legacy`, không đổi với PDF chữ/`PDFPageText` — không đụng). Vì `transcript` không có đoạn,
     `liveText` KHÔNG đứng độc lập: `PageOCR.recognizeLiveTextMerged` (iOS 26+) luôn chạy CẢ HAI
     engine — lấy khung đoạn (`\n\n`) từ `documents`, ghép chữ từ `liveText` vào theo tỉ lệ số từ
     mỗi đoạn (`PageOCR.mergeParagraphBoundaries`, hàm thuần, test bằng chuỗi dựng tay — không cần
     thuật toán căn chữ kiểu Needleman-Wunsch vì số từ hai engine lệch tối thiểu). `OCRResult.engine
     = "liveText"` khi ghép thành công; rơi về `documents` nếu Live Text lỗi/rỗng/không hỗ trợ, rồi
     `legacy` nếu `documents` cũng lỗi/rỗng hoặc OS < 26 (không đổi hành vi cũ trên OS cũ — chưa có
     số đo `liveText` so `legacy` trên iOS 17–25, để ngỏ, xem T2 câu (e) chưa trả lời).
  3. **Không thực hiện T3b** (đồng thuận `documents`+`legacy`) — `documents` đã thắng rõ `legacy` ở
     mọi số đo kể cả trước ADR này; đồng thuận hai engine tương quan lỗi không mang lại gì ngoài rủi
     ro mới, và T2 đã trả lời đủ để chọn hướng (ii) thay vì cần T3b.
- **Đã cân nhắc:**
  - *Live Text đứng đầu chuỗi fallback, dùng thẳng `transcript`* (hướng (i) trong plan nháp) — loại:
    đo thật xác nhận không có `\n\n`, sẽ phá hợp đồng "`\n\n` = ranh giới đoạn" của prompt v6.
  - *Giữ nguyên `documents`, không đổi engine* — cân nhắc nghiêm túc (WER của `documents` trên
    screenshot đã khá tốt: 0.01–0.12), nhưng số đo cho thấy `liveText` tốt hơn rõ rệt và chi phí
    thêm (chạy 2 engine) chấp nhận được trên dữ liệu đo được — fen chọn hướng ghép thay vì giữ
    nguyên (AskUserQuestion, 2026-10-05).
- **Hệ quả:**
  - **ReadoKit** (`Analysis/PageOCR.swift`): thêm `import VisionKit`, `recognizeLiveTextMerged`
    (`@available(iOS 26.0, macOS 26.0, *)`, private), `mergeParagraphBoundaries` (public, testable).
    `AnalysisAgentStore`, `OpenAICompatClient`, `AppleIntelligenceAnalyzer` không đổi (đọc
    `PageTextRecognizer`/`OCRResult` qua protocol, không biết engine nào chạy bên dưới).
  - **`AppleIntelligenceStatus.swift`**: thêm hằng `AppleIntelligence.ocrFixDefault`.
  - **`scripts/diag_summary.py`**: nhánh riêng cho `engine == "liveText"` (observations/lines kế
    thừa từ `documents`, không phải số liệu riêng của Live Text — "unseen" không áp dụng).
  - **Test:** `AnalyzerFactoryTests.testOCRFixDefaultIsOff`, `PageOCRTests` 5 case
    `mergeParagraphBoundaries`, `OCRProbeTests` thêm cấu hình `liveText` + WER/CER thật (Levenshtein
    từ/ký tự) thay chỉ đếm câu thiếu. `scripts/test.sh` đầy đủ 549/552 xanh (3 skip cũ không đổi).
  - Chi tiết task breakdown + bảng số đo đầy đủ: `plan_ocr_quality_r1.md` (gốc repo, chưa vào
    `docs/plans/`), `docs/journal/2026-10-05.md`.

## ADR-065 — Gỡ hẳn OCR-fix bằng LLM — ocr-quality-r1 T7

- **Bối cảnh:** ADR-064 (T3a) đổi engine OCR mặc định sang `liveText`, đo WER thấp hơn rõ rệt so
  với `documents` trên dữ liệu thật — đúng loại lỗi (nhận dạng ký tự) mà `CorrectingTextRecognizer`
  (ADR-063) từng nhắm tới, nhưng không có rủi ro "sửa im lặng sai chỗ" của hướng LLM-đề-xuất-rồi-lọc
  (xem Context ADR-064). Fen tự dùng tính năng Apple Intelligence trên máy thật (2026-10-05, sau khi
  T3a đã xem tay xong — `diag_summary` ra đúng `engine=liveText`), thấy ổn, chủ động hỏi gỡ code
  không còn dùng.
- **Trước khi gỡ — code review phát hiện 1 lỗi thật cần sửa trước (không liên quan T7):**
  `mergeParagraphBoundaries` (T3a) làm tròn ĐỘC LẬP từng đoạn, sai số dồn vào cuối trang trên trang
  nhiều đoạn ngắn (hội thoại) — T2 chỉ đo 3 trang ít đoạn dài nên không lộ ra. Sửa bằng biên tích luỹ
  trước khi gỡ OCR-fix, kèm 3 phát hiện phụ (log chẩn đoán gây hiểu lầm khi `engine=liveText`,
  `UITextChecker` không an toàn luồng, 2 bản Levenshtein trùng) — xem `docs/journal/2026-10-05.md`.
- **Quyết định:** gỡ toàn bộ nhánh sửa OCR bằng LLM:
  - Xoá file nguồn: `CorrectingTextRecognizer.swift` (tách riêng `TimeoutRunner` — dùng chung cho
    `AppleIntelligenceAnalyzer` giới hạn thời gian gọi model AI, không phải riêng OCR-fix, giữ lại
    trong file mới `TimeoutRunner.swift`), `FoundationModelsOCRCorrector.swift`, `OCRCorrector.swift`,
    `OCRFix.swift` (`OCRFix` struct + `OCRFixApplier`).
  - Xoá test: `CorrectingTextRecognizerTests.swift`, `OCRFixApplierTests.swift` (tách
    `TimeoutRunnerTests` ra file riêng — `TimeoutRunner` còn dùng); 5 test trong `AnalyzerFactoryTests`
    (4 case `textRecognizer` cũ + `testOCRFixDefaultIsOff`, hằng đã xoá).
  - `OCRResult` (`PageOCR.swift`): bỏ field `rawText`/`fixes`/`fixRejectedCount`/`fixMs`/`fixError` +
    method `corrected(...)` — không ai còn tạo ra các giá trị này.
  - `AnalyzerFactory`: bỏ hẳn `textRecognizer(...)` + tham số `ocrFixEnabled` của `active(...)` —
    `analyzer(...)` dùng thẳng `PageOCR.live` (mặc định sẵn có).
  - `AppleIntelligence` (`AppleIntelligenceStatus.swift`): bỏ `ocrFixDefaultsKey`/`ocrFixDefault`/
    `liveOCRCorrector()`.
  - App: `AppModel+Capture.swift` bỏ đọc `UserDefaults` cho `ocrFixEnabled`; `SettingsView.swift` bỏ
    hẳn Toggle "Sửa lỗi OCR bằng Apple Intelligence" + câu footer nhắc soát OCR; `AppModel.swift` bỏ
    `ocrFixAvailable` (computed mỗi `reloadOverview()`, không ai đọc nữa).
  - Log chẩn đoán: `OpenAICompatClient.ocrDebugJSON`/`AppleIntelligenceAnalyzer` bỏ key
    `rawText`/`fixes`/`fixRejected`/`fixMs`/`fixError`/`ocrFixes`; `diag_summary.py` bỏ nhánh in
    "OCR fix: … áp / … loại / … ms".
  - Docs: `CLAUDE.md` §1/§5, `prd.md` FR-02 (thêm bảng v0.15, giữ nguyên bảng v0.14 cũ làm lịch sử),
    `ROADMAP.md` 3.18/3.19 (ghi chú đảo, không xoá dòng lịch sử).
- **Không gỡ:** agent kind `apple_intelligence` (`AnalysisAgentStore`, `AppleIntelligenceAnalyzer`,
  `OnDeviceAnalysisModel`, migration v6) — đó là tính năng khác (dịch + trích từ vựng bằng Apple
  Intelligence), không phải bước soát OCR. `TimeoutRunner` cũng giữ (dùng chung).
- **Đã cân nhắc:** giữ code nằm im (toggle đã TẮT mặc định từ T0, không hại gì) — fen chọn gỡ hẳn vì
  code không dùng + không ai định bật lại (khác tinh thần T7 gốc "viết plan riêng nếu vẫn cần sửa
  OCR theo hướng khác" — hướng khác đó, nếu cần, sẽ là một thiết kế mới, không phải bật lại cái này).
- **Hệ quả:** `scripts/test.sh` 525/528 xanh (3 skip cũ, mất 26 test của nhánh đã gỡ, giữ lại 2 test
  `TimeoutRunner`). Không đổi schema/migration — OCR-fix chưa bao giờ có bảng DB riêng, chỉ
  `UserDefaults`.

## ADR-066 — Đảo Q-09 cho FR-10: so khớp "đã thuộc" toàn app thay vì theo collection — vocab-identity-r1 T0

- **Ngày:** 2026-10-05
- **Bối cảnh:** Fen đọc 3-4 trang/ngày (PDF là chính), thu ~20 từ/ngày — vượt xa
  `daily_new_limit` mặc định 10, tồn đọng tăng ~10 từ/ngày (~300/tháng). Ba nguyên nhân
  trong code: (1) chọn sẵn cố định 5 từ/trang không liên hệ hạn mức ngày (FR-09); (2)
  `daily_new_limit` mặc định 10; (3) FR-10 chỉ gập từ *đã thuộc* trong **cùng collection**
  (Q-09, ADR-032, 2026-09-22) — từ đang học hoặc đã có ở collection khác vẫn qua
  `saveCapture` bình thường, sinh `vocab_items`+`cards` mới mỗi lần gặp lại. Lý do gốc của
  Q-09 ("mỗi collection ≈ một cuốn sách, nghĩa mới của từ cũ vẫn phải thêm khi sang sách
  khác") vẫn đúng, nhưng lúc chốt (2026-09-22) **chưa có FR-22** — cách duy nhất để "gặp
  lại" được ghi nhận là tạo thêm một dòng `vocab_items`. FR-22 (reencounter-r1, 2026-10-02)
  đã lấp đúng chỗ đó: bảng `encounters` ghi lại lần gặp (`seen`/`recognized`) **xuyên mọi
  collection** mà không cần thẻ mới. Giữ Q-09 cũ cho FR-10 giờ chỉ còn cái giá (thẻ trùng),
  không còn cái lợi (ghi nhận gặp lại) — cái lợi đó FR-22 đã làm tốt hơn.
- **Quyết định:** Đảo Q-09 — bộ lọc FR-10 so khớp `term+pos` (Q-06 không lemmatize, Q-08
  `stability >= 21` giữ nguyên) trên **toàn app**, không còn giới hạn theo collection đang
  chụp. Thống nhất với phạm vi FR-22 vốn đã toàn app từ đầu. Nhóm gập (Q-13, ADR-056) đổi
  tên "Đã thuộc" → **"Đã có trong kho"**, mở rộng gồm **mọi** từ đã có (đang học + đã thuộc,
  mọi collection) — không chỉ từ đã thuộc (D2). Item khớp khoá mặc định **không tạo thẻ**,
  chỉ ghi `encounters.kind='seen'` kèm câu gốc (cột mới, xem Hệ quả) + collection nguồn;
  "Nghĩa khác — lưu" vẫn tạo dòng + thẻ mới như cũ nếu người dùng xác nhận đây là nghĩa
  khác (đồng âm).
  - **D1 — ngân sách chọn sẵn mỗi ngày:** bám thẳng `daily_new_limit` (không thêm setting
    riêng) — `preselectBudget = max(0, daily_new_limit - newSavedToday)` thay cho hằng
    `preselectLimit = 5` cố định.
    - **Q1 (fen, T1):** giữ trần 5/trang — suất chọn sẵn = `min(5, preselectBudget)`; ngân
      sách ngày không nâng trần theo trang.
    - **Q3 (plan, T1):** `newSavedToday` tính cả từ nhập CSV (FR-20) — CSV ghi `created_at` =
      lúc nhập, không phân biệt được nguồn; chỉ ảnh hưởng gợi ý chọn sẵn, không đụng dữ liệu.
  - **D2 — phạm vi nhóm "Đã có trong kho":** mọi từ đã có (đang học + đã thuộc, mọi
    collection) — không chỉ từ đã thuộc trong cùng collection như FR-10 cũ.
  - **D3 — ôn theo bộ (FR-18):** từ gặp lại ở collection khác **không** kéo vào khi ôn
    theo phạm vi một bộ; thẻ ở lại collection gốc. Để R2.
  - **D4 — gạch chân từ cũ ngay trong màn đọc PDF:** để sau, không làm trong
    vocab-identity-r1 (không có task spike PDF ở plan này).
- **Lý do:** Trùng lặp là câu hỏi sư phạm (vocabulary.md §6.3), không phải toàn vẹn dữ
  liệu — gặp lại từ chưa thuộc vẫn là tín hiệu tốt, chỉ khác là giờ tín hiệu đó được ghi
  bằng `encounters` thay vì bằng một dòng `vocab_items`+`cards` mới. Giữ cơ chế chống trùng
  duy nhất (không `unique`) hiệu quả hơn mà không đổi bản chất "một dòng = một nghĩa".
- **Hệ quả:**
  - FR-09 GWT 1 đổi "preselect tối đa 5" → "preselect theo ngân sách ngày".
  - FR-10 GWT 1/3 đổi phạm vi so khớp + tên nhóm gập.
  - FR-22 thêm GWT: `encounters` ghi kèm câu (`sentence`) + collection nguồn
    (`collection_id`) — migration v7, hai cột mới cho phép NULL (dòng cũ giữ NULL).
  - **N4** — Ôn theo bộ (FR-18) không thấy từ gặp lại ở bộ khác (hệ quả D3, chấp nhận R1).
  - **N5** — Thẻ trùng **cũ** (sinh trước plan này) vẫn còn nguyên; plan chỉ chặn trùng
    mới từ nay về sau. Công cụ gộp thẻ trùng cũ + gộp lịch FSRS để Later (rủi ro hỏng dữ
    liệu nếu làm tự động).
  - `CLAUDE.md` §5, `prd.md` FR-09/FR-10/FR-22, `journeys.md` J1/J2b, `vocabulary.md` §6.3
    sửa theo ADR này (vocab-identity-r1 T0).
  - Không đụng FSRS/`cards`/`review_logs`, `Prompt.version` (giữ v6), `PDFPageText`/OCR.
  - **T2 (2026-10-05, dữ liệu ngữ cảnh) — tự quyết của plan:**
    - **Q6** — câu ngữ cảnh > 300 ký tự (OCR thiếu dấu câu): cắt cửa sổ ±120 ký tự quanh
      từ khớp, nới về ranh giới khoảng trắng, "…" ở phía bị cắt.
    - **Q10** — field JSON export là `collectionID` (theo `ExportVocabItem`), Optional;
      `version` giữ 1.
    - **Q11** — dùng `NLTokenizer` qua `import NaturalLanguage`, không sửa `Package.swift`
      (link tự động; đã build kit macOS + iOS OK).
    - Migration v7 = hai `ALTER TABLE encounters ADD COLUMN` riêng, nullable không DEFAULT.
  - **T3 (2026-10-05, so khớp toàn app + "Ghi gặp lại") - tự quyết của plan:**
    - **Q4** - giữ tên `matureHidden`/`MatureHiddenDraft` (đổi nghĩa + doc comment, không đổi tên).
    - **Q5** - giữ tham số `matureSenses:` của `drafts`; thêm `knownSenses:` ưu tiên khi không rỗng.
      `regroup` + test giữ nguyên, `AnalysisView` không còn gọi (bỏ `.onChange` đích + `regroupMatureIfNeeded`).
    - **Q7** - trang chỉ có từ cũ (context-only) vẫn lưu phiên đọc theo luật cũ (bộ có tên + có nội dung).
    - **Q8** - từ leech nằm trong nhóm, nhãn "đang ở Từ hay quên", KHÔNG ghi `seen`, ẩn nút chọn khi mọi nghĩa là leech.
  - **T4 (2026-10-05, hiện ngữ cảnh) - tự quyết của plan:**
    - **Q9** - popover ghi **"Gặp lại N lần"** (N = số dòng `seen`, mỗi lần lưu trang = 1), không phải "Gặp ở N chỗ".
      Kèm tối đa 2 câu gần nhất + tên bộ ("bộ đã xoá" khi `collection_id` NULL). Mặt sau thẻ: mục "Gặp lại",
      tối đa 3 câu (`lineLimit(2)`), bỏ câu trùng `example` của thẻ (trim, không phân biệt hoa thường).
    - Dữ liệu demo DEBUG: 2 dòng `seen` có câu "Demo: ..." gắn vào "routine" (fallback vocab đầu tiên) vì fixture
      `analysis-demo.json` mở popover của match đầu tiên còn trong từ điển là "routine".
  - Plan đầy đủ: `docs/plans/done/vocab-identity-r1.md`.

---

## ADR-067 — Gộp từ trùng cũ (FR-24) — engagement-r1 T0

- **Ngày:** 2026-10-05
- **Bối cảnh:** ADR-066 chỉ chặn trùng **mới** (hệ quả N5 ghi "công cụ gộp để Later vì rủi ro
  hỏng dữ liệu nếu làm tự động"). Các dòng lưu trước đó cùng `term_normalized + pos` ở nhiều
  bộ vẫn mỗi dòng một thẻ ôn, nên một từ bị ôn nhiều lần và các con số "Gặp lại"/"Đã nhớ" lệch.
  Fen muốn dọn nhưng vẫn có người duyệt (cùng khoá có thể là hai nghĩa khác — đồng âm lưu qua
  "Nghĩa khác — lưu").
- **Quyết định:** FR-24 — màn "Gộp từ trùng" ở Dữ liệu; **fen duyệt từng nhóm** (mặc định chọn
  gộp, bỏ chọn dòng mang nghĩa khác). Giữ **một** dòng/thẻ: không leech → `stability` cao nhất →
  `last_review_at` mới nhất → `created_at` cũ nhất. `review_logs` chuyển sang thẻ giữ;
  `encounters` chuyển sang dòng giữ (bỏ `recognized` trùng ngày học); mỗi dòng gộp thành một
  `seen` mang câu + bộ của nó; dòng gộp bị xoá. Một transaction cho cả lượt gộp.
- **Lý do:** không tự viết FSRS (NG-09) — chỉ chọn thẻ có sẵn, trạng thái FSRS của thẻ giữ
  không đổi; không mất ngữ cảnh (vision #4); không lịch sử `review_logs` nào bị mất.
- **Hệ quả:**
  - Đảo một phần N5 của ADR-066 (công cụ gộp từ "Later" thành làm ngay), nhưng **không** tự
    động: luôn qua duyệt tay.
  - "Gặp lại N lần" của từ tăng thêm 1 cho mỗi dòng gộp; tổng số `review_logs` không đổi.
  - Không lưu nhóm đã bỏ qua (không thêm schema, vẫn v7): nhóm hiện lại ở lần mở sau.
  - Gộp không hoàn tác; JSON FR-16 chưa nhập lại được → hộp thoại nhắc xuất backup trước.
  - Tiêu chí dừng: 0 nhóm trùng trên dữ liệu thật → không cần làm (xem plan).
- Plan: `docs/plans/done/engagement-r1.md`.

---

## ADR-068 — Tăng gắn bó (engagement-r1): ý 1–6 của tang_gang_bo — engagement-r1 T0

- **Ngày:** 2026-10-05
- **Bối cảnh:** `idea/tang_gang_bo.md` (brainstorm 2026-10-02) liệt kê 7 ý tăng gắn bó. Nguyên
  tắc: phần thưởng là bằng chứng việc đọc tiến bộ thật (vision #6), không XP/huy hiệu ảo
  (NG-04). Dò code 2026-10-05: sheet gặp lại đã có "Gặp lại N lần" + haptic khi Nhận ra nhưng
  thiếu câu gốc lần đầu/"N ngày trước"/mức; `Mastery.level` chưa UI nào gọi; chưa có điểm dừng
  giữa phiên ôn; dòng nhắc streak dựa vào nỗi sợ mất chuỗi.
- **Quyết định:** làm ý **1, 2, 3, 4, 5, 6**; ý 7 (thẻ chia sẻ) để sau (NG-05/NG-04).
  - **Ý 1 + 6:** sheet gặp lại thêm câu gốc lần đầu + "N ngày trước" + mức; haptic/animation
    khi lên Đã thấm (Reduce Motion); "Trang này có N từ bạn đã gặp"; mặt sau thẻ "Gặp lần đầu
    N ngày trước" (chỉ khi từ đã lưu ≥ 7 ngày).
  - **Ý 2:** nút phụ "Ôn nhanh 3 thẻ · ~2 phút" ở hero; xong thì được dừng hẳn. Số đến hạn của
    hero giữ nguyên nên FR-14 không đổi.
  - **Ý 3:** bản đồ chấm theo 4 mức **thay** thanh 4 màu ở header Hub (không thêm khối mới).
  - **Ý 4:** cụm đáng nhớ chọn từ `segments[].phrases` bằng heuristic (cụm có EN chứa từ vừa
    lưu, không có thì cụm dài nhất); không đổi prompt.
  - **Ý 5:** thẻ "Tuần qua" trên Home (không notification); **không đếm số trang** — không có
    nguồn bền (`reading_sessions` chỉ giữ 10 phiên/bộ, NFR-04).
  - **Streak (bổ sung ADR-038):** giữ pill; dòng nhắc trong hero đổi sang "Tuần này ôn N/7
    ngày" (khớp M-02). N/7 đếm mọi mode giống streak (thống nhất với `reviewedToday` chỉ đếm
    `srs`).
- **Lý do:** mỗi con số đo được từ `encounters`/`review_logs`/`vocab_items`; đồng bộ với "mỗi
  ngày giữ thêm vài từ là đủ" (Retention) thay vì đòi học hết.
- **Hệ quả:** FR-22/14/11/02 thêm GWT (prd v0.17); không đổi schema (v7), không đổi
  `Prompt.version`. Ghi nhận, chưa sửa: bộ đếm overview dùng `Mastery.stabilityThreshold` cứng
  bỏ qua `known_stability` (`VocabRepository+Overview.swift`).
- Plan: `docs/plans/done/engagement-r1.md`.

## ADR-069 — Mô hình docs 5 tầng + 3 nguyên tắc (workflow-docs-r1)

- **Ngày:** 2026-10-06
- **Bối cảnh:** Bằng chứng mà workflow dựa vào (kết quả test, plan đang mở, quyết định đã chốt) từng sai mà không ai biết: summary test xanh cũ vẫn được nạp như kết quả mới, plan thiếu dòng trạng thái không hiện ở hook, Q-09 còn ghi "theo collection" ở ROADMAP dù đã có ADR-066, `CLAUDE.md` phình tới 13KB vì chép "Chốt thêm…".
- **Quyết định:** Docs chia 5 tầng, mỗi tầng một luật:

  | Tầng | File | Luật |
  |---|---|---|
  | Hiến pháp | `CLAUDE.md` (+ `app/ReadoKit/CLAUDE.md`), `vision.md`, `MASTER.md`, `coding-conventions.md` | Hiếm khi đổi, không ghi ngày |
  | Hợp đồng | `prd.md`, `journeys.md`, `db.md`, `solution-design.md`, `prompt-spec.md` | Chỉ ghi hiện tại; bia mộ tối đa 1 dòng |
  | Quyết định | `decisions-log.md` + index đầu file | Thân ADR bất biến; index được sửa |
  | Trạng thái | brief (§1–2 ≤ 3KB), `docs/qa/pending.md`, plans | Dùng ID ổn định, không dùng số thứ tự |
  | Lịch sử | journal, `prd-changelog.md`, `docs/journal/archive-*` | Agent không đọc mặc định |

  Ba nguyên tắc: (1) mỗi sự thật có đúng một nhà, nơi khác chỉ trỏ tới; (2) việc máy kiểm được thì đưa vào script/hook, không viết thành lời dặn; (3) mỗi loại bằng chứng chỉ có một script ghi, và gắn với nội dung code (tree hash của `app/`), không gắn với thời điểm (HEAD).
- **Hệ quả:** Quyết định hiện hành chỉ đọc ở `CLAUDE.md` §5 + index ADR này; mục "Đã chốt" trong research/spec là ảnh chụp lúc nghiên cứu. Giữ nguyên số mục `CLAUDE.md` §4–§7 vì ~25 chỗ trỏ theo số.
- **Thay thế đã loại:** Không làm gì (sự cố đã xảy ra thật); viết lại toàn bộ docs một lượt (rủi ro vỡ con trỏ, mất bằng chứng lịch sử).
