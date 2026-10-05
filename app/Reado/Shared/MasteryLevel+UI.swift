import ReadoKit

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
}
