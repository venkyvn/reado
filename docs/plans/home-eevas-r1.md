# Plan: home-eevas-r1 — học UI từ eevas: header nút tròn, hero số phụ, từ hay quên, tìm từ

> **Trạng thái:** T1 xong (2026-10-04, ADR-057) — code + commit. Build xanh, full suite
> 424/426 (2 skip opt-in, cùng baseline trước task). Đã xem tay trên simulator (`sim_screens.sh`):
> Home light + dark với seed `demo-reviewed` (trạng thái `.extra`, 2 metric "Gặp lại tuần này" +
> "Đã nhớ") và seed `demo` (trạng thái `.review`, hero `value`+title to, 1 metric vì
> `reencounteredThisWeek == 0`); theme sepia (accent thứ hai); Dynamic Type
> `accessibility-extra-large` và `accessibility-extra-extra-extra-large` (metric xếp dọc, toolbar
> không vỡ — title "Xong phần hôm nay" bị cắt `…` ở cỡ XXXL nhưng đây là hành vi `Label` có sẵn từ
> trước T1, không phải regression); seed `empty` (onboarding — không pill, chỉ còn ⚙).
> **Lệch so với spec khi code:** `Label` + `.labelStyle(.titleAndIcon)` trong `ToolbarItem` bị iOS 26
> tự rút về chỉ-icon trong nút tròn toolbar (xác nhận bằng ảnh — số streak biến mất khỏi pill) dù
> đã ép labelStyle; đổi sang `HStack(Image, Text)` thường thì số hiện đúng, pill/⚙ vẫn tách thành
> hai hình tròn riêng nhờ `ToolbarSpacer`. T2/T3/T4 **chưa làm** — xem phần dưới.
>
> Bước đầu tiên khi bắt đầu T1: lưu file này thành `docs/plans/home-eevas-r1.md` (cùng commit T1).
> Người implement: Sonnet, **1 task = 1 session**, đóng bằng `/rhandoff`. Task UI → load skill
> `reado-ui` trước khi sửa view.

## Context

Fen thấy app eevas (https://eevas.top — quản lý chi tiêu, Android/web) có UI đẹp: hàng nút tròn
góc phải header Home, hero một số to + số phụ, banner cảnh báo bấm được, dòng "Đã điền từ hoá
đơn — kiểm tra lại". Fen muốn Reado học các điểm này. Fen đã chốt (2026-10-04):

- Header Home: **🔥N · 🔍 · ⚙** (không có nút lịch — trùng pill streak).
- Từ hay quên (FR-19): **màn tối thiểu** — danh sách + "Đưa lại hàng đợi" / "Xoá". Sinh lại thẻ /
  sửa tay để plan khác (đụng hợp đồng prompt).
- Số phụ hero: **"Gặp lại tuần này" · "Đã nhớ"** (dữ liệu có sẵn, không đổi FR-14).

**KHÔNG làm:** cấp streak/huy hiệu, lượt khôi phục (streak freeze — J-R1-P cấm), nền gradient
(look FROZEN, MASTER.md), ý "tiến độ kiểu ngân sách" (đã có: `MasteryRing` + "Đã nhớ x/y" ở pin,
thanh 4 màu `CollectionStatsHeader`).

## Spec

- **FR / journey:** FR-14 (streak, due), FR-22 (gặp lại), Q-08 (đã nhớ), FR-19 (UI xem lại leech),
  FR-08 (thêm tiêu chí tìm — T4), FR-09 (preselect 5). Journey: khung Home (`journeys.md` Phần 1
  dòng ~20–24), J-R1-P bước 1 (dòng ~461), J1 màn duyệt.
- **Nguyên lý:** #6 (chỉ số đo thật; pill chỉ là số ngày, không cấp) · #3 (AI đề xuất, người duyệt)
  · #5 ("có cấu trúc thì tra cứu được") · FR-19 (lọc từ không bao giờ thuộc). Không đụng
  "Chống lại" / NG nào.
- **Không đụng:** `CaptureView`, hằng số `ShellTabBar`/`ShellCaptureButton`, `AppTheme`, FSRS,
  schema/`Migration.swift`, prompt, `project.pbxproj` (synchronized folders — file mới chỉ cần tạo
  trong `app/Reado/**`; trước `scripts/test.sh` chạy `git add -N <file mới>` vì
  `pbxproj_tool.py check` chỉ tính file đã track).

## Tầng 1 — HLD

- **Module:** T1, T2 chỉ `app/Reado`. T3 thêm 1 hàm + DevSeed trong ReadoKit. T4 thêm 1 hàm thuần
  trong ReadoKit. Không schema, không migration.
- **Toolbar iOS 26:** `ToolbarItem(placement: .topBarTrailing)` native → hệ thống tự vẽ nút tròn
  glass (đúng MASTER: glass chỉ trên chrome). iOS 26 gộp item cạnh nhau thành MỘT capsule → chèn
  `ToolbarSpacer(.fixed, placement: .topBarTrailing)` giữa từng item để tách thành hình tròn riêng
  như eevas. Không tự vẽ nền/`.glassEffect` cho nút.
- **Transaction:** "Đưa lại hàng đợi" = `LeechService.unsuspend` (1 UPDATE). "Xoá" = hàm mới
  `LeechService.deleteWord` (1 `DELETE FROM vocab_items`, FK `ON DELETE CASCADE` dọn
  cards/review_logs/encounters — `PRAGMA foreign_keys = ON` đã bật ở `Database.swift:77`). Không
  dùng `LeechService.deleteCard` (để lại vocab_item mồ côi không thẻ, vẫn hiện trong Kho).
- **ADR:** viết **ADR-057** ở T1 trong `docs/decisions-log.md` ("Header Home kiểu nút tròn tách,
  streak từ hàng riêng lên pill toolbar, hero số phụ"); T3/T4 bổ sung một đoạn vào ADR-057.
- **Route mới** (`RootView.swift:37` `enum ShellRoute`): `.leeches` (T3), `.search` (T4); thêm case
  tương ứng vào `shellDestination(_:)` (`RootView.swift:372`).
- **Debug screen** để chụp ảnh không cần chạm: thêm `DebugLaunch.Screen.leeches` (`leeches`),
  `.search` (`search`) theo đúng mẫu `saveBanner` (`DebugLaunch.swift:56` + parse `:150`, test
  `DebugLaunchTests.swift:33`), xử lý trong `RootView.applyDebugScreenIfNeeded` (switch ~dòng 280:
  `selectedTab = .today; todayPath = [.leeches]`), cập nhật danh sách màn trong comment đầu
  `scripts/sim_screens.sh`.

---

## Tầng 2 — Tasks

### T1 — Header nút tròn + hero số to/số phụ ⭐ làm trước

**Files:** `app/Reado/Home/HomeTabView.swift`, `app/Reado/Shared/HeroCard.swift`,
`docs/specs/journeys.md`, `docs/decisions-log.md`, `docs/plans/home-eevas-r1.md` (lưu plan).

**Việc:**

1. **Toolbar** (`HomeTabView.swift` `.toolbar {…}` hiện chỉ có ⚙):
   - Item 1 — pill streak: chỉ hiện khi `model.dailyProgress != nil && model.hasFirstPage` (ẩn lúc
     onboarding). `NavigationLink(value: ShellRoute.streak)` với label
     `Label { Text("\(progress.streak)").monospacedDigit() } icon: { Image(systemName: "flame.fill").foregroundStyle(Theme.due) }`
     + `.labelStyle(.titleAndIcon)` để thành pill. Giữ `.contentTransition(.numericText())` và
     `.symbolEffect(.bounce, value:)` (tôn trọng `reduceMotion`) đang có ở `statsSection`.
     `accessibilityLabel("Chuỗi \(n) ngày, mở lịch streak")`.
   - `ToolbarSpacer(.fixed, placement: .topBarTrailing)`.
   - Item 2 — 🔍: **T1 chưa thêm** (T4 gắn). Ghi chú TODO không cần — T4 tự thêm.
   - Item 3 — ⚙ giữ nguyên (`Button(action: onSettings)`).
2. **Bỏ `statsSection`** (hàng streak + "Gặp lại N từ tuần này") khỏi `homeList` và xoá property.
3. **`HeroCard`** thêm 2 trường tuỳ chọn, giữ mọi call site cũ biên dịch được (giá trị mặc định):
   ```swift
   struct Metric: Identifiable { let value: String; let label: String; var id: String { label } }
   var value: String? = nil        // số to đứng trước title (vd "12"), nil = như cũ
   var metrics: [Metric] = []       // 0–2 số phụ, rỗng = không vẽ hàng
   ```
   - Có `value`: vẽ `HStack(alignment: .firstTextBaseline)` gồm
     `Text(value).font(.largeTitle.weight(.bold)).monospacedDigit().contentTransition(.numericText())`
     + `Text(title).font(.title3.weight(.semibold))`. Không font custom, không `.system(size:)`.
   - `metrics`: hàng dưới title/subtitle, trước nút chính. Mỗi metric = `VStack(alignment: .leading)`
     { `Text(value).font(.headline).monospacedDigit()`, `Text(label).font(Typo.meta).foregroundStyle(.secondary)` }.
     Bố cục `HStack(spacing: Spacing.lg)`; `dynamicTypeSize.isAccessibilitySize` → `VStack` (dùng
     `AnyLayout` y như `statsSection` cũ). Mỗi metric `.accessibilityElement(children: .combine)`.
   - Cập nhật `#Preview` thêm một ca có value + 2 metric.
4. **`HomeTabView.heroCard(_:)`:**
   - `.review(count)`: `value: "\(count)"`, `title: "thẻ đến hạn"`, `metrics: heroMetrics`,
     `subtitle`: nếu `progress.streak > 0 && !progress.reviewedToday` → `"Hôm nay chưa ôn — 1 thẻ là giữ streak"`
     (chuyển từ `statsSection` sang), ngược lại nil.
   - `.extra` / `.done`: giữ title/checkmark như cũ, thêm `metrics: heroMetrics`.
   - 3 trạng thái onboarding: không metric.
   - `heroMetrics`:
     - "Gặp lại tuần này" = `model.reencounteredThisWeek` — **ẩn khi 0** (giữ luật cũ: 0 trông như lỗi).
     - "Đã nhớ" = `model.collections.reduce(0) { $0 + $1.masteredCount }` → value `"\(n) từ"`.
       Luôn hiện khi đã có trang (số đo thật kể cả 0).
5. **Docs:**
   - `journeys.md`: khung app dòng ~20–24 (⚙ trên toolbar → "toolbar Hôm nay: pill 🔥N (Lịch streak)
     · ⚙"); J-R1-P bước 1 (~461) "tap hàng streak" → "tap pill 🔥N trên toolbar"; mục "Màn UI" (~469)
     sửa tương ứng. Grep thêm `hàng streak` trong `journeys.md`/`prd.md` để sửa chỗ còn sót.
   - ADR-057 (mẫu ADR-054 trong `decisions-log.md`): bối cảnh eevas, quyết định, hệ quả (statsSection
     bỏ; nhắc giữ streak thành subtitle hero).

**Test:** `scripts/test.sh build`; `scripts/test.sh test -only-testing:ReadoKitTests/HomeHeroTests`
(không đổi logic, chạy để chắc). Full `scripts/test.sh` trước `/rhandoff`.

**DoD (ảnh, skill `reado-ui`):**
- `scripts/sim_screens.sh open home --seed demo-reviewed --fresh` → `shot after-home-header`
  (light + dark). Lặp với `--theme sepia` (≥ 2 accent: forest + sepia).
- `scripts/sim_screens.sh open home --seed demo --fresh` (còn thẻ due) → hero hiện số to + metric.
- `scripts/sim_screens.sh size extra-extra-large` (rồi một cỡ accessibility) → toolbar không vỡ, metric xếp dọc.
- `--seed empty` → onboarding: không pill, không metric.
- Pill và ⚙ là 2 hình tròn tách nhau (không gộp capsule). Vùng chạm ≥ 44pt.
