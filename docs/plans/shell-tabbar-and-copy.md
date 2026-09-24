# Plan: shell-tabbar-and-copy

> ✅ Done 2026-09-24 — apply trên `e8b1933` (phần còn lại sau agent-json), 204/204 test xanh. Sửa 1 bug test `ctx`.

Base: `869902f` (`feat(v2): port máy kia — protocol agent + OpenAI-compat adapter + SwipeCommit + proxy`).
Patch: `.lucy/carry/shell-tabbar-and-copy.patch` — apply trên đúng commit đó, working tree sạch.

Patch = **toàn bộ** `git diff` vs HEAD, gồm việc session này **và** phần chưa commit từ lần agent-json/OCR/camera. Apply một lần.

## Spec

- FR / journey: không FR mới. IA 3 tab Home / Ôn / Kho + FloatShutter. NFR-08: cửa Dữ liệu vẫn từ Home. ADR-025/033: vuốt trái = Again (`Quên`), phải = Good (`Được`) — **không đổi mapping, không đổi nhãn bốn nút**.
- In-scope:
  - Capsule `ShellTabBar` 64pt thay native tab bar; Cài đặt + Dữ liệu: sheet → push.
  - Copy UI: `collection` → bộ, gỡ `FR-*` trên UI, `Huỷ`, `Lịch ôn`, `Ưu tiên`, `Hết thẻ hôm nay`, một nhãn **Kho tạm**.
  - Phần đã nằm trong tree: camera usage keys, bóc JSON agent, PageOCR, accent dark mode, lật dịch từng đoạn phiên đọc.
- Out-of-scope / không đụng: FSRS, DDL, sheet Chụp / Duyệt từ / Ôn bộ này; gộp FloatShutter vào thanh; đổi Quên/Khó/Được/Dễ.
- Q mở: không. Overlay camera vẫn nên verify on-device (simulator không camera). Máy này không chạy `xcodebuild`.

## Tầng 1 — HLD

- Module: Reado (View, copy). ReadoKit: OCR + parser JSON (phần leftover). pbxproj: `ShellTabBar.swift`, `PageOCRTests.swift`, `INFOPLIST_KEY_NSCamera*`.
- Protocol / transaction: không đổi.
- File cấm: schema SQLite, FSRS.

## Tầng 2 — Tasks

Đã làm một phiên. Patch là toàn bộ.

### T1 — ShellTabBar + Cài đặt/Dữ liệu push

- Files: `app/Reado/ShellTabBar.swift` (mới) · `app/Reado/RootView.swift` · `app/Reado/SettingsView.swift` · `app/Reado.xcodeproj/project.pbxproj`
- DoD: 3 tab đổi đúng; thanh còn trên Hub / Lịch ôn / Phiên đọc / Cài đặt / Dữ liệu; shutter ẩn đúng `showShutter`; Lưu settings pop về Home.

### T2 — Copy UI

- Files: `RootView` · `ReviewQueueView` · `ExportView` · `CaptureView` · `CollectionDetailView` · `StreakCalendarView` · `HomePinToggle` · `ImportView` · `AnalysisView` · `SettingsView` (footer giờ chuyển ngày)
- DoD: không còn `FR-01`/`FR-20` trên UI; header **Bộ**; swipe Kho **Ưu tiên**; hint ôn `trái Quên · phải Được`.

### T3 — leftover đã trong tree (agent-json / OCR / camera / dark accent / phiên đọc)

- Files: `OpenAICompatClient` · `Prompt` · `AnalysisAgentStore` · `PageOCR.swift` · `PageOCRTests` · `AnalysisTests` · `PageAnalyzer` · `CaptureView` (quyền + overlay) · `ReadoApp` (accent light/dark) · `ReadingSessionView` (lật từng đoạn) · `docs/decisions-log.md` · `docs/specs/journeys.md`
- DoD: Qwen/Gemini ra `PageAnalysis` khi content có object; camera có usage description (xoá app rồi cài lại mới hỏi quyền).

## Apply

```bash
git log -1 --oneline          # 869902f
git apply --check .lucy/carry/shell-tabbar-and-copy.patch
git apply         .lucy/carry/shell-tabbar-and-copy.patch
```
