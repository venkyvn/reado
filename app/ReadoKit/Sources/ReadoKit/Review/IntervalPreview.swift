import Foundation

/// U1 ux-polish-r1: xem trước nhịp ôn cho cả 4 mức chấm — gọi đúng
/// `ReviewScheduler.grade` (thuần, không ghi DB), không tự tính FSRS (luật
/// CLAUDE.md §4 "FSRS phải dùng thư viện"). Dùng CÙNG settings (kể cả fuzz)
/// với lần chấm thật — nhãn là ước lượng thô nên lệch vài % do `now` khác
/// nhau không đổi bậc hiển thị (ngày/tháng/năm).
public enum IntervalPreview {
    public static func outcomes(
        scheduler: ReviewScheduler, snapshot: CardSnapshot, now: Date
    ) throws -> [ReadoRating: ReviewOutcome] {
        var result: [ReadoRating: ReviewOutcome] = [:]
        for rating in ReadoRating.allCases {
            result[rating] = try scheduler.grade(rating, snapshot: snapshot, now: now)
        }
        return result
    }

    /// Nhãn ngắn tiếng Việt từ số ngày: 0 → "<1 ngày", 1–29 → "N ngày",
    /// 30–364 → "N tháng" (days/30 làm tròn, tối thiểu 1), ≥365 → "N năm"
    /// (1 chữ số thập phân, bỏ ",0": "1,5 năm" / "2 năm").
    public static func label(days: Int) -> String {
        if days <= 0 {
            return "<1 ngày"
        }
        if days < 30 {
            return "\(days) ngày"
        }
        if days < 365 {
            let months = max(1, Int((Double(days) / 30).rounded()))
            return "\(months) tháng"
        }
        let years = (Double(days) / 365 * 10).rounded() / 10
        if years.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(years)) năm"
        }
        let formatted = String(format: "%.1f", years).replacingOccurrences(of: ".", with: ",")
        return "\(formatted) năm"
    }
}
