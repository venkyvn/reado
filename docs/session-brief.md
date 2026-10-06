# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (mục lục — chi tiết ở plan/journal)

> Số test + `code:` hash: hook SessionStart nạp `.tmp/results/*-summary.txt` — không ghi tay.

- pdf-reader-r1 (FR-23, ADR-058): T0–T4 xong, còn T5 eval prompt trên PDF thật. `docs/plans/pdf-reader-r1.md`
- ocr-quality-r1: T0–T4 + T7 xong; T6 chờ OW-12. `docs/plans/ocr-quality-r1.md`
- Nợ xem tay: `docs/qa/pending.md` (ID `QA-NN`). Chờ fen quyết/đưa dữ liệu: §2 (ID `OW-NN`).
- Khép gần đây: workflow-docs-r1 (10-06) · engagement-r1, vocab-identity-r1 (10-05) · pdf-nav-r1, home-eevas-r1 (10-04) · structure-review-r1, visual-polish-r1, apple-ai-r1 (10-06). Cũ hơn: `docs/journal/`.

## 2. Chờ owner (không tự bắt đầu)

- **OW-01** nguồn OCR bộ `.tmp/diagnostics/20260928T112557Z` chưa tốt: muốn chấm prompt chặt hơn thì fen đưa data OCR sạch (hoặc `pull_diagnostics.sh` lượt mới).
- **OW-03** "Từ session này collect thêm" (J2 bước 7, `ROADMAP.md` §4): (a) thêm FK `session_id` · (b) để R2 · (c) bỏ bước khỏi J2.
- **OW-06** repo-hygiene-r1: `venkyvn/reado` public hay private (ảnh `ref/sample` còn trong history → public cần `git filter-repo`)? Key Gemini từng ở `.env.example`: rotate nếu dán nơi khác. `docs/sample.md`, `.keep.json`: giữ hay xoá?
- **OW-10** pdf-reader-r1 T5: fen đưa 3–5 trang PDF thật (1 cột có header/footer/gạch nối · 2 cột · scan không chữ · scan lớp chữ rác) rồi `scripts/pull_diagnostics.sh device <udid>`.
- **OW-12** ocr-quality-r1 T6 (`sourceKind`, `Prompt.version` 6→7), D3: tự nhận qua metadata Photos (cần quyền), người dùng tự chọn, hay để R2?
- **OW-13** vocab-identity-r1 T0: 3 query SQL baseline trên máy fen (export JSON FR-16 hoặc báo 3 số) — `docs/plans/done/vocab-identity-r1.md` T0.

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
