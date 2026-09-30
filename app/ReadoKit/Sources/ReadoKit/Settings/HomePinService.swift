import Foundation

/// Pin Home — port UI lab (2026-09-23): nâng FR-17 từ 2 shortcut lên TỐI ĐA 5
/// collection "đang đọc". Lưu JSON array ở `settings.home_pin_ids` (thứ tự = thứ
/// tự user thêm). Kho tạm (is_default = 1) không ghim được; không trùng.
/// Cột cũ `home_shortcut_1_id` / `home_shortcut_2_id` giữ lại (deprecate) —
/// `ids` đọc JSON trước, fallback về 2 slot khi JSON rỗng (lazy migrate, không
/// mất dữ liệu cài cũ).
public enum HomePinError: Error, LocalizedError, Equatable {
    /// Collection id không tồn tại.
    case notFound
    /// Kho tạm không phải bài đọc chủ động.
    case isInbox
    /// Ghim trùng một collection.
    case duplicate
    /// Nhiều hơn maxPins collection.
    case tooMany

    public var errorDescription: String? {
        switch self {
        case .notFound: "Collection không tồn tại"
        case .isInbox: "Kho tạm không thể ghim lên Home"
        case .duplicate: "Không được ghim trùng collection"
        case .tooMany: "Home giữ tối đa 5 collection đang đọc"
        }
    }
}

public enum HomePinService {
    public static let maxPins = 5

    /// Đọc danh sách id đang ghim (JSON, thứ tự user thêm). JSON rỗng/chưa ghi →
    /// đọc 2 slot cũ (lazy migrate). Không có hàng settings → mảng rỗng.
    /// Xoá collection đang ghim → pin tự rớt (lọc dangling id, JSON không có FK).
    public static func ids(on db: SQLiteDatabase) throws -> [String] {
        guard
            let row = try db.rows(
                """
                SELECT home_pin_ids, home_shortcut_1_id, home_shortcut_2_id
                FROM settings WHERE id = 1;
                """
            ).first,
            row.count == 3
        else {
            return []
        }
        let raw: [String]
        if let json = row[0].textValue, !json.isEmpty,
           let legacy = JSONStringArray.decode(json), !legacy.isEmpty
        {
            raw = legacy
        } else {
            // JSON chưa ghi (cài cũ) → đọc 2 slot rồi compact, không ghi ngược.
            raw = [row[1].textValue, row[2].textValue]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
        }
        // Xoá collection → id không còn tồn tại; bỏ khỏi danh sách (giữ thứ tự).
        return raw.filter { id in
            (try? db.scalarInt64(
                "SELECT 1 FROM collections WHERE id = ? LIMIT 1;",
                [.text(id)])) != nil
        }
    }

    /// Ghi lại toàn bộ danh sách ghim (JSON). Validate TRƯỚC khi ghi:
    /// - mỗi id phải tồn tại (`.notFound`) và không phải kho tạm (`.isInbox`)
    /// - không trùng (`.duplicate`), không quá 5 (`.tooMany`)
    /// Thứ tự mảng = thứ tự ghim; trả danh sách chuẩn hoá đã ghi.
    @discardableResult
    public static func set(
        on db: SQLiteDatabase, ids: [String]
    ) throws -> [String] {
        let normalized = ids.filter { !$0.isEmpty }
        guard normalized.count <= maxPins else {
            throw HomePinError.tooMany
        }
        guard Set(normalized).count == normalized.count else {
            throw HomePinError.duplicate
        }
        for id in normalized {
            guard let isDefault = try db.scalarInt64(
                "SELECT is_default FROM collections WHERE id = ? LIMIT 1;",
                [.text(id)])
            else {
                throw HomePinError.notFound
            }
            guard isDefault == 0 else { throw HomePinError.isInbox }
        }
        try db.run(
            "UPDATE settings SET home_pin_ids = ? WHERE id = 1;",
            [.text(JSONStringArray.encode(normalized))])
        return normalized
    }
}