# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (mục lục — chi tiết ở journal/plan, không lặp lại ở đây)

> Số test chính thức: hook `session-context.sh` tự nạp `.tmp/results/{last,kit}-summary.txt` — không ghi tay.

**Đang mở / hàng đợi**
- pdf-reader-r1 (FR-23, ADR-058, branch `pdf-reader-r1`): T0–T4 xong (code + build +
  full test 464/466), chỉ còn **T5 eval prompt PDF trên PDF thật** (cần fen + file
  thật, xem dưới). T0 docs/ADR · T1 schema `pdf_sources` + `PDFSourceRepository` ·
  T2 `PDFPageText` (lớp chữ + chấm chất lượng) + `Prompt.pdfText` + `analyzeText` ·
  T3 `PDFReaderView` (đọc + nhớ trang) + gắn/đổi/gỡ PDF ở Hub + `DebugLaunch
  pdf-reader` · T4 CTA "Phân tích trang này" → `preparePDFAnalysis` → sheet Duyệt &
  lưu dùng chung lối ảnh, lỗi FR-04 đổi nút "Về trang đọc".
  **Nợ xem tay (DebugLaunch không giả lập chạm được):** T3 — lật trang bằng tay,
  "Đổi PDF…", "Gỡ PDF", xoá file ngoài → "Chọn lại file". T4 — cả vòng chạm CTA →
  phân tích → lưu → quay lại trang đọc (cần agent thật). Xem tay layout/style qua
  ảnh đã xong cho cả hai (bắt được 1 bug `.safeAreaInset` ở T3, đã sửa + ghi gotcha
  vào skill reado-ui). → `docs/plans/pdf-reader-r1.md`

**Đã khép gần đây** (một dòng mỗi task; chi tiết ở journal ngày tương ứng)
- 2026-10-04 → `docs/journal/2026-10-04.md`: home-eevas-r1 — học UI từ eevas.top theo yêu cầu fen, cả 4 task trong 1 session ("đủ context"): T1 header toolbar Home kiểu nút tròn (pill 🔥N · 🔍 · ⚙, `ToolbarSpacer`) + hero số to "N thẻ đến hạn" + 2 số phụ "Gặp lại tuần này"/"Đã nhớ" (ADR-057, bỏ `statsSection` cũ) · T2 màn duyệt thêm dòng "AI chọn sẵn N từ…" + báo trước số từ sau khi lưu (tự đổi theo đích ADR-053) · T3 màn "Từ hay quên" tối thiểu FR-19 (`LeechService.deleteWord`, banner Home, swipe đưa lại hàng đợi/xoá) · T4 tìm từ xuyên collection FR-08 (`VocabRepository.searchVocabulary`, gập dấu tầng Swift, màn `VocabSearchView`). 435/437 xanh (424→435, +11 test mới qua 4 task, 2 skip cũ không đổi). → `docs/plans/done/home-eevas-r1.md`
- 2026-10-02 → `docs/journal/2026-10-02.md`: ux-redesign-r1 (ADR-052/053/054, shell 2 tab, `journeys.md` Phần 1 viết lại) · prompt-v6 (prompt v6 + `phrases` chạm-sáng + preselect 5; fen chấp nhận bảng eval) · fsrs-queue-fix-r1 T3 (elapsed_days một định nghĩa — lib tự ghi đè, bỏ `CardSnapshot.dayDiff`) · q13-sense-filter-r1 (ADR-056, gập thay vì xoá — T1 kit + T2 UI "Đã thuộc · N"/fixture/ảnh, khép plan) · verify-nav-r1 T3 (fen xem tay toàn bộ §2.7 trên simulator thật — Ôn thêm/Alert lỗi/Reencounter/Capture/Settings/prompt-v6/migration/camera + nhóm "Đã thuộc · N" đều pass, khép plan) · fix nhỏ `save-banner` debug fixture thiếu `bannerHubID` (phát hiện lúc fen tự rà lại các ADR chốt nhanh) · reencounter-r1 khép hẳn (T3 hết nghi N=0, xác nhận qua verify-nav-r1 T3) · fr10-close-r1 (Task 3.8 khép — `ReviewDraftBuilder.regroup` tính lại nhóm "Đã thuộc" khi đổi đích trên màn duyệt, ADR-053/Q-09; 9 test mới, full 424/426 xanh; fen xem tay đổi đích trên simulator thật, pass). → `docs/plans/done/q13-sense-filter-r1.md`, `docs/plans/done/verify-nav-r1.md`, `docs/plans/done/reencounter-r1.md`, `docs/plans/done/fr10-close-r1.md`
- 2026-10-01 → `docs/journal/2026-10-01.md`: fix-alert-sheet-dismiss-r1 (`AlertHostStack`) · master-rewrite-r1 (ADR-051) · extra-review-r1 "Ôn thêm 20" (ADR-050) · remove-proxy-r1 BYOK-only (ADR-049) · refactor-r2/r3/r4 · audit nhỏ sau refactor-r4.
- 2026-09-30 → `docs/journal/2026-09-30.md`: new-order-r1 (ADR-047) · vision-refresh-r2 · shell-chrome-r1.
- 2026-09-28 → `docs/journal/2026-09-28.md`: repo-hygiene-r1 (ADR-044/046) · cram-collection-r1 (ADR-043) · OCR `RecognizeDocumentsRequest` (ADR-042).

## 2. Chờ owner (không tự bắt đầu)

> Số mục giữ cố định — plan/spec khác trỏ `§2.3`/`§2.4`/`§2.7`. Mục đã xong thu còn một dòng gạch.

1. ~~A-02~~ — fen chấp nhận bảng eval v5/v6 (2026-10-02). Nợ: nguồn OCR bộ diagnostics `.tmp/diagnostics/20260928T112557Z/` chưa tốt — muốn đánh giá prompt chặt hơn thì fen đưa data OCR sạch, hoặc `pull_diagnostics.sh` lượt chụp mới rồi `prompt_eval.py` lại.
2. ~~Ngưỡng leech FR-19~~ — đã chốt = 6 (`CLAUDE.md` §5).
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4): (a) thêm FK, (b) để R2, (c) bỏ bước khỏi J2.
4. ~~Camera (ADR-036) permission-denied~~ — fen test tay (2026-10-02): từ chối quyền camera bật đúng nút "Mở Cài đặt".
5. ~~D-3~~ — đã trả lời (ADR-050): "Ôn thêm" ghi lịch FSRS thật; fsrs-queue-fix-r1 T3 đã xong (2026-10-02).
6. repo-hygiene-r1: repo `venkyvn/reado` public hay private? (ảnh `ref/sample` còn trong history cũ → public thì cần `git filter-repo`); key Gemini từng nằm trong `.env.example` (chưa commit) — rotate nếu dán ở nơi khác; `docs/sample.md` (untracked) và `.keep.json` (`{}`) — giữ hay xoá.
7. ~~Xem tay UI còn treo~~ — fen xem tay trên simulator thật (2026-10-02, verify-nav-r1 T3): Ôn thêm, Alert lỗi, Reencounter, Capture, Settings, prompt-v6 (`ReadingSessionView` qua Hub), migration v3→v4 — tất cả pass. Chi tiết từng mục: `docs/plans/done/verify-nav-r1.md` T3, `docs/journal/2026-10-02.md`.
8. ~~fr10-close-r1: xem tay đổi đích~~ — fen test tay (2026-10-02): đổi "Lưu vào ⏷" sang bộ khác và về Kho tạm trên simulator thật, nhóm "Đã thuộc · N" tính lại đúng. `docs/plans/done/fr10-close-r1.md` T1 hết nợ.
9. home-eevas-r1: xem tay 2 chỗ chưa giả lập chạm được bằng ảnh tĩnh — T3 màn "Từ hay quên" (vuốt trái "Đưa lại hàng đợi", vuốt phải "Xoá" + `confirmationDialog`, `contextMenu`) và T4 gõ tìm kiếm thật (debounce, kết quả matching/order trên simulator/máy thật — logic đã test đủ ở ReadoKit). `docs/plans/done/home-eevas-r1.md`.
10. pdf-reader-r1: xem tay tương tác thật chưa làm được bằng DebugLaunch — T3 (lật
    trang bằng tay, "Đổi PDF…", "Gỡ PDF", xoá file ngoài Files → "Chọn lại file") và
    T4 (chạm CTA → phân tích thật → lưu → quay lại trang đọc, cần agent thật). T5
    (eval prompt PDF) cần fen đưa 3–5 trang từ PDF thật (1 cột có header/footer/gạch
    nối, 2 cột, scan không chữ, scan lớp chữ rác nếu có) rồi
    `scripts/pull_diagnostics.sh device`. `docs/plans/pdf-reader-r1.md`.

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
