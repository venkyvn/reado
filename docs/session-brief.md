# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (cập nhật 2026-09-26)

- **Git:** `git log -1 --oneline` là HEAD thật — "HEAD xem git" (tooling: dọn agent chỉ Claude Code ADR-035 + hooks/`scripts/test.sh` boot simulator + pbxproj check). Hash trong journal từ T2 trở về có thể không resolve sau reword — đừng checkout hash cũ.
- **Tooling (ADR-035, 2026-09-26):** Chỉ dùng Claude Code — bỏ DSH/Cursor. Protocol còn giá trị gộp vào `CLAUDE.md` §7 (workflow, đọc file lớn, pbxproj, bẫy build); `AGENTS.md` chỉ còn stub. Build/test **chỉ** qua `scripts/test.sh` (tự boot simulator, chạy `pbxproj_tool.py check` trước build, ghi `.tmp/results/last.xcresult`, in dòng `RESULT:`). Hooks mới `.claude/hooks/`: `guard.py` (PreToolUse) chặn edit tay `project.pbxproj`/`swift build`/`xcodebuild` trần; `session-context.sh` (SessionStart) tự nạp HEAD + git status + brief §1–2. Chi tiết: `docs/journal/2026-09-26.md`.
- **Analysis:** OCR trên máy trước mỗi lần gọi agent (ADR-034): `PageOCR` (Vision, ghép dòng theo bbox + tách 2 cột khi khe X rõ); `OpenAICompatClient` gửi **chỉ text** (bỏ `image_url`) → `Prompt` v4 (`PAGE_OCR`, `PROMPT_VERSION` 4); OCR trống/không đọc được → `AnalysisError.imageUnreadable` (FR-04), không gửi JPEG. `reado_proxy` không đổi (vẫn multipart ảnh). Key agent ở Keychain (không vào SQLite/export), `AgentURLRule` khóa miền origin. `MockAnalyzer` chỉ còn cho kind lạ/agent thiếu url/model.
- **IA hiện tại:** 3 tab (Home / Ôn / Kho) qua capsule `ShellTabBar` 64pt thay native tab bar; Cài đặt + Dữ liệu sheet → push. Copy UI gỡ `FR-*`, `collection` → bộ, nhãn **Kho tạm**, hint `trái Quên · phải Được`. Pin Home tối đa 5, CEFR nhiều level, migration v3.
- **Ôn tập:** vuốt Tinder trên **cả hai mặt thẻ** (ADR-033) — thẻ bám tay + tilt + stamp "Quên"/"Được" + fly-off; mapping ADR-025 giữ (trái=Again / phải=Good).
- **Test gần nhất đã ghi:** **204/204** trên iPhone 18 Pro — tooling ADR-035 (dọn agent + hooks + `scripts/test.sh` v2), `RESULT: Passed — passed 204/204, failed 0, skipped 0`, `** TEST SUCCEEDED **`. Máy không build iOS thì không chạy lại, và không ghi "xong" khi thiếu `** TEST SUCCEEDED **`.
- **Cổng chưa code:** 3.8 FR-10 (Q đã chốt, chờ dữ liệu thật) · proxy 0.7 chưa deploy (adapter FR-21 đã code + test xanh, chờ deploy proxy) · 3.13 đo NFR · cram FR-18 (R2) · "Từ session collect thêm" (chưa chọn: thêm `session_id` / để R2 / bỏ bước).
- **Leech:** owner chốt 2026-09-24 = 6 lần Again. Không gộp với Q-08.

## 2. Chờ owner (không tự bắt đầu)

1. Dán prompt baseline thủ công cho A-02 (`docs/agent/agent-rulebook.md` mục 8) — vẫn trống, chặn A-02/0.8.
2. Ngưỡng leech FR-19 đã chốt = 6 (2026-09-24). Không hỏi lại.
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4).

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- (trống)

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
