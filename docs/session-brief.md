# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (mục lục — chi tiết ở journal/plan, không lặp lại ở đây)

> Số test chính thức: hook `session-context.sh` tự nạp `.tmp/results/{last,kit}-summary.txt` — không ghi tay.

**Đang mở / hàng đợi**
- reencounter-r1 (T1 ✅ T2 ✅ T3 ✅-tạm, ADR-048) — FR-22 gặp lại từ cũ khi đọc. → `docs/plans/reencounter-r1.md`

**Đã khép gần đây** (một dòng mỗi task; chi tiết ở journal ngày tương ứng)
- 2026-10-02 → `docs/journal/2026-10-02.md`: ux-redesign-r1 (ADR-052/053/054, shell 2 tab, `journeys.md` Phần 1 viết lại) · prompt-v6 (prompt v6 + `phrases` chạm-sáng + preselect 5; fen chấp nhận bảng eval) · fsrs-queue-fix-r1 T3 (elapsed_days một định nghĩa — lib tự ghi đè, bỏ `CardSnapshot.dayDiff`) · q13-sense-filter-r1 (ADR-056, gập thay vì xoá — T1 kit + T2 UI "Đã thuộc · N"/fixture/ảnh, khép plan) · verify-nav-r1 T3 (fen xem tay toàn bộ §2.7 trên simulator thật — Ôn thêm/Alert lỗi/Reencounter/Capture/Settings/prompt-v6/migration/camera + nhóm "Đã thuộc · N" đều pass, khép plan). → `docs/plans/done/q13-sense-filter-r1.md`, `docs/plans/done/verify-nav-r1.md`
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

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
