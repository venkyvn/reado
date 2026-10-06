---
name: reado-ui
description: Dùng khi sửa hoặc thêm SwiftUI view trong app/Reado/** — luật UI (MASTER), gotcha đã gặp, và cách verify bằng ảnh chụp simulator. Không dùng cho ReadoKit, test hay docs.
paths: app/Reado/**/*.swift
---

# Reado UI

## Luật
Đọc `design-system/reado/MASTER.md` trước khi sửa. MASTER ghi tên token; giá trị nằm ở `app/Reado/Shared/DesignSystem.swift` và `app/Reado/App/ReadoApp.swift`.

## Gotchas
- **ShellTabBar che cuối màn.** Root mỗi tab tự có khe; màn push qua `navigationDestination` thì không → gắn `.shellScrollChrome()` lên đúng `ScrollView`/`List` gốc của màn (đã gồm padding + ẩn/hiện thanh khi cuộn, `App/ShellChrome.swift`). Không gọi `.safeAreaPadding` tay, không cộng thêm `height`.
- **`UIViewRepresentable` nuốt chiều cao sibling** (vd `PDFView` + thanh "Tr. N/M"): dùng `VStack(spacing: 0) { representable.frame(maxWidth: .infinity, maxHeight: .infinity); thanh }`. Dò bằng cách tạm tô nền thanh `Color.red` rồi chụp (`PDF/PDFReaderView.swift`).
- **`Button` nuốt chạm link trong `Text`** → dùng `.onTapGesture`; link đi qua `openURL` (`EncounterText.swift`).
- **Thẻ giật đầu kéo:** `DragGesture(minimumDistance: 20)` cho `translation` ~20pt ở lần `onChanged` đầu → neo `dragAnchor` rồi trừ (`ReviewQueueView+Card.swift`).
- **Alert không hiện dưới sheet** → `.appErrorAlert()` ở gốc mỗi `sheet`/`fullScreenCover` (`Shared/ErrorAlert.swift`).
- **Alert quyền camera kẹt trên simulator** (qua cả uninstall) → `xcrun simctl shutdown <udid>` rồi `scripts/sim_screens.sh --fresh`.

## Màn mới
Thêm case vào `DebugLaunch.Screen` để `sim_screens.sh open` tới thẳng được. Không có case thì màn đó luôn là "chưa xem tay".

## Verify trước khi báo xong
1. `scripts/test.sh build` xanh.
2. `scripts/sim_screens.sh open <màn> --no-build [--theme forest|sepia|indigo|system] [--fresh]`, rồi `scripts/sim_screens.sh shot after-<màn>`. Danh sách màn: `scripts/sim_screens.sh list`; cờ khác: header `scripts/sim_screens.sh`. Script tự đợi khung ổn định, ảnh không còn trắng; có cảnh báo `⚠️ ảnh … chưa ổn` thì xem bằng mắt.
3. Đọc cả hai PNG light/dark trong `.tmp/screens/`, đối chiếu checklist cuối MASTER (accent thứ hai, Dynamic Type `accessibility-extra-large`, không bị ShellTabBar che, diff không có hex/số lẻ mới).
4. Màn `open` không tới được → ghi "chưa xem tay", không báo xong.
