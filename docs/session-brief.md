# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (cập nhật 2026-09-26, verify máy thật)

- **Git:** `git log -1 --oneline` là HEAD thật — "HEAD xem git" (capture: camera AVFoundation + PhotosPicker + crop full màn, ADR-036). 3 commit liền trong session này: shutter/agent-lag → AI-Box stream → camera rewrite. Hash trong journal từ T2 trở về có thể không resolve sau reword — đừng checkout hash cũ.
- **Tooling (ADR-035):** Chỉ dùng Claude Code. Build/test **chỉ** qua `scripts/test.sh`. Hooks `.claude/hooks/` (`guard.py`, `session-context.sh`). Chi tiết: `docs/journal/2026-09-26.md`.
- **Analysis / AI-Box (đo thật 2026-09-26):** `deepseek-v4.1-flash` không stream + không tắt suy nghĩ → byte đầu **63s** (quá idle-timeout cũ 60s → luôn timeout). `enable_thinking: false` (chỉ host `ai-box.vn`, `OpenAICompatClient.extraBodyParams`) + `stream: true` (SSE, fallback đọc JSON thường nếu server lờ stream) → byte đầu ~1s, tổng **15–18s** (đo lại qua `LiveAIBoxTests`: OCR thật + AI-Box thật = 24s, 15 từ, 2 đoạn). `AgentURLRule.storedBase` tự thêm `/v1` cho `api.ai-box.vn` thiếu path (thiếu `/v1` → server trả 301, không phải lỗi rõ). `AnalysisAgentStore` có preset `aiboxBaseURL`/`aiboxModel`; `AgentFormSheet` có Picker mẫu AI-Box/Gemini/Tuỳ chỉnh (mặc định AI-Box). `AnalysisProgress` (readingPage/waitingAgent/thinking/writing) hiện trong `AnalysisView` khi đang gọi. Lỗi agent → nút "Mở Cài đặt" (`AppModel.pendingSettingsNavigation`). `reado_proxy` vẫn multipart ảnh, không đổi; `proxy.reado.app` **chưa deploy** (không resolve DNS) nên agent mặc định luôn lỗi tới khi user tự thêm agent BYOK — thông điệp lỗi giờ gợi ý đúng việc đó. Test mạng thật opt-in: `ReadoTests/LiveAIBoxTests.swift` (`READO_LIVE_AIBOX_KEY`), seed dev trên simulator: `scripts/sim_aibox.sh` (đọc `.env`, không in key, cần biến `READO_DEV_AIBOX_KEY` lúc launch — chỉ hoạt động trong `#if DEBUG`).
- **Capture (ADR-036) — owner đã test máy thật 2026-09-26:** `UIImagePickerController` bị bỏ hẳn (nguyên nhân màn đen + mất nút thoát: `addChild(hosting)` đẩy overlay SwiftUI đè lên preview + nút hệ thống). `CameraController.swift` (mới) tự vẽ bằng AVFoundation, `CaptureView` viết lại toàn bộ với chrome SwiftUI thật (X/chip đích/+/thư viện/shutter/flash), thư viện qua `PhotosPicker`, crop hiện ngay trong `ZStack` (không `.sheet`) nên full màn. `RootView`/`StreakCalendarView` mở bằng `.fullScreenCover`. **Happy case đã xác nhận trên máy thật:** chụp → crop → gọi AI-Box thật → dịch → lưu từ, cả chuỗi thành công. **Còn chưa test:** từ chối quyền camera → có bật đúng nút "Mở Cài đặt" không (không chặn, việc phụ).
- **Shutter nổi:** vị trí đúng đo bằng screenshot — overlay đứng **trước** `.safeAreaInset(ShellTabBar)`, chỉ cộng khe `shutterGap`; bản đầu (trước session này) cộng trùng cả chiều cao tab bar nên nút chụp cao hẳn lên. Chọn agent trong Cài đặt cập nhật lạc quan (`AnalysisAgentStore.setActive(knownHasKey:)`), không còn khựng.
- **IA hiện tại:** 3 tab (Home / Ôn / Kho) qua capsule `ShellTabBar` 64pt; Cài đặt + Dữ liệu sheet → push. Pin Home tối đa 5, CEFR nhiều level, migration v3.
- **Ôn tập:** vuốt Tinder trên **cả hai mặt thẻ** (ADR-033); mapping ADR-025 giữ (trái=Again / phải=Good).
- **Test gần nhất đã ghi:** **211/212** trên iPhone 18 Pro (1 skip = `LiveAIBoxTests` không có key mạng thật), `** TEST SUCCEEDED **`. Chạy riêng có `READO_LIVE_AIBOX_KEY`: `LiveAIBoxTests` 1/1 (24s, OCR thật → AI-Box thật). Máy không build iOS thì không chạy lại, không ghi "xong" khi thiếu `** TEST SUCCEEDED **`.
- **Cổng chưa code:** 3.8 FR-10 (Q đã chốt, chờ dữ liệu thật) · proxy chưa deploy (agent AI-Box đã chạy được, không còn chặn walking skeleton) · 3.13 đo NFR · cram FR-18 (R2) · "Từ session collect thêm" (chưa chọn: thêm `session_id` / để R2 / bỏ bước) · camera ADR-036 permission-denied flow chưa test trên máy (happy case đã OK, xem trên).
- **Leech:** owner chốt 2026-09-24 = 6 lần Again. Không gộp với Q-08.

## 2. Chờ owner (không tự bắt đầu)

1. Dán prompt baseline thủ công cho A-02 (`docs/agent/agent-rulebook.md` mục 8) — vẫn trống, chặn A-02/0.8.
2. Ngưỡng leech FR-19 đã chốt = 6 (2026-09-24). Không hỏi lại.
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4).
4. Camera (ADR-036) permission-denied: fen test khi tiện — từ chối quyền camera có bật đúng nút "Mở Cài đặt" không. Không chặn, happy case đã xong.

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- (trống)

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
