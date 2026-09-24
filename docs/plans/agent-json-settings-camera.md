# Plan: agent-json-settings-camera

> ✅ Done 2026-09-24 — committed `e8b1933`, 196/196 test xanh.

Base: `869902f` (`feat(v2): port máy kia — protocol agent + OpenAI-compat adapter + SwipeCommit + proxy`).
Patch: `.lucy/carry/agent-json-settings-camera.patch` — apply trên đúng commit đó, working tree sạch.

## Spec

- FR / journey: FR-21 (agent OpenAI-compat, một agent active) · FR-02 (một lần gọi trả `segments` / `vocabulary` / `summary_vi`) · FR-01 (camera hệ thống). Không viết lại GWT.
- In-scope:
  - Bóc JSON trang khỏi wrapping của nhiều provider (markdown, `<think>`, `content` object / parts, `choices[0].text`).
  - Một object mẫu trong prompt (`PROMPT_VERSION` 2).
  - Settings: Lưu xong đóng sheet về Home. Vuốt agent user: Sửa (accent) / Xoá (danger). Sửa để trống key = giữ Keychain.
  - `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` (Debug và Release).
- Out-of-scope / không đụng: `json_schema` strict, alias key (`source` → `source_en`), gọi lần hai để sửa JSON, bundle id, proxy Python.
- Q mở: không. Máy này không chạy được test (CodeSign `ReadoTests.xctest`: resource fork / Finder detritus).

## Tầng 1 — HLD

- Module: parser + `AnalysisAgentStore.update` ở ReadoKit. Sheet Settings và dismiss ở Reado. Privacy key ở `project.pbxproj` (build setting, không file Info.plist riêng).
- Protocol: HTTP vẫn `{base}/chat/completions`, `response_format: json_object`. Hợp đồng trang không đổi — object có `segments` hoặc `vocabulary`. Array top-level, key lạ, JSON trong `<think>` vẫn lỗi.
- File cấm: không đụng schema SQLite, FSRS, FR-07/FR-13.

## Tầng 2 — Tasks

Đã làm một phiên. Patch là toàn bộ.

### T1 — agent-json-settings-camera

- Files:
  - `app/ReadoKit/Sources/ReadoKit/Analysis/OpenAICompatClient.swift`
  - `app/ReadoKit/Sources/ReadoKit/Analysis/Prompt.swift`
  - `app/ReadoKit/Sources/ReadoKit/Analysis/AnalysisAgentStore.swift`
  - `app/Reado/SettingsView.swift`
  - `app/ReadoTests/AnalysisTests.swift`
  - `app/Reado.xcodeproj/project.pbxproj`
- Test: `AnalysisTests` — bóc JSON sau `<think>` + fence; `content` là object; `update` agent giữ/đổi key. Chưa có `** TEST SUCCEEDED **` trên máy này.
- DoD: Qwen/Gemini cùng ra `PageAnalysis` khi content có object Reado. Lưu Settings về Home. Vuốt agent có Sửa/Xoá. Camera hiện hộp thoại quyền sau khi xoá app và cài lại.

## Apply

```bash
git log -1 --oneline          # 869902f
git apply --check .lucy/carry/agent-json-settings-camera.patch
git apply         .lucy/carry/agent-json-settings-camera.patch
```

Sau khi cài lên iPhone: xoá app Reado rồi Run lại, để iOS hỏi quyền camera.
