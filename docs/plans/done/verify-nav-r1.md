# Plan: verify-nav-r1

> **Trạng thái:** closed (2026-10-02) - launch argument mở thẳng màn cho agent chụp simulator; T1 + T2 xong (`docs/journal/2026-10-01.md`). T3: fen xem tay toàn bộ brief §2.7 trên simulator thật (Ôn thêm, Alert lỗi, Reencounter, Capture, Settings, prompt-v6, migration v3→v4, camera permission-denied) — tất cả pass, không có mục fail. Chi tiết: `docs/journal/2026-10-02.md`.

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
  - `AppModel`: thêm `seedDevIfNeeded` đọc `DebugLaunch.seed` rồi gọi `seedDevDemoCSVIfNeeded` (giữ nguyên, đọc env `READO_DEV_DEMO_CSV`) + `DevSeed.gradeHistory` tuỳ trường hợp. `nil`/`demo` → chỉ CSV (hành vi cũ). `demo-reviewed` → CSV rồi `gradeHistory`. `empty` → bỏ qua hẳn (xem onboarding trống). Fixture phân tích đi qua env riêng `READO_DEV_ANALYSIS_FIXTURE` (đọc ở `RootView`, không phải `AppModel`).
  - `RootView.onAppear` → `applyDebugScreen(_:)` map sang state:
    - `home`, `kho`, `review`: đặt `selectedTab`.
    - `review-extra`: `model.shell.pendingReviewMode = .extra` rồi chọn tab review (đúng đường CTA Home).
    - `collection:x`: tìm `model.collections` theo id, không thấy thì theo tên. Sau đó `selectedTab = .kho` và `khoPath = [.hub(id)]`.
    - `settings`, `streak`, `data`: `homePath = [route]`.
    - `capture`: `showCapture = true`.
    - `analysis-fixture`: decode JSON, gán `model.capture.analysisResult`, rồi `showAnalysis = true`.
    - `encounter-sheet`: giống analysis-fixture, thêm cờ `model.shell.debugOpenFirstEncounter` (thuộc `ShellSignals`, bọc `#if DEBUG`). `AnalysisView` đọc cờ trong `.task`, đợi khoảng 0.6s cho sheet ổn định, lấy match đầu tiên của `encounterMatcher` trên segment đầu, gán `encounterSelection` rồi xoá cờ.
  - `-ReadoAlert`: dùng đường thật. `dup-name` gọi `model.createCollectionOrAlert(name: Seeder.defaultCollectionName)`, `pin-limit` ép `HomePinError.tooMany` qua `HomePinService.set` 6 id giả (không cần 6 collection thật — `set` kiểm count trước khi validate từng id). **Chỉ áp dụng khi KHÔNG đi cùng `analysis-fixture`/`encounter-sheet`** — xem bug alert+sheet ở T2.
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

### T2 — seed `demo-reviewed` + màn fixture + `-ReadoAlert` — ✅
- Files: `ReadoKit/Dev/DevSeed.swift` (mới) + `ReadoKitTests/DevSeedTests.swift` (6 test), `App/AppModel.swift` (`seedDevIfNeeded`), `App/AppState.swift` (cờ `debugOpenFirstEncounter`), `App/AppModel+Collections.swift` (`debugTriggerPinLimitAlert`), `Analysis/AnalysisView.swift` (`.task` mở encounter đầu tiên), `App/RootView.swift` (`openDebugAnalysisFixture`/`applyDebugAlert`), `scripts/fixtures/analysis-demo.json` (mới), `scripts/sim_screens.sh` (`--seed`, `--alert`).
- Test kit `DevSeedTests` (6 ca): `dueToday == 0` + `extraAvailableCount > 0` sau `gradeHistory`; ≥ 10 ngày khác nhau trong `review_logs`; mọi `cards.state` thuộc 4 giá trị đã biết và không còn thẻ `new`; có dòng `encounters` trong 7 ngày; gọi lần 2 không nhân đôi; kho rỗng thì không làm gì.
- **Phát hiện ngoài kế hoạch — bug có sẵn, không phải do task này:** `RootView` và mỗi sheet (`AnalysisView`) cùng gắn `.appErrorAlert()` (`Shared/ErrorAlert.swift`) trên CHUNG `model.alertMessage`. Set `alertMessage` trong lúc một sheet đang mở (bất kể đồng bộ hay trễ 1.5s) làm UIKit coi RootView "already presenting" — log `com.apple.UIKit:Presentation`, "Attempt to present ... which is already presenting ..." — và huỷ CẢ sheet lẫn alert, không chỉ riêng alert. Xác nhận bằng `xcrun simctl spawn log stream` lúc debug `-ReadoAlert` + `analysis-fixture`. Vì vậy DoD gốc "alert hiện cả ở root lẫn trong sheet" **bỏ** — `RootView.applyDebugScreenIfNeeded` giờ bỏ qua `-ReadoAlert` khi đi cùng `analysis-fixture`/`encounter-sheet` (im lặng, không set `alertMessage` nữa vì chính nó cũng dính lỗi). Ghi vào `docs/session-brief.md` §2 cho owner — KHÔNG sửa `ErrorAlert.swift` ở task này (ảnh hưởng mọi sheet thật trong app, cần phiên riêng để kiểm kỹ).
- DoD (đã đạt, trừ câu alert+sheet đã bỏ ở trên): kit 347/347 xanh, build xanh, full suite 366/368 (2 skip opt-in cũ). Ảnh chụp thật trên simulator xác nhận: Home có "Xong phần hôm nay — Ôn thêm 20 thẻ" + "Gặp lại 5 từ tuần này"; heatmap `Lịch ôn` nhiều mức màu (21 ngày streak); `analysis-fixture` mở đúng AnalysisView với 4 từ gạch chân chấm (keystone/routine/resilient/discipline); `encounter-sheet` mở đúng EncounterSheet "keystone" chồng lên Analysis; `--alert dup-name`/`pin-limit` đứng riêng (không kèm sheet) hiện alert đúng; `analysis-fixture --alert dup-name` giờ mở sheet bình thường, không còn treo trắng màn.

### T3 — chạy verify brief §2.7 — ✅
- Files: `docs/session-brief.md` §2.4/§2.7 (cập nhật kết quả), `docs/journal/2026-10-02.md`.
- Việc: thay vì agent chụp (không có GUI), fen tự chạy `scripts/sim_screens.sh open <màn>` trên máy có Simulator GUI thật
  (mở qua Xcode DeviceHub, không phải `open -a Simulator` — máy fen không đăng ký tên app đó với Launch Services) và chạm
  tay trực tiếp.
- Kết quả — **tất cả pass**, không có mục fail hay mục cần hoãn:
  - Ôn thêm: trộn đúng cũ+mới, CTA Home mở đúng `.extra`, heatmap đổi màu rõ.
  - Alert lỗi: tạo/đổi tên bộ trùng, xoá/chuyển, ghim >5 (root + trong sheet) đều đúng.
  - Reencounter: gạch chân + "Nhận ra", hàng "Gặp lại N từ", thanh 4 màu/`MasteryRing`.
  - Capture: chip "Lưu vào", sheet chọn/tạo bộ.
  - Settings: ẩn agent builtin, lỗi "chưa có agent" khi chụp lúc chưa thêm key.
  - prompt-v6: `ReadingSessionView` thật qua Hub.
  - Migration v3→v4 trên DB thật (cài đè bản cũ).
  - Camera permission-denied: nút "Mở Cài đặt" bật đúng (gộp luôn §2.4, đóng chung đợt này).
  - Bonus ngoài §2.7 (q13-sense-filter-r1 vừa ship): nhóm "Đã thuộc · N" trên `analysis-fixture` — đóng sẵn, mở ra đúng 2 nghĩa, chọn tăng "Lưu (N)" đúng.
- DoD: không còn mục nào ở brief §2.7 — xoá cả mục, giữ pointer vào plan này + journal.

## Verification (tổng)
- `scripts/test.sh kit` sau T1 và T2. Toàn bộ `scripts/test.sh` trước `/rhandoff` của T2.
- Kiểm Release không đọc arg: grep cho thấy mọi chỗ đọc `DebugLaunch.parse` / `ProcessInfo...arguments` ở app nằm trong `#if DEBUG`.
- `scripts/sim_screens.sh open <screen>` rồi `shot after-<screen>`, đọc PNG cả light lẫn dark.
