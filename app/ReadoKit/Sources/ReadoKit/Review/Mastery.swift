import Foundation

/// Q-08: "đã thuộc" = `stability >= 21` VÀ `state == "review"`. Một hằng số
/// duy nhất cho cả `VocabRepository.matureKeys` (FR-10) và toast ăn mừng lúc
/// chấm (ADR-038) — không để hai nơi tự chép số 21.
public enum Mastery: Sendable {
    public static let stabilityThreshold = 21.0

    /// Thẻ vừa VƯỢT ngưỡng "đã thuộc" trong lượt chấm này: TRƯỚC chưa đạt,
    /// SAU đã đạt, và state SAU phải là `review` (thẻ `learning`/`relearning`
    /// dù stability cao vẫn chưa tính — khớp điều kiện `matureKeys`).
    public static func crossed(before: Double, after: Double, stateAfter: String) -> Bool {
        before < stabilityThreshold && after >= stabilityThreshold && stateAfter == "review"
    }
}
