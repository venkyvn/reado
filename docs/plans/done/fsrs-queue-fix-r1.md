# Plan: fsrs-queue-fix-r1

> **Trạng thái:** closed (2026-10-02) - T1/T2/T3 xong. T3: `elapsed_days` một định nghĩa (lib swift-fsrs tự ghi đè, bỏ `CardSnapshot.dayDiff`), docs `review.md` §4.1 cập nhật.

> Fen save 2026-09-30. Nguồn: review "FSRS đã best practice chưa" (session cloud, đối chiếu `swift-fsrs` @`4fbaf20`).
> 1 task tầng 2 / session, đóng bằng `/rhandoff`. Thứ tự: **T1 → T2 → T3**. T1 ✅ T2 ✅; T3 **chặn** tới khi chốt D-3 (dưới).
> Chưa code. Test phải chạy ở máy có Xcode (`scripts/test.sh`) — container cloud không build được.

## Spec
- **FR / journey:** FR-11 (hàng đợi, giờ chuyển ngày) · `solution-design.md` §9 ("queue so `due_at <= window.end`" — code đang so `now`, **code lệch spec**) · FR-12 (undo) · FR-19 (leech) · `research/review.md` §4.1 ("`reviewed_at` thắng"). Không GWT mới.
- **Nguyên lý:** vision "Retention Is A Solved Problem — Use The Solution" / NG-09 — dùng FSRS đúng cách, không tự viết. Không đụng mục "Chống lại" / NG nào.
- **In-scope:**
  1. Hạn ôn theo **ngày học** (`window.end`), không theo `now` — thẻ hẹn 21h hôm nay phải hiện từ sáng.
  2. Nhãn xem trước (4 nút) **= lịch thật được ghi** (fuzz của swift-fsrs seed theo timestamp → tính lại lúc bấm có thể lệch nhãn).
  3. Một `now` cho mỗi lần chấm (`AppModel.grade` đang gọi `SystemClock().now` hai lần).
  4. Leech suspend nằm **cùng transaction** với `UPDATE cards` + `INSERT review_logs`.
  5. `elapsed_days` một định nghĩa (hiện có 3: comment `CardSnapshot` sai, log srs = hiệu ngày lịch UTC của lib, log cram = Δ/24h làm tròn).
- **Out-of-scope / không đụng:** thứ tự thẻ mới/ôn (thuộc plan hàng đợi #1 đã chốt) · optimizer R2 · schema/migration · Q-12 · Q-11 · số "Đến hạn" ở header collection đang đếm cả thẻ `new` (hành vi có sẵn, chỉ ghi nhận).
- **Đã chốt với fen (2026-09-30):**
  - **D-2 (Q2) OK:** ở T2, `due` tính từ lúc thẻ được lật/hiện nhãn (lệch ≤ 30 phút so với lúc bấm) để nhãn luôn đúng; `reviewed_at` / `last_review_at` = giờ bấm thật.
- **Mở — chặn T3:**
  - **D-3:** fen muốn **"Ôn thêm" (Cram) cũng cập nhật lịch hẹn mới** như ôn thường. Đây là **đảo** ADR-011 / ADR-043 và `review.md` §8.1 (cập nhật 2026-09-08: cram "không đụng state") → cần plan riêng (`cram-reschedule-r1`) + ADR mới, **không** gộp vào plan này. Nếu đảo: câu hỏi cũ "`scheduled_days` của log cram = 0 hay lịch cũ" tự hết (log cram ghi lịch mới như srs), và phần cram của T3 đi theo plan kia.

## Tầng 1 — HLD
- **ReadoKit:** `ReviewQueue`, `VocabRepository`, `DailyProgress`, `ReviewService`, `LeechService`, `CardSnapshot`; mới: `Review/GradePreview.swift`, `ElapsedDays` (logic thuần → test lane `kit`).
- **Reado (app):** chỉ `AppModel` (`loadReviewQueue`, `grade`, `intervalLabels`, `gradeCram`).
- **Transaction:** `SQLiteDatabase.inTransaction` **không lồng được** (BEGIN trong BEGIN lỗi) → leech phải chạy **trong thân** transaction của `ReviewService.record`, không bọc thêm lớp ngoài.
- **File cấm:** `project.pbxproj` · không migration · không thêm dependency.
- **Sự thật về lib (`swift-fsrs` @`4fbaf20`, = HEAD `main`):**
  - `AbstractScheduler.init` **tự tính lại** `elapsedDays` từ `lastReview` bằng `Date.dateDiffInDays` = hiệu ngày lịch **UTC** (floor theo `startOfDay` UTC) — giá trị Reado truyền vào `Card.elapsedDays` bị bỏ qua.
  - `LongTermScheduler` (short-term tắt, Q-12): mọi thẻ sau chấm đều `state = review`; `lapses += 1` chỉ khi chấm Again ở thẻ đã ôn (thẻ new Again không tính lapse).
  - `due = reviewTime + N×24h` → hạn có giờ-phút, nên queue phải so theo ngày học.
  - Fuzz seed = `"\(reviewTime.timeIntervalSince1970)_\(reps)_\(d*s)"` → khác `now` là khác fuzz.

## Tầng 2 — Tasks
1 task = 1 session. Chỉ implement task fen vừa OK.

### T1 — due-window (hạn ôn theo ngày học) ✅ xong 2026-09-30
- **Files** — mọi chỗ so `due_at` với `now` trong logic hàng đợi → `ReviewQueue.currentDayWindow(on:now:).end`:
  - `app/ReadoKit/Sources/ReadoKit/Review/ReviewQueue.swift`: `loadFullQueue` (`dueBeforeIso` = `window.end`); `cramCardIDs` / `crammableCount` → `due_at > window.end` (tính trong hàm, chữ ký giữ nguyên — thẻ đến hạn tối nay không lọt vào Cram); sửa comment `dueCardIDs`.
  - `app/Reado/App/AppModel.swift` `loadReviewQueue`: `dueOutsideScopeCount` dùng `window.end`.
  - `app/ReadoKit/Sources/ReadoKit/Progress/DailyProgress.swift:~74`: `dueCount` dùng `window.end`.
  - `app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift`: `allCollectionSummaries` (`due_now`, `crammable_count`) và `nextDue` (`due_at > window.end` — "Lần ôn tiếp" không trỏ vào thẻ đã nằm trong hàng đợi hôm nay).
- **Test:**
  - `ReviewQueueAndServiceTests`: thẻ due `now + 6h` (trước giờ chuyển ngày) **có** trong hàng đợi; due sau `window.end` **không**.
  - `CramReviewTests`: Cram loại thẻ due tối nay.
  - `VocabularyListTests`: `due_now` / `nextDue` lệch đúng như trên.
  - Chạy lại `ScopedReviewTests`, `LearnMoreTests` (fixture dễ giả định `due = now + 1h` là chưa đến hạn).
- **DoD:** `scripts/test.sh` xanh full suite · `grep -rn "due_at <= \|due_at > " app/ReadoKit/Sources` không còn chỗ nào bind `now` trong logic hàng đợi · journal ghi lý do.
- **Xong 2026-09-30:** 277 test (275 chạy + 2 skip opt-in) xanh, `** TEST SUCCEEDED **`. Chi tiết: `docs/journal/2026-09-30.md` mục "fsrs-queue-fix-r1 — T1 due-window".

### T2 — grade-atomic (preview = thật, một `now`, leech trong transaction) ✅ xong 2026-10-01
- **Xong 2026-10-01** (commit `12090f9`, fen chạy trên Mac): **281/283** xanh (2 skip opt-in), `** TEST SUCCEEDED **`; thêm `GradePreview.swift` + 6 test (`GradePreviewTests` lane kit, `LeechTests`, `ReviewQueueAndServiceTests`). Lệch plan: `ReviewService.record` trả `RecordResult(logID, becameLeech)` (struct, không tuple); `evaluateAfterGrade` giữ vì `LeechTests` còn gọi; dedupe `INSERT review_logs` (srs+cram) gộp vào đây (refactor-r2 mục 5).
- **Files:**
  - Mới `app/ReadoKit/Sources/ReadoKit/Review/GradePreview.swift`: giữ `cardID`, `snapshot`, `computedAt`, 4 `ReviewOutcome`; `outcome(for:cardID:snapshot:now:)` trả cache khi đúng thẻ + đúng snapshot + `now - computedAt < 30 phút`, ngược lại `nil` (caller tính lại).
  - `AppModel`: `intervalLabels` điền cache; `grade` lấy `let now = SystemClock().now` **một lần**, ưu tiên outcome cache (D-2), `reviewed_at` = `now`; `gradeCram` cũng một `now`.
  - `ReviewService.record` thêm `leechThreshold: Int?`, trả `(logID, becameLeech)`; UPDATE `suspended_at` chạy trong cùng thân transaction.
  - `LeechService`: tách `suspendIfNeeded` (không tự mở transaction); `evaluateAfterGrade` giữ cho caller cũ hoặc xoá nếu hết chỗ gọi. Undo đã khôi phục `suspended_at` từ snapshot — không đổi.
- **Test:**
  - `app/ReadoKit/Tests/ReadoKitTests/GradePreviewTests.swift` (lane `kit`): trúng cache / trượt khi đổi thẻ, đổi snapshot, quá 30 phút; fuzz bật → outcome commit == outcome đã preview.
  - `LeechTests`: lần chấm thứ 6 → suspend + log trong **một** lần gọi; undo gỡ suspend.
  - `ReviewQueueAndServiceTests`: `last_review_at` == `reviewed_at`.
- **DoD:** suite xanh · nhãn nút == `scheduled_days` được ghi (test `GradePreview` với fuzz bật).

### T3 — elapsed-days (một định nghĩa + docs) ✅ xong 2026-10-02
- **Xong 2026-10-02:** D-3 đã tự hết — ADR-050 (extra-review-r1, 2026-10-01) xoá hẳn đường `recordCram`/`mode='cram'`, nên vế cram của T3 không còn áp dụng. Còn lại đúng 1 định nghĩa lệch: `CardSnapshot.schedulerCard` tự tính `elapsedDays` rồi truyền cho lib, nhưng `AbstractScheduler.init` (swift-fsrs @`4fbaf20`) **ghi đè ngay** bằng `Date.dateDiffInDays` (hiệu ngày lịch UTC) — giá trị Reado tính toán chưa bao giờ được dùng.
- **Lệch so với bản plan gốc (ghi nhận, không chặn):** không tạo `ElapsedDays.calendarDaysUTC` — không còn chỗ nào trong Reado cần giá trị này (log lấy thẳng từ `ReviewOutcome.elapsedDaysRounded` do lib trả, cram đã bỏ, optimizer R2 sẽ tính lại từ `reviewed_at`). Chép lại công thức lib chỉ để đưa vào một input bị lib bỏ qua là thêm code không ai đọc. Chọn cách đơn giản hơn: truyền thẳng `0`, xoá `CardSnapshot.dayDiff`.
- **Files:**
  - `app/ReadoKit/Sources/ReadoKit/Review/CardSnapshot.swift`: `schedulerCard` truyền `elapsedDays: 0` + comment giải thích lib ghi đè; xoá `dayDiff`.
  - `app/ReadoKit/Tests/ReadoKitTests/FoundationPrimitivesTests.swift`: xoá `testDayDiffRoundingAndBounds`.
  - `app/ReadoKit/Tests/ReadoKitTests/ReviewSchedulerTests.swift`: thêm `testElapsedDaysIsUTCCalendarDiffNotRounded24h` (guard lib drift — 3 cặp timestamp, kể cả vắt nửa đêm UTC, so với giá trị `elapsedDaysRounded` thật từ `scheduler.grade`).
  - `docs/research/review.md` §4.1: thêm đoạn "Cập nhật 2026-10-02" — `elapsed_days` là giá trị swift-fsrs tự tính (ngày lịch UTC), không theo `day_cutoff_hour`; Reado không tự định nghĩa lại.
- **Test:** `scripts/test.sh kit` 387/387 · targeted simulator (`ReviewSchedulerTests`+`FoundationPrimitivesTests`) 24/24 · full `scripts/test.sh test` 406/408 (2 skip opt-in, không đổi so với trước).
- **DoD:** `grep -rn "dayDiff" app/` rỗng · suite xanh · docs khớp code.
