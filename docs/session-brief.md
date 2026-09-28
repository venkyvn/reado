# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (cập nhật 2026-09-28, OCR đổi sang `RecognizeDocumentsRequest` — ADR-042, ocr-line-drop)

- **Git:** `git log -1 --oneline` là HEAD thật — "HEAD xem git". Hash trong journal cũ có thể không resolve sau reword.
- **OCR (ADR-042, 2026-09-28):** iOS 26+ dùng `RecognizeDocumentsRequest` (đoạn có sẵn từ Vision, `PageOCR.joinParagraphs`), lỗi/rỗng rơi về legacy `VNRecognizeTextRequest` + ngắt đoạn hình học ADR-037 (chỉ còn chạy trên iOS 17–25). `Prompt.version` giữ 5. `ImageCompressor` áp `scale = 1` → FR-01 (≤1600px) thật (trước ra ~4800px). `ocr.json`/`diag_summary.py` ghi `engine`. Probe simulator: ảnh không crop legacy thiếu 11 câu → documents 2 (nhiễu 1 ký tự); đủ 8 đoạn khớp Live Text. Bundle điều tra + số đo: `docs/investigations/ocr-line-drop/` (README §11). **Chưa kiểm trên máy thật:** iPhone từng ra 26 observation vs simulator 30 trên cùng ảnh (chưa giải thích) — cần chụp lại rồi `diag_summary` phải in `engine=documents`. `sameLine` legacy vẫn gộp nhầm hàng ở ảnh không crop (nợ biết trước, chỉ ảnh hưởng iOS 17–25). `captures/*/page.jpg` là ảnh sách có bản quyền — xoá khi đóng điều tra.
- **Tooling (ADR-035):** Chỉ dùng Claude Code. Build/test **chỉ** qua `scripts/test.sh`. Hooks `.claude/hooks/` (`guard.py`, `session-context.sh`). Log chẩn đoán DEBUG (ADR-037): `scripts/pull_diagnostics.sh [sim|device]` + `scripts/diag_summary.py <dir>`. Bẫy: sau khi test xong xcodebuild có thể treo ở `simctl diagnose` → kill khi đã pass.
- **Analysis / AI-Box:** agent mặc định `proxy.reado.app` **chưa deploy** nên luôn lỗi tới khi user thêm agent BYOK (mẫu AI-Box: `deepseek-v4.1-flash`, `enable_thinking: false` + `stream: true`, ~15–18s). `AnalysisProgress` hiện khi đang gọi; lỗi agent → nút "Mở Cài đặt". Test mạng thật opt-in: `LiveAIBoxTests` (`READO_LIVE_AIBOX_KEY`); seed dev simulator: `scripts/sim_aibox.sh`.
- **Capture (ADR-036):** camera AVFoundation tự vẽ (`CameraController`, `CaptureView`), thư viện qua `PhotosPicker`, crop full màn. Happy case xác nhận trên máy thật 2026-09-26.
- **IA / UX:** 3 tab (Home / Ôn / Kho) qua `ShellTabBar`; onboarding checklist 3 bước trên Home (ADR-041); ăn mừng tiến bộ đo được (`SessionTally`/`SessionDoneView`, ADR-038); "Học thêm 10 từ" (ADR-039); TTS on-device (ADR-040). Ôn tập vuốt Tinder hai mặt (ADR-033), trái=Again / phải=Good (ADR-025).
- **Test gần nhất đã ghi:** **256/258** trên iPhone 18 Pro (2 skip = `LiveAIBoxTests` + `OCRProbeTests`, opt-in theo env), `** TEST SUCCEEDED **`, 2026-09-28. Không build iOS được thì không ghi "xong".
- **Cổng chưa code:** 3.8 FR-10 (Q đã chốt, chờ dữ liệu thật) · proxy chưa deploy · 3.13 đo NFR · cram FR-18 (R2) · "Từ session collect thêm" · camera permission-denied chưa test máy · T2/T3 motivation-r1 theo `docs/plans/motivation-r1.md`.
- **Leech:** owner chốt 2026-09-24 = 6 lần Again. Không gộp với Q-08.

## 2. Chờ owner (không tự bắt đầu)

1. Dán prompt baseline thủ công cho A-02 (`docs/agent/agent-rulebook.md` mục 8) — vẫn trống, chặn A-02/0.8.
2. Ngưỡng leech FR-19 đã chốt = 6 (2026-09-24). Không hỏi lại.
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4).
4. Camera (ADR-036) permission-denied: fen test khi tiện — từ chối quyền camera có bật đúng nút "Mở Cài đặt" không. Không chặn, happy case đã xong.
5. OCR ADR-042: fen build Xcode Run lên iPhone (bundle `com.readoluca.app`), chụp lại trang "Economist Bhashkar Mazumder" (crop và không crop) → `scripts/pull_diagnostics.sh device` + `scripts/diag_summary.py <dir>`, gửi bản tóm tắt: phải thấy `engine=documents`, đủ đoạn, không `gap` giả. Nếu máy thật vẫn thiếu hàng → mở điều tra riêng (decode EXIF / ANE). Xong thì xoá `docs/investigations/ocr-line-drop/captures/*/page.jpg` (bản quyền).

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
