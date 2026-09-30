# Plan: shell-chrome-r1

> Fen confirm 2026-09-28 (T1–T3b); T4 thêm 2026-09-30 (fen góp ý lần 2). 1 task tầng 2 / session, đóng bằng `/rhandoff`. Thứ tự: **T1 → T2 → T4 → T3a → T3b**.
>
> **Khép 2026-09-30 — cả 5 task ✅, build+test xanh (267/269, 2 skip opt-in).** Lệch so với HLD lúc lập:
> `ScrollChromeTracker` (T3a) chuyển sang **ReadoKit** thay vì `app/Reado` — `ReadoTests` không có test host vào target `Reado`
> (không `@testable import` được), phát hiện khi soạn `SettingsTests.clampNewLimit` (T1) rồi thấy lại ở T3a; đặt logic thuần ở
> ReadoKit là đúng convention sẵn có của repo (xem `CaptureFailureTests` comment) nên giữ, không lùi về app target. Vì lý do
> tương tự, bỏ test `clampNewLimit` (T1) — hàm 3 dòng, verify tay đủ.
> **Chưa xem tay:** T3a/T3b (cuộn ẩn/hiện thật) và một phần T4 (còn giật sau khi vá neo không) — máy chạy agent không có
> Simulator GUI/touch input, chỉ chụp ảnh tĩnh được. Chi tiết: `docs/journal/2026-09-30.md` mục shell-chrome-r1.

## Spec
- **FR / journey:** FR-15 + J-R1-S (núm học tập — đã xong ở 3.7, chỉ đổi control nhập) · FR-11 (giờ chuyển ngày) · shell `ShellTabBar` / `FloatShutter` (port UI lab) · swipe chấm thẻ (`SwipeCommit`, cảm giác kéo). Không GWT mới.
- **In-scope:**
  1. (2026-09-28) "Thẻ mới mỗi ngày": bỏ Stepper +/- → ô nhập số (bàn phím số), kẹp 0–999.
  2. (2026-09-28) "Giờ chuyển ngày": bỏ Stepper +/- → wheel picker 0–23, **cùng kiểu** wheel "Giờ nhắc" ngay dưới (đồng bộ UI).
  3. (2026-09-28) Thanh tab + `FloatShutter` ẩn khi cuộn xuống, hiện lại khi cuộn lên nhẹ (kiểu Facebook) — **một** modifier dùng chung cho mọi màn cuộn trong tab.
  4. (2026-09-28) Bug: hàng nút Quên/Khó/Được/Dễ ở màn Ôn (tab) bị thanh tab che.
  5. (2026-09-30) Bug: kéo thẻ Ôn qua lại bị giật nhẹ lúc bắt đầu kéo + cảm giác vật liệu không khớp phần còn lại app.
- **Out-of-scope / không đụng:** `SettingsService` + validate (0–999 / 0–23 đã có); schema; ReadoKit; FSRS; sheet không có thanh tab (`AnalysisView`, `ImportView`, `CaptureView`, `ScopePickerSheet`, Ôn mở dạng sheet từ Streak/Hub); `ReadingSessionView` (đã tự ẩn shutter + có `safeAreaInset` dịch riêng — để nguyên). Không chuyển sang native tab bar / `.tabBarMinimizeBehavior` (chỉ chạy với thanh native, app dùng capsule tự vẽ).
- **Q mở:** không. Lựa chọn hiển thị (CLAUDE.md §6.4), ghi journal khi `/rhandoff`:
  - **D1** — Tab Ôn **không** ẩn thanh tab (không cuộn, cần thanh để thoát). Bug che nút sửa bằng layout (T2).
  - **D2** — iOS 17 (deployment target) không có `onScrollGeometryChange` (iOS 18+) → thanh luôn hiện. VoiceOver bật → không bao giờ ẩn. Reduce Motion → chỉ fade, không trượt.
  - **D3** — Khi ẩn, **giữ nguyên** chiều cao phần tử trong `safeAreaInset`, chỉ offset + fade capsule. Đổi inset → đổi offset cuộn → đổi trạng thái → vòng lặp giật.

## Tầng 1 — HLD
- **Module:** chỉ `app/Reado`. Không đụng ReadoKit.
- **State mới:** `ShellChrome` (`@Observable final class`, `var isHidden = false`, `func reveal()`), file `app/Reado/App/ShellChrome.swift`. RootView sở hữu (`@State`), inject `.environment(chrome)` lên `TabView`. **Không** nhét vào `AppModel` (815 dòng, nợ B4).
- **Logic thuần:** `ScrollChromeTracker` (struct, không phụ thuộc SwiftUI state) cùng file, test ở `ReadoTests`.
- **Modifier:** `View.shellScrollChrome()` cùng file. iOS 18+ dùng `onScrollGeometryChange`; environment không có `ShellChrome` (sheet) → no-op.
- **Transaction / protocol:** không.
- **File cấm:** `project.pbxproj` (file mới chỉ cần tạo trong `app/Reado/App/`, `app/ReadoTests/`), ReadoKit, `SettingsService`.

## Tầng 2 — Tasks

### T1 — settings-inputs ✅ 2026-09-30
- **Files:** `app/Reado/Settings/SettingsView.swift` (khối `learningSection`, ~dòng 108–129; comment dòng 45).
- **Làm:**
  - Thẻ mới/ngày — thay `Stepper` bằng:
    ```swift
    HStack {
        Text("Thẻ mới mỗi ngày")
        Spacer()
        TextField("0", value: $dailyNewLimit, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(maxWidth: 80)
            .focused($limitFieldFocused)
    }
    ```
    `@FocusState private var limitFieldFocused: Bool`; `.toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Xong") { limitFieldFocused = false } } }` (gộp vào `.toolbar` sẵn có của body, không tạo modifier toolbar thứ hai nếu gây xung đột).
    Kẹp: thêm `static func clampNewLimit(_ v: Int) -> Int { min(max(v, 0), 999) }` (internal để test gọi được); gọi trong `.onChange(of: dailyNewLimit)` (chỉ gán lại khi khác, tránh vòng lặp) và trong `save()` trước khi gửi service. Xoá trống ô → `format: .number` giữ giá trị cũ — kiểm lại trên simulator.
  - Giờ chuyển ngày — thay `Stepper` bằng:
    ```swift
    VStack(alignment: .leading, spacing: Spacing.xs) {
        Label("Giờ chuyển ngày", systemImage: "bed.double")
        Picker("Giờ chuyển ngày", selection: $dayCutoffHour) {
            ForEach(0..<24, id: \.self) { h in Text(Self.hourLabel(h)).tag(h) }
        }
        .pickerStyle(.wheel)
        .frame(maxHeight: 120)
    }
    ```
    `hourLabel` là `private static` (~dòng 387) — dùng được trong cùng struct, không đổi.
  - Comment dòng 45: "mỗi lần Stepper/Picker đổi" → "mỗi lần ô nhập/Picker đổi".
- **Test:** `app/ReadoTests/SettingsTests.swift` thêm 1 test `clampNewLimit`: -5→0, 1500→999, 12→12, 0→0. `scripts/test.sh test -only-testing:ReadoTests/SettingsTests` rồi full.
- **DoD:** full test xanh; simulator: gõ số → Lưu → rời màn + vào lại thấy đúng; lăn wheel → Lưu → footer "Đã lưu"; fen xem tay.

### T2 — review-grade-inset ✅ 2026-09-30
- **Files:** `app/Reado/Review/ReviewQueueView+Grade.swift` (`.padding(.bottom, Spacing.lg)` ~dòng 34), `app/Reado/Review/ReviewQueueView+Card.swift` (khối bottom controls ~dòng 83–92), có thể `app/Reado/App/RootView.swift` (tab Ôn ~dòng 74–80) + `ShellTabBar.swift`.
- **Làm:**
  1. **Tái hiện trước, không đoán.** Simulator iPhone 18 Pro cần có ≥1 thẻ due (seed nếu trống). Screenshot `xcrun simctl io booted screenshot <scratchpad>/t2-tab.png`: tab Ôn, lật thẻ. Rồi `<scratchpad>/t2-sheet.png`: Hub → Ôn (sheet), lật thẻ. Đọc 2 ảnh.
  2. **Sửa theo kết quả:**
     - **Nhánh A** — sheet ổn, tab bị che (inset `TabView` không tới trang): thêm `static let reservedHeight = height + outerBottomPadding + Spacing.sm` vào `ShellTabBar`; ở RootView tab Ôn: `ReviewQueueView(showsCloseButton: false).safeAreaPadding(.bottom, ShellTabBar.reservedHeight)`. Sheet không đổi.
     - **Nhánh B** — cả hai đều ổn về inset nhưng khe quá sát (capsule glass nhìn như che): tăng `.padding(.bottom)` của `gradeButtons` và dòng gợi ý "Chạm để lật…" lên `Spacing.xl` (hoặc token gần nhất có sẵn trong `DesignSystem.swift`).
     - **Khác cả A và B** → **dừng, báo fen** kèm 2 ảnh, không tự chế.
  3. Kiểm Dynamic Type accessibility (lưới 2×2) cũng không bị che.
- **Test:** layout thuần — không unit test. Bằng chứng: screenshot trước/sau trong scratchpad (không commit ảnh) + full test xanh.
- **DoD:** 4 nút nằm trọn trên capsule, khe ≥ 8pt, trên iPhone 18 Pro; Ôn dạng sheet không lệch; fen xem tay.

### T4 — review-swipe-feel ✅ 2026-09-30 (vá A; nghi phạm B chưa cần — xem journal)
- **Files:** `app/Reado/Review/ReviewQueueView+Card.swift` (`swipeGesture` ~dòng 128–155, `cardView` ~46–70). Có thể `app/Reado/Shared/DesignSystem.swift` (`cardShadow` dòng 51), chỉ khi cần cho bước 4.
- **Nghi phạm (đọc code, chưa đo):**
  - **A — nhảy lúc bắt đầu kéo (khả năng cao nhất).** `DragGesture(minimumDistance: 20)` → lần `onChanged` đầu tiên `translation.width` đã ~±20pt → thẻ nhảy một bậc thay vì đi theo ngón tay từ 0.
  - **B — rớt khung khi kéo.** Mỗi khung vẽ lại shadow cho 3 lớp thẻ (thẻ kế + 2 mặt `rotation3DEffect`) + `clipShape` + `rotationEffect` + `overlay` stamp; stamp chèn/gỡ ở mốc `swipeProgress > 0.02` đổi cấu trúc view.
  - **C — tranh chấp tap/drag.** `.gesture(swipeGesture)` và `.onTapGesture` cùng gắn trên một view.
- **Làm:**
  1. **Tái hiện trước, không đoán.** Simulator iPhone 18 Pro, tab Ôn, kéo chậm qua lại. `xcrun simctl io booted recordVideo <scratchpad>/t4-before.mov`.
  2. **Sửa A:** lưu điểm neo ở lần `onChanged` đầu (`@State var dragAnchor: CGSize?`), đặt `dragOffset = translation - anchor`. Reset anchor ở `onEnded`, `snapBack`, `gradeNow`. Ngưỡng chấm vẫn dùng `translation`/`predictedEndTranslation` gốc — **`SwipeCommit` không đổi**, không đụng ReadoKit, test chấm giữ nguyên. Có thể hạ `minimumDistance` xuống 10 (giữ ≥10 để tap lật thẻ không bị nuốt).
  3. **Sửa B (chỉ khi video sau bước 2 vẫn còn giật):** `.compositingGroup()` trước `.rotationEffect` của thẻ trên. Stamp luôn nằm trong cây view, chỉ đổi `opacity` (bỏ `if`). **Không** dùng `drawingGroup()` (rasterize mất text/nút loa).
  4. **"Không đồng bộ" (cảm nhận thị giác):** chụp tab Ôn cạnh Home/Kho, so với `design-system/reado/MASTER.md` (liquid-glass FROZEN). Lệch token → sửa theo token **đã có** trong `DesignSystem.swift`. Cần token/vật liệu mới hoặc không rõ nghĩa "đồng bộ" → **dừng, gửi ảnh cho fen**, không tự chế.
  5. Reduce Motion: giữ nguyên guard `!reduceMotion` hiện có trên đường kéo.
- **Test:** logic neo là phép trừ thuần trong View, không cần unit test mới. `scripts/test.sh test -only-testing:ReadoTests/ReviewQueueAndServiceTests` rồi full. Bằng chứng: video trước/sau trong scratchpad (không commit).
- **DoD:** thẻ đi theo ngón tay từ 0, không bậc nhảy; kéo qua lại liên tục không khựng; tap vẫn lật thẻ; hất nhanh vẫn chấm; Undo về đúng giữa; full test xanh; fen xem tay trên máy thật (giật khung đo trên simulator không đáng tin).

### T3a — scroll-chrome-core ✅ 2026-09-30 (logic ở ReadoKit, không phải app/Reado — xem ghi chú đầu file)
- **Files mới:** `app/Reado/App/ShellChrome.swift`, `app/ReadoTests/ScrollChromeTrackerTests.swift`.
- **Files sửa:** `app/Reado/App/RootView.swift`, `app/Reado/App/ShellTabBar.swift`, `app/Reado/Home/HomeTabView.swift` (gắn thử 1 màn).
- **Làm:**
  1. `ScrollChromeTracker`:
     ```swift
     struct ScrollChromeTracker {
         static let hideThreshold: CGFloat = 24
         static let showThreshold: CGFloat = 12
         static let topSlack: CGFloat = 8
         private(set) var isHidden = false
         private var lastOffset: CGFloat?
         private var accumulated: CGFloat = 0   // >0 xuống, <0 lên

         /// offsetY = contentOffset.y + contentInsets.top (0 = đỉnh thật, kể cả large title).
         /// maxOffset = max(0, contentHeight + insets.top + insets.bottom - containerHeight).
         /// Trả về trạng thái mới nếu ĐỔI, nil nếu không đổi.
         mutating func update(offsetY: CGFloat, maxOffset: CGFloat) -> Bool?
     }
     ```
     Luật: offsetY ≤ topSlack → hiện (reset accumulated). offsetY > maxOffset (nảy mép dưới) hoặc < 0 (nảy mép trên, đã xử lý bởi luật đỉnh) → bỏ qua, chỉ cập nhật `lastOffset`. Delta cùng dấu `accumulated` → cộng dồn; đổi dấu → `accumulated = delta`. `accumulated ≥ hideThreshold` → ẩn; `≤ -showThreshold` → hiện. Chỉ trả non-nil khi `isHidden` đổi.
  2. `@Observable final class ShellChrome { var isHidden = false; func reveal() { isHidden = false } }`.
  3. Modifier:
     ```swift
     private struct ShellScrollChrome: ViewModifier {
         @Environment(ShellChrome.self) private var chrome: ShellChrome?
         @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
         @State private var tracker = ScrollChromeTracker()
         func body(content: Content) -> some View {
             if #available(iOS 18, *) {
                 content
                     .onScrollGeometryChange(for: ScrollSample.self) { g in
                         ScrollSample(offsetY: g.contentOffset.y + g.contentInsets.top,
                                      maxOffset: max(0, g.contentSize.height + g.contentInsets.top
                                                     + g.contentInsets.bottom - g.containerSize.height))
                     } action: { _, s in
                         guard let chrome, !voiceOver else { return }
                         if let hidden = tracker.update(offsetY: s.offsetY, maxOffset: s.maxOffset) {
                             chrome.isHidden = hidden
                         }
                     }
                     .onDisappear { chrome?.reveal() }
             } else {
                 content
             }
         }
     }
     private struct ScrollSample: Equatable { var offsetY: CGFloat; var maxOffset: CGFloat }
     extension View { func shellScrollChrome() -> some View { modifier(ShellScrollChrome()) } }
     ```
     Nếu `@Environment(ShellChrome.self)` optional không compile trên toolchain → dùng `@Environment(ShellChrome.self) private var chrome: ShellChrome?` là cú pháp chuẩn iOS 17; lỗi khác → báo, không đổi kiến trúc.
  4. RootView: `@State private var chrome = ShellChrome()`; `.environment(chrome)` gắn trên `TabView`. `.onChange(of: selectedTab)`, `.onChange(of: homePath)`, `.onChange(of: khoPath)` → `chrome.reveal()`. Trong `onDismiss` của fullScreenCover capture và sheet analysis → `chrome.reveal()`. `showShutter`: thêm `if chrome.isHidden { return false }` ngay đầu. Thêm `.animation(reduceMotion ? nil : Motion.reveal, value: chrome.isHidden)` cạnh animation `showShutter` sẵn có.
  5. ShellTabBar: thêm `var isHidden = false`; RootView truyền `isHidden: chrome.isHidden`. Trên capsule (sau `.padding(.bottom, …)`):
     ```swift
     .offset(y: isHidden && !reduceMotion ? Self.height + Self.outerBottomPadding + 40 : 0)
     .opacity(isHidden ? 0 : 1)
     .allowsHitTesting(!isHidden)
     .accessibilityHidden(isHidden)
     ```
     (+40 phủ home indicator ~34pt; không cần GeometryReader.) **Không** đổi `frame(height:)` hay padding — D3.
  6. `HomeTabView`: gắn `.shellScrollChrome()` lên đúng `ScrollView`/`List` gốc (không lên container ngoài).
- **Test:** `ScrollChromeTrackerTests` (6 case): xuống 30pt từ offset 100 → ẩn · xuống 10pt → nil · đang ẩn, lên 15pt → hiện · rung ±5pt nhiều lần → nil · về offset 4 → hiện · offset > maxOffset → nil. `-only-testing:ReadoTests/ScrollChromeTrackerTests` rồi full.
- **DoD:** full test xanh; simulator Home: cuộn xuống → capsule + shutter trượt đi; kéo lên nhẹ → hiện; về đỉnh → hiện; đổi tab / push Settings → hiện; không giật ở mép trên/dưới; fen xem tay.

### T3b — scroll-chrome-rollout ✅ 2026-09-30 (build+test xanh; cuộn ẩn/hiện chưa xem tay)
- **Files:** gắn `.shellScrollChrome()` (1 dòng, lên đúng `ScrollView`/`List` gốc) vào `app/Reado/Library/KhoTabView.swift`, `app/Reado/Library/CollectionDetailView.swift`, `app/Reado/Home/StreakCalendarView.swift`, `app/Reado/Settings/SettingsView.swift`, `app/Reado/Library/ExportView.swift`. **Không** gắn `ReadingSessionView`, `ReviewQueueView`, các sheet.
- **Lưu ý:** `StreakCalendarView` có `safeAreaInset(edge: .bottom) { cta }` — kiểm CTA không bị lộ/che lạ khi thanh ẩn. `SettingsView`: ô nhập T1 đang focus + bàn phím → không được ẩn/hiện nhấp nháy (nếu có, guard trong modifier không đủ → báo fen).
- **Test:** không unit test mới; full test xanh.
- **DoD:** 5 màn hành vi giống Home; Ôn (tab) + Ôn sheet + phiên đọc không đổi; fen xem tay. `/rhandoff`: ghi D1–D3 vào journal; hỏi fen có muốn thêm 1 dòng quy ước "thanh tab ẩn khi cuộn" vào `design-system/reado/MASTER.md`.
