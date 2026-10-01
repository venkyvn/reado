---
name: reado-ui
description: Chỉ cho SwiftUI view của Reado (app/Reado/**). Gồm luật UI (MASTER), gotcha đã gặp và bước verify bằng ảnh chụp simulator. Không dùng cho ReadoKit, test hay docs.
paths: app/Reado/**/*.swift
---

# Reado UI — sửa SwiftUI view

## Luật
Đọc `design-system/reado/MASTER.md` trước khi sửa: token, màu, vật liệu, chữ, icon, bố cục, Không làm, checklist. Token thật nằm ở `app/Reado/Shared/DesignSystem.swift` và `app/Reado/App/ReadoApp.swift`. MASTER chỉ ghi tên token, giá trị thì đọc trong code.

## Gotchas
- **ShellTabBar che nút cuối màn.** Tab bar nổi đè lên nội dung, vì vậy màn cuộn trong shell phải có `.safeAreaPadding(.bottom, ShellTabBar.reservedHeight)` (xem `app/Reado/App/RootView.swift`). Không cộng thêm `height` lên trên padding đó vì sẽ cộng trùng.
- **`Button` nuốt chạm của link trong `Text`.** Đoạn văn có link (từ gặp lại, FR-22) phải dùng `.onTapGesture` thay cho `Button`. Chạm link đi qua `openURL` (`EncounterText.swift`, `ReadingSessionView.swift`).
- **Thẻ giật lúc bắt đầu kéo.** Với `DragGesture(minimumDistance: 20)`, ngay lần `onChanged` đầu `translation` đã khoảng 20pt. Cần neo `dragAnchor` ở lần đầu rồi trừ đi, để thẻ đi theo tay từ 0 (`ReviewQueueView+Card.swift`).
- **Alert không hiện khi có sheet che.** Gắn `.appErrorAlert()` ở gốc mỗi `sheet`/`fullScreenCover`, không chỉ ở `RootView` (`Shared/ErrorAlert.swift`).
- **Logic thuần không test được trong target app.** `ReadoTests` không `@testable import` được target Reado, nên logic tách được (clamp, tính toán, state machine) phải đặt ở ReadoKit rồi test bằng `scripts/test.sh kit`. View chỉ giữ state SwiftUI.
- **Alert quyền camera kẹt trên simulator.** Alert đã hiện một lần thì kẹt qua cả uninstall và che ảnh chụp. Cách gỡ: `xcrun simctl shutdown <udid>` rồi `scripts/sim_screens.sh --fresh`.

## Verify trước khi báo xong
1. `scripts/test.sh build` phải xanh.
2. `scripts/sim_screens.sh` (hoặc `--fresh`) để cài và mở app với dữ liệu mẫu. Điều hướng tới màn vừa sửa rồi chạy `scripts/sim_screens.sh shot after-<màn>`.
3. Đọc cả hai PNG light và dark trong `.tmp/screens/`, đối chiếu từng dòng checklist cuối MASTER (accent thứ hai, Dynamic Type `accessibility-extra-large`, không bị ShellTabBar che, diff không có hex hay số lẻ mới).
4. Màn nào không tới được bằng script (cần chạm, cần trạng thái đặc biệt) thì ghi rõ "chưa xem tay", không được báo là xong.
