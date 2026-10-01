import ReadoKit
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

/// Gốc tạm của tab Ôn (T1a): tab không còn tự chạy hàng đợi, chỉ tóm tắt + nút mở
/// phiên ôn toàn màn. T1b bỏ cả tab này (Q-b = B) — hero Home thành cửa ôn chính.
struct ReviewStartView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.startReview) private var startReview

    private var dueToday: Int { model.dailyProgress?.dueToday ?? 0 }
    private var extraCount: Int {
        min(model.homeExtraAvailableCount, ReviewQueue.extraBatchSize)
    }
    private var scope: Set<String>? { model.reviewScopeDefault.scopeSet }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: dueToday > 0 ? "brain.head.profile.fill" : "checkmark.circle.fill")
                .font(Typo.heroSymbol)
                .foregroundStyle(dueToday > 0 ? Color.accentColor : Theme.ok)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(Typo.rowSubtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if dueToday > 0 {
                Button("Bắt đầu ôn") {
                    startReview(ReviewRequest(scope: scope, mode: .srs))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if extraCount > 0 {
                Button("Ôn thêm \(extraCount) thẻ") {
                    startReview(ReviewRequest(scope: scope, mode: .extra))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Ôn tập")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        if dueToday > 0 { return "\(dueToday) thẻ đến hạn" }
        return extraCount > 0 ? "Xong phần hôm nay" : "Không có gì cần ôn"
    }

    private var subtitle: String {
        if dueToday > 0 {
            return scope == nil
                ? "Phạm vi: tất cả bộ"
                : "Phạm vi: \(scope?.count ?? 0) bộ ưu tiên"
        }
        return extraCount > 0
            ? "Bạn vẫn có thể ôn thêm từ mới hoặc ôn sớm."
            : "Tất cả thẻ đã được ôn rồi. Bạn có thể chụp trang mới."
    }
}
