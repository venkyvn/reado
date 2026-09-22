import ReadoKit
import SwiftUI

@main
struct ReadoApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // 3.12: khôi phục lịch nhắc từ settings lúc khởi động. Tắt →
                // dọn pending (không hỏi quyền); bật → đặt lại trigger hằng ngày.
                .task { await model.syncReminderSchedule(requestPermission: true) }
        }
    }
}