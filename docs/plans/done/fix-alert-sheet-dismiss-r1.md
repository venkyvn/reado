# Plan: fix-alert-sheet-dismiss-r1

> **Trạng thái:** closed (2026-10-01) - T1 xong, 371/373 test xanh, verify bằng ảnh `sim_screens.sh open analysis-fixture --alert dup-name`

## Spec
- FR / journey: không có FR riêng — `journeys.md` §4 "Error/empty dùng chung" chỉ nói lỗi phải hiện alert tại chỗ, không chỉ định cơ chế trình bày. Bug hạ tầng UI (`ErrorAlert.swift`), không phải tính năng mới.
- Nguyên lý: không phục vụ nguyên lý nào trực tiếp — bug làm lỗi *biến mất* thay vì hiện ra, phá ngầm yêu cầu "người dùng phải thấy lỗi" (hệ quả §4 journeys). Không đụng NG nào.
- In-scope: sửa cơ chế present alert để không còn race "already presenting" khi `alertMessage` set lúc sheet/fullScreenCover đang mở; bỏ workaround tạm trong `RootView.swift` (đoạn "BUG CÓ SẴN").
- Out-of-scope / không đụng: nội dung thông báo lỗi, API `report`/`attempt`/`read`, accent/theme (việc khác của fen), DB/FSRS/transaction.
- Q mở / chỗ thiếu hợp đồng: không có.

## Tầng 1 — HLD
- Nguyên nhân gốc: `RootView` và mỗi sheet con (`CaptureView`, `AnalysisView`, `CollectionMoveSheet`, `EncounterSheet`) đều tự gắn `.appErrorAlert()`, cả 5 cùng đọc chung `model.alertMessage` — khi đổi, tất cả instance đang mount cùng cố present `.alert()`, cái dưới (RootView) bị UIKit từ chối vì VC khác đã present trên nó, kéo sheet biến mất theo.
- Hướng sửa: không đổi 5 call-site — chỉ sửa modifier `AppErrorAlert` để mỗi instance đăng ký vào stack thứ tự mount trên `AppModel`; chỉ instance ở đỉnh stack mới thật sự gọi `.alert(isPresented:)`.
- Module: Reado vs ReadoKit — logic stack thuần (`AlertHostStack`) ở `ReadoKit/Shell/`, theo tiền lệ `ScrollChromeTracker.swift`; wiring SwiftUI ở `app/Reado/Shared/ErrorAlert.swift` + `AppModel.swift`.
- Protocol / transaction đụng tới: không.
- File cấm: không liên quan.

## Tầng 2 — Tasks

### T1 — alert-host-stack — ✅ 2026-10-01
- Files:
  - `app/ReadoKit/Sources/ReadoKit/Shell/AlertHostStack.swift` (mới)
  - `app/ReadoKit/Tests/ReadoKitTests/AlertHostStackTests.swift` (mới)
  - `app/Reado/App/AppModel.swift` — thêm `alertHosts`
  - `app/Reado/Shared/ErrorAlert.swift` — gate present theo `isTop`
  - `app/Reado/App/RootView.swift` — bỏ workaround "BUG CÓ SẴN"
- Test: `scripts/test.sh kit` (AlertHostStackTests) + `scripts/test.sh test` (full suite, không hồi quy)
- DoD:
  - Kit test xanh cho `AlertHostStack`
  - `scripts/sim_screens.sh open analysis-fixture -ReadoAlert dup-name` → ảnh thấy cả sheet lẫn alert cùng lúc, sheet không biến mất
  - Full suite xanh như cũ
  - Xoá comment "BUG CÓ SẴN" lỗi thời
