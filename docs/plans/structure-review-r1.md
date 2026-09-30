# Plan: structure-review-r1 — review cấu trúc code + roadmap refactor/enhance

> Nguồn: fen nhờ "ngó cách cấu trúc code, xem có gì refactor/enhance" (2026-09-30). Review **tĩnh** (grep + đọc có chọn lọc) tại HEAD `3e8b0c2` trong session cloud không có Xcode — **chưa build/test gì**. Mọi `file:dòng` đúng tại HEAD đó; tới lượt task nào thì kiểm lại bằng `grep -n` trước khi sửa.
> Trạng thái: **đề xuất — chưa task nào được fen OK.** 1 task = 1 session (CLAUDE.md §7); task đụng hợp đồng phải `/rplan` riêng.
> Quy mô lúc review: `app/Reado` 6.2k dòng / 19 file · `ReadoKit` 6.1k / 45 file · `ReadoTests` 5.0k / 25 file (~256 hàm `test…`) · `proxy` 264 dòng Python.

## Spec

- **FR / journey:** không FR mới, không đổi GWT nào. Chạm hành vi: FR-11/FR-12 (A1 — chấm/undo lỗi phải hiện ra), FR-19 (leech vẫn đánh giá SAU `record`), FR-10 (`matureKeysForCapture`), J1 (luồng chụp→phân tích→lưu, T8).
- **In-scope:**
  1. Sửa lỗi + chỗ phá luật đã ghi trong `docs/agent/coding-conventions.md` (Phase 1).
  2. Đưa nghiệp vụ khỏi `AppModel`/View xuống ReadoKit để test được (Phase 2).
  3. Tổ chức thư mục/tệp của app (Phase 3).
  4. Dev-loop (previews, tách test) + data-access Kit (Phase 4).
- **Out-of-scope / không đụng:** schema/DDL/`Migration.swift` · thuật toán FSRS · `ReviewService.record`/`undo` (transaction) · bia mộ FR-07/FR-13 · thêm dependency · tách Kit thành nhiều SPM target · i18n catalog · proxy Python (chỉ báo — Q-03 đã chốt).
- **Q mở / chỗ thiếu hợp đồng (không tự chốt — hỏi fen):**
  1. **Proxy Python:** park hay revive? Prompt proxy v1 vs app v5; `proxy.reado.app` chưa deploy nên agent mặc định luôn lỗi tới khi thêm BYOK. Đụng Q-03 đã chốt "hybrid" — chỉ báo.
  2. **A7:** đồng ý đo `SWIFT_STRICT_CONCURRENCY=complete` trước khi thêm `@MainActor`? (mặc định: có).
  3. `LocalizedError` tiếng Việt trong Kit và `IntervalPreview.label` ("ngày/tháng/năm") lệch conventions §1: đề xuất **sửa convention** (cho phép) thay vì dời code — OK không?
  4. **T16:** file nào được archive.

### Nhận định

Nền tảng tốt: Kit tách sạch khỏi UI, app không `import CSQLite/FSRS`, service là enum tĩnh nhất quán (`X.f(on: db, …)`), transaction chấm đúng luật, đã có mẫu "logic thuần ở Kit + test" (`SessionTally`, `SwipeCommit`, `Mastery`, `IntervalPreview`, `OnboardingChecklist`), DI/test đúng kiểu ở `AgentSecretStore` + `StubURLProtocol`.

Vấn đề gom ở **ranh giới app↔Kit bị mòn khi tính năng dồn vào `AppModel`/View**: nghiệp vụ nằm đúng chỗ `ReadoTests` không với tới (không `TEST_HOST`, conventions §7 — `AppModel`/View không unit-test được).

### Phát hiện A — lỗi & chỗ phá luật (sửa trước, diff nhỏ)

| # | Phát hiện | Bằng chứng |
|---|---|---|
| A1 | **Chấm/undo lỗi bị nuốt im.** View `catch` rỗng, comment "AppModel đã set reviewError" nhưng `grade`/`undoReview` không bao giờ set (chỉ `loadReviewQueue` set). DB/scheduler lỗi → bấm chấm không phản hồi | `ReviewQueueView.swift:601-603,647-649` · `AppModel.swift:338,355` |
| A2 | **Kiểu swift-fsrs lọt API public** (trái conventions §2/§8.10): `ReviewScheduler.engine`/`.parameters`/`grade(card:)`, `CardSnapshot.schedulerCard`, `CardStateCode.from/toState`. Chỉ 1 test chạm. `@unchecked Sendable` (§6) có thể giữ vì chỉ `let` — nên ghi lý do vào comment | `ReviewScheduler.swift:189-193,206,247,251` · `CardSnapshot.swift:50` · `ReviewSchedulerTests.swift:22` |
| A3 | **SQL thô ở app** (`SELECT id FROM collections WHERE is_default = 1`), trùng đúng câu trong Kit | `AppModel.swift:481-482` ↔ `VocabRepository.swift:199` |
| A4 | **`Date()` lách `Clock`** (default param + gọi thẳng) và **`?? Date()` che timestamp hỏng** thay vì throw như `ReviewService.fetchSnapshot` | `Seeder.swift:29` · `VocabRepository.swift:134,168,304` · `ExportService.swift:220,329` · `AnalysisAgentStore.swift:123` · `ReadingSession.swift:79` |
| A5 | **Xử lý `database == nil` thiếu nhất quán:** 28× `guard let database` trả ≥ 6 kiểu (`0`, `nil`, `false`, `[]`, silent, throw); `importRows` ném `.emptyFile` ("File rỗng…") sai ngữ nghĩa | `AppModel.swift:745` (+27 chỗ) |
| A6 | **Code chết/trùng:** `AppModel.reviewQueue` (0 ref), `currentReviewSnapshot` (chỉ ghi, không ai đọc), `saveLearningSettings(cefrLevel:)` (0 caller); `CollectionOverview` = bản sao 1-1 `VocabRepository.CollectionSummary`; `ShutterPressStyle` khai báo 2 lần; `addAgent` viết 2 lần; key `"appTheme"` literal 2 nơi; 11× `SystemClock()` rải trong `AppModel` | `AppModel.swift:97,113,115-124,403,512` · `RootView.swift:240` = `CaptureView.swift:444` · `SettingsView.swift:15,319` · `ReadoApp.swift:176` |
| A7 | **Concurrency — cần kiểm chứng:** `AppModel` là `@Observable` không `@MainActor`, app target `SWIFT_VERSION = 5.0`; `analyzeCurrentImage()`/`loadReviewQueue()` async non-isolated mà ghi state → có thể ghi off-main | `AppModel.swift:23-24,225-271,332-360` · `project.pbxproj:511` |
| A8 | **Doc lệch code:** conventions §2 liệt kê 3 thư mục Kit (Time/Database/Review) trong khi thực tế 14, dòng "KHÔNG chạy SQL trực tiếp?" còn dấu hỏi; `proxy/prompt.py` `VERSION = 1` ghi "Khớp Prompt.swift" trong khi app v5; `docs/session-brief.md` §1 dừng ở 2026-09-26 (227/228, "T2/T3 chưa làm") trong khi HEAD đã có motivation-r1 T1–T3 và ux-polish-r1 T1–T5 (`docs/plans/ux-polish-r1.md` ghi 244/245) — hook SessionStart nạp đúng bản cũ này vào mỗi session | `coding-conventions.md:19-34` · `proxy/prompt.py:1,5` ↔ `Prompt.swift:13` · `session-brief.md:19` |

### Phát hiện B — cấu trúc (refactor có kế hoạch, mỗi mục cần `/rplan` riêng)

| # | Phát hiện | Bằng chứng |
|---|---|---|
| B1 | **`AppModel` = god facade:** 750 dòng, 36 hàm, 11 nhóm việc (MARK) + 5 cờ điều hướng "hộp thư" (`pendingRecapture`, `pendingSettingsNavigation`, `pendingHubNavigationID`, `shutterTargetCollectionID`, `suppressFloatShutter`). ~20 hàm chỉ forward xuống Kit + `reloadOverview()`. Nghiệp vụ không test được: `grade` (settings→scheduler→record→leech→mastery), `toggleReviewPriority`, add/remove/replace/togglePin | `AppModel.swift:366-385,590-726` |
| B2 | **`ReviewQueueView` 824 dòng, 18 `@State`** = state machine trong view (index, undo, tally, 2 toast, scope); `loadQueue` reset tay ~12 biến; nguồn sự thật đôi (`model.reviewItems` copy sang `@State items`) | `ReviewQueueView.swift:14-47,561-679` |
| B3 | **Luồng capture→analysis nhân bản** ở `RootView` và `StreakCalendarView`, dựa 3 cờ hộp thư → điểm vào thứ 3 phải chép lại | `RootView.swift:116-151` · `StreakCalendarView.swift:36-54` |
| B4 | **File gộp nhiều màn; design system nằm trong file `@main`:** `RootView` (tab+route+FloatShutter+HomeTab ~210 dòng+MasteryRing+KhoTab ~170 dòng); `ReadoApp.swift` chứa Theme/AppTheme/Motion/Haptics/card/chromeGlass; `SettingsView` chứa `AgentFormSheet` ~185 dòng; `AnalysisView` chứa 4 component. `app/Reado/` phẳng 17/19 file vì `pbxproj_tool.py` ghi `path = {basename}` | `RootView.swift:208-661` · `ReadoApp.swift:10-169` · `pbxproj_tool.py:170,375` |
| B5 | **Data-access Kit:** 141 `row[i]` theo vị trí ở 13 file (`ExportService` 56, `VocabRepository` 24); danh sách cột lặp giữa SELECT/UPDATE; `VocabRepository` 443 dòng gồm 4 vai trò; `OpenAICompatClient` 484 dòng (transport+SSE+trích JSON+map lỗi); 3 nơi tự dựng URLSession (`OpenAICompatClient`, `ReadoProxyClient`, `AgentKeyChecker`) | `ReviewService.swift:12-47,62-103` · `OpenAICompatClient.swift:152-465` |
| B6 | **Dev-loop:** 1 `#Preview` toàn app (`AppModel.init` mở DB thật trên đĩa, không inject); `AnalysisTests.swift` 1147 dòng/1 class/≥ 8 thành phần + stub; `ReadoKitTests` chỉ 37 dòng | `AppModel.swift:126-151` · `AnalysisTests.swift:7,1043-1147` |

### Phát hiện C — theo dõi, chưa làm (đo trước, gắn task NFR 3.13)

- `StreakCalendarService.load` quét toàn `review_logs` trên main (`StreakCalendar.swift:64`).
- `reloadOverview()` 25 chỗ gọi × ≥ 6 truy vấn + tra Keychain mỗi agent, đồng bộ trên main.
- `ReviewQueue.loadFullQueue` nạp toàn bộ due + snapshot.

## Tầng 1 — HLD

### Ranh giới Reado vs ReadoKit (nguyên tắc đích)

- **ReadoKit** giữ mọi rule dữ liệu/nghiệp vụ dưới dạng enum static / value type test được: chấm + leech + mastery, ghim Home, ưu tiên ôn, phiên ôn (index/undo/tally), truy vấn.
- **Reado (app)** giữ UI, điều hướng, platform (camera, notification, TTS), `@Observable` cầu nối. `AppModel` chỉ còn là composition root: mở DB, giữ clock/services, forward.
- Không đưa `AppModel` sang Kit (Kit `.macOS(.v13)` không có Observation).

### Nên giữ, không làm

Enum service tĩnh `X.f(on: db, …)` · không tách Kit thành nhiều SPM target (tốn pbxproj thủ công, lợi ít) · không thêm dependency/DI framework (luật cứng) · chưa i18n catalog (1 user, tiếng Việt) · nhân rộng mẫu `AgentSecretStore` + `StubURLProtocol`.

### Protocol / transaction

- `ReviewService.record` / `undo` **không đổi**. T5 chỉ gọi lại theo đúng thứ tự cũ: `readSettings → ReviewScheduler.grade → ReviewService.record (UPDATE cards + INSERT review_logs, 1 transaction) → LeechService.evaluateAfterGrade → Mastery.crossed`.
- Không transaction mới, không đổi schema. `GradeResult` chuyển từ app sang Kit (T5).

### File cấm

`project.pbxproj` sửa tay (dùng `scripts/pbxproj_tool.py`; T10 nâng chính tool) · `Migration.swift` · `ReviewService.record/undo` · thuật toán trong `ReviewScheduler`.

### Luật cứng phải giữ (CLAUDE.md §4)

Không `unique` trên `vocab_items` · FSRS chỉ qua swift-fsrs `defaultWv6` · FR-07/FR-13 là bia mộ · không ảnh trang vào SQLite · `cards.state` 4 giá trị · `review_logs` snapshot TRƯỚC khi chấm, cùng transaction · timestamp UTC `Z` + uuid có gạch · không thêm dependency · Q-11 còn mở, không tự chốt.

## Tầng 2 — Tasks

Thứ tự khuyên: **Phase 1** (T1 → T2 → T3 → T4) · **Phase 2** (T5 → T6 → T7 → T8 → T9) · **Phase 3** (T10 → T11 → T12) · **Phase 4** (T13 → T14 → T15 → T16). Phụ thuộc: T11 cần T10; T12 cần T11; T9 nên sau T5–T8; T13 cần `AppModel.init(database:)`.

**Baseline test:** không tin số trong file này. Trước mỗi task chạy `scripts/test.sh` một lần để lấy số thật (số ghi gần nhất là 244/245 ở `docs/plans/ux-polish-r1.md`; T5 của plan đó còn "chờ full suite"; `docs/session-brief.md` §1 đã cũ). "Xanh" = `** TEST SUCCEEDED **`, số pass không giảm so với baseline vừa đo + test mới của task.

### Phase 1 — đúng luật, hết nuốt lỗi

#### T1 — `kit-boundary-hygiene` (A2 + A3 + A4)

- **Files:** `ReadoKit/Review/ReviewScheduler.swift` (`engine`, `parameters`, `grade(card:)`, `CardStateCode.from/toState` → `internal`; thêm `public var weightCount: Int` cho test, không lộ kiểu FSRS; ghi lý do cạnh `@unchecked Sendable`) · `Review/CardSnapshot.swift` (`schedulerCard` → `internal`) · `Vocab/VocabRepository.swift` (thêm `defaultCollectionID(on:)` dùng ở `saveCapture`; bỏ default `now: Date = Date()`; `?? Date()` → `throw DatabaseError.failed` theo mẫu `ReviewService.fetchSnapshot`) · `Database/Seeder.swift`, `Export/ExportService.swift` (bỏ default `now`) · `Analysis/AnalysisAgentStore.swift` (`add` nhận `now`) · `Session/ReadingSession.swift` (throw) · `Reado/AppModel.swift` (`matureKeysForCapture` gọi `defaultCollectionID`) · sửa call site (`grep -rn` `Seeder.seed`, `saveCapture`, `fetchBundle`, `AnalysisAgentStore.add`).
- **Test:** `ReviewSchedulerTests` dòng 22 đổi sang `weightCount`; thêm 1 test `defaultCollectionID` (dùng `Fixtures.seededDB()`); thêm 1 test timestamp hỏng → throw (UPDATE thẳng cột `created_at` rồi gọi `allCollections`/`listSessions`). Toàn suite cũ vẫn xanh.
- **DoD:** suite xanh · `grep -rnE 'public .*\b(FSRS|FSRSParameters|Card|CardState|RecordLogItem)\b' app/ReadoKit/Sources` rỗng · `grep -rn 'Date()' app/ReadoKit/Sources` chỉ còn `Clock.swift`, `DebugTrace`, đo thời gian ở `OpenAICompatClient` · `grep -rnE '"(SELECT|INSERT|UPDATE|DELETE) ' app/Reado` rỗng.

#### T2 — `appmodel-cleanup` (A1 + A5 + A6)

- **Files:** `Reado/AppModel.swift` · `Reado/Screens/ReviewQueueView.swift` · `Reado/RootView.swift` · `Reado/Capture/CaptureView.swift` · `Reado/SettingsView.swift` · `Reado/ReadoApp.swift` (+ mọi nơi dùng `CollectionOverview`/`totalItems`).
- **Việc:**
  1. `grade`/`undoReview` lỗi → set `reviewError` (hoặc trả lỗi cho view hiện toast/alert); bỏ 2 `catch` comment-only ở `ReviewQueueView.swift:601-603,647-649` (`:677` của `loadQueue` đã đúng).
  2. `requireDatabase() throws` → `ReviewError.modelUnavailable`; hàm đọc UI giữ `[]`/`nil` có chủ đích, hàm ghi throw; bỏ `.emptyFile` sai ở `importRows`.
  3. Xoá `reviewQueue`, `currentReviewSnapshot`, `saveLearningSettings(cefrLevel:)`; `typealias CollectionOverview = VocabRepository.CollectionSummary` (đổi `totalItems` → `wordCount` ở view); gom `ShutterPressStyle` một nơi; `addAgent` một nơi (`AppModel`, `SettingsView` gọi lại + `reloadAgents()`); `enum PrefKey` cho `"appTheme"`, `"reado.onboarding.*"`, `"reado.appliedForestDefault"`; một thuộc tính clock thay 11× `SystemClock()`.
- **Test:** app layer không unit-test được → DoD dựa suite xanh + fen thử tay: (a) chấm/undo thẻ bình thường; (b) ép lỗi (`UPDATE settings SET fsrs_version='fsrs-5' WHERE id=1` trên DB simulator) → bấm chấm phải hiện lỗi, không im lặng; trả lại `fsrs-6` sau khi thử.
- **DoD:** build + suite xanh · `grep -n 'AppModel đã set reviewError' app/Reado` rỗng hoặc đúng sự thật · `grep -c 'guard let database' app/Reado/AppModel.swift` giảm rõ rệt.

#### T3 — `concurrency-audit` (A7)

- **Files:** đọc `/tmp/build.log`; sửa `Reado/AppModel.swift` nếu xác nhận.
- **Việc:** `scripts/test.sh build SWIFT_STRICT_CONCURRENCY=complete` (cờ dòng lệnh, **không** sửa pbxproj); lọc cảnh báo liên quan `AppModel`, `Task { @MainActor … }`; xác nhận ghi off-main thì thêm `@MainActor` cho `AppModel` (+ sửa call site cần `await`/`MainActor.run`).
- **Test:** suite không link app target nên không bị ảnh hưởng; fen thử tay chụp→phân tích→lưu và ôn.
- **DoD:** số + nhóm cảnh báo dán vào journal; nếu áp `@MainActor`: build xanh, không cảnh báo mới, hành vi luồng phân tích không đổi. Không bật strict concurrency vĩnh viễn ở task này.

#### T4 — `docs-drift` (A8)

- **Files:** `docs/agent/coding-conventions.md` (§2 layout thật 14 thư mục; dòng 22 chốt "app không chạy SQL — chỉ qua ReadoKit"; §1 cho phép `LocalizedError` tiếng Việt trong Kit nếu fen OK Q mở #3) · `docs/decisions-log.md` (ADR cho T1–T3 — grep số ADR kế tiếp) · `proxy/prompt.py` (chỉ sửa docstring khi fen chốt Q mở #1) · nhắc `/rhandoff` cập nhật `docs/session-brief.md` §1.
- **Test:** `node scripts/verify/check-doc-links.mjs` exit 0.
- **DoD:** layout trong conventions khớp `ls app/ReadoKit/Sources/ReadoKit`; không còn dấu "?" ở quy tắc; ADR có số; không sửa dòng đã chốt.

### Phase 2 — nghiệp vụ xuống Kit, AppModel mỏng (strangler, sau Phase 1)

#### T5 — `kit-grade-usecase`

- **Files:** `ReadoKit/Review/ReviewGrader.swift` (mới; `GradeResult` chuyển từ `AppModel` sang Kit) · `Reado/AppModel.swift` (`grade` còn guard + gọi Kit) · `ReadoTests/ReviewGraderTests.swift` (mới, `pbxproj_tool.py add --group ReadoTests --target ReadoTests`).
- **Test:** (1) chấm Good thẻ new → `cards` + 1 dòng `review_logs` cùng cập nhật; (2) `crossedMastery` true khi stability vượt 21 (`Mastery.crossed`); (3) Again lần thứ 6 → leech suspend SAU khi ghi log; (4) settings hỏng (`fsrs_version` sai) → throw và **không** ghi log/cards.
- **DoD:** suite xanh · `git diff` không chạm `ReviewService.record/undo`.

#### T6 — `kit-pin-scope-rules`

- **Files:** `Settings/HomePinService.swift` (+`add/remove/replace/toggle` trả `[String]`) · `Settings/ReviewScopeService.swift` (+`togglePriority`) · `Reado/AppModel.swift` (forward + `reloadOverview()`) · `ReadoTests/HomePinTests.swift`, `ScopedReviewTests.swift`.
- **Test:** add trùng → không đổi; đủ 5 → `.tooMany`; replace pin đã mất → coi như add; toggle kho tạm → `.isInbox`; togglePriority thứ 4 → `.tooMany`; bật ưu tiên thì `reviewAll` tắt.
- **DoD:** suite xanh · các hàm pin/scope trong `AppModel` ≤ 3 dòng · thông điệp lỗi hiện có không đổi.

#### T7 — `review-session-kit`

- **Files:** `ReadoKit/Review/ReviewSession.swift` (mới; value type: items, index, undo entry đúng 1 bước — FR-12, `SessionTally`, `reset`) · `Reado/Screens/ReviewQueueView.swift` (chỉ render + gesture + toast) · `ReadoTests/ReviewSessionTests.swift` (mới). Tái dùng `SessionTally`, `SwipeCommit`, `ReviewQueue.loadFullQueue`.
- **Test:** chấm 3 thẻ → index 3, `tally.reviewed` 3; undo → index 2, tally hoàn; undo lần 2 liên tiếp = no-op; `reset(scope:)` xoá sạch undo/tally; hết hàng đợi → kết thúc.
- **DoD:** suite xanh · `ReviewQueueView` giảm rõ (mục tiêu ≤ ~600 dòng, ≤ 10 `@State`) · không còn nguồn sự thật đôi · fen thử tay swipe/undo/đổi scope/hoàn thành phiên, UX không đổi.

#### T8 — `capture-flow-coordinator`

- **Files:** `Reado/Capture/CaptureFlow.swift` (mới: `@Observable` + `enum CaptureOutcome { saved(hubID), recapture, openSettings, cancelled }` + `View.captureFlow(...)`) · `RootView.swift` · `StreakCalendarView.swift` · `AnalysisView.swift` · `AppModel.swift` (bỏ `pendingRecapture`, `pendingSettingsNavigation`, `pendingHubNavigationID`).
- **Test:** phần thuần (trạng thái → outcome) đặt ở Kit nếu tách được; còn lại e2e tay: chụp→phân tích→lưu→hub; ảnh mờ→chụp lại; lỗi agent→Mở Cài đặt; vào từ Lịch streak.
- **DoD:** khối `fullScreenCover` + `sheet` chỉ còn 1 bản · 3 cờ hộp thư biến mất · 3 nhánh dismiss giữ hành vi cũ (đối chiếu `RootView.swift:127-151` trước khi sửa).

#### T9 — `appmodel-split` (cần `/rplan` riêng: đụng mọi view + `Environment` injection)

- **Files:** `AppModel.swift` → composition root `init(database:clock:)` · mới `LibraryModel` (collections/vocab/sessions/pins/scope), `ReviewModel`, `SettingsModel`, `AppRouter` · mọi view đổi `@Environment`.
- **Test:** logic thuần còn lại đã ở Kit (T5–T7); e2e tay toàn app.
- **DoD:** `AppModel.swift` ≲ 200 dòng, chỉ bootstrap DB + giữ services · mỗi view chỉ đọc model nó cần.

### Phase 3 — thư mục & file (fen chọn: nâng `pbxproj_tool.py`)

#### T10 — `pbxproj-subdir`

- **Files:** `scripts/pbxproj_tool.py` (`add --subdir`; lệnh `move` = `git mv` + đổi `path =`; `check` so đường dẫn tương đối thay vì basename — `:375`) · `scripts/test_pbxproj_tool.py` (mới, `python3 -m unittest`) · `CLAUDE.md` §7 (bỏ ghi chú "chỉ basename") · `.claude/hooks/guard.py` chỉ nếu cần.
- **Test:** unittest trên bản sao pbxproj: add vào subdir → đủ 4 tham chiếu và `path = Sub/X.swift`; move → chỉ đổi `path`, không nhân đôi; check bắt file thiếu tham chiếu; chạy `check` trên pbxproj thật vẫn OK.
- **DoD:** unittest xanh · `python3 scripts/pbxproj_tool.py check` OK · fen chạy `scripts/test.sh build` trên Mac sau một lần `move` thử.

#### T11 — `app-folders` (cần T10)

- **Files:** chỉ `git mv` + `pbxproj_tool.py move`, không đổi nội dung. Layout đích: `App/` (ReadoApp, AppModel) · `DesignSystem/` · `Shell/` (RootView, ShellTabBar) · `Home/` (OnboardingChecklistSection, HomePinToggle) · `Library/` (CollectionDetailView, ReadingSessionView, ImportView, ExportView) · `Capture/` (+CameraController) · `Analysis/` · `Review/` (ReviewQueueView, SessionDoneView, StreakCalendarView) · `Settings/` · `Platform/` (NotificationScheduler, Pronunciation).
- **Test:** `pbxproj_tool.py check` + suite.
- **DoD:** `git diff -M` toàn rename 100% · suite xanh · `python3 scripts/repo_map.py` phản ánh thư mục mới.

#### T12 — `split-big-views` (cần T11)

- **Files:** `ReadoApp.swift` → `DesignSystem/{Theme,Motion,Haptics,Modifiers}.swift` (giữ `ReadoApp` chỉ `@main`) · `RootView.swift` → `RootView`, `HomeTabView`, `KhoTabView`, `FloatShutter`, `MasteryRing` · `SettingsView.swift` → `AgentFormSheet.swift` (+ `AgentPreset`, `KeyCheck`) · `AnalysisView.swift` → `ReviewCardRow`, `SegmentBlock`, `VerificationBadge`, `AnalysisSkeleton`.
- **Test:** không đổi hành vi → `check` + suite.
- **DoD:** mỗi file ≲ 350 dòng, một màn/component chính · `private` → `internal` tối thiểu · diff chỉ là di chuyển.

### Phase 4 — dev-loop & data-access (rủi ro tăng dần, làm cuối)

#### T13 — `previews`

- **Files:** `AppModel.swift` (`init(database:clock:)`; `init()` giữ hành vi cũ) · `Reado/PreviewSupport.swift` (mới, `#if DEBUG`; `SQLiteDatabase(inMemory:)` + seed theo mẫu `Fixtures` ở `ReadoTests/TestSupport.swift`) · `#Preview` cho Home, Kho, Hub, Ôn, Phân tích, Cài đặt.
- **Test:** build Debug; mở canvas Xcode cho 6 màn.
- **DoD:** ≥ 6 `#Preview` chạy được, không đụng DB thật · Release không chứa `PreviewSupport`.

#### T14 — `split-analysis-tests`

- **Files:** `ReadoTests/AnalysisTests.swift` → ~6 file theo MARK (Decoder/Normalizer/Verify · AgentStore/Factory · OpenAICompatClient · ReadoProxyClient · ReviewDraft) + `NetworkStubs.swift` (`StubURLProtocol`, `RequestCapture`, `AttemptCounter`, `ProgressCapture`); `testSaveCapturePersists…` (`:988`) → `VocabularyListTests`; file mới qua `pbxproj_tool.py add`.
- **Test:** số hàm test không đổi.
- **DoD:** `check` OK · tổng pass bằng baseline · mỗi file test ≲ 300 dòng.

#### T15 — `kit-row-and-repos` (làm cuối; mỗi file một commit)

- **Files:** `Database/Database.swift` (+`SQLiteRow` tra theo tên cột) · `Export/ExportService.swift` (đầu tiên — 56 chỗ) → `Vocab/VocabRepository.swift` (tách `CollectionRepository`/`VocabRepository`/`TermNormalizer`) · `Analysis/AnalysisHTTP.swift` (mới, dùng chung 3 client) · `OpenAICompatClient.swift` (chuyển `extractAnalysisJSON/objectCandidates/removingThinkBlocks`, `:360-429`, sang phía `AnalysisResponseDecoder`).
- **Test:** suite hiện có làm lưới an toàn (`ExportTests`, `VocabularyListTests`, `AnalysisTests`) + test mới cho `SQLiteRow`.
- **DoD:** suite xanh sau **mỗi** file · API public đổi tối thiểu · `grep -c 'row\[[0-9]' <file>` = 0 ở file đã chuyển.

#### T16 — `repo-hygiene`

- **Files:** xét chuyển `qr/`, `idea.md`, `AGENTS.md` (stub), `ui-lab/` sang `docs/archive/`; sửa link trỏ tới.
- **Test:** `grep -rn` không còn tham chiếu đường dẫn cũ; `node scripts/verify/check-doc-links.mjs` exit 0.
- **DoD:** **fen duyệt danh sách** trước khi `git mv`.

## Không đo được ở review này

Toàn bộ là đọc tĩnh, chưa build: A7 (concurrency), hiệu năng ở mục C, và mọi giả định "đổi `public` → `internal` không vỡ call site" đều phải xác nhận bằng `scripts/test.sh` trên Mac.
