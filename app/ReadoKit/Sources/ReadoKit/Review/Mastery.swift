import Foundation

/// Q-08: "đã thuộc" = `stability >= 21` VÀ `state == "review"`. Một hằng số
/// duy nhất cho cả `VocabRepository.matureKeys` (FR-10) và toast ăn mừng lúc
/// chấm (ADR-038) — không để hai nơi tự chép số 21.
public enum Mastery: Sendable {
    public static let stabilityThreshold = 21.0

    /// Thang tiến độ của một TỪ (vision #6, reencounter-r1 T3) — tính lúc đọc,
    /// không lưu cột.
    public enum Level: String, CaseIterable, Equatable, Sendable {
        /// Thẻ `new` — chưa học lần nào.
        case new
        /// Còn lại: đang học/nhớ nhưng chưa đạt Q-08 (gộp "Đang nhớ" cũ vào đây).
        case learning
        /// Q-08 (`state == "review"` và `stability >= 21`), chưa từng "nhận ra" khi đọc.
        case remembered
        /// Đã nhớ VÀ ≥ 1 lần "nhận ra" khi đọc (FR-22). Tụt khỏi Q-08 thì tự về `learning`.
        case absorbed
    }

    /// Mức của một thẻ + số lần "nhận ra" của từ. Hàm THUẦN — nguồn luật duy
    /// nhất; SQL đếm của `VocabRepository.allCollectionSummaries` phải khớp (test
    /// đối chiếu). `recognizedCount` không làm lên mức nếu chưa đạt Q-08.
    public static func level(state: String, stability: Double, recognizedCount: Int) -> Level {
        if state == "new" { return .new }
        guard state == "review", stability >= stabilityThreshold else { return .learning }
        return recognizedCount > 0 ? .absorbed : .remembered
    }

    /// Thẻ vừa VƯỢT ngưỡng "đã thuộc" trong lượt chấm này: TRƯỚC chưa đạt,
    /// SAU đã đạt, và state SAU phải là `review` (thẻ `learning`/`relearning`
    /// dù stability cao vẫn chưa tính — khớp điều kiện `matureKeys`).
    public static func crossed(before: Double, after: Double, stateAfter: String) -> Bool {
        before < stabilityThreshold && after >= stabilityThreshold && stateAfter == "review"
    }
}
