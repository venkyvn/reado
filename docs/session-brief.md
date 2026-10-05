# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (mục lục — chi tiết ở journal/plan, không lặp lại ở đây)

> Số test chính thức: hook `session-context.sh` tự nạp `.tmp/results/{last,kit}-summary.txt` — không ghi tay.

**Đang mở / hàng đợi**
- vocab-identity-r1 (ADR-066, `docs/plans/vocab-identity-r1.md`): đảo Q-09 cho FR-10
  (so khớp "đã có trong kho" **toàn app**, không còn theo collection) + ngân sách chọn
  sẵn mỗi ngày (FR-09) + `encounters` ghi câu/nguồn (FR-22). D1-D4 fen đã chốt
  2026-10-05 (D4 = không làm spike PDF). **T0 xong** (docs + ADR-066, không code) —
  `prd.md` v0.16, `db.md`, `journeys.md`, `vocabulary.md` §6.3, `CLAUDE.md` §5 đồng bộ.
  **Nợ của T0:** baseline đo trước/sau (3 query SQL ở plan mục T0) cần dữ liệu thật —
  chờ fen export JSON (FR-16) hoặc tự chạy query rồi báo 3 con số.
  **T1 xong** (2026-10-05): `VocabRepository.newSavedToday` + `drafts(preselectBudget:)`, suất
  chọn sẵn = `min(5, daily_new_limit − đã lưu hôm nay)`, dòng "Hôm nay đã đủ N từ mới" khi hết.
  Nợ xem tay: đặt "Từ mới mỗi ngày" = 1, phân tích 2 trang → trang 2 thấy dòng đó (ảnh tĩnh
  không dựng được ca budget = 0). Plan đã chi tiết hoá T1–T4. **T2 xong**: migration v7 (`encounters.sentence` + `collection_id`), `EncounterMatcher.contexts`
  (NLTokenizer, cắt câu dài ±120 ký tự), `saveCapture` ghi câu + bộ vào `seen`, export thêm 2 field.
  Chưa có UI (hiện ở T4). **T3 xong**: `VocabRepository.knownSenses` (toàn app, mọi trạng thái) + nhóm "Đã có trong kho",
  nút đáy "Ghi gặp lại N từ" (context-only, không tạo thẻ), bỏ regroup theo đích. Đo N6 ở 3000 từ:
  `knownSenses` ~14ms, `saveCapture` ~82ms — chưa cần cache. **Nợ xem tay**: bỏ chọn hết → "Ghi gặp lại"
  → banner; lưu trang PDF có từ cũ rồi chạy query T0 (khoá trùng không tăng); nhóm ở Dynamic Type
  lớn + accent Nâu giấy. Task tiếp: **T4** (hiện ngữ cảnh ở popover + mặt sau thẻ).
- pdf-reader-r1 (FR-23, ADR-058, branch `pdf-reader-r1`): T0–T4 xong, chỉ còn
  **T5 eval prompt PDF trên PDF thật**. 2026-10-05: fen đưa PDF thật (dùng chung với
  ocr-quality-r1 T1) — `PDFPageTextProbeTests.swift` (mới, opt-in lane `kit`, xem
  `docs/journal/2026-10-05.md`) xác nhận `PDFPageText.extract()` chạy tốt trên PDF
  này (10/12 trang mẫu dùng được, không lỗi tách khoảng trắng). Còn thiếu để làm T5
  đầy đủ: `prompt_eval.py --swift-func` (chưa viết) + chạy eval thật + chỉnh ngưỡng.
  Nợ xem tay T3/T4 (DebugLaunch không giả lập chạm được) — chi tiết
  `docs/plans/pdf-reader-r1.md`.
**Đã khép gần đây** (một dòng mỗi task; chi tiết ở journal ngày tương ứng)
- 2026-10-05 → `docs/journal/2026-10-05.md`: ocr-quality-r1 (branch `ocr-quality-r1` từ `main`,
  ADR-064/065 — plan nháp `plan_ocr_quality_r1.md` gốc repo, chưa vào `docs/plans/`) — T0 OCR-fix
  mặc định TẮT · T4 nhãn "kiểm tra lại" · T1 rút gọn (6 ảnh thật, thiếu nhóm PDF-scan/label — fen
  chốt bỏ qua) · T2 probe `liveText` (WER thấp hơn `documents` rõ rệt, không giữ `\n\n`) · T3a engine
  mặc định `liveText` ghép khung đoạn `documents`, xem tay máy thật xong · code review sau T3a sửa 4
  phát hiện thật (quan trọng nhất: `mergeParagraphBoundaries` làm tròn dồn sai số trên trang nhiều
  đoạn ngắn) · T7 gỡ hẳn nhánh OCR-fix bằng LLM sau khi fen tự thử thấy ổn (xoá
  `CorrectingTextRecognizer`/`FoundationModelsOCRCorrector`/`OCRFixApplier` + toggle Settings, tách
  riêng `TimeoutRunner` còn dùng). T5 fen chốt bỏ qua. `scripts/test.sh` 525/528 xanh (3 skip cũ).
- 2026-10-04 → `docs/journal/2026-10-04.md`: pdf-nav-r1 (ADR-059/060/061/062, gõ số
  trang + Mục lục + ẩn chrome khi đọc) → `docs/plans/done/pdf-nav-r1.md` · home-eevas-r1
  (header nút tròn, "Từ hay quên" FR-19, tìm từ FR-08) → `docs/plans/done/home-eevas-r1.md`.
- 2026-10-02 → `docs/journal/2026-10-02.md`: ux-redesign-r1 (ADR-052/053/054) ·
  prompt-v6 · q13-sense-filter-r1 (ADR-056) · verify-nav-r1 (xem tay toàn bộ §2.7) ·
  fr10-close-r1 · reencounter-r1 khép. → `docs/plans/done/{q13-sense-filter-r1,verify-nav-r1,reencounter-r1,fr10-close-r1}.md`
- 2026-10-01 trở về trước → xem `docs/journal/2026-10-01.md` và các file ngày trước đó.

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
11. pdf-nav-r1 (khép 2026-10-04): xem tay 3 chỗ cần chạm thật, DebugLaunch không giả
    lập được — (a) chạm vào trang để ẩn/hiện nav bar + thanh đáy (ADR-060), (b) vuốt
    ngang lật trang thật trên PDF dài (có bị cử chỉ "vuốt mép trái để back" của iOS
    giành không), (c) màn Cài đặt → Section "Đọc PDF" → chọn tông giấy (Picker) +
    kéo Slider độ đậm, xem reader áp đúng lúc mở lại (ADR-061/062) — đã xác nhận
    layout/màu của reader đúng qua ảnh + tiêm `UserDefaults` thẳng (không qua chạm
    Picker/Slider thật); CHƯA chụp được Section "Đọc PDF" ở Cài đặt (nằm dưới cuộn,
    không tự scroll được qua DebugLaunch). `docs/plans/done/pdf-nav-r1.md`.
12. ocr-quality-r1 T6 (gợi ý loại nguồn cho prompt — `sourceKind` 'page'/'screenshot'/
    'label', đổi `Prompt.version` 6→7): **D3 chưa chốt** — tự nhận qua metadata Photos
    (cần quyền thư viện ảnh), để người dùng tự chọn tay, hay để hẳn R2. Không làm cho
    tới khi D3 có câu trả lời. `plan_ocr_quality_r1.md` (gốc repo) mục D3/T6,
    `docs/journal/2026-10-05.md`.
13. vocab-identity-r1 T0: baseline trước/sau cần dữ liệu thật trên máy fen — 3 query SQL
    (khoá `term_normalized+pos` trùng, thẻ `new` tồn, từ mới/14 ngày) ở mục T0 của
    `docs/plans/vocab-identity-r1.md`. Agent không truy cập được DB thật trên máy fen —
    fen export JSON (Settings → Dữ liệu → Xuất dữ liệu, FR-16) đưa file, hoặc tự chạy
    3 query rồi báo 3 con số.

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
