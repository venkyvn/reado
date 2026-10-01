import ReadoKit
import SwiftUI

/// Alert lỗi dùng chung (refactor-r3 #1): hiện `AppModel.alertMessage` rồi xoá
/// khi đóng. Gắn ở `RootView` và ở gốc mỗi sheet/fullScreenCover — alert của
/// view bên dưới không hiện được khi đang có sheet che.
///
/// fix-alert-sheet-dismiss-r1: nhiều instance có thể cùng mount (RootView +
/// sheet con), cùng đọc chung `alertMessage` — nếu CẢ hai cùng cố present
/// `.alert()`, UIKit từ chối present trên VC đã bị VC khác che, kéo theo cả
/// sheet đang mở biến mất. Mỗi instance tự đăng ký vào `model.alertHosts`
/// (`AlertHostStack`, ReadoKit) lúc mount/unmount; chỉ instance ở ĐỈNH stack —
/// tức layer đang thật sự hiện trên màn — mới gọi `.alert(isPresented:)`.
private struct AppErrorAlert: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var hostID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { model.alertHosts.push(hostID) }
            .onDisappear { model.alertHosts.pop(hostID) }
            .alert(
                "Có lỗi",
                isPresented: Binding(
                    get: { model.alertHosts.isTop(hostID) && model.alertMessage != nil },
                    set: { if !$0 { model.alertMessage = nil } })
            ) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text(model.alertMessage ?? "")
            }
    }
}

extension View {
    func appErrorAlert() -> some View {
        modifier(AppErrorAlert())
    }
}
