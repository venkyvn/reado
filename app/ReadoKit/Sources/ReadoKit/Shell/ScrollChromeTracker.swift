import Foundation

/// T3a shell-chrome-r1 — thanh tab + `FloatShutter` ẩn khi cuộn xuống, hiện lại
/// khi cuộn lên nhẹ (kiểu Facebook). Logic thuần, không phụ thuộc SwiftUI/UIKit —
/// đặt ở ReadoKit (không phải `app/Reado`) để test được: `ReadoTests` không có
/// test host vào target `Reado` (xem `CaptureFailureTests`), chỉ link được
/// ReadoKit. `ShellChrome`/modifier (SwiftUI) vẫn sống ở app target, gọi struct
/// này.
public struct ScrollChromeTracker: Sendable {
    public static let hideThreshold: CGFloat = 24
    public static let showThreshold: CGFloat = 12
    public static let topSlack: CGFloat = 8

    public private(set) var isHidden = false
    private var lastOffset: CGFloat?
    private var accumulated: CGFloat = 0  // >0 xuống, <0 lên

    public init() {}

    /// - Parameters:
    ///   - offsetY: `contentOffset.y + contentInsets.top` (0 = đỉnh thật, kể cả large title).
    ///   - maxOffset: `max(0, contentHeight + insets.top + insets.bottom - containerHeight)`.
    /// - Returns: trạng thái `isHidden` MỚI nếu vừa đổi, `nil` nếu không đổi.
    public mutating func update(offsetY: CGFloat, maxOffset: CGFloat) -> Bool? {
        defer { lastOffset = offsetY }

        // Đỉnh (kể cả slack nhỏ) → luôn hiện, bất kể đang cộng dồn gì.
        if offsetY <= Self.topSlack {
            accumulated = 0
            return setHidden(false)
        }

        guard let last = lastOffset else { return nil }
        // Nảy mép trên/dưới: bounce có thể đẩy offset < 0 hoặc > maxOffset —
        // không tính vào cộng dồn, chỉ cập nhật lastOffset (qua defer).
        if offsetY < 0 || offsetY > maxOffset { return nil }

        let delta = offsetY - last
        if delta == 0 { return nil }
        if (delta > 0) == (accumulated > 0) {
            accumulated += delta
        } else {
            accumulated = delta
        }

        if accumulated >= Self.hideThreshold {
            return setHidden(true)
        }
        if accumulated <= -Self.showThreshold {
            return setHidden(false)
        }
        return nil
    }

    private mutating func setHidden(_ value: Bool) -> Bool? {
        guard isHidden != value else { return nil }
        isHidden = value
        accumulated = 0
        return value
    }
}
