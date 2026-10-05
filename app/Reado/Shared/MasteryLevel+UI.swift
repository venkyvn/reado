import ReadoKit
import SwiftUI

/// Nhãn 4 mức tiến độ của một từ (vision #6) — dùng chung ở màn có chip mức.
extension Mastery.Level {
    var title: String {
        switch self {
        case .new: "Mới"
        case .learning: "Đang học"
        case .remembered: "Đã nhớ"
        case .absorbed: "Đã thấm"
        }
    }

    /// Tông `Pill` cùng nghĩa màu với thanh/lưới mức ở Hub.
    var pillTone: Pill.Tone {
        switch self {
        case .new: .neutral
        case .learning: .due
        case .remembered: .accent
        case .absorbed: .ok
        }
    }

    /// Màu của mức — dùng chung lưới chấm, legend và thanh tiến độ ở Hub để không lệch nhau.
    var color: Color {
        switch self {
        case .new: Theme.surfaceStrong
        case .learning: Theme.due
        case .remembered: Color.accentColor.opacity(0.6)
        case .absorbed: Theme.ok
        }
    }
}
