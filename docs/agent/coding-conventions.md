# Coding Conventions — Reado (Swift / iOS)

| Field | Value |
|---|---|
| Created | 2026-09-18 (bản này thay bản TS PWA-gen — đã archive: coding-conventions-pwa-gen.md (đã xoá, ADR-044)) |
| Phạm vi | Code Swift R1: `app/Reado` (SwiftUI) + `app/ReadoKit` (package). Nguồn luật: bộ docs sản phẩm (PRD, db.md, tech-stack, rulebook). Mâu thuẫn với docs sản phẩm → docs thắng, ghi lại vào ROADMAP mục 4 |

## 1. Ngôn ngữ & tên gọi

- **Định danh code: tiếng Anh** — API/domain term ở lại codebase (`dueCardIDs`,
  `dailyNewLimit`, `requestRetention`). Người đọc sau đổi provider vẫn hiểu.
- **Chữ người dùng thấy (UI): tiếng Việt.** String hiển thị không nằm trong ReadoKit
  (trừ tên seed cố định như `Seeder.defaultCollectionName`) — app layer sở hữu UI copy.
- **Comment giải thích *vì sao*, tiếng Việt, ngắn.** Không kể lại *cái gì*. Quyết định
  quan trọng ghi mã chốt kèm nguồn: `// Q-12 CHỐT: ...` / `// db.md A.1: ...`.

## 2. Layout thư mục (ranh giới cứng)

```
app/
  Reado.xcodeproj        — project Xcode (objectVersion 70, synchronized folders; xem bẫy mục 9)
  Reado/                 — app SwiftUI. UI + bootstrap; KHÔNG chạy SQL trực tiếp?
                          (chỉ qua ReadoKit public API). Chia theo feature (B2 repo-hygiene-r1):
    App/                 — ReadoApp, RootView (shell + route), ShellTabBar, AppModel (+Capture/+Collections/+Review/+Settings/+Encounter/+Errors), AppState (ReviewState/CaptureFlow/ShellSignals/LibraryState — view đọc `model.review.*`, `model.capture.*`…), NotificationScheduler
    Home/                — checklist onboarding, streak calendar, pin bộ lên Home
    Capture/             — CaptureView, CameraController (FR-01)
    Analysis/            — AnalysisView + card duyệt (FR-02..04)
    Review/              — ReviewQueueView, SessionDoneView (FR-11/12)
    Library/             — Kho, CollectionDetailView, ReadingSessionView, Import/Export
    Settings/            — SettingsView
    Shared/              — DesignSystem (token + Pill/IconTile/VocabSummary), Pronunciation
  View > ~400 dòng thì tách theo `// MARK:` (subview thành file riêng; phần thân struct thành
  `extension X` ở `X+Card.swift`…, chỗ đó `private` → internal — vd `ReviewQueueView+Card/+Grade`).
  ReadoKit/              — package nền; toàn bộ logic sản phẩm
    Sources/CSQLite/     — system library SQLite C (shim.h + module.modulemap)
    Sources/ReadoKit/
      Primitive           — Identifier, ISOTimestamp, Clock (không phụ thuộc tầng khác)
      Time/               — DayBoundary — mọi phép "hôm nay" đi qua đây
      Database/           — SQLiteDatabase (wrapping C API), Migration, Seeder
      Review/             — ReviewScheduler (FSRS), CardSnapshot, ReviewService,
                            ReviewQueue
    Tests/ReadoKitTests/  — bộ test hành vi chính (logic thuần); chạy macOS qua
                            `scripts/test.sh kit` LẪN iOS Simulator qua scheme
                            `Reado` (`Reado.xctestplan`, refactor-r4 T2)
  ReadoTests/            — chỉ các file cần UIKit/Vision (OCR, ảnh) — không build
                            được trên macOS, chạy iOS Simulator qua xcodebuild
```

- **ReadoKit là adapter cô lập thư viện ngoài:** kiểu của swift-fsrs (`Card`,
  `Rating`, `CardState`) KHÔNG lọt vào API public — vào/ra qua `CardSnapshot`,
  `ReadoRating`, `ReviewOutcome`. Muốn đổi thư viện FSRS chỉ đụng tầng `Review/`.
- App layer không `import FSRS`, không `import CSQLite`.
- Logic LIÊN QUAN dữ liệu (kể cả đọc overview) sống ở ReadoKit; View chỉ hiển thị.

## 3. Dialect SQLite — đã chốt (db.md A.1, CLAUDE.md §4)

- `uuid` TEXT thường có gạch nối; sinh client-side qua `Identifier.uuid()`.
- Timestamp TEXT ISO-8601 **UTC hậu tố `Z`, không fractional** qua `ISOTimestamp` —
  chuỗi cùng độ dài nên so sánh lexicographic = so sánh thời gian.
- Boolean = INTEGER 0/1; `fsrs_params` TEXT JSON + cột `fsrs_version` đi kèm.
- `PRAGMA foreign_keys = ON` cho **mọi** connection (`SQLiteDatabase.init` làm sẵn).
- Không dùng `datetime('now')` trần trong SQL — app truyền timestamp qua `Clock`.
- Schema chỉ đổi qua `Migration` (user_version); DDL chuẩn nằm đúng từng dòng db.md.

## 4. Dữ liệu & transaction

- `cards.state` có **BỐN** giá trị `new/learning/review/relearning` — không gộp.
- Một lần chấm = `UPDATE cards` + `INSERT review_logs` **CÙNG transaction**
  (`ReviewService.record`). Log ghi ảnh chụp **TRƯỚC** khi chấm (`CardSnapshot`).
- Undo = XOÁ đúng dòng log vừa ghi + trả card về snapshot, cùng transaction —
  không UPDATE log cũ.
- KHÔNG `unique (collection_id, term_normalized)` trên `vocab_items` — chống trùng
  ở FR-10 lúc trích xuất.
- `review_logs.scheduled_days` = nhịp MỚI sau lần chấm (convention ts-fsrs); nhịp
  trong log của swift-fsrs là nhịp CŨ (`last.scheduledDays`) — đừng lẫn.

## 5. FSRS

- Luôn `ReadoFSRS.parameters(from:)` — `FSRSDefaults.defaultWv6` (21 trọng số);
  **cấm** `FSRS()` không tham số (FSRS-5 = silent breakage).
- Q-12: `enableShortTerm = false`, `learningSteps = []`, `relearningSteps = []` —
  state `learning` không xuất hiện ở R1.
- `fsrs_params` trong DB phải đi kèm `fsrs_version = 'fsrs-6'` và đủ 21 phần tử,
  nếu không `ReviewSchedulerError.unsupportedParamsVersion`.
- Mọi phép "hôm nay" đi qua `DayBoundary.window(now:timezone:dayCutoffHour:)`.

## 6. Concurrency (package biên dịch Swift 6 mode)

- Package tools 6.0 → strict concurrency bật sẵn: không `static let` cho class không
  Sendable (`ISO8601DateFormatter`…). Dùng struct Sendable (`ISO8601FormatStyle`).
- `@unchecked Sendable` chỉ cho wrapper sở hữu `OpaquePointer` C API
  (`SQLiteDatabase`, `SQLiteStatement`) — không dùng để lách trách nhiệm concurrency.
- Thời gian inject qua `Clock` (protocol Sendable) — cấm `Date()` trần trong logic.

## 7. Kiểm thử

- Acceptance criteria của FR = test case. Test hành vi logic
  thuần ở `app/ReadoKit/Tests/ReadoKitTests` — chạy nhanh bằng `scripts/test.sh
  kit` (macOS) khi đang sửa, scheme `Reado` (xcodebuild iOS Simulator) chạy lại
  full trước `/rhandoff`. Các file cần UIKit/Vision (OCR, nén ảnh) ở `app/ReadoTests`,
  chỉ chạy được iOS Simulator.
- **Không có target nào link app (`TEST_HOST`).** Hệ quả: `AppModel`/SwiftUI view
  KHÔNG unit-test được dù ở target nào. Test logic ở ReadoKit (enum error,
  queue/service/decoder, repository); hành vi của AppModel/view verify bằng
  owner e2e, không bằng unit test.
- DB trong test dùng `SQLiteDatabase(inMemory:)`; fixtures qua enum `Fixtures`
  (time + timezone cố định, không phụ thuộc đồng hồ thật).
- Test logic mới tạo trong `app/ReadoKit/Tests/ReadoKitTests/` (SPM tự nhận);
  chỉ test cần UIKit/Vision mới vào `app/ReadoTests/` (synchronized folders,
  ADR-046). Test chạy trên macOS (`kit`) ghi vào `~/Documents` THẬT (không
  sandbox) — class nào gọi `DebugTrace`/code ghi Documents phải override
  `DebugTrace.documentsDirectoryOverride` sang thư mục tạm ở `setUp`/`tearDown`
  (mẫu: `DebugTraceTests`, `AnalysisNetworkTestCase`). Tin cột `Executed N tests` / dòng
  `RESULT` của `scripts/test.sh`, không tin số trong commit cũ.
- "Xong" = toàn bộ criteria pass + lệnh đã chạy ghi bằng chứng vào plan.

## 7b. Commit message — bắt buộc (owner chốt 2026-09-19; sửa 2026-10-06 theo thực tế, workflow-docs-r1 D9)

Mỗi task = một commit riêng. Format chuẩn:

```
type(scope): tóm tắt bằng tiếng Việt — chi tiết cần thiết
```

- **Prefix** (`type`) là một trong `feat` · `fix` · `refactor` · `docs` · `chore` · `test` (gitmoji không dùng). Scope
  trong ngoặc đơn: `app`, `kit`, tên plan/task…
- `:` rồi một khoảng trắng rồi tóm tắt **tiếng Việt, mô tả FR/task đã làm**. Con
  người đọc vào là biết đổi gì, không cần mở diff.
- Tách `-` nếu có hai việc khác loại trong cùng commit (chi tiết lẻ).
- Không để body trống: tóm tắt phải tự đứng được.
- Không viết hoa sau dấu hai chấm kiểu Conventional Commits tiếng Anh — dùng tiếng
  Việt như repo vẫn làm (`feat(app): xoá PWA — …`).

Ví dụ:

```
feat(app): FR-01 capture — camera/photos picker + crop xoay, chọn/tạo collection tại chỗ
feat(kit): FR-02 analysis — protocol PageAnalyzer + proxy client, mock cho walking skeleton
```

## 8. Điều cấm (danh sách đóng, từ docs)

1. KHÔNG tự viết SRS algorithm — chỉ swift-fsrs + defaultWv6.
2. KHÔNG thêm `unique` trên `vocab_items (collection_id, term_normalized)`.
3. KHÔNG implement FR-07 / FR-13; không xoá dòng bia mộ khỏi docs.
4. KHÔNG lưu ảnh trang vào SQLite (NFR-04 — chỉ segments JSON).
5. KHÔNG ghi key API vào SQLite/plist/log (user key = Keychain, FR-21).
6. KHÔNG tự chốt câu hỏi mở của owner; không đảo quyết định đã chốt.
7. KHÔNG thêm dependencies ngoài nếu không thực sự cần (chỉ swift-fsrs hiện tại).
8. KHÔNG `timestamptz` thiếu timezone — mọi ts app-side qua `Clock` + `ISOTimestamp`.
9. KHÔNG lưu state SAU khi chấm vào log — snapshot TRƯỚC, cùng transaction.
10. KHÔNG để kiểu lib ngoài lọt vào API public của ReadoKit (mục 1).

## 9. Bẫy đã biết (thêm khi đụng)

- **Bẫy `find` trong Swift Package:** Thư mục `.build/` của SPM chứa hàng ngàn file header hệ thống. Tuyệt đối không chạy `find` trần trên toàn bộ workspace, việc này sẽ làm tràn context window và tiêu tốn hàng chục ngàn token vô ích.
- **pbxproj synchronized folders:** objectVersion 70 (ADR-046); local package vẫn là
  `XCSwiftPackageProductDependency`. Scheme share nằm ở `xcshareddata/xcschemes/`.
- **`swift-fsrs` buildLog:** `log.scheduledDays` là nhịp CŨ — nhịp mới ở
  `item.card.scheduledDays` (mục 4).
- **SQLite `COLLATE NOCASE` chỉ gập ASCII** — gập hoa thường tiếng Việt là việc
  tầng app lúc trim/insert (FR-20), không kỳ vọng DB làm (báo ROADMAP mục 4).
- **ISO8601FormatStyle:** style khởi tạo trần không có field nào — phải compose
  `.year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .omitted)`
  thì mới parse/format được (bẫy đã tốn 1 lần crash fixture trong test).