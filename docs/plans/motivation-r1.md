# Plan: motivation-r1 — động lực ôn hằng ngày (ý 1 + 2 + 3 + 4 + 7)

> Nguồn: brainstorm 2026-09-26 (session-brief/journal). Ý còn lại (6, 8, 9, 10, 11) nằm ở
> `ROADMAP.md` Phase 4 — "Động lực học (brainstorm, chưa chốt)".

## Spec

- **FR / journey:**
  - J4 bước 4 — *"Hết due → summary buổi: đã xong, streak theo giờ chuyển ngày"* (`docs/specs/journeys.md` J4). Ý 1 + 2 lấp đúng khoảng trống này.
  - FR-14 — streak = ngày ôn ≥ 1 thẻ theo giờ chuyển ngày FR-11. Code đã đúng (`StreakCalendarService`) → ý 7 chỉ là hiển thị.
  - FR-11 — hạn mức new bắt buộc, áp toàn cục trước lọc phạm vi. **Ý 3 thêm criterion mới** (xem Q-A).
  - Q-08 — "đã thuộc" = `stability >= 21`; code (`VocabRepository.matureKeys`) thêm `state = 'review'`. Ý 2 + 4 dùng đúng định nghĩa này, gom về một hằng số.
- **In-scope:**
  1. Màn "Xong hôm nay" khi phiên vừa chấm hết hàng đợi: streak hiện tại, số thẻ đã ôn, số từ vừa thuộc, % không-Again. Animation tôn trọng `reduceMotion`.
  2. Toast "Thuộc rồi!" trên thẻ vừa chấm khi `before.stability < 21 ≤ after.stability`.
  3. Nút "Học thêm 10 từ" trên màn xong — nới hạn mức new **riêng hôm nay**, chỉ khi user bấm.
  4. Tiến độ theo bộ "Đã thuộc X/Y" (hub + dòng bộ ở Kho).
  7. Home nhắc giữ streak khi streak > 0 và hôm nay chưa ôn thẻ nào.
- **Out-of-scope:** Cram (R2), streak freeze (J-R1-P cấm), huy hiệu mốc / nhắc thông minh / dự báo / bản đồ trí nhớ / đọc lại trang (brainstorm), điểm/XP, leaderboard (NG-04), mọi đổi schema.
- **Không đụng:** `ReviewService.record` / `undo` (transaction #? giữ nguyên), `ReviewScheduler` / FSRS, DDL `review_logs`, `Migration.swift`.

### Mâu thuẫn phải ghi (không im lặng sửa)

- `docs/ux/visual-redesign-plan.md` §3 + comment `ReviewQueueView` ("Hết thẻ hôm nay không nảy vào — chống gamification") diễn giải vision #6 thành "chống gamification". Vision #6 thật ra chống *tóm tắt thay đọc*, không cấm ghi nhận tiến bộ. Owner 2026-09-26 chủ động muốn khuyến khích → **ADR-038** đảo phần diễn giải UX, kèm rào: chỉ ăn mừng **tiến bộ đo được** (thẻ ôn, từ thuộc theo Q-08, streak FR-14) — không điểm ảo, không màu grade kiểu game (giữ §3 cho nút grade). Ghi `ROADMAP.md` §4.

### Q đã chốt (owner 2026-09-26)

- **Q-A:** phần nới "Học thêm" giữ **trong bộ nhớ app** (`AppModel`, gắn `dayStart`). Thoát app → mất phần nới chưa dùng; thẻ đã học vẫn được đếm qua `newIntroducedCount` (suy từ log) nên không lệch. Không schema, không migration.
- **Q-B:** N = **10 từ cố định**, một nút "Học thêm 10 từ".

## Tầng 1 — HLD

### ReadoKit (logic thuần, test được)

| File | Thay đổi |
|---|---|
| `Review/Mastery.swift` (mới) | `enum Mastery { static let stabilityThreshold = 21.0; static func crossed(before: Double, after: Double, stateAfter: String) -> Bool }` — `before < 21 && after >= 21 && stateAfter == "review"` |
| `Review/SessionTally.swift` (mới) | `struct SessionTally { reviewed, again, newlyMastered: [String] (term) ; mutating func record(rating:crossed:term:) ; mutating func undoLast() ; var accuracy: Double? }` — giữ stack các entry để undo đúng một bước (FR-12) |
| `Vocab/VocabRepository.swift` | `matureKeys` dùng `Mastery.stabilityThreshold`; `CollectionSummary.masteredCount` (SQL: `ca.state='review' AND ca.stability >= ? AND ca.suspended_at IS NULL`) |
| `Review/ReviewQueue.swift` | `loadFullQueue(..., extraNew: Int = 0)` → `remainingQuota = max(0, limit + extraNew − introduced)`; mặc định 0 = hành vi cũ |
| `Progress/DailyProgress.swift` | `reviewedToday: Bool` (≥ 1 log `mode='srs'` từ `dayStart`); `load(..., extraNew:)` để số new Home khớp hàng đợi |

### Reado (UI)

| File | Thay đổi |
|---|---|
| `AppModel.swift` | `grade(...)` trả thêm `crossedMastery: Bool` (struct `GradeResult { logID, crossedMastery }`) — tính từ `snapshot.stability` + `outcome` đã có, **không** query thêm; `extraNewQuota: (dayStart: String, count: Int)` reset khi `dayStart` đổi; `learnMore()` cộng N rồi reload queue |
| `Screens/ReviewQueueView.swift` | `@State tally: SessionTally`; `gradeNow` ghi tally + bật toast "Thuộc rồi!"; `performUndo` gọi `tally.undoLast()`; nhánh `doneView` tách: `tally.reviewed > 0` → `SessionDoneView` (ăn mừng), còn lại giữ empty state cũ |
| `Screens/SessionDoneView.swift` (mới) | Lửa streak + 3 con số + danh sách từ vừa thuộc (≤ 5) + CTA "Học thêm 10 từ" (ẩn nếu 0 thẻ new còn chờ) + "Về Home" |
| `CollectionDetailView.swift`, `RootView.swift` (Kho row, Home) | `ProgressView(value: mastered, total: wordCount)` + nhãn "Đã thuộc X/Y"; Home dòng nhắc "Hôm nay chưa ôn — 1 thẻ là giữ lửa 🔥 N ngày" |

### Protocol / transaction

- Không transaction mới. Tally/crossing tính từ `before` (đã có cho undo) và `ReviewOutcome` trả về trước khi `record` ghi.
- `newIntroducedCount` vẫn suy từ log (FR-11 criterion 5) — "Học thêm" chỉ đổi *trần*, không đổi *cách đếm*.

### File cấm

`project.pbxproj` sửa tay (dùng `scripts/pbxproj_tool.py add`) · `Migration.swift` (nếu Q-A = a) · `ReviewScheduler.swift` · `ReviewService.swift`.

## Tầng 2 — Tasks

Thứ tự khuyên: **T1 → T3 → T2**.

### T1 — `session-celebration` (ý 1 + 2) — ✅ 2026-09-26, commit `4acdd93`, 227/228 test xanh (1 skip `LiveAIBoxTests` không đổi). Lệch nhỏ: `SessionDoneView.swift` đặt phẳng `app/Reado/` (không `Screens/`) vì `pbxproj_tool.py` ghi path theo basename — bám số đông file Screen hiện có, ghi trong ADR-038. Chưa xem UI thật trên simulator (agent build-check + test logic, không thao tác UI).

- **Files:** `ReadoKit/Review/Mastery.swift` (mới), `ReadoKit/Review/SessionTally.swift` (mới), `VocabRepository.matureKeys` (dùng hằng số), `AppModel.grade` (trả `GradeResult`), `ReviewQueueView` (tally + toast + tách done), `Screens/SessionDoneView.swift` (mới, `pbxproj_tool.py add --group Reado --target Reado`), `ReadoTests/SessionTallyTests.swift` (mới, `--group ReadoTests --target ReadoTests`).
- **Test (`SessionTallyTests`):**
  - `Mastery.crossed`: 20.9→21.0 review = true; 21→25 = false; 18→30 nhưng `learning` = false.
  - Tally: 3 chấm (1 Again) → `reviewed=3`, `accuracy≈0.667`; `undoLast` sau thẻ vượt ngưỡng → `newlyMastered` rỗng lại, `reviewed=2`.
  - Tally rỗng → `accuracy == nil` (UI không bắn ăn mừng).
  - Test cũ `matureKeys` (FR-10) vẫn xanh sau khi đổi sang hằng số.
- **DoD:** `scripts/test.sh` `** TEST SUCCEEDED **`, không test cũ đỏ; screenshot simulator màn xong + toast; journeys J4 bước 4 mô tả summary; ADR-038 + `ROADMAP.md` §4 dòng mâu thuẫn gamification; bỏ comment "chống gamification" trong `ReviewQueueView`.

### T2 — `learn-more` (ý 3)

- **Files:** `ReviewQueue.loadFullQueue` (`extraNew`), `DailyProgress.load` (`extraNew`), `AppModel` (`extraNewQuota: (dayStart: String, count: Int)?`, `learnMore()` cộng 10), `SessionDoneView` (CTA "Học thêm 10 từ"), `ReadoTests/LearnMoreTests.swift` (mới).
- **Docs:** `prd.md` FR-11 thêm GWT: *Given hàng đợi hôm nay đã hết, when user chủ động bấm "Học thêm 10 từ", then hạn mức new riêng ngày học hiện tại tăng 10, vẫn áp toàn cục trước lọc phạm vi; hệ thống không bao giờ tự nới.* · `journeys.md` J3 thêm nhánh · ADR-039.
- **Test (`LearnMoreTests`):**
  - `extraNew = 0` → kết quả y hệt test FR-11 hiện có.
  - limit 10, đã giới thiệu 10, `extraNew = 10` → đúng 10 thẻ new thêm.
  - scope 1 bộ + `extraNew` → vẫn áp toàn cục trước lọc (bộ khác đã ăn hạn mức thì bộ này nhận phần còn lại).
  - Qua giờ chuyển ngày (`dayStart` đổi) → `AppModel` reset về 0 (test ở tầng ReadoKit bằng hàm thuần `effectiveExtra(stored:dayStart:)`).
- **DoD:** test xanh; PRD/journeys/ADR đồng bộ; Home số new khớp hàng đợi sau khi bấm.

### T3 — `book-progress` + `streak-nudge` (ý 4 + 7) — ✅ 2026-09-26, commit `edcbf18`, 233/234 test xanh (+6, skip `LiveAIBoxTests` không đổi). `TestSupport.Fixtures.insertLog` thêm param `mode` optional (default `srs`) để test nhánh cram — ngoài phạm vi HLD ban đầu nhưng không đổi API cũ. Chưa xem UI thật trên simulator.

- **Files:** `VocabRepository.allCollectionSummaries` (`mastered_count`), `DailyProgressService` (`reviewedToday`), `CollectionDetailView` header, `KhoTabView.collectionRow`, `HomeTabView` dòng nhắc.
- **Test:**
  - `VocabularyListTests`: `review` + stability 21 → tính; `learning` + 30 → không; suspended → không; bộ rỗng → 0/0 (UI ẩn thanh).
  - `DailyProgressTests`: chưa log hôm nay → `false`; log 03:59 với cutoff 4h → vẫn tính hôm qua (`false`); log 04:00 → `true`.
- **DoD:** test xanh; screenshot Kho + hub + Home (có và không có dòng nhắc).
