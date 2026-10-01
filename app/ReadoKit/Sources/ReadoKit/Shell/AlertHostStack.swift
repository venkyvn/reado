import Foundation

/// fix-alert-sheet-dismiss-r1 — nhiều view (`RootView` + mỗi sheet con) có thể
/// cùng gắn `.appErrorAlert()` và cùng đọc chung `AppModel.alertMessage`. Nếu
/// cả view dưới (RootView) lẫn view trên (sheet đang mở) cùng cố present
/// `.alert()` một lúc, UIKit từ chối present trên VC đã có VC khác che —
/// quan sát thực tế: kéo theo cả sheet đang mở biến mất, không chỉ riêng alert
/// đứng im (xem `docs/plans/fix-alert-sheet-dismiss-r1.md`).
///
/// Stack thứ tự mount: mỗi instance `.appErrorAlert()` `push` lúc `onAppear`,
/// `pop` lúc `onDisappear`. Chỉ instance đang `isTop` mới thật sự gọi
/// `.alert(isPresented:)` — layer dưới giữ `alertMessage` chờ, tự hiện đúng khi
/// layer trên dismiss (dismiss đổi `@State` của view cha → re-render → `isTop`
/// tính lại). Logic thuần, không phụ thuộc SwiftUI/UIKit — đặt ở ReadoKit để
/// test được ở lane `kit` (không cần simulator), theo tiền lệ
/// `ScrollChromeTracker.swift` cùng thư mục.
public struct AlertHostStack: Sendable {
    private var ids: [UUID] = []

    public init() {}

    public mutating func push(_ id: UUID) {
        ids.append(id)
    }

    public mutating func pop(_ id: UUID) {
        ids.removeAll { $0 == id }
    }

    public func isTop(_ id: UUID) -> Bool {
        ids.last == id
    }
}
