import Foundation

/// Đếm dồn một PHIÊN ôn cho màn "Xong hôm nay" (ý 1+2, ADR-038) — không phải
/// điểm/XP (NG-04), chỉ phản chiếu số đo đã có: thẻ ôn, không-Again, từ vừa
/// thuộc (`Mastery.crossed`). Sống trong `@State` của view, mất khi rời màn —
/// không cần persist.
public struct SessionTally: Equatable, Sendable {
    /// Một lượt chấm đã ghi — giữ đủ để `undoLast()` lùi đúng, không chỉ trừ số nguyên
    /// (FR-12: undo một thẻ KHÔNG mastered sau khi có thẻ khác mastered vẫn phải đúng).
    private struct Entry: Equatable, Sendable {
        let isAgain: Bool
        let crossed: Bool
        let term: String
    }

    public private(set) var reviewed: Int = 0
    public private(set) var again: Int = 0
    /// Term các thẻ vừa vượt ngưỡng thuộc trong phiên này, theo thứ tự chấm.
    public private(set) var newlyMastered: [String] = []

    private var entries: [Entry] = []

    public init() {}

    /// Ghi một lượt chấm. `crossed` = kết quả `Mastery.crossed(before:after:stateAfter:)`
    /// đã tính ở nơi gọi (không query lại DB).
    public mutating func record(rating: ReadoRating, crossed: Bool, term: String) {
        let entry = Entry(isAgain: rating == .again, crossed: crossed, term: term)
        entries.append(entry)
        reviewed += 1
        if entry.isAgain { again += 1 }
        if entry.crossed { newlyMastered.append(term) }
    }

    /// Lùi đúng lượt chấm cuối (FR-12) — pop entry, trừ lại đúng đóng góp của nó.
    public mutating func undoLast() {
        guard let entry = entries.popLast() else { return }
        reviewed -= 1
        if entry.isAgain { again -= 1 }
        if entry.crossed {
            // Xoá đúng một lần xuất hiện gần nhất (không xoá theo tên — hai thẻ
            // trùng term khác pos hiếm nhưng vẫn phải lùi đúng thẻ vừa chấm).
            if let index = newlyMastered.lastIndex(of: entry.term) {
                newlyMastered.remove(at: index)
            }
        }
    }

    /// % không-Again — `nil` khi chưa chấm gì (UI ẩn dòng này, không bắn 0%).
    public var accuracy: Double? {
        guard reviewed > 0 else { return nil }
        return Double(reviewed - again) / Double(reviewed)
    }
}
