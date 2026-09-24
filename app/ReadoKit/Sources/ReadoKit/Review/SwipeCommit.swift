import CoreGraphics
import Foundation

/// Quyết định chấm từ một cú vuốt (ADR-025 / ADR-033).
/// Tách khỏi SwiftUI vì ReadoTests không link app target — view không unit-test được.
/// Rating và hướng bay phải cùng dấu `predictedEndTranslation`: `translation` có thể
/// ngược chiều khi tay hất lại lúc nhả, và thẻ sẽ bay về phía stamp không khớp điểm.
public enum SwipeCommit: Sendable {
    /// Ngưỡng điểm-thoát-dự-đoán. Kéo chậm phải qua ngưỡng; hất nhanh vẫn chấm
    /// dù tay chưa tới, vì predicted đã vượt.
    public static let threshold: CGFloat = 110

    /// `nil` = dưới ngưỡng, thẻ bật về, không chấm.
    public static func rating(predictedWidth: CGFloat) -> ReadoRating? {
        if predictedWidth < -threshold { return .again }
        if predictedWidth > threshold { return .good }
        return nil
    }

    /// +1 bay phải (Good), −1 bay trái (Again). Cùng nguồn với `rating`.
    public static func direction(predictedWidth: CGFloat) -> CGFloat {
        predictedWidth < 0 ? -1 : 1
    }
}
