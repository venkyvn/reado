import SwiftUI

// ux-redesign-r1 T1a: một cửa duy nhất mở phiên ôn — toàn màn, che cả thanh tab,
// nên không đổi tab giữa phiên và `tally` không bị nạp lại (audit #2, #3, #13).

/// Yêu cầu mở một phiên ôn. `Identifiable` để `RootView` present bằng
/// `.fullScreenCover(item:)`; mỗi lần bấm là một `id` mới nên bấm lại luôn mở lại.
struct ReviewRequest: Identifiable {
    let id = UUID()
    /// nil = tất cả bộ (cùng nghĩa với `ReviewQueue`).
    let scope: Set<String>?
    let mode: ReviewMode
}

private struct StartReviewKey: EnvironmentKey {
    // Computed, không `static let`: closure không Sendable — tránh lỗi global state ở Swift 6.
    static var defaultValue: (ReviewRequest) -> Void { { _ in } }
}

extension EnvironmentValues {
    /// `RootView` gán — Home, Hub, Lịch streak gọi cái này thay vì giữ sheet ôn riêng.
    var startReview: (ReviewRequest) -> Void {
        get { self[StartReviewKey.self] }
        set { self[StartReviewKey.self] = newValue }
    }
}
