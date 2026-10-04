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
- **Ảnh đầu tiên sau `sim_screens.sh open` hay trắng.** App chưa vẽ xong khung hình
  (vừa relaunch/điều hướng) — `shot` ngay sau `open` có thể ra ảnh trắng toàn bộ dù
  app đã lên đúng màn. Luôn `shot` lại lần 2 (có thể thêm `sleep 1-2`) trước khi kết
  luận màn sai hay trống thật (pdf-nav-r1).
- **`UIViewRepresentable` không chia chỗ cho sibling cuối màn.** Một view bọc UIKit tự quản bounds (vd `PDFView` với `usePageViewController`) đặt cạnh một thanh cố định (vd "Tr. N/M") trong `VStack` thường sẽ NUỐT HẾT chiều cao, đẩy thanh kia xuống 0pt — không lỗi biên dịch, chỉ mất tăm trên màn. `.safeAreaInset` lồng bên trong cũng KHÔNG cứu được nếu màn đã thiếu `.safeAreaPadding(.bottom, ShellTabBar.reservedHeight)` ở gốc (gotcha đầu tiên) — nội dung vẫn tràn xuống tận đáy vật lý, thanh cố định bị đẩy ra SAU `ShellTabBar` (che khuất, không phải biến mất). Luôn thêm `.safeAreaPadding(.bottom, ShellTabBar.reservedHeight)` TRƯỚC, rồi mới `VStack(spacing: 0) { representable.frame(maxWidth: .infinity, maxHeight: .infinity); thanhCốĐịnh }` — không cần `.overlay`/`.safeAreaInset` thêm. Phát hiện bằng cách tạm đổi `.background` của thanh cố định sang một màu chói (`Color.red`) rồi chụp ảnh — thấy dải màu rơi xuống đâu là biết chỗ sai (`PDFReaderView.swift`, pdf-reader-r1 T3).

## Verify trước khi báo xong
1. `scripts/test.sh build` phải xanh.
2. `scripts/sim_screens.sh open <màn> [--theme forest|sepia|indigo|system] [--fresh]` (verify-nav-r1 — launch argument DEBUG-only, xem `DebugLaunch.Screen` cho danh sách màn) để mở THẲNG màn vừa sửa, không cần chạm tay. Rồi `scripts/sim_screens.sh shot after-<màn>`.
3. Đọc cả hai PNG light và dark trong `.tmp/screens/`, đối chiếu từng dòng checklist cuối MASTER (accent thứ hai, Dynamic Type `accessibility-extra-large`, không bị ShellTabBar che, diff không có hex hay số lẻ mới).
4. Màn nào `open` không tới được (cần chạm, cần trạng thái đặc biệt chưa có cờ debug) thì ghi rõ "chưa xem tay", không được báo là xong.
