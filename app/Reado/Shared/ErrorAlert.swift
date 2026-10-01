import SwiftUI

/// Alert lỗi dùng chung (refactor-r3 #1): hiện `AppModel.alertMessage` rồi xoá
/// khi đóng. Gắn ở `RootView` và ở gốc mỗi sheet/fullScreenCover — alert của
/// view bên dưới không hiện được khi đang có sheet che.
private struct AppErrorAlert: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.alert(
            "Có lỗi",
            isPresented: Binding(
                get: { model.alertMessage != nil },
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
