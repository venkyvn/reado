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
}
