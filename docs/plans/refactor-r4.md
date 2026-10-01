# Plan: refactor-r4 — tách CaptureView, dọn try?, B5 chuyển test sang ReadoKitTests

> **Trạng thái:** T1 ✅ · T2 ✅ 2026-10-01 (355/357 xanh). T3 chưa làm.

> Viết cho **Sonnet** thực thi: **1 task = 1 session**, làm đúng thứ tự T1 → T2 → T3.
> Khi fen duyệt plan: lưu nguyên văn vào `docs/plans/refactor-r4.md` (commit chung với T1).
> Máy chạy là Mac local, có Xcode + simulator — `scripts/test.sh` chạy được, phải chạy thật, không bịa số.

## Context

Sau refactor-r2/r3 + merge PR #2 (HEAD `beec9d2`, full **306/308** xanh), lần quét lại tìm ra:
- `app/Reado/Capture/CaptureView.swift` **460 dòng** — vượt quy ước ~400 dòng/file (`coding-conventions.md` §2).
- Còn **45 `try?`** ở 26 file. Phân loại xong: chỉ 2 chỗ nuốt lỗi thật, còn lại hợp lệ (xem T1).
- **B5** hoãn từ repo-hygiene-r1: 28 file test ở `app/ReadoTests` (chạy simulator), trong khi 24 file chỉ `import ReadoKit` + XCTest → chạy được ở lane `kit` macOS (~10s). `AnalysisTests.swift` 1147 dòng cần tách.
- Phát hiện quan trọng: scheme `Reado` **chỉ có `ReadoTests`** (308 test). `ReadoKitTests` (49 test) **chưa bao giờ chạy** trong full suite — hai số tách nhau. **Fen chốt:** thêm `ReadoKitTests` vào scheme `Reado` → full suite ra MỘT số (~357), lane `kit` là tập con nhanh.

## Spec
- FR / journey: không có — refactor thuần, không đổi hành vi người dùng (trừ 2 chỗ `try?` ở T1, chỉ đổi đường lỗi).
- Nguyên lý: không đụng nguyên lý nào trong vision.md; không đụng NG.
- In-scope: T1 tách `CaptureView` + 2 `try?`; T2 chuyển 24 file test sang `ReadoKitTests` + đưa vào scheme; T3 tách `AnalysisTests.swift`.
- Out-of-scope: `AnalysisView.swift` (408 dòng, sát ngưỡng, để nguyên); `DayContext` `try?` (lý do ở T1); 4 file test dùng UIKit/Vision ở lại `ReadoTests`; mọi thay đổi assertion/logic test.
- Q mở: không.

## Tầng 1 — HLD
- Module: T1 = `Reado` (app) + 1 dòng ReadoKit (`HomePinService`). T2/T3 = test targets.
- Transaction/protocol: không đụng.
- File cấm: `project.pbxproj` (hook chặn; synchronized folders tự nhận file mới). `Package.swift` không sửa (nếu bắt buộc phải sửa → dừng, hỏi fen).
- Đổi scheme: **fen làm trong Xcode** (bước 0 của T2), không sửa tay `.xcscheme`.

---

## Tầng 2 — Tasks

### T1 — tách `CaptureView` + dọn 2 `try?` (1 session)

**1a. Tách `CaptureView.swift` (460 dòng → ~330 + ~135)** — di chuyển thuần, theo mẫu đã có `ReviewQueueView+Card.swift`/`+Grade.swift`.
- Tạo `app/Reado/Capture/CaptureView+Destination.swift` (synchronized folder tự nhận, không đụng pbxproj), `import SwiftUI` + `import UIKit` (+ `ReadoKit` nếu cần), chứa `extension CaptureView { … }` với 6 member chọn đích lưu, cắt nguyên văn từ file gốc:
  - `destChip` (dòng ~230–252), `destName`, `cameraDestIsInbox`, `selectDest(_:)`, `destPickerSheet(close:)`, `newCollectionSheet(close:)` (dòng ~295–394), giữ nguyên doc comment.
- Bỏ `private` ở những gì extension khác file cần thấy (extension không đọc được `private`):
  - 6 member vừa chuyển → internal.
  - Trong `CaptureView.swift`: `@Environment(AppModel.self) private var model` → `var model`; `@State private var showDestPicker` → `@State var showDestPicker`; `@State private var newCollectionName` → `@State var newCollectionName`. Build báo thiếu cái nào thì bỏ `private` đúng cái đó, không bỏ tràn lan.
- Giữ ở `CaptureView.swift`: `body`, `busyMessage`, màn camera (`cameraScreen`, `framingGuide`, `deniedView`, `unavailableView`, `topBar`, `bottomBar`), `captureTapped`, `processImage`, `ShutterButtonLabel`, `ShutterPressStyle`, `#Preview`.
- Kiểm "chỉ di chuyển": so tập dòng thêm/bớt — khác biệt chỉ được là dòng `private` bị bỏ + header/`extension` của file mới:
  ```bash
  git add -N app/Reado/Capture/CaptureView+Destination.swift
  git diff -U0 -- app/Reado/Capture/ | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' > .tmp/t1.diff
  diff <(grep '^-' .tmp/t1.diff | cut -c2- | sed 's/^ *//' | sort) \
       <(grep '^+' .tmp/t1.diff | cut -c2- | sed 's/^ *//' | sort)
  ```

**1b. Hai `try?` nuốt lỗi thật**
- `app/ReadoKit/Sources/ReadoKit/Settings/HomePinService.swift:59` — trong `ids(on:)` (đã `throws`): lỗi DB đang bị coi như "collection không tồn tại" → ghim biến mất im lặng. Đổi:
  ```swift
  return try raw.filter { id in
      try db.scalarInt64("SELECT 1 FROM collections WHERE id = ? LIMIT 1;", [.text(id)]) != nil
  }
  ```
  (`filter` là `rethrows`; không có hàng → `nil` vẫn lọc đúng như cũ.)
- `app/Reado/App/NotificationScheduler.swift:36` — `try? await center.add(request)`: đặt lịch nhắc hỏng thì im lặng. Đổi sang `do { try await center.add(request) } catch { DebugTrace.event("reminder", "scheduleFailed", ["error": String(describing: error)]) }`. Không thêm alert (không đổi UI).

**1c. Không sửa — ghi lý do vào journal** (để session sau không rà lại):
- `DayContext.read` (`try?` + fallback UTC/4h): mọi chỗ gọi (`ReviewQueue.currentDayWindow` → ~12 call site) đều chạy query khác ngay sau đó trong cùng hàm `throws`, DB hỏng sẽ ném ở đó; đổi chữ ký lan ~12 chỗ không đáng.
- Hợp lệ theo ngữ nghĩa: `Task.sleep` (cancel), parse/decode trả optional (`JSONStringArray`, `ISOTimestamp`, `LearningSettings`, `PageAnalyzer`, `ReadingSession`, `ReviewScheduler`, `ExportService`, `AnalysisResponseExtractor`, error mapper/envelope ở `OpenAICompat*`/`ReadoProxyClient`), `ROLLBACK` trong nhánh catch (`Database.swift:176`), xoá bù khi lưu Keychain hỏng rồi rethrow (`AnalysisAgentStore:128`), fallback OCR legacy theo ADR-042 (`PageOCR:93`), `DebugTrace` best-effort, `AVAudioSession`/camera config, `requestAuthorization` (từ chối quyền là trạng thái bình thường), `ReminderService.describe`, seed dev trong `#if DEBUG` của `AppModel`, `loadTransferable` ở `CaptureView` (đã trace + alert).

**Test:** không thêm test mới (lỗi DB giả lập không có hạ tầng; `HomePinTests` phủ đường đúng). Chạy `scripts/test.sh test -only-testing:ReadoTests/HomePinTests` khi sửa, rồi full.
**DoD:** `scripts/test.sh` full **306/308**, `** TEST SUCCEEDED **`; `wc -l` `CaptureView.swift` ≤ ~340; lệnh so tập dòng chỉ còn khác biệt `private`/header; fen xem tay màn chụp: chip "Lưu vào", sheet chọn bộ, sheet tạo bộ mới (gồm tạo trùng tên → alert) vẫn chạy. Commit: `refactor(capture): refactor-r4 T1 — tách CaptureView+Destination, bỏ 2 try? nuốt lỗi`.

---

### T2 — B5: chuyển test logic thuần sang `ReadoKitTests` (1 session)

**Bước 0 — fen làm trong Xcode (Sonnet dừng chờ, không tự sửa `.xcscheme`):**
Product → Scheme → Edit Scheme… → Test → `+` → chọn `ReadoKitTests` (package ReadoKit) → Close. Sau đó Sonnet chạy `scripts/test.sh` lấy **mốc mới**: kỳ vọng **355/357** (306 + 49, 2 skip). Ghi số mốc. Nếu không ra 357 → dừng, báo fen. File `app/Reado.xcodeproj/xcshareddata/xcschemes/Reado.xcscheme` đổi → commit trong T2.

**Bước 1 — chuyển 24 file bằng `git mv`** từ `app/ReadoTests/` sang `app/ReadoKit/Tests/ReadoKitTests/` (SPM tự nhận theo thư mục):
- Chuyển: `TestSupport.swift` (enum `Fixtures`) + 23 file: `AnalysisTests`, `CSVImportTests`, `CaptureFailureTests`, `CramReviewTests`, `DailyProgressTests`, `DebugTraceTests`, `EncounterRepositoryTests`, `ExportTests`, `FoundationPrimitivesTests`, `HomePinTests`, `LearnMoreTests`, `LeechTests`, `MigrationAndSeedTests`, `OnboardingChecklistTests`, `ReadingSessionTests`, `ReminderTests`, `ReviewQueueAndServiceTests`, `ReviewSchedulerTests`, `ScopedReviewTests`, `SessionTallyTests`, `SettingsTests`, `StreakCalendarTests`, `VocabularyListTests`.
- **Ở lại `ReadoTests`** (dùng UIKit/Vision, không chạy macOS): `ImageCompressorTests`, `LiveAIBoxTests`, `OCRProbeTests`, `PageOCRTests`. Đã kiểm: 4 file này không dùng `Fixtures`; 23 file kia không dùng `UIImage`/`ImageCompressor`/Vision/`UNUserNotification`. Không trùng tên class/file với 6 file kit có sẵn.
- Làm theo lô (vd 6 file/lô), sau mỗi lô chạy `scripts/test.sh kit` để lỗi biên dịch ít một.

**Bẫy biết trước:**
1. **Swift 6 strict concurrency.** `ReadoTests` đang `SWIFT_VERSION = 5.0`; package `ReadoKit` là tools 6.0 → test target chạy Swift 6 mode. Lỗi chắc gặp: `AnalysisTests.swift:1119` `static var handler` trong `StubURLProtocol` → `nonisolated(unsafe) static var handler` (cùng cách `DebugTrace.documentsDirectoryOverride`, brief §3). Lỗi concurrency khác: sửa tối thiểu bằng annotation (`nonisolated(unsafe)` cho static test-only, `@unchecked Sendable` cho class helper test, `@MainActor` nếu test chạm API MainActor) — **không đổi assertion, không xoá test**. Không sửa được bằng annotation → dừng, báo fen (không tự đổi `Package.swift` sang Swift 5 mode).
2. **`DebugTrace` ghi vào `~/Documents` thật của Mac.** Trên macOS test không sandbox; `OpenAICompatClient`/`ReadoProxyClient` gọi `DebugTrace.event` → ghi `~/Documents/Diagnostics/`. Trong `AnalysisTests` thêm `setUp` gán `DebugTrace.documentsDirectoryOverride = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)` và `tearDown` trả `nil` (xem cách `DebugTraceTests` làm). Kiểm sau khi chạy kit: `ls ~/Documents/Diagnostics` phải **không tồn tại** (hiện tại không có).
3. Lane full giờ chạy `ReadoKitTests` trên simulator, lane `kit` chạy cùng bộ đó trên macOS — test phụ thuộc nền tảng (Locale/timezone) phải xanh cả hai.

**Bước 2 — docs con trỏ sống** (chỉ sửa dòng còn hiệu lực, không sửa nhật ký cũ). `grep -rn "ReadoTests" CLAUDE.md docs/agent .claude/agents .claude/commands`:
- `CLAUDE.md` §2: ví dụ `-only-testing:` thêm `ReadoKitTests/<Class>` (test logic) bên cạnh `ReadoTests/<Class>` (4 test UIKit/Vision); §7 pbxproj: test logic mới tạo trong `app/ReadoKit/Tests/ReadoKitTests/` (SPM tự nhận), test cần UIKit vẫn ở `app/ReadoTests/`.
- `docs/agent/coding-conventions.md` §2 (cây thư mục dòng ~42–43) + §7 (dòng ~93–104): `ReadoKitTests` = bộ test hành vi chính (chạy cả simulator qua scheme `Reado` lẫn macOS qua `kit`); `ReadoTests` = chỉ test cần UIKit/Vision.

**DoD:** `scripts/test.sh` full = **đúng số mốc bước 0** (355/357, 2 skip), `** TEST SUCCEEDED **`; `scripts/test.sh kit` xanh, kỳ vọng **336 test** (49 + 287 chuyển sang; 21 test ở lại `ReadoTests` — lấy số thật từ dòng `RESULT`); `app/ReadoTests` còn đúng 4 file; `~/Documents/Diagnostics` không bị tạo. `python3 scripts/pbxproj_tool.py check` OK (test.sh tự chạy). Commit: `refactor(test): refactor-r4 T2 — B5 chuyển 23 test logic sang ReadoKitTests, thêm kit vào scheme Reado`.

---

### T3 — tách `AnalysisTests.swift` (1147 dòng) (1 session, sau T2)

File lúc này ở `app/ReadoKit/Tests/ReadoKitTests/AnalysisTests.swift`, 1 class / 39 test. Tách theo các `// MARK:` có sẵn, di chuyển thuần:

| File mới | Nội dung (dòng gốc, số dòng có thể lệch sau T2) |
|---|---|
| `AnalysisTestSupport.swift` | JSON fixtures đầu class (dòng ~9–36) → `enum AnalysisFixtures` (static), + toàn bộ helper cuối file (~1018–1147): `FixedPageOCR`, `MemorySecrets`, `bodyData`, `RequestCapture`, `AttemptCounter`, `ProgressCapture`, `sseLine`, `StubURLProtocol`; bỏ `private`/`fileprivate` để file khác thấy |
| `AnalysisDecoderTests.swift` | MARK Decoder + VerifyEngine (~37–198) |
| `AnalyzerFactoryTests.swift` | MARK AnalyzerFactory (~199–523) |
| `AnalysisStreamTests.swift` | MARK Stream + AI-Box (~524–710) |
| `ReadoProxyClientTests.swift` | MARK ReadoProxyClient wire + Map error envelope (~711–844) |
| `ReviewDraftBuilderTests.swift` | MARK ReviewDraftBuilder (~845–1017) |

- Xoá `AnalysisTests.swift` sau khi chuyển hết (`git rm`).
- Mỗi class mới: `final class XxxTests: XCTestCase`. Nếu class gốc có `setUp`/`tearDown` (vd reset `StubURLProtocol.handler`, override `DebugTrace` từ T2) → class nào dùng stub/client thì mang theo. Cách gọn: trong `AnalysisTestSupport.swift` tạo `class AnalysisNetworkTestCase: XCTestCase` chứa setUp/tearDown đó, 3 class Factory/Stream/Proxy kế thừa.
- Chỗ test gọi fixture JSON kiểu `Self.xxx`/`xxx` → đổi sang `AnalysisFixtures.xxx` (thay đổi cơ học duy nhất được phép).
- Không bật parallel testing (`StubURLProtocol.handler` là static dùng chung — các class chạy tuần tự như hiện nay).
- Kiểm "chỉ di chuyển" bằng lệnh so tập dòng như T1 (khác biệt chỉ còn: `private`, header `import`/`final class`, `AnalysisFixtures.` prefix).

**DoD:** `scripts/test.sh kit` và `scripts/test.sh` full ra **đúng số test như sau T2** (không mất test nào; đếm `grep -c "func test"` trước/sau = 39); không file mới nào > ~400 dòng; `grep -rn "AnalysisTests" CLAUDE.md docs/agent .claude` không còn con trỏ sống tới file cũ. Commit: `refactor(test): refactor-r4 T3 — tách AnalysisTests thành 6 file theo MARK`.

---

## Verification (chung cho mỗi task)
1. Trong lúc sửa: `scripts/test.sh kit` (T2/T3) hoặc `scripts/test.sh test -only-testing:<Target>/<Class>`.
2. Trước `/rhandoff`: `scripts/test.sh` full (background, chờ `** TEST SUCCEEDED **` + dòng `RESULT:`). Treo > 10 phút sau khi đã boot → kill, báo fen.
3. Lệnh so tập dòng (T1, T3) để chứng minh di chuyển thuần.
4. Xcode chạy xong hay re-sort pbxproj → trước commit `git diff app/Reado.xcodeproj` chỉ giữ hunk thật (T2: chỉ `.xcscheme`; pbxproj không được đổi).
5. `/rhandoff` mỗi task: brief §1 thay bullet refactor-r4, journal 3–5 dòng, đánh dấu task trong `docs/plans/refactor-r4.md`; xong T3 → plan khép. Cập nhật brief: số test chính thức từ giờ là số **gộp** của scheme `Reado`.
