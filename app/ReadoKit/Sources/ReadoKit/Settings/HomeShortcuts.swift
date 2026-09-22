import Foundation

/// FR-17 — shortcut Home: tối đa HAI named collection "đang đọc" hiện trên Home,
/// mở thẳng vào Collection Hub. Chỉ là shortcut, không pin session (PRD v0.7).
/// Lưu ở hai cột `settings.home_shortcut_1_id` / `home_shortcut_2_id` (db.md A.1),
/// thứ tự slot = thứ tự user đặt. Collection bị xoá → slot thành NULL nhờ
/// `ON DELETE SET NULL` (db.md A.2.2), shortcut lỗi tự bỏ.
public enum HomeShortcutError: Error, LocalizedError, Equatable {
    /// Collection id không tồn tại.
    case notFound
    /// Kho tạm (is_default = 1) không phải bài đọc chủ động — không ghim được.
    case isInbox
    /// Hai slot trỏ cùng một collection.
    case duplicate
    /// Nhiều hơn maxShortcuts collection — Home giữ tối đa 2.
    case tooMany

    public var errorDescription: String? {
        switch self {
        case .notFound: "Collection không tồn tại"
        case .isInbox: "Kho tạm không thể ghim lên Home"
        case .duplicate: "Hai slot không được trùng collection"
        case .tooMany: "Home giữ tối đa 2 collection đang đọc"
        }
    }
}

/// Đọc/ghi hai cột shortcut trên `settings` (id = 1). Mọi quy tắc ở đây là
/// app-rule FR-17 + db.md A.2.2 (không kho tạm, không trùng slot, tối đa 2);
/// DDL không `CHECK` các quy tắc này vì chúng phụ thuộc bảng `collections`.
public enum HomeShortcutService {
    public static let maxShortcuts = 2

    /// Hai cột slot theo thứ tự — `set` ghi lần lượt từng slot.
    private static let slotColumns = ["home_shortcut_1_id", "home_shortcut_2_id"]

    /// Đọc danh sách collection đang ghim, theo thứ tự slot 1 → 2, bỏ slot NULL
    /// (collection bị xoá → FK đã NULL hoá). Trả mảng compact, tối đa 2 phần tử.
    public static func ids(on db: SQLiteDatabase) throws -> [String] {
        guard let row = try db.rows(
            """
            SELECT home_shortcut_1_id, home_shortcut_2_id
            FROM settings WHERE id = 1;
            """
        ).first, row.count == 2 else {
            return []
        }
        return row.compactMap(\.textValue).filter { !$0.isEmpty }
    }

    /// Ghi lại toàn bộ danh sách ghim. Validate TRƯỚC khi ghi:
    /// - mỗi id phải tồn tại (`.notFound`) và không phải kho tạm (`.isInbox`)
    /// - không trùng (`.duplicate`), không quá 2 (`.tooMany`)
    /// Thứ tự mảng = thứ tự slot; ghi hai cột trong MỘT transaction để không
    /// lệch thứ tự khi slot rỗng. Trả danh sách chuẩn hoá đã ghi (bỏ chuỗi rỗng).
    @discardableResult
    public static func set(
        on db: SQLiteDatabase, ids: [String]
    ) throws -> [String] {
        let normalized = ids.filter { !$0.isEmpty }
        guard normalized.count <= maxShortcuts else {
            throw HomeShortcutError.tooMany
        }
        guard Set(normalized).count == normalized.count else {
            throw HomeShortcutError.duplicate
        }
        // Validate từng collection tồn tại + không phải kho tạm.
        for id in normalized {
            guard let isDefault = try db.scalarInt64(
                "SELECT is_default FROM collections WHERE id = ? LIMIT 1;",
                [.text(id)])
            else {
                throw HomeShortcutError.notFound
            }
            guard isDefault == 0 else { throw HomeShortcutError.isInbox }
        }
        try db.inTransaction {
            // Xoá cả hai slot trước, rồi ghi lại theo thứ tự — thứ tự luôn compact.
            try db.run(
                """
                UPDATE settings
                   SET home_shortcut_1_id = NULL, home_shortcut_2_id = NULL
                 WHERE id = 1;
                """)
            for (index, id) in normalized.enumerated() {
                let column = slotColumns[index]
                try db.run(
                    "UPDATE settings SET \(column) = ? WHERE id = 1;",
                    [.text(id)])
            }
        }
        return normalized
    }
}