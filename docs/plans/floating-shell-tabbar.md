# Plan: floating-shell-tabbar

> ✅ Done 2026-09-24 — superseded bởi `shell-tabbar-and-copy` (đã port toàn bộ, 204/204 test xanh).

## Spec

- FR / journey: không FR mới. IA 3 tab Home / Ôn / Kho (port UI lab) + FloatShutter (không tab Chụp). NFR-08: Dữ liệu không cạnh bánh răng trên cùng một toolbar — cửa Dữ liệu vẫn từ Home.
- In-scope:
  - Ẩn thanh tab native, dựng capsule nổi 64pt (`ShellTabBar`).
  - Gắn qua `safeAreaInset` để theo mọi màn push (Hub, Lịch streak, Phiên đọc).
  - Cài đặt + Dữ liệu: sheet → push `ShellRoute` để thanh còn hiện.
- Out-of-scope / không đụng: ReadoKit, FSRS, DDL, FR; sheet Chụp / Duyệt từ / Ôn bộ này; gộp FloatShutter vào thanh.
- Q mở: không.

## Tầng 1 — HLD

- Module: Reado (View). ReadoKit không đụng.
- Protocol / transaction: không.
- File cấm: `docs/specs/*`, schema SQLite, FSRS.

## Tầng 2 — Tasks

### T1 — ShellTabBar + RootView

- Files: `app/Reado/ShellTabBar.swift` (mới) · `app/Reado/RootView.swift` · `app/Reado.xcodeproj/project.pbxproj` (qua `pbxproj_tool.py`)
- Test: không suite mới (thuần UI).
- DoD: 3 tab đổi đúng; thanh còn trên Hub / Lịch streak / Phiên đọc; CTA đáy Streak / Phiên đọc không bị che; shutter ẩn/hiện đúng `showShutter`; grade buttons Ôn không dính thanh.

### T2 — Cài đặt + Dữ liệu push

- Files: `app/Reado/RootView.swift` · `app/Reado/SettingsView.swift`
- Test: không suite mới.
- DoD: mở Cài đặt / Dữ liệu vẫn còn thanh, back bằng nav bar, lưu settings xong Home refresh như cũ.

### T3 — Copy UI (session sau; giữ Quên/Khó/Được/Dễ)

- Files: `RootView` · `ReviewQueueView` · `ExportView` · `CaptureView` · `CollectionDetailView` · `StreakCalendarView` · `HomePinToggle` · `ImportView` · `AnalysisView` · `SettingsView`
- DoD: `collection` → bộ trên UI; gỡ `FR-*`; `Huỷ`; `Lịch ôn`; Kho swipe Ưu tiên; hint `trái Quên · phải Được`.
