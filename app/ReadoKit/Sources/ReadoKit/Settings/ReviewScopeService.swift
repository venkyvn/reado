import Foundation

/// Phạm vi ôn mặc định của tab Ôn — port UI lab (2026-09-23): "Ôn nhanh" 1–3
/// collection hoặc tất cả. Lưu JSON `settings.review_priority_ids` + bool
/// `review_all`. `scopeSet` đổi về `Set<String>?` cho `ReviewQueue` (FR-18):
/// `review_all` hoặc chưa ghim bộ nào → nil (tất cả); ngược lại → đúng các bộ.
public struct ReviewScope: Equatable, Sendable {
    public var priorityIDs: [String]
    public var reviewAll: Bool

    public static let empty = ReviewScope(priorityIDs: [], reviewAll: true)

    /// `Set<String>?` cho tham số `scope` của `ReviewQueue` — nil = tất cả.
    public var scopeSet: Set<String>? {
        if reviewAll || priorityIDs.isEmpty { return nil }
        return Set(priorityIDs)
    }
}

public enum ReviewScopeError: Error, LocalizedError, Equatable {
    /// Nhiều hơn maxPriority collection.
    case tooMany
    /// Collection id không tồn tại.
    case notFound

    public var errorDescription: String? {
        switch self {
        case .tooMany: "Ôn nhanh giữ tối đa 3 collection"
        case .notFound: "Collection không tồn tại"
        }
    }
}

public enum ReviewScopeService {
    public static let maxPriority = 3

    /// Đọc scope ôn. Không có hàng settings → `.empty` (tất cả).
    public static func load(on db: SQLiteDatabase) throws -> ReviewScope {
        guard
            let row = try db.rows(
                """
                SELECT review_priority_ids, review_all
                FROM settings WHERE id = 1;
                """
            ).first
        else {
            return .empty
        }
        let all = (row["review_all"].intValue ?? 0) != 0
        var ids: [String] = []
        if let json = row["review_priority_ids"].textValue, !json.isEmpty {
            ids = JSONStringArray.decode(json) ?? []
        }
        // Chưa ghim bộ nào → mặc định "tất cả" (cho cả seed default review_all = 0).
        guard !ids.isEmpty else { return .empty }
        return ReviewScope(priorityIDs: all ? [] : ids, reviewAll: all)
    }

    /// Validate (tối đa 3, mỗi id tồn tại) rồi ghi. `reviewAll` true → priority
    /// ids bỏ qua (lưu mảng rỗng). Trả scope đã ghi.
    @discardableResult
    public static func update(
        on db: SQLiteDatabase,
        priorityIDs: [String],
        reviewAll: Bool
    ) throws -> ReviewScope {
        let ids = priorityIDs.filter { !$0.isEmpty }
        guard ids.count <= maxPriority else { throw ReviewScopeError.tooMany }
        for id in ids {
            let exists = try db.scalarInt64(
                "SELECT 1 FROM collections WHERE id = ? LIMIT 1;", [.text(id)])
            guard exists != nil else { throw ReviewScopeError.notFound }
        }
        let json = reviewAll ? "[]" : JSONStringArray.encode(ids)
        try db.run(
            """
            UPDATE settings
               SET review_priority_ids = ?, review_all = ?
             WHERE id = 1;
            """,
            [.text(json), .int(reviewAll ? 1 : 0)])
        return ReviewScope(
            priorityIDs: reviewAll ? [] : ids, reviewAll: reviewAll)
    }
}