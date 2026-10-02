# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (mục lục — chi tiết ở journal/plan, không lặp lại ở đây)

> Số test chính thức = số gộp scheme `Reado` — hook `session-context.sh` tự nạp kết quả gần nhất (`.tmp/results/last-summary.txt`/`kit-summary.txt`) vào đầu session, không ghi tay ở đây nữa. **Chưa xem tay UI** trên nhiều màn — §2.7 giờ mở được phần lớn bằng `scripts/sim_screens.sh open <màn>` (verify-nav-r1 T1+T2), còn chạy qua từng mục + đọc ảnh thật (T3) chưa làm.

- ux-redesign-r1 (2026-10-02, ✅ KHÉP, ADR-052/053/054) — shell 2 tab Hôm nay/Thư viện + nút chụp trong thanh,
  Ôn là phiên toàn màn, banner thay alert sau Lưu, đổi đích ở màn duyệt, pin ≤5. T0+T10 code + xem tay (chi tiết
  3 bug đã sửa → `docs/journal/2026-10-02.md`); T11 viết lại `docs/specs/journeys.md` Phần 1 theo IA mới, bỏ
  Phần 2 (DB schema PWA cũ, trỏ `db.md`), ghi 3 ADR. → `docs/plans/done/ux-redesign-r1.md`
- fix-alert-sheet-dismiss-r1 (2026-10-01, ✅ KHÉP) — bug §2 mục 8 cũ: `RootView` + sheet con cùng gắn `.appErrorAlert()` trên chung `alertMessage`, set lỗi lúc sheet mở huỷ cả sheet lẫn alert. Sửa bằng `AlertHostStack` (ReadoKit, logic thuần, 5 test) — chỉ layer mount sau cùng mới present `.alert()`; bỏ workaround debug-only trong `RootView.swift`. Verify bằng ảnh `scripts/sim_screens.sh open analysis-fixture --alert dup-name`: sheet "Duyệt & lưu từ vựng" + alert "Có lỗi" cùng hiện. → `docs/plans/done/fix-alert-sheet-dismiss-r1.md`
- verify-nav-r1 (2026-10-01, T1 ✅ T2 ✅, T3 chưa làm) — launch argument DEBUG (`-ReadoScreen`/`-ReadoTheme`/`-ReadoSeed`/`-ReadoAlert`) + `sim_screens.sh open` để agent mở thẳng một màn (kể cả seed lịch ôn giả, fixture phân tích) và chụp không cần chạm tay. T2 lộ bug alert+sheet có sẵn — §2 mục 8. → `docs/plans/verify-nav-r1.md`
- master-rewrite-r1 (2026-10-01, ✅, ADR-051) — MASTER.md viết lại thành luật SwiftUI (trước là output web của ui-ux-pro-max, lệch code); skill `reado-ui`; `/raudit` kiểm token MASTER. → `docs/journal/2026-10-01.md`
- extra-review-r1 (2026-10-01, ✅ KHÉP, ADR-050) — gộp Cram + "Học thêm" thành "Ôn thêm" 20 thẻ ghi lịch FSRS thật, LIFO thật cho thẻ mới, heatmap theo phân vị. → `docs/journal/2026-10-01.md`
- remove-proxy-r1 (2026-10-01, ✅ KHÉP, ADR-049) — xoá proxy Reado, FR-02 chỉ còn BYOK. → `docs/journal/2026-10-01.md`
- refactor-r4 (2026-10-01, ✅ KHÉP) — tách `CaptureView`, B5 chuyển test sang `ReadoKitTests`, tách `AnalysisTests.swift`. → `docs/plans/done/refactor-r4.md`
- refactor-r2 + refactor-r3 (2026-10-01, ✅) — `AppModel.clock`, facade DB cho Settings/Export, đọc cột theo tên (`SQLRow`), chia state `AppModel` 4 nhóm, dọn `try?` nuốt lỗi thật. → `docs/journal/2026-10-01.md`
- Audit nhỏ sau refactor-r4 (2026-10-01, ✅) — gộp SQL rời vào `VocabRepository.defaultCollectionID`. → `docs/journal/2026-10-01.md`
- fsrs-queue-fix-r1 (T1 ✅ T2 ✅, **T3 hết chặn — chưa làm**) — queue so `due_at` với cửa sổ ngày học, `GradePreview` tái dùng nhãn trong 30'. → `docs/plans/fsrs-queue-fix-r1.md`
- reencounter-r1 (T1 ✅ T2 ✅ T3 ✅-tạm, 2026-10-01, ADR-048) — FR-22 gặp lại từ cũ khi đọc, thang Mới/Đang học/Đã nhớ/Đã thấm. → `docs/plans/reencounter-r1.md`
- new-order-r1 (2026-09-30, ✅ KHÉP, ADR-047) — thẻ mới ưu tiên bộ vừa thêm (LIFO trong bộ đảo tiếp ở extra-review-r1). → `docs/journal/2026-09-30.md`
- vision-refresh-r2 (2026-09-30, ✅, docs-only) — `vision.md` chỉ giữ luật hiện hành, thang 4 mức Mới/Đang học/Đã nhớ/Đã thấm. → `docs/journal/2026-09-30.md`
- shell-chrome-r1 (2026-09-30, ✅ KHÉP) — ô nhập Settings, nút Ôn hết bị tab bar che, hết giật kéo thẻ, ẩn/hiện tab khi cuộn. → `docs/plans/done/shell-chrome-r1.md`
- repo-hygiene-r1 (2026-09-28, ✅ KHÉP Phase A+B, ADR-044/046) — pbxproj synchronized folders, chia `app/Reado` theo feature. → `docs/plans/done/repo-hygiene-r1.md`
- cram-collection-r1 (2026-09-28, ✅ KHÉP, ADR-043) — tiền thân Cram + header collection (cơ chế chấm đã thay bằng extra-review-r1). → `docs/journal/2026-09-28.md`
- OCR (2026-09-28, ✅, ADR-042) — `RecognizeDocumentsRequest` iOS 26+, nén ảnh 1600px thật, đã kiểm trên máy thật. → `docs/investigations/ocr-line-drop/`
- prompt-v6 (2026-10-02, **T1 ✅**, T2/T3 chưa làm) — `scripts/prompt_eval.py` + `scripts/prompts/v5.txt`
  (template rút từ `Prompt.swift` v5), chạy thật trên `.tmp/diagnostics/` có sẵn — model
  `deepseek-v4.1-flash` trả 503 model_not_found (đáng chú ý cho T2, không phải lỗi script). → `docs/plans/prompt-v6.md`

## 2. Chờ owner (không tự bắt đầu)

1. A-02: prompt baseline **đã có** ở `docs/agent/prompt-spec.md` §2 (owner dán 2026-09-08; dòng "vẫn trống" cũ ở đây sai). Còn thiếu: fen chấm output baseline vs app — `prompt-v6` T1 xong công cụ dựng bảng so (`scripts/prompt_eval.py`), T2 sẽ chạy v5 vs v6 thật.
2. Ngưỡng leech FR-19 đã chốt = 6 (2026-09-24). Không hỏi lại.
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4).
4. Camera (ADR-036) permission-denied: fen test khi tiện — từ chối quyền camera có bật đúng nút "Mở Cài đặt" không. Không chặn, happy case đã xong.
5. ~~D-3~~ — **đã trả lời 2026-10-01 (ADR-050, extra-review-r1):** có, Cram (giờ gọi "Ôn thêm") cập nhật lịch hẹn mới như ôn thường. T3 của `fsrs-queue-fix-r1.md` (elapsed_days một định nghĩa) hết bị chặn — kiểm lại khi mở plan đó tiếp.
6. repo-hygiene-r1: repo `venkyvn/reado` public hay private? (ảnh `ref/sample` còn trong history cũ → public thì cần `git filter-repo`); key Gemini từng nằm trong `.env.example` (chưa commit) — rotate nếu dán ở nơi khác; `docs/sample.md` (untracked, không rõ chủ) và `.keep.json` (`{}`) — giữ hay xoá.
7. Xem tay UI còn treo (máy agent không có Simulator GUI) — gộp theo màn, không theo task:
   - **Ôn thêm** (extra-review-r1): trộn đúng cũ+mới, Quên → due mai, lượt 2 không ra thẻ cũ, CTA Home mở đúng `.extra`, heatmap đổi màu rõ khi ôn nhiều.
   - **Alert lỗi** (refactor-r3): tạo/đổi tên bộ trùng, xoá/chuyển, ghim >5 — đã xem bằng `-ReadoAlert dup-name|pin-limit` lúc KHÔNG có sheet, alert hiện đúng. "alert phải hiện cả trong sheet" **từng THẤY BUG, đã sửa 2026-10-01** — ~~mục 8~~ dưới.
   - **Reencounter** (reencounter-r1 T2/T3): gạch chân + "Nhận ra", hàng Home "Gặp lại N từ" (nghi N=0 — kiểm `SELECT kind, created_at FROM encounters`), thanh 4 màu/`MasteryRing`.
   - **Capture** (refactor-r4 T1): chip "Lưu vào", sheet chọn/tạo bộ.
   - **Settings** (remove-proxy-r1): ẩn agent builtin, lỗi "chưa có agent" khi chụp lúc chưa thêm key.
   - (c) migration v3→v4 trên DB thật (cài đè bản cũ) — chưa làm.
   - Việc kế tiếp sau khi xem xong: `prompt-v6` — một session riêng.
8. ~~Bug alert+sheet~~ — **đã sửa 2026-10-01**, `AlertHostStack` (chỉ layer mount sau cùng present `.alert()`). → `docs/plans/done/fix-alert-sheet-dismiss-r1.md`
9. ~~Accent lệch~~ — **đã sửa 2026-10-02 (ux-redesign-r1 T10)**, đọc `AppTheme` từ `@AppStorage` thay vì environment cho view tự vẽ. → `docs/journal/2026-10-02.md`

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
