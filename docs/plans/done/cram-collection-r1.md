# Plan — Cram "Ôn thêm" + thiết kế lại header màn Collection

> **Trạng thái:** closed (2026-09-28) - Cram "Ôn thêm" + header Collection (cơ chế chấm đã thay bằng extra-review-r1)

> Chi tiết: Phiên A (T1+T2 Cram) ✅ và Phiên B (T3+T4 header collection) ✅, 267/269 xanh. T5 docs xong. **Lệch plan khi làm B:** (1) CTA chính ghi "Ôn bộ này · N đến hạn" thay vì "Ôn N thẻ đến hạn" — `dueNow` đếm cả thẻ new mà hàng đợi cắt theo hạn mức new/ngày; (2) file mới chỉ cần tạo trong `app/Reado/Library/` (synchronized folders, ADR-046) — bỏ `pbxproj_tool.py add`; (3) `ReviewQueueView` thêm `initialMode` để nút "Ôn thêm" mở thẳng Cram; (4) `ReviewQueue.currentDayWindow` tách từ `currentDayStartIso` cho `nextDue`. **Chưa xem tay UI** (Cram + header) trên simulator; `SessionDoneView` vẫn chưa có nút Cram.

## Context

- **Vấn đề 1:** fen rảnh, bấm "Ôn bộ này" → `ReviewQueueView` chỉ lấy thẻ *đến hạn* (FR-18 scope) → hết due thì hiện "Không có gì cần ôn", ngõ cụt.
  Đây đúng là **Cram** (PRD FR-18 criterion 4, ADR-011): chấm + ghi `review_logs.mode='cram'`, **không** update `cards` → lịch FSRS không bị lệch.
  Trước đây hoãn R2 vì `journeys.md` ghi "không có journey Cram cho tới khi owner nói 'học' = ôn chưa due" — **owner nói rồi (2026-09-28)**.
  Schema đã có sẵn `mode IN ('srs','cram',…)` → **không migration**.
- **Vấn đề 2:** header `CollectionDetailView` là các dòng `LabeledContent` ("Số từ", "Lần thêm gần nhất" ngày tuyệt đối) — nghèo thông tin, không gợi hành động.
- Owner chốt 2026-09-28: Cram lấy **thẻ đã học (state ≠ new), sắp đến hạn trước, tối đa 20/lượt**; header = **thẻ tiến độ 4 màu + 3 ô số + CTA theo ngữ cảnh**.

## Phát hiện phải sửa kèm (bug tiềm ẩn)

`ReviewQueue.newIntroducedCount` ([ReviewQueue.swift:54-70](app/ReadoKit/Sources/ReadoKit/Review/ReviewQueue.swift#L54-L70)) đếm mọi log, **không lọc `mode='srs'`** — trái ADR-011. Khi có log cram, cả hai subquery `EXISTS`/`NOT EXISTS` phải thêm `AND mode = 'srs'`. (`DailyProgress.swift:91` đã lọc đúng; `StreakCalendar` đếm mọi log — đúng ADR-011 "cram vẫn tính streak".)

## Đã kiểm trong code (để khỏi đoán)
- **Leech** ([LeechService.swift](app/ReadoKit/Sources/ReadoKit/Leech/LeechService.swift)) đọc `cards.lapses`, gọi trong `AppModel.grade` ([AppModel.swift:381](app/Reado/App/AppModel.swift#L381)). Cram không update `cards` → **không gọi `LeechService` ở đường cram**, không cần sửa leech.
- `newIntroducedCount`: vì cram chỉ lấy thẻ `state != 'new'` (luôn có log srs trước), bug không thực sự nổ — vẫn sửa cho đúng ADR-011, 1 test khoá.
- `ReviewQueue.loadFullQueue` ([ReviewQueue.swift:189](app/ReadoKit/Sources/ReadoKit/Review/ReviewQueue.swift#L189)): phần "ids → `ReviewItem` + snapshot" (SELECT join vocab/collections + `fetchSnapshot`) → **tách thành `private static func hydrate(on:cardIDs:)`**, dùng chung cho srs và cram. Lưu ý hydrate `ORDER BY c.due_at` — cram cũng muốn due gần trước nên dùng chung được.
- `ReviewService.undo` update lại `cards` → cram cần hàm riêng `undoCram(on:logID:cardID:)` chỉ `DELETE FROM review_logs WHERE id=? AND card_id=? AND mode='cram'`.
- `allCollectionSummaries` ([VocabRepository.swift:~312](app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift#L312)) đếm **từ** (`COUNT(DISTINCT v.id)`), một từ có tối đa 2 thẻ (direction). `dueNow` đếm **thẻ**.

## Tasks

### T1 — ReadoKit: Cram service (hợp đồng)
- `ReviewQueue.cramCardIDs(on:scope:limit:now:)`: `cards` join `vocab_items`, `state != 'new'`, `suspended_at IS NULL`, `due_at > now` (chưa due — due thì đi đường srs), trong scope, `ORDER BY due_at ASC LIMIT 20`. Tái dùng `inScopeClause`.
- `ReviewService.recordCram(on:cardID:before:rating:now:)`: **chỉ** INSERT `review_logs` với `mode='cram'`, snapshot `before` = trạng thái hiện tại, `scheduled_days` = của card (không đổi), không UPDATE `cards`. Undo cram = `DELETE` đúng log (tái dùng nhánh delete của `undo`, không update cards).
- Sửa `newIntroducedCount` lọc `mode='srs'`.
- Leech FR-19: không sửa (đọc `cards.lapses`, cram không đụng) — chỉ không gọi `LeechService` ở đường cram.
- Test mới `CramReviewTests`: (a) cram không đổi hàng `cards`; (b) log mode='cram'; (c) cram thẻ không ăn `daily_new_limit`; (d) queue cram loại new/suspended/due, đúng thứ tự + limit 20 + scope; (e) undo xoá log, cards nguyên; (f) cram Again không kích leech.

### T2 — UI Cram
- `AppModel`: `loadCramQueue(scope:)` (đặt vào `reviewItems`/`reviewSnapshots` như `loadReviewQueue`), `gradeCram(cardID:snapshot:rating:) -> GradeResult` (`crossedMastery = false`), `undoCram(cardID:logID:)`. Sau cram gọi `reloadOverview()` + bump `dataRevision` như grade srs (để streak/Home refresh).
- `ReviewQueueView`: thêm `@State mode: ReviewMode` (`.srs | .cram`, init param mặc định `.srs`); `loadQueue`, `gradeNow`, `performUndo` rẽ nhánh theo mode. Cram vẫn hiện nhãn khoảng ôn? **Không** — ẩn nhãn interval (không có ý nghĩa vì không đổi lịch), hiện badge nhỏ "Ôn thêm" ở hàng progress. Chế độ cram: tiêu đề/nhãn "Ôn thêm — không ảnh hưởng lịch ôn", grade gọi `AppModel.gradeCram` → `ReviewService.recordCram`; không hiện debtBanner; done view "Đã ôn thêm N thẻ".
- `emptyView` nhánh "Không có gì cần ôn": nếu scope còn thẻ đã học → nút **"Ôn thêm 20 thẻ"** (chuyển mode cram, reload). Kho còn thẻ new → giữ/hiện "Học thêm 10 từ" (ADR-039, tái dùng `AppModel` extraNewQuota).
- Mastered toast (ADR-038) không bắn trong cram (stability không đổi).

### T3 — ReadoKit: số liệu header collection
- Mở rộng `VocabRepository.CollectionSummary` (query `collection_summaries`, [VocabRepository.swift:~300-350](app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift#L330)) — thêm cột aggregate trong CÙNG query, không query mới mỗi bộ:
  - Thanh 4 màu đếm theo **từ** (khớp "Đã thuộc X/Y" đang có). Mỗi từ xếp vào đúng 1 nhóm theo ưu tiên, bỏ thẻ suspended: **Đã thuộc** (có thẻ `review` & `stability >= Mastery.stabilityThreshold` — y hệt `mastered_count` hiện tại) › **Đang học** (có thẻ `learning`/`relearning`) › **Đang nhớ** (có thẻ `review`) › **Chưa học** (còn lại). Làm bằng subquery gom theo `v.id` (`MAX(CASE…)` cờ từng nhóm) rồi SUM ở ngoài. Tổng 4 nhóm = `word_count` trừ từ chỉ có thẻ suspended — test khoá phép cộng này.
  - `addedLast7Days`: `COUNT(DISTINCT CASE WHEN v.created_at >= ? THEN v.id END)`, bind `now − 7 ngày` ISO `Z`.
  - `crammableCount` (thẻ): `state != 'new' AND suspended_at IS NULL AND due_at > now` — đúng điều kiện queue cram T1.
- **Lần ôn tiếp** chỉ cần ở màn chi tiết → hàm riêng `VocabRepository.nextDue(on:collectionID:now:) -> (date: Date, count: Int)?`: `MIN(due_at)` của thẻ chưa suspend có `due_at > now`; `count` = số thẻ có `due_at` trong ngày chứa MIN đó, ranh giới ngày = `ReviewQueue.currentDayStartIso(on:now: minDue)` tới +24h (giờ chuyển ngày FR-11, không nửa đêm). Gọi trong `reloadList()` của `CollectionDetailView`.
- Map sang `AppModel.CollectionOverview`. Test: thêm case vào test summary hiện có (grep `collectionSummaries` trong `ReadoTests`).

### T4 — UI header `CollectionDetailView`
Thay Section đầu ([CollectionDetailView.swift:38-72](app/Reado/Library/CollectionDetailView.swift#L38-L72)) bằng view mới `CollectionStatsHeader` (file mới `app/Reado/Library/CollectionStatsHeader.swift`, thêm bằng `pbxproj_tool.py add`):
- **Thẻ tiến độ:** "Đã thuộc X/Y" + thanh chồng 4 đoạn (Đã thuộc `Theme.ok` · Đang nhớ · Đang học `Theme.due` · Chưa học xám) + legend kèm số. Bộ rỗng: ẩn thanh (giữ quy ước motivation-r1).
- **3 ô số:** Đến hạn hôm nay (`dueNow`) · "+N từ / 7 ngày" (phụ: "thêm lần cuối 3 ngày trước" — `RelativeDateTimeFormatter`) · Lần ôn tiếp ("mai · 5 thẻ", nếu dueNow>0 thì "ngay bây giờ").
- **CTA chính theo ngữ cảnh** (thay nút "Ôn bộ này"): `dueNow>0` → "Ôn N thẻ đến hạn" · else `crammableCount>0` → "Ôn thêm (không đổi lịch)" mở cram · else → "Chụp trang để thêm từ" (gợi FloatShutter, hoặc ẩn CTA).
- `HomePinToggle` chuyển xuống Section riêng cuối header (không đổi hành vi, kho tạm vẫn ẩn).
- Accessibility: mỗi ô `accessibilityElement(children: .combine)`, thanh chồng có label đọc đủ 4 số; Dynamic Type accessibility → 3 ô xếp dọc (`ViewThatFits`).
- Chi tiết hiển thị (màu, khoảng cách) chọn đơn giản nhất theo `Theme` hiện có — ghi lại lựa chọn trong plan doc.

### T5 — Docs
- ADR-043 "Cram R1 cho collection: thẻ đã học, sắp due trước, 20/lượt" (owner chốt 2026-09-28); cập nhật `journeys.md` (J2/J5: bỏ dòng "không CTA Cram" chỗ hub collection, thêm nhánh Cram), `prd.md` §R1 scope (cram kéo về R1), `ROADMAP.md` (cram FR-18 → task mới), `session-brief.md`.
- Lưu plan này vào `docs/plans/cram-collection-r1.md` khi fen OK.

## Thứ tự làm
Hai phiên (CLAUDE.md §7: 1 task tầng 2 / session): **Phiên A = T1+T2 (Cram)** → `/rhandoff` → **Phiên B = T3+T4 (header)** → `/rhandoff`. T5 docs rải theo phiên (ADR + journeys ở A, ROADMAP/brief cả hai). Việc đầu tiên của phiên A: lưu plan này vào `docs/plans/cram-collection-r1.md`.

## File chính
- `app/ReadoKit/Sources/ReadoKit/Review/ReviewQueue.swift`, `ReviewService.swift`
- `app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift`
- `app/Reado/App/AppModel.swift` (`CollectionOverview`, `gradeCram`)
- `app/Reado/Review/ReviewQueueView.swift`, `app/Reado/Library/CollectionDetailView.swift`, mới `app/Reado/Library/CollectionStatsHeader.swift`
- Test mới `app/ReadoTests/CramReviewTests.swift` (+ `pbxproj_tool.py add --group ReadoTests --target ReadoTests`)

## Verification
1. `scripts/test.sh test -only-testing:ReadoTests/CramReviewTests` rồi `ScopedReviewTests`, `DailyProgressTests` khi đang sửa.
2. Full `scripts/test.sh` trước `/rhandoff` — ghi số test thật.
3. Xem tay trên simulator iPhone 18 Pro (`scripts/sim_screens.sh` nếu hợp): bộ có due → CTA "Ôn N thẻ"; ôn hết → empty có "Ôn thêm 20 thẻ"; ôn cram xong quay lại header: số "Đến hạn"/"Lần ôn tiếp" **không đổi** (chứng minh không đụng lịch); bộ rỗng; Dynamic Type lớn.
4. Không chạy được simulator → không ghi "xong".
