# Architecture Decision Records — Reado

> **ADR log** ghi lại các quyết định kiến trúc **đã chốt**. Mỗi quyết định có ID,
> lý do, ngày, và hệ quả. Không chứa câu hỏi hay tiến độ — xem ROADMAP.md.
> (ADR-001..ADR-024 thuộc thế hệ PWA; ADR-026..028 ghi pivot v2 — task 0.2 trong ROADMAP.)
>
> Quy ước: ADR-001 là quyết định đầu tiên. Khi thêm mới, lấy số tiếp theo. Không
> sửa nội dung ADR đã ghi — thêm ADR mới nếu quyết định bị đảo.

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
- **Hệ quả:** FSRS, `cards`, `review_logs` không bị đụng — "nhận ra khi đọc" không đổi lịch (khớp Retention của vision). Chuyển collection giữ lịch sử (khoá theo vocab), xoá vocab thì cascade. `EncounterRepository.insertSeen` không tự mở transaction (`inTransaction` không lồng) — T2 phải gọi trong transaction lưu trang. Số `seen` sẽ cộng vào khoá thứ (2) của `newCardIDs` ở T3 (ADR-047). Không import lại `encounters` từ backup (FR-16 vẫn không nhập JSON). T1 (dữ liệu) xong; T2 (màn đọc) và T3 (thang tiến độ) theo `docs/plans/reencounter-r1.md`.

---

## ADR-049 — Bỏ proxy Reado, FR-02 chỉ còn BYOK — đảo phần proxy của ADR-028/Q-03 (remove-proxy-r1)

- **Ngày:** 2026-10-01
- **Bối cảnh:** Owner thấy proxy không còn cần: `proxy.reado.app` chưa bao giờ deploy (ADR-041 đã ghi "agent mặc định luôn lỗi"), và từ ADR-034 app đã OCR trên máy rồi gọi agent **text** (BYOK OpenAI-compat) — `proxy/` (Python, gửi multipart ảnh) và `ReadoProxyClient` thành code chết, chỉ còn gây hiểu nhầm kiến trúc. R1 vẫn một user (NG-05), không có nhu cầu giấu key sản phẩm cho nhiều người dùng.
- **Quyết định:** Xoá `proxy/` và `ReadoProxyClient.swift`. FR-02 chỉ còn đi qua agent BYOK (`openai_compat`) user tự thêm. Hàng seed `analysis_agents` (`kind = 'reado_proxy'`, id cố định) **không xoá** — đổi nghĩa thành placeholder "chưa chọn agent": `AnalysisAgentStore.list()` lọc khỏi danh sách hiển thị, `AnalyzerFactory` trả `NoAgentAnalyzer` ném lỗi rõ ("Chưa có agent phân tích — thêm agent trong Cài đặt") nếu lọt vào `analyze()`. Không migration — `settings.active_agent_id` vẫn NOT NULL + khoá ngoại, CHECK cột `kind` vẫn nhận literal `'reado_proxy'` (đổi value này mới cần migration, không đáng cho một cách gọi tên).
- **Lý do:** Rebuild bảng `settings` để bỏ NOT NULL chỉ để xoá một hàng seed là rủi ro không cần — đổi nghĩa tại tầng Swift (list lọc, factory báo lỗi) đạt cùng mục đích (ẩn khỏi UI, không gọi mạng chết) mà không đụng DDL hay dữ liệu máy fen đang có.
- **Hệ quả:** `AnalysisAgent.isBuiltinProxy` → `isPlaceholder`; `Seeder.readoProxyAgentID/-Name` → `placeholderAgentID/-Name`; `StoreError.cannotDeleteProxy` → `cannotDeletePlaceholder`. `SettingsView` bỏ hẳn nhánh hiển thị "Proxy Reado" (list đã lọc, không còn ca này). `AppModel.activeAgentReady` suy trực tiếp từ `hasKey` (không cần loại trừ builtin nữa). NFR-07 chỉ còn vế key user ở Keychain — vế "key sản phẩm ở `.env` proxy" là bia mộ. `CLAUDE.md`, `prd.md` (Q-03, FR-21, NFR-07), `solution-design.md`, `db.md`, `tech-stack.md`, `journeys.md` ghi chú trỏ ADR này tại các đoạn nhắc proxy cũ — không xoá bia mộ. Test: xoá 4 test `ReadoProxyClientTests`, sửa `AnalyzerFactoryTests` theo hành vi mới — 351/353 xanh (từ 355/357, giữ 2 skip cũ).
