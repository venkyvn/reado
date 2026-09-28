# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (cập nhật 2026-09-28, cram-collection-r1 Phiên B — header collection)

- **Git:** `git log -1 --oneline` là HEAD thật — "HEAD xem git". Hash trong journal cũ có thể không resolve sau reword.
- **OCR (ADR-042, 2026-09-28):** iOS 26+ dùng `RecognizeDocumentsRequest` (đoạn có sẵn từ Vision, `PageOCR.joinParagraphs`), lỗi/rỗng rơi về legacy `VNRecognizeTextRequest` + ngắt đoạn hình học ADR-037 (chỉ còn chạy trên iOS 17–25). `Prompt.version` giữ 5. `ImageCompressor` áp `scale = 1` → FR-01 (≤1600px) thật (trước ra ~4800px). `ocr.json`/`diag_summary.py` ghi `engine`. Probe simulator: ảnh không crop legacy thiếu 11 câu → documents 2 (nhiễu 1 ký tự); đủ 8 đoạn khớp Live Text. Bundle điều tra + số đo: `docs/investigations/ocr-line-drop/` (README §11). **Đã kiểm trên máy thật 2026-09-28 (iPhone Air):** `engine=documents`, đủ 8 đoạn, không `gap` giả; ảnh không crop kéo theo chrome trình duyệt vào OCR nhưng 12 từ vựng đều từ thân bài (điều tra `ocr-line-drop` đóng, README §12). `sameLine` legacy vẫn gộp nhầm hàng ở ảnh không crop (nợ biết trước, chỉ ảnh hưởng iOS 17–25). `captures/*/page.jpg` đã xoá (bản quyền).
- **Tooling (ADR-035):** Chỉ dùng Claude Code. Build/test **chỉ** qua `scripts/test.sh`; lane nhanh `scripts/test.sh kit` = ReadoKit trên macOS (~10s, không simulator, log `/tmp/build-kit.log`). Hooks `.claude/hooks/` (`guard.py`, `session-context.sh`). Log chẩn đoán DEBUG (ADR-037): `scripts/pull_diagnostics.sh [sim|device]` + `scripts/diag_summary.py <dir>`. Bẫy: sau khi test xong xcodebuild có thể treo ở `simctl diagnose` → kill khi đã pass.
- **Repo (repo-hygiene-r1 xong: Phase A ADR-044, Phase B ADR-046, 2026-09-28):** entry point duy nhất = `CLAUDE.md`; `docs/archive/`, `AGENTS.md`, `PROJECT.md`, `qr/`, script Node Phase 0 đã xoá; ảnh `ref/sample/*.png|jpg|jpeg` không còn track (bản quyền; còn trong history cũ). **pbxproj = synchronized folders** (objectVersion 70): thêm/xoá/`git mv` file Swift chỉ cần làm trong `app/Reado/**` hoặc `app/ReadoTests/**`; `pbxproj_tool.py` chỉ còn `check`/`list`; file nằm trong thư mục là được compile kể cả chưa track git. `app/Reado` chia `App/ Home/ Capture/ Analysis/ Review/ Library/ Settings/ Shared/` (cây ở `docs/agent/coding-conventions.md` §2); `RootView`/`AnalysisView`/`ReviewQueueView` đã tách, mỗi file ≤ ~400 dòng (`+Card`/`+Grade` là extension nên một số `@State`/method internal thay vì `private`). Hoãn tới khi vướng: B4 tách `AppModel` (815 dòng), B5 chuyển test logic thuần sang `ReadoKitTests`. Plan: `docs/plans/repo-hygiene-r1.md`.
- **Cram + header collection (ADR-043, 2026-09-28, `cram-collection-r1` Phiên A+B ✅):** hết thẻ đến hạn → màn Ôn hiện "Ôn thêm N thẻ" (thẻ đã học chưa due, sắp due trước, ≤20/lượt); chấm = log `mode='cram'`, không đổi `cards`, không leech, không ăn hạn mức new (`ReviewQueue.cramCardIDs`, `ReviewService.recordCram`/`undoCram`, `AppModel.loadCramQueue`/`gradeCram`). **Phiên B:** header `CollectionDetailView` = `CollectionStatsHeader` (`app/Reado/Library/`): thẻ tiến độ + thanh 4 màu theo từ, 3 ô số (Đến hạn / +N từ 7 ngày / Lần ôn tiếp), CTA theo ngữ cảnh ("Ôn bộ này · N đến hạn" › "Ôn thêm N thẻ" › gợi ý chụp). ReadoKit: `CollectionSummary` +5 field (cùng query), `VocabRepository.nextDue`, `ReviewQueue.currentDayWindow`; `ReviewQueueView(initialMode:)` mở thẳng Cram. **UI Cram + header chưa xem tay trên simulator**; chưa có nút Cram ở `SessionDoneView`. Plan: `docs/plans/cram-collection-r1.md`.
- **Test gần nhất đã ghi:** **267/269** trên iPhone 18 Pro (2 skip = `LiveAIBoxTests` + `OCRProbeTests`, opt-in theo env), `** TEST SUCCEEDED **`, 2026-09-28 (+4 test summary/nextDue trong `VocabularyListTests`). Không build iOS được thì không ghi "xong".
- **Cổng chưa code:** 3.8 FR-10 (Q đã chốt, chờ dữ liệu thật) · proxy chưa deploy · 3.13 đo NFR · "Từ session collect thêm" · camera permission-denied chưa test máy. (`motivation-r1` T1/T2/T3 và `ux-polish-r1` T1–T5 đã xong + khép — UI chưa xem tay trên simulator.)
- **Leech:** owner chốt 2026-09-24 = 6 lần Again. Không gộp với Q-08.

## 2. Chờ owner (không tự bắt đầu)

1. Dán prompt baseline thủ công cho A-02 (`docs/agent/agent-rulebook.md` mục 8) — vẫn trống, chặn A-02/0.8.
2. Ngưỡng leech FR-19 đã chốt = 6 (2026-09-24). Không hỏi lại.
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4).
4. Camera (ADR-036) permission-denied: fen test khi tiện — từ chối quyền camera có bật đúng nút "Mở Cài đặt" không. Không chặn, happy case đã xong.
5. repo-hygiene-r1: repo `venkyvn/reado` public hay private? (ảnh `ref/sample` còn trong history cũ → public thì cần `git filter-repo`); key Gemini từng nằm trong `.env.example` (chưa commit) — rotate nếu dán ở nơi khác; `docs/sample.md` (untracked, không rõ chủ) và `.keep.json` (`{}`) — giữ hay xoá.

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
