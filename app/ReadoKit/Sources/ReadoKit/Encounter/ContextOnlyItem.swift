/// ADR-066: từ để lại trong nhóm "Đã có trong kho" - không tạo thẻ, chỉ ghi `seen`.
public struct ContextOnlyItem: Equatable, Sendable {
    public let term: String
    public let pos: String
    /// Câu AI đưa - chỉ truyền khi draft `verified` (N2), còn lại nil.
    public let example: String?

    public init(term: String, pos: String, example: String?) {
        self.term = term
        self.pos = pos
        self.example = example
    }
}
