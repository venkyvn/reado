# app/ReadoKit — đọc khi sửa package

Luật đầy đủ: `docs/agent/coding-conventions.md` §2–6, §8–9. Dưới đây là chỗ hay sai nhất.

- Kiểu của swift-fsrs không lọt ra API public — vào/ra qua `CardSnapshot`, `ReadoRating`, `ReviewOutcome`.
- Tham số FSRS luôn qua `ReadoFSRS.parameters(from:)`; cấm `FSRS()` trần.
- Chấm điểm đi qua `ReviewService.record` (một transaction, snapshot trước). Undo = xoá đúng dòng log vừa ghi + trả card về snapshot, cùng transaction.
- Thời gian qua `Clock`, "hôm nay" qua `DayBoundary.window(...)`. Cấm `Date()` trần trong logic, cấm `datetime('now')` trong SQL.
- Timestamp qua `ISOTimestamp`. `ISO8601FormatStyle()` trần không parse được — phải compose đủ field.
- `COLLATE NOCASE` chỉ gập ASCII — gập tiếng Việt ở tầng Swift (FR-20).
- Lane `kit` chạy macOS, ghi vào `~/Documents` thật: class nào chạm `DebugTrace` phải set `DebugTrace.documentsDirectoryOverride` sang thư mục tạm ở `setUp`/`tearDown`.

## Đổi schema (khi đã có plan fen confirm)

1. Thêm `case N:` mới trong `Migration.run` (nâng N → N+1) và tăng `currentVersion`. **Không sửa case cũ** — DB đã ở version cao hơn sẽ không bao giờ chạy lại nó.
2. Cập nhật DDL ở `docs/specs/db.md`.
3. Test nâng cấp từ version cũ trong `MigrationAndSeedTests` bằng `Migration.run(on:upTo:)`.
4. Bảng/cột mới có vào export (FR-16) không: quyết, ghi vào `db.md`; nếu có thì sửa `ExportService` + `ExportTests`.
