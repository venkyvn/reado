# Ghi chú verify: nhánh `refactor/appmodel-split` (PR #1)

PR: https://github.com/venkyvn/reado/pull/1 (draft, base `main` @ 32d2f93)
Ba commit: `cd9e169` (tách AppModel + DayContext), `35c049c` (tách file lớn + JSONStringArray), `e0794b4` (@MainActor + FULLMUTEX).

**Trạng thái: chưa build, chưa chạy test.** Môi trường tạo nhánh là Linux, không có xcodebuild. Mọi thứ dưới đây chỉ được kiểm bằng cách so sánh tập dòng code trước/sau và `pbxproj_tool.py check` (OK).

## Chạy trên máy local

```bash
git fetch origin refactor/appmodel-split && git checkout refactor/appmodel-split
scripts/test.sh kit     # ~10s, ReadoKit thuần, chạy trước
scripts/test.sh         # build app + toàn bộ test (baseline gần nhất: 271/273, 2 skip opt-in)
```

Baseline để so: `docs/session-brief.md` §1 ghi 271/273 xanh trên iPhone 18 Pro. Nếu số khác, so với `main` trước khi đổ lỗi cho nhánh này.

## Đổi gì (tóm tắt)

| Nhóm | Thay đổi |
|---|---|
| `AppModel.swift` 839 → 234 dòng | Tách `AppModel+Capture/Review/Settings/Collections.swift`. Cắt nguyên văn theo dòng. |
| `VocabRepository.swift` 547 → 285 dòng | Thêm `+Collections`, `+Overview` (extension). |
| View | `AgentFormSheet.swift`, `CollectionMoveSheet.swift`, `CropView.swift` ra file riêng. |
| ReadoKit | `Time/DayContext.swift` (thay 3 bản chép đọc timezone + giờ chuyển ngày); `JSONStringArray.swift` (thay 3 bản mã hoá/giải mã `[String]` JSON). |
| An toàn luồng | `AppModel` gắn `@MainActor`; `SQLiteDatabase` mở với `SQLITE_OPEN_FULLMUTEX`. |
| Comment | Sửa hai comment sai "AppModel đã set reviewError" ở `ReviewQueueView+Grade.swift`. |

## Chỗ dễ lỗi compile (xem trước nếu build đỏ)

1. **`@MainActor` trên `AppModel`** (`app/Reado/App/AppModel.swift`). Nếu có chỗ gọi từ ngữ cảnh non-isolated sẽ báo lỗi "main actor-isolated ... in a synchronous nonisolated context". Ứng viên: `Task.detached` trong `CaptureView.processImage`, `AnalyzerFactory.active(... onProgress:)`. Cách lui nhanh: xoá dòng `@MainActor`, các phần còn lại độc lập.
2. **Quyền truy cập sau khi tách file.** Extension ở file khác không ghi được `private(set)`, nên các state mà extension ghi đã đổi thành `var`. Nếu còn thiếu, lỗi có dạng "cannot assign to property: 'x' setter is inaccessible". Cách sửa: bỏ `private(set)` ở property đó trong `AppModel.swift`.
3. **`MoveIntention`, `CollectionMoveSheet`** đã bỏ `private` vì khác file. Nếu trùng tên với type khác trong module sẽ báo "invalid redeclaration".
4. **`ShutterPressStyle`** cố ý để nguyên trong `CaptureView.swift`: `FloatShutter.swift` có bản `private` trùng tên.

## Smoke test tay (sau khi test xanh)

- Ôn một thẻ, chấm, Hoàn tác, chấm lại (đường đi liên quan `AppModel+Review`).
- Mở Cài đặt, thêm/sửa agent (form đã tách file), lưu "Thẻ mới mỗi ngày".
- Vào một collection, chọn lô từ, "Chuyển" (sheet đã tách file).
- Chụp trang, crop (`CropView` đã tách file).
- Ghim/bỏ ghim collection lên Home, bật "Ôn nhanh" (dùng `JSONStringArray`).
- Mở app lần đầu trên DB cũ v2 để chạy migration v2→v3 (đổi `migrateLegacyHomePins` sang `JSONStringArray`), nếu có bản backup DB cũ.

## Cố ý KHÔNG đổi (không phải quên)

- Không sửa bug nghiệp vụ: xem `/mnt/project-files/reviews/reado-review-2026-09-30.md`. Các lỗi nặng nhất: undo rồi chấm lại ghi sai trạng thái FSRS, hàng đợi so `now` thay vì hết ngày, parser CSV (CRLF, dấu `"`), số "Đến hạn" bỏ qua hạn mức thẻ mới.
- Không tách `OpenAICompatClient` (485 dòng) và `PageOCR` (396 dòng): mỗi file có hàm dài, tách khi không có compiler rủi ro hơn lợi ích.
- Không bật WAL, không inject clock, không đổi cách đọc cột SQLite.
- Không xử lý lỗi bị nuốt ở chấm/undo: cần thiết kế thông báo lỗi riêng.
