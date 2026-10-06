# Plan: visual-polish-r1 — nâng cấp visual theo hướng "Native iOS tinh chỉnh"

> **Trạng thái:** closed (2026-10-06) - T0–T5 code+commit xong (ADR-045); nợ xem tay dời sang docs/qa/pending.md (workflow-docs-r1 D2)

> Chi tiết: build xanh, full suite 263/265
> (2 skip opt-in; gồm 7 test của luồng `cram-collection-r1` chạy song song). **Plan còn mở** cho tới khi fen xem tay các màn chưa kiểm. Đã xem thực
> tế trên simulator: Home (light + dark). **Chưa xem tay:** Ôn (2 mặt thẻ), SessionDone,
> Kho, CollectionDetail, Streak, Analysis — cần fen điều hướng simulator + chụp
> (`scripts/sim_screens.sh shot after-<màn>`); Analysis cần AI thật.
>
> **Lệch so với plan bên dưới (ghi để review):**
> - Fixture demo đặt tên bộ "Demo Habits/Journey/Sapiens", không dùng tên sách thật.
> - T3 due row: cuối row là `play.circle.fill` (nút hành động), không `Pill` số thẻ — số
>   đã nằm ở dòng phụ "N thẻ sẽ ôn". Thêm `.buttonStyle(.plain)` vì Button trong List tô
>   label theo tint (chữ mờ xanh).
> - T3 streak: row nhắc streak gộp vào row streak → bấm mở **Lịch streak** (trước đây row
>   nhắc bấm là vào Ôn). Đổi hành vi nhỏ; CTA "Ôn ngay" vẫn có trong màn Lịch.
> - T3 checklist: giữ tách nhãn (gộp a11y) khỏi nút như comment cũ, không "bỏ HStack lồng";
>   cỡ chữ accessibility → nút xuống dưới text.
> - T2: shadow card Ôn vẫn nằm trong `clipShape` (hành vi cũ) — chưa dời ra ngoài; chưa
>   xác nhận có bị cắt.
> - T4: row Analysis nay hiện thêm pill CEFR và IPA có `/…/`; `VerificationBadge` thành
>   `Pill` (rộng hơn chữ caption2 cũ — cần xem có chật ở màn hẹp).
> - `IconTile` symbol đổi màu theo appearance (white trên accent nhạt dark chìm).
> - `CaptureView` giữ nguyên (ngoài phạm vi, ADR-036).
> - Bẫy tooling: `scripts/pbxproj_tool.py check` chỉ tính file Swift đã git-track → file mới
>   phải `git add -N` trước khi `scripts/test.sh` qua cổng.


> Lưu thành `docs/plans/done/visual-polish-r1.md` ở bước đầu T0 (fen đã OK plan).
> Người implement: Sonnet, mỗi task 1 session, đóng bằng `/rhandoff`.

## Context

Fen thấy app "chưa chỉn chu". Soát code (3 agent đọc 4 màn chính + grep toàn `app/Reado`):
- **Nền đã tốt:** màu semantic đã token hoá (`Theme`, `ReadoApp.swift:10`), accent theo `AppTheme`, chữ dùng text style hệ thống, có `Motion`, `Haptics`, `card()` (`ReadoApp.swift:151`), `chromeGlass` (`:159`).
- **Lý do trông "chưa chỉn chu":**
  1. Khoảng cách lệch thang (spacing có 12 giá trị: 2,3,4,6,8,10,12,14,16,20,24; padding 7/10/28/36/3).
  2. Bo góc 6 cỡ (2,4,8,10,12,16), không `.continuous`.
  3. Phân cấp chữ phẳng: `.caption` 35 lần, `.secondary` 48 lần, nên mỗi row chồng 3–4 dòng chữ nhỏ xám. Card Ôn bị ngược: mặt trước từ `.title.bold`, mặt sau nghĩa (đáp án) chỉ `.headline` và mất luôn từ.
  4. Pill/badge copy tay ≥7 chỗ với opacity 0.12/0.15/0.18, padding 10/4, 7/3, 6/2. POS là pill ở Analysis nhưng là chữ trơn ở CollectionDetail.
  5. Home: 4 row giữa nằm ngoài Section (khối không tiêu đề), icon đầu row mỗi kiểu một cỡ, streak lặp 2 row + emoji 🔥. Kho row có tới 3 phụ kiện bên phải.
  6. Có emoji làm icon (🎉, 🔥) — vi phạm `design-system/reado/MASTER.md`.

**Hướng đã chốt (fen, 2026-09-28): Native iOS tinh chỉnh** — kiểu app Apple (Notes/Reminders). Giữ `List`/`Form`/`NavigationStack`, không serif hay nền giấy, không màu nổi kiểu gamification. Fen đánh dấu cả 4 màn là khó chịu: Ôn, Home, Kho/CollectionDetail, Analysis.

## Spec

- FR/journey: không đổi hành vi. Chỉ lớp trình bày của J1–J6 (`docs/specs/journeys.md`).
- **In-scope:** token Spacing/Radius/Typo, 3 component dùng chung, làm lại visual 4 màn chính + SessionDone, áp token cho các màn còn lại, dev-seed CSV DEBUG để chụp màn hình.
- **Out-of-scope / KHÔNG đụng:**
  - `ReadoKit`, DB, prompt, FSRS.
  - Gesture vuốt + map Again/Good (ADR-025/033), màu nút grade.
  - Vị trí `ShellTabBar`/`FloatShutter` và hằng số `ShellTabBar.height/outerBottomPadding/shutterGap` (đã đo bằng screenshot, comment `RootView.swift:94-103`).
  - `CaptureView` (tự vẽ, ADR-036). Glass trên nội dung đọc (MASTER: nội dung đặc).
  - Không thêm dependency.
- Q mở: không. Q-11 không liên quan.

## Tầng 1 — HLD

- **Module:** chỉ `app/Reado` (target Reado). Riêng T0 thêm hook DEBUG trong `AppModel.swift` (gọi API ReadoKit có sẵn `CSVImport.parse` + `CSVImport.importRows`, không sửa ReadoKit).
- **File mới:** `app/Reado/DesignSystem.swift` (token + component). Thêm bằng `python3 scripts/pbxproj_tool.py add --file app/Reado/DesignSystem.swift --group Reado --target Reado`.
- Không đụng protocol hay transaction.
- **ADR mới** trong `docs/decisions-log.md`: "visual-polish-r1 — native tinh chỉnh; token Spacing/Radius/Typo; component Pill/IconTile/VocabSummary". Dùng số ADR kế tiếp sau ADR-042.

### Token (T1 định nghĩa, mọi task sau chỉ dùng token)

```swift
/// Thang khoảng cách (MASTER.md §Spacing + 12 cho khe row iOS).
enum Spacing {
    static let tight: CGFloat = 2   // giữa các dòng chữ trong một khối
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let row: CGFloat = 12    // icon ↔ text trong row, khe giữa nút
    static let md: CGFloat = 16     // padding chuẩn, inset ngang
    static let lg: CGFloat = 24     // giữa các khối trong ScrollView
    static let xl: CGFloat = 32
}

/// Bo góc — luôn dùng với `style: .continuous`.
enum Radius {
    static let sm: CGFloat = 8      // ô nhập, icon tile
    static let md: CGFloat = 12     // card, nút lớn, banner (= default card())
    static let lg: CGFloat = 20     // card Ôn tập
}

/// Vai trò chữ — map về text style hệ thống để giữ Dynamic Type.
enum Typo {
    static let rowTitle = Font.headline
    static let rowSubtitle = Font.subheadline          // + .secondary
    static let meta = Font.footnote                    // + .secondary; thay .caption cho chữ đọc
    static let pill = Font.caption.weight(.semibold)   // .caption chỉ còn dùng trong pill/nhãn nhỏ
    static let cardTerm = Font.largeTitle.bold()
    static let cardAnswer = Font.title2.weight(.semibold)
    static let metric = Font.title2.bold().monospacedDigit()
    static let heroSymbol = Font.system(size: 56)      // symbol trang trí lớn (done, empty)
}
```

`card()` giữ API, bên trong đổi sang `RoundedRectangle(cornerRadius: Radius.md, style: .continuous)`. Thêm `func cardShadow()` = `.shadow(color: .black.opacity(0.08), radius: 12, y: 4)` cho card Ôn.

**Quy tắc thay số (áp mọi task):**

| Đang có | Thay bằng |
|---|---|
| spacing 2, 3 trong VStack chữ | `Spacing.tight` |
| 4, 6 trong VStack chữ | `Spacing.xs` |
| 6, 8 giữa icon↔label | `Spacing.sm` |
| 10, 12, 14 khe row/nút | `Spacing.row` |
| 16, `.padding()` mặc định | `Spacing.md` (ghi rõ số) |
| 20, 24 giữa khối | `Spacing.lg` |
| 28, 32, 36 | `Spacing.xl` |
| radius 8/10 | `Radius.sm` |
| radius 12 | `Radius.md` |
| radius 16 (card lớn) | `Radius.lg` |
| `.caption` + `.secondary` cho chữ đọc | `Typo.meta` + `.secondary` |
| pill copy tay | `Pill` |

**Ngoại lệ được giữ literal (có comment):** ô heatmap `StreakCalendarView` (radius 2, cell spacing 3, min 6 — hình học lưới), hằng số `ShellTabBar`, skeleton frame trong `AnalysisView`, peek offset/scale và góc xoay stamp trong `ReviewQueueView`.

### Component (T1, cùng `DesignSystem.swift`)

1. **`Pill`** — thay mọi capsule copy tay.
   ```swift
   struct Pill: View {
       enum Tone { case neutral, due, level, ok, warn, danger, accent }
       let text: String; var systemImage: String? = nil; var tone: Tone = .neutral
       // Label/Text với Typo.pill, padding(.horizontal, Spacing.sm) + (.vertical, Spacing.tight),
       // nền Capsule fill tone.color.opacity(0.15) (neutral = Theme.surfaceStrong).
       // Chữ .primary (tint nhạt + chữ màu cam/xanh không đạt contrast 4.5:1).
       // Icon (nếu có) tô màu tone. monospacedDigit.
   }
   ```
   Map: due count → `.due`, CEFR → `.level`, POS → `.neutral`, `VerificationBadge` → `.ok/.warn/.danger` kèm icon hiện có, priority → `.neutral`.
2. **`IconTile`** — ô icon đầu row cho Home/Kho, để thẳng mép trái.
   `IconTile(systemImage:, tint: Color = .accentColor)`: frame 32×32, `RoundedRectangle(Radius.sm, .continuous)` fill tint, symbol `.body.weight(.semibold)` màu trắng. Kèm hằng `IconTile.size = 32` để row không có tile căn thẳng bằng `frame(width: IconTile.size)`.
3. **`VocabSummary`** — khối nội dung một từ, dùng chung cho row CollectionDetail và summary của `ReviewCardRow` (Analysis). Thứ tự cố định:
   - Dòng 1: term (`Typo.rowTitle`) + `Pill(pos, .neutral)` + `Pill(cefr, .level)` nếu có (giữ `ViewThatFits` fallback như CollectionDetail hiện tại).
   - Dòng 2: meaning, `Typo.rowSubtitle`, `.primary`, lineLimit 2.
   - Dòng 3: `/ipa/` (luôn có gạch chéo), `Typo.meta`, `.secondary`.
   - Dòng 4: example, `Typo.meta.italic()`, `.secondary`, lineLimit 2.
   - `VStack(alignment: .leading, spacing: Spacing.xs)`. Nhận tham số giá trị thuần (term, pos, cefr, ipa, meaning, example), không nhận model, để hai nơi gọi tự map.

## Tầng 2 — Tasks

Mỗi task = 1 session = 1 commit (T1 commit riêng vì là nền). Trước commit: `python3 scripts/pbxproj_tool.py check`; chỉ giữ hunk pbxproj thật.

### T0 ✅ (code xong, chưa xem tay hết) — Dev-seed + ảnh hiện trạng
- **Files:**
  - `docs/plans/done/visual-polish-r1.md`: bản plan này.
  - `app/Reado/AppModel.swift`: thêm `#if DEBUG seedDevDemoCSVIfNeeded(on:)` cạnh `seedDevAIBoxAgentIfNeeded` (`AppModel.swift:158`), gọi ngay sau nó (`:144`). Đọc env `READO_DEV_DEMO_CSV` (đường dẫn file trên máy host; simulator đọc được FS host). Chỉ import khi `CSVImport.existingTermNormalizedSet(on:)` rỗng: `parse` → `importRows(on:rows:now:)`. Lỗi → bỏ qua im lặng như hook AI-Box.
  - `scripts/fixtures/demo-vocab.csv`: khoảng 40 dòng, header 7 cột `term,pos,ipa,meaning_vi,cefr,example,collection` (xem `ImportView.swift:70`, parser `ReadoKit/Vocab/CSVImport.swift:97`). 3 collection tên sách giả ("Atomic Habits", "The Hobbit", "Sapiens"), CEFR B1–C1, câu ví dụ **tự viết** (không trích sách — bản quyền).
  - `scripts/sim_screens.sh`: dựa trên `sim_aibox.sh` (tìm UDID, `Reado.app` trong `DerivedData`).
    - `--fresh`: `simctl uninstall` trước.
    - Cài + `SIMCTL_CHILD_READO_DEV_DEMO_CSV=<abs path fixture> xcrun simctl launch`.
    - Subcommand `shot <name>`: `xcrun simctl io <udid> screenshot .tmp/screens/<name>-{light,dark}.png`, đổi `simctl ui <udid> appearance light|dark` giữa 2 lần chụp.
    - `.tmp/` đã ngoài git (kiểm `.gitignore`, thiếu thì thêm).
- **Chụp baseline:** script tự chụp Home sau launch. Các màn khác cần bấm tay: Sonnet nhờ fen điều hướng simulator (Ôn mặt trước, mặt sau, SessionDone, Kho, CollectionDetail, StreakCalendar), chạy `shot` sau mỗi màn. Analysis cần chụp thật + AI nên fen chụp trên máy thật và thả vào `.tmp/screens/before-analysis.png`. Lưu các ảnh này với tiền tố `before-`.
- **Test:** `scripts/test.sh build`; full suite (không đổi logic, vẫn 256/258).
- **DoD:** simulator fresh + seed có đủ 3 collection và thẻ due; có bộ ảnh `before-*`.

### T1 ✅ (code xong, chưa xem tay hết) — Token + component nền
- **Files:**
  - `app/Reado/DesignSystem.swift` (mới): `Spacing`, `Radius`, `Typo`, `Pill`, `IconTile`, `VocabSummary`, `cardShadow()`. Mỗi component có `#Preview` với light/dark + Dynamic Type lớn.
  - `app/Reado/ReadoApp.swift`: `SurfaceCardModifier` dùng `Radius.md` + `.continuous`.
  - `docs/ux/visual-redesign-plan.md` §0: thêm bảng Spacing/Radius/Typo + quy tắc thay số (copy bảng trên).
  - `design-system/reado/MASTER.md`: không sửa (FROZEN). Chỉ ghi ở ADR rằng Swift token là bản native của MASTER.
  - `docs/decisions-log.md`: ADR mới.
- Không đổi màn nào ngoài hiệu ứng phụ của `card()`.
- **Test:** build + full suite.
- **DoD:** preview component render đúng cả 2 mode; `pbxproj_tool.py check` xanh.

### T2 ✅ (code xong, chưa xem tay hết) — Màn Ôn (`Screens/ReviewQueueView.swift`, `SessionDoneView.swift`)
**`cardView` (235–311):**
- **Header (242–257):** thay text `n/N` bằng `HStack(spacing: Spacing.row)`: `ProgressView(value: done, total: total)` + `Text("n/N")` `Typo.meta.monospacedDigit()` `.secondary` + nút "Hoàn tác" giữ `.bordered`. Inset ngang thống nhất `Spacing.md` (thay `.padding(.horizontal)` ở 257; 284 và 526 cũng dùng token).
- **Banner** `debtBanner` (177–199), `masteredToastBanner` (203–220):
  - Radius `Radius.md` continuous, cùng opacity 0.12.
  - Thêm `.padding(.horizontal, Spacing.md)` để không chạy mép.
  - Emoji "🎉" (207) → `Image(systemName: "party.popper.fill")`.
  - Spacing 10 → `Spacing.sm`.
- `VStack(spacing: 24)` giữ, đổi thành `Spacing.lg`.

**Card:**
- **`cardFace` (442–475):**
  - Radius 16 → `Radius.lg` continuous (444, 275, 285).
  - Shadow inline (446) → `cardShadow()`, đặt **ngoài** `clipShape` (275) để không bị cắt. Đọc kỹ vì sao có clip (lật thẻ, peek). Nếu dời shadow làm hỏng animation thì giữ nguyên và ghi lại lý do.
- **Mặt trước (449–462):**
  - term `.title.bold()` → `Typo.cardTerm`.
  - POS capsule (457–459) → `Pill(pos, tone: .neutral)`.
  - Spacing 12 → `Spacing.row`; padding `Spacing.lg`.
- **`backFaceContent` (478–498):**
  - Thêm dòng đầu: term `Typo.rowTitle` `.secondary` (nhắc lại từ).
  - meaning `.headline` → `Typo.cardAnswer`.
  - IPA + `SpeakButton` giữ.
  - example giữ `.body.italic()`.
  - Tên collection `.caption .tertiary` → `Typo.meta .secondary`.
  - `VStack(spacing: Spacing.row)`, `.padding(Spacing.lg)`, `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)` để mặt sau có cùng khung với mặt trước.

**Nút chấm, khi xong, hint:**
- **`gradeButton` (530–552):**
  - Radius 8 → `Radius.md` continuous; minHeight 52 → 56.
  - Label `.subheadline.semibold` giữ; hint `.caption2` giữ; spacing 2 → `Spacing.tight`.
  - HStack 12 → `Spacing.row`. **Không đổi màu** (`ReadoRating` 795–824).
- **`doneView` (156–173):** `.system(size: 64)` → `Typo.heroSymbol`; spacing 16 → `Spacing.md`.
- **Hint caption (306–307):** `Typo.meta` `.secondary`.

**`SessionDoneView`:**
- `stat` (105–123):
  - Label `.caption2` → `Typo.meta` `.secondary`; số → `Typo.metric`.
  - Các ô cao bằng nhau: `.frame(maxWidth: .infinity, maxHeight: .infinity)` trong ô, `HStack.fixedSize(horizontal: false, vertical: true)`.
  - Padding dọc 12 → `Spacing.row`.
- `masteredSection` (127–149): term `.subheadline` `.primary` (bỏ secondary); "+N" → `Typo.meta` `.secondary`.
- Nút (40–45): `.controlSize(.large)` + `frame(maxWidth: .infinity)` đặt **trong** label để nút phủ ngang.
- Còn lại: `.system(size: 56)` → `Typo.heroSymbol`; spacing 20 → `Spacing.lg`, 6 → `Spacing.xs`; header `.padding(.top, 24)` → `Spacing.lg`. Mesh fallback opacity 0.15 → 0.18 cho khớp bản mesh (64 vs 69).

- **Test:** `scripts/test.sh test -only-testing:ReadoTests/<lớp test Review/Session nếu có>` khi sửa, full trước `/rhandoff`.
- **DoD:** ảnh `after-review-front/back`, `after-session-done` (light/dark) đặt cạnh `before-*`, fen duyệt.

### T3 ✅ (code xong, chưa xem tay hết) — Home + tab Kho (`RootView.swift`, `OnboardingChecklistSection.swift`, `StreakCalendarView.swift`)
**`HomeTabView`, `homeList` (293–303):**
- Gom `dailyProgressRows`, `inboxRow`, `streakRow` vào `Section("Hôm nay")`. Bỏ `.listRowSeparator(.hidden)` để có separator native.
- **Due row (311–334):**
  - Icon tile 40/10 tự vẽ → `IconTile("rectangle.stack.fill")` hoặc giữ symbol hiện tại.
  - Title `Typo.rowTitle`, subtitle "N thẻ sẽ ôn" `Typo.rowSubtitle` `.secondary`.
  - **Bỏ chevron vẽ tay** (329–330), vì row chuyển tab chứ không push. Thay bằng `Pill("\(n)", tone: .due)` ở trailing.
- **Inbox row (350–378):** `IconTile("tray.fill")`; badge capsule (371–373) → `Pill(tone: .due)`; subtitle `Typo.rowSubtitle`.
- **Streak (385–405) + nudge (410–422):**
  - Gộp thành **một row**: `IconTile("flame.fill", tint: Theme.due)`, title "N ngày ôn liên tục".
  - Subtitle: nội dung nudge nếu có, không thì "N trang đã phân tích".
  - **Bỏ emoji 🔥**. Xoá view `streakNudgeRow` nếu không còn dùng.
- **Pins (426–460):**
  - Icon `pin` nhỏ → khung `frame(width: IconTile.size)` để thẳng mép.
  - Name `Typo.rowTitle`; dòng mastery `Typo.rowSubtitle` `.secondary`.
  - Badge (449–453) → `Pill(tone: .due)`. Spacing 2 → `Spacing.tight`.
- **Toolbar "Dữ liệu" (284–289):** icon `archivebox` trùng icon tab Kho → `externaldrive`.

**`OnboardingChecklistSection` (116–146):**
- Bỏ HStack lồng đôi (123/126), còn một `HStack(spacing: Spacing.row)`.
- Icon đầu row trong `frame(width: IconTile.size)`.
- Title `Typo.rowTitle`; subtitle `Typo.rowSubtitle` `.secondary`.
- Footer "Ẩn hướng dẫn" `.caption` → `Typo.meta`.
- Row CEFR có 2 nút: khi Dynamic Type accessibility thì xếp dọc dưới text (`ViewThatFits` hoặc `dynamicTypeSize.isAccessibilitySize`).

**`KhoTabView` (493–662):**
- Row bộ (593–630): tối đa **2 phụ kiện phải**, là MasteryRing + `Pill(due)`. Số ưu tiên (617–619) chuyển vào subtitle ("Ưu tiên N · …").
- Name `Typo.rowTitle`; mastery `Typo.rowSubtitle` `.secondary`; spacing 4/6 → `Spacing.xs`.
- Swipe tint `.gray`/`.indigo` (641, 657) → `Theme.surfaceStrong`/`Theme.level`. Nếu `.tint` cần màu đặc thì dùng `Color(.systemGray)` và ghi chú.

**`StreakCalendarView`:** chỉ áp token (spacing 20 → `Spacing.lg`, `.padding()` → `Spacing.md`, stat số → `Typo.metric`, caption đọc → `Typo.meta`). Giữ ngoại lệ heatmap. CTA bar (275–292): padding 10 → `Spacing.row`.

- **Không đụng:** `FloatShutter`, `ShellTabBar`, overlay/safeAreaInset (94–115).
- **Test:** build + full suite (có test dùng `RootView`/checklist thì chạy lớp đó trước).
- **DoD:** ảnh `after-home` (có checklist + sau khi ẩn checklist), `after-kho`, `after-streak` light/dark; Dynamic Type `extra-extra-large` không vỡ (`xcrun simctl ui <udid> content_size extra-extra-large`).

### T4 ✅ (code xong, chưa xem tay hết) — Kho chi tiết + Duyệt từ (`CollectionDetailView.swift`, `AnalysisView.swift`)
**`CollectionDetailView`:**
- Bọc `ForEach` từ vựng (87–89) trong `Section { … } header: { Text("Từ vựng · \(n)") }`. Bỏ caption đếm trùng dưới ProgressView (48–49) nếu đã có trong `LabeledContent` "Số từ".
- **Row (240–311):**
  - Phần text → `VocabSummary(...)`.
  - CEFR pill copy tay (303–308) → `Pill(tone: .level)` (nằm trong `VocabSummary`).
  - `HStack(alignment: .top, spacing: Spacing.row)`, thêm `.padding(.vertical, Spacing.xs)`.
  - Giữ `onTapGesture` + vòng chọn: đổi sang `List(selection:)` là đổi hành vi, ngoài scope.
- Sessions row (159–190): spacing 4 → `Spacing.xs`; `.footnote` header giữ; `.caption` → `Typo.meta`.

**`AnalysisView` — `ReviewCardRow` (407–592):**
- `summaryText` (VStack 3, 482–505) → `VocabSummary`. Thứ tự dòng khớp CollectionDetail; IPA có `/…/`.
- POS pill (515–522) → `Pill(.neutral)` trong `VocabSummary`.
- `VerificationBadge` (626–645) → `Pill(text, systemImage:, tone: .ok/.warn/.danger)`.
- Spacing 10 (416, 537) → `Spacing.row`; 6 (472, 484, 673) → `Spacing.xs`/`Spacing.sm` theo bảng; `Spacer(minLength: 2)` → `Spacing.sm`.
- Ô editor (586–589): radius 8 → `Radius.sm` continuous; padding 8 → `Spacing.sm`. Nhãn field `.caption` giữ (là nhãn, không phải chữ đọc).
- Swipe tint `.gray` (358) → như T3.
- `.padding(.top, 32)` (101) → `Spacing.xl`; `.padding(.vertical, 4)` (435) → `Spacing.xs`.

- **Test:** build + các lớp test Analysis/Collection nếu có, full trước `/rhandoff`.
- **DoD:** ảnh `after-collection` (simulator seed). Analysis: fen xem trên máy thật (cần AI-Box) hoặc simulator với `scripts/sim_aibox.sh` + ảnh thư viện (`xcrun simctl addmedia`, ảnh tự tạo, không ảnh sách có bản quyền).

### T5 ✅ (code xong, chưa xem tay hết) — Áp token các màn còn lại + khép
- **Files:** `SettingsView.swift` (có pill ở 156 → `Pill`), `ImportView.swift`, `ExportView.swift`, `ReadingSessionView.swift`. `ShellTabBar.swift` chỉ đổi spacing/padding *bên trong* capsule nếu map thẳng, **không** đổi 3 hằng số.
- Đổi thẳng theo bảng, không đổi layout.
- Kiểm sót bằng grep: `grep -rnE "spacing: ?(3|6|10|14|20)|cornerRadius: ?(10|16)|\.padding\((7|10|28|36)\)|🎉|🔥" app/Reado` → chỉ còn các ngoại lệ đã comment.
- **Docs:**
  - `docs/ux/visual-redesign-plan.md`: tick DoD §5.
  - `docs/session-brief.md` §1: dòng "IA/UX" ghi visual-polish-r1.
  - Plan: đánh dấu xong.
- **DoD** (checklist `visual-redesign-plan.md` §5): touch ≥44pt; contrast 4.5:1 cả 2 mode (Pill chữ `.primary`); Dynamic Type + Reduce Motion không vỡ; không emoji làm icon; không màu hardcode ngoài token; fen xem tay trên máy thật cả 4 màn.

## Verification (mọi task)
1. `scripts/test.sh build` sau mỗi cụm sửa. `scripts/test.sh` full trước `/rhandoff`, mốc 256/258 (2 skip opt-in). Không chạy được simulator thì không ghi "xong".
2. `python3 scripts/pbxproj_tool.py check` (test.sh tự chạy).
3. Ảnh trước/sau: `scripts/sim_screens.sh --fresh` rồi `shot <name>` (light + dark) vào `.tmp/screens/`. Fen điều hướng các màn cần bấm. Tuỳ chọn: gom `before-*`/`after-*` vào một trang artifact để fen so.
4. Dynamic Type lớn: `xcrun simctl ui <udid> content_size extra-extra-large`, chụp lại Home + Ôn.
5. Fen xem tay trên máy thật trước khi khép plan (session-brief ghi UI chưa từng được xem tay).
