# Plan: verify-nav-r1

> **Trạng thái:** open (2026-10-01) - launch argument mở thẳng màn cho agent chụp simulator; T1 xong (`docs/journal/2026-10-01.md`), T2/T3 chưa làm

## Context
Máy agent không có idb/XCUITest, `scripts/sim_screens.sh` chỉ chụp được màn mở đầu (Home). Vì vậy brief §2.7 còn treo nhiều mục "chưa xem tay" (Ôn thêm, alert lỗi, reencounter, Capture, Settings, accent lệch). Mục tiêu: chỉ bằng launch argument của bản DEBUG, agent mở thẳng được một màn (kèm theme và seed), chụp light/dark rồi tự đọc PNG, không cần ai chạm tay.

## Spec
- FR / journey: không có FR mới. Đây là công cụ dev, chỉ có ở bản DEBUG, giống `READO_DEV_DEMO_CSV` / `READO_DEV_AIBOX_KEY` (`AppModel.swift:122-158`) và ngoại lệ DEBUG ở ADR-037. Màn được mở là J1–J6 có sẵn, không đổi hành vi nào.
- Nguyên lý: không phục vụ trực tiếp nguyên lý nào trong vision. Đây là hạ tầng kiểm chất lượng, giúp verify UI nhanh hơn. Không đụng mục "Chống lại" nào, không đụng NG nào.
- In-scope:
  - Launch argument (chỉ DEBUG): `-ReadoScreen home|kho|review|review-extra|collection:<id|tên>|settings|streak|data|capture|analysis-fixture|encounter-sheet`, `-ReadoTheme forest|sepia|indigo|system`, `-ReadoSeed demo|demo-reviewed|empty`, `-ReadoAlert dup-name|pin-limit`.
  - Hàm parse thuần ở ReadoKit, có test kit. App chỉ map kết quả sang state điều hướng.
  - Seed `demo-reviewed`: import CSV demo, sau đó chấm bằng FSRS thật với `now` lùi về quá khứ, rải trên khoảng 20 ngày. Nhờ vậy có heatmap, có dueToday = 0, có thẻ Ôn thêm, và có vài dòng `encounters`.
  - Fixture `scripts/fixtures/analysis-demo.json` (segments chứa từ demo như keystone/resilient), đọc qua `AnalysisResponseDecoder.decode`.
  - `sim_screens.sh open <screen> [--theme x] [--seed y] [--alert z] [--fresh]`, chạy xong thì `shot` như cũ.
  - Skill `reado-ui` bước Verify: dùng `open` thay cho "điều hướng tới màn".
  - Chạy lần lượt các mục ở brief §2.7, báo pass / fail / vẫn cần tay.
- Out-of-scope / không đụng:
  - Bản Release: call site bọc `#if DEBUG`, nên Release không đọc argument nào.
  - Không thêm dependency, không đổi schema hay migration, không có transaction mới (seed gọi lại `ReviewService.record`, `CSVImport.importRows`, `EncounterRepository.insertSeen` có sẵn).
  - Thao tác cần chạm, như kéo thẻ, chấm Quên rồi kiểm due mai, hay "lượt 2 không ra thẻ cũ": dựa vào test kit đã có (`ExtraReviewTests`). Ảnh chụp chỉ dùng để kiểm hiển thị.
  - Sheet chọn/tạo bộ trong Capture và `AgentFormSheet`: cần chạm, nên ghi "cần tay".
  - Lỗi "chưa có agent" khi chụp: cần ảnh chụp thật để đi vào `analyzeCurrentImage`. Ngoài phạm vi, ghi "cần tay".
  - Migration v3→v4 trên DB thật (cài đè bản cũ): cần tay.
  - Camera permission-denied (brief §2.4): cần tay.
- Q mở / chỗ thiếu hợp đồng: không có. Không đụng Q-11.

## Tầng 1 — HLD
- **ReadoKit** (`Sources/ReadoKit/Shell/DebugLaunch.swift`, mới; không bọc `#if DEBUG` để test kit được):
  - `public struct DebugLaunch: Equatable { screen: Screen?; theme: String?; seed: Seed?; alert: Alert?; problems: [String] }`
  - `enum Screen { home, kho, review, reviewExtra, collection(String), settings, streak, data, capture, analysisFixture, encounterSheet }`; `enum Seed { demo, demoReviewed, empty }`; `enum Alert { dupName, pinLimit }`.
  - `static func parse(_ arguments: [String]) -> DebugLaunch`: đọc cặp `-Key value`. Giá trị lạ hoặc thiếu thì ghi vào `problems`, không crash. `collection:` mà rỗng cũng là problem. Theme chỉ trả chuỗi thô, app tự validate bằng `AppTheme(rawValue:)` (AppTheme nằm ở app).
  - `DevSeed` (`Sources/ReadoKit/Settings/` hoặc thư mục `Dev/` mới): `static func gradeHistory(on db, now: Date, days: Int)`. Hàm này lấy thẻ `new`, chấm Good hoặc Hard bằng `ReviewScheduler` + `ReviewService.record` với `now - k ngày`, mỗi thẻ một transaction (đúng luật snapshot trước khi chấm), rồi `insertSeen` vài vocab. Chỉ chạy khi chưa có `review_logs`.
- **Reado (app)**, mọi call site bọc `#if DEBUG`:
  - `ReadoApp.init`: parse `ProcessInfo.processInfo.arguments` một lần. Có theme thì ghi `UserDefaults` `appTheme`, đồng thời bật `reado.appliedForestDefault = true`. Bẫy: nếu không bật cờ thì `-ReadoTheme system` trên DB mới bị `applyForestDefaultIfNeeded` đổi về forest.
  - `AppModel`: thay `seedDevDemoCSVIfNeeded` (đọc env `READO_DEV_DEMO_CSV`) bằng `seedDevIfNeeded(seed:)`. Thư mục fixture đi qua env `READO_DEV_FIXTURES` (simulator đọc được đường dẫn máy host, đúng cơ chế cũ). `demo` thì import `demo-vocab.csv`. `demo-reviewed` thì import xong gọi `DevSeed.gradeHistory`. `empty` thì không làm gì (để xem onboarding).
  - `RootView.onAppear` → `applyDebugScreen(_:)` map sang state:
    - `home`, `kho`, `review`: đặt `selectedTab`.
    - `review-extra`: `model.shell.pendingReviewMode = .extra` rồi chọn tab review (đúng đường CTA Home).
    - `collection:x`: tìm `model.collections` theo id, không thấy thì theo tên. Sau đó `selectedTab = .kho` và `khoPath = [.hub(id)]`.
    - `settings`, `streak`, `data`: `homePath = [route]`.
    - `capture`: `showCapture = true`.
    - `analysis-fixture`: decode JSON, gán `model.capture.analysisResult`, rồi `showAnalysis = true`.
    - `encounter-sheet`: giống analysis-fixture, thêm cờ `model.shell.debugOpenFirstEncounter` (thuộc `ShellSignals`, bọc `#if DEBUG`). `AnalysisView` đọc cờ trong `.task`, đợi khoảng 0.6s cho sheet ổn định, lấy match đầu tiên của `encounterMatcher` trên segment đầu, gán `encounterSelection` rồi xoá cờ.
  - `-ReadoAlert`: dùng đường thật. `dup-name` gọi `model.createCollectionOrAlert(name: <tên bộ demo đã có>)`, `pin-limit` ghim tới bộ thứ 6 qua hàm ghim có sẵn. Hàm được gọi sau khi màn đã lên (delay ngắn), nên khi đi cùng `analysis-fixture` thì kiểm luôn được việc alert hiện trong sheet.
  - Có `problems` hoặc theme lạ thì gán `model.alertMessage = "Launch arg lạ: …"`. Lỗi hiện ngay trên ảnh chụp, không bao giờ âm thầm mở sai màn.
- **Script** `scripts/sim_screens.sh`:
  - Thêm nhánh `open`: `bootstatus`, sau đó `--fresh` thì gỡ cài và cài lại bản build gần nhất, rồi grant quyền, rồi `SIMCTL_CHILD_READO_DEV_FIXTURES=… xcrun simctl launch --terminate-running-process … -ReadoScreen x [-ReadoTheme y] [-ReadoSeed z] [-ReadoAlert w]`, rồi `sleep` khoảng 4s.
  - Không có `--seed` thì mặc định `demo`. Seed chỉ áp khi kho trống, nên đổi seed phải kèm `--fresh`. Script in ra cảnh báo này.
  - Lệnh mặc định (build + cài + mở) giữ nguyên hành vi cũ, đổi sang dùng `-ReadoSeed demo`.
- Protocol / transaction: không có protocol mới. Seed tái dùng `ReviewService.record` (một transaction cho mỗi lần chấm).
- File cấm: `project.pbxproj`. File mới đặt trong thư mục synchronized, Xcode tự nhận. Không sửa schema/`Migration`.
- Lưu ý working tree: đang có diff chưa commit (`FloatShutter`, `ShellTabBar`, MASTER, skill reado-ui, settings.json) — đã xem qua, là fix accent lệch có trước, không đụng tới trong task này.

## Tầng 2 — Tasks
1 task = 1 session. Làm theo thứ tự T1 → T2 → T3.

### T1 — parse + điều hướng + theme + `open` (làm trước) — ✅
- Files: `ReadoKit/Shell/DebugLaunch.swift` (mới), `ReadoKitTests/DebugLaunchTests.swift` (mới), `App/ReadoApp.swift`, `App/RootView.swift`, `scripts/sim_screens.sh`, `.claude/skills/reado-ui/SKILL.md` (bước Verify 2 và 4).
- Phạm vi màn: home, kho, review, review-extra, collection, settings, streak, data, capture, cùng `-ReadoTheme`. Seed giữ nguyên CSV demo (chỉ đổi cách truyền sang `-ReadoSeed demo`).
- Test: `scripts/test.sh kit`. Các ca test: mỗi screen hợp lệ, `collection:` rỗng, key lặp lại (lấy giá trị cuối), giá trị lạ vào `problems`, thiếu value, argument của hệ thống (`-NSDoubleLocalizedStrings` và tương tự) bị bỏ qua. Sau đó `scripts/test.sh build`, rồi `open` từng màn và `shot`, đọc PNG.
- DoD: kit xanh, build xanh. Mỗi màn T1 có cặp ảnh light/dark đúng màn. `open home --theme sepia` ra accent nâu. Gõ sai screen thì thấy alert "Launch arg lạ". Skill reado-ui đã đổi sang dùng `open`.

### T2 — seed `demo-reviewed` + màn fixture + `-ReadoAlert`
- Files: `ReadoKit/.../DevSeed.swift` (mới) + test kit, `App/AppModel.swift` (seed), `App/AppState.swift` (cờ DEBUG), `Analysis/AnalysisView.swift` (mở encounter đầu tiên), `App/RootView.swift`, `scripts/fixtures/analysis-demo.json` (mới), `scripts/sim_screens.sh` (`--seed`, `--alert`).
- Test kit `DevSeedTests`: sau `gradeHistory` thì `dailyProgress.dueToday == 0`, `ReviewQueue.extraAvailableCount > 0`, `review_logs` có ≥ 10 ngày khác nhau, mọi `cards.state` thuộc 4 giá trị, gọi lần 2 thì không làm gì. Sau đó build, `open analysis-fixture`, `open encounter-sheet`, `open home --alert dup-name`, `open analysis-fixture --alert dup-name`.
- DoD: kit xanh, build xanh. Ảnh cho thấy Home có CTA "Ôn thêm" và hàng "Gặp lại N từ" (N > 0), heatmap có nhiều mức màu, AnalysisView có gạch chân chấm, EncounterSheet chồng lên Analysis, alert hiện cả ở root lẫn trong sheet.

### T3 — chạy verify brief §2.7
- Files: `docs/session-brief.md` §2.7 (cập nhật kết quả), `docs/journal/2026-10-xx.md`, ảnh trong `.tmp/screens/` (ngoài git).
- Việc: với mỗi mục §2.7 tới được bằng script, `open` rồi `shot` (theme forest + sepia nếu liên quan accent, có `size accessibility-extra-large` cho màn chính), đọc PNG, ghi vào bảng.
- Dự kiến phân loại:
  - **Tới được bằng script:** CTA Home mở `.extra`, heatmap, alert trùng tên / ghim > 5 (root + trong sheet), gạch chân + EncounterSheet, hàng "Gặp lại N từ", thanh 4 màu / `MasteryRing` ở hub, chip "Lưu vào" trên Capture, Settings ẩn agent builtin, accent FloatShutter/tab ở forest + sepia.
  - **Vẫn cần tay:** kéo/chấm thẻ (Quên thì due mai, lượt 2 không ra thẻ cũ: kit đã test logic), sheet chọn/tạo bộ, lỗi "chưa có agent" khi chụp, migration v3→v4, camera permission-denied.
- DoD: bảng pass / fail / cần tay được in ra chat. Mỗi mục fail có ảnh và mô tả lỗi; fix nằm ở task khác, không sửa trong T3. Brief §2.7 chỉ còn các mục cần tay và các mục fail.

## Verification (tổng)
- `scripts/test.sh kit` sau T1 và T2. Toàn bộ `scripts/test.sh` trước `/rhandoff` của T2.
- Kiểm Release không đọc arg: grep cho thấy mọi chỗ đọc `DebugLaunch.parse` / `ProcessInfo...arguments` ở app nằm trong `#if DEBUG`.
- `scripts/sim_screens.sh open <screen>` rồi `shot after-<screen>`, đọc PNG cả light lẫn dark.
