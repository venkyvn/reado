import Foundation

/// PDF gắn với một collection có tên (FR-23, ADR-058, pdf-reader-r1). File không
/// bao giờ được chép vào app — `bookmark` là `URL.bookmarkData` (security-scoped,
/// base64 vì `SQLValue` không có BLOB) trỏ tới file đang nằm trong Files/iCloud
/// Drive của người dùng. `pageIndex` đếm từ 0 — UI hiện `pageIndex + 1`.
public struct PDFSource: Equatable, Sendable {
    public let collectionID: String
    public let displayName: String
    public let bookmark: String
    public let pageIndex: Int
    public let pageCount: Int
    public let updatedAt: Date

    public init(
        collectionID: String,
        displayName: String,
        bookmark: String,
        pageIndex: Int,
        pageCount: Int,
        updatedAt: Date
    ) {
        self.collectionID = collectionID
        self.displayName = displayName
        self.bookmark = bookmark
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        self.updatedAt = updatedAt
    }
}

/// CRUD cho bảng `pdf_sources` (migration v5). Khoá chính là `collection_id` —
/// mỗi collection gắn tối đa 1 PDF; `attach` ghi đè thẳng, không cần xoá trước.
/// Kho tạm (`is_default`) bị chặn ở tầng app (db.md A.2.2) — repository không tự
/// kiểm `is_default`, vì nó chỉ là lớp CRUD, không phải nơi giữ luật nghiệp vụ.
public enum PDFSourceRepository {

    /// Gắn (hoặc đổi) PDF cho một collection. UPSERT theo `collection_id` — gắn
    /// lần 2 ghi đè nguyên dòng cũ và **đưa `page_index` về 0** (đổi file thì
    /// trang đang đọc của file cũ vô nghĩa với file mới).
    public static func attach(
        on db: SQLiteDatabase,
        collectionID: String,
        displayName: String,
        bookmark: String,
        pageCount: Int,
        now: Date
    ) throws {
        try db.run(
            """
            INSERT INTO pdf_sources (collection_id, display_name, bookmark, page_index, page_count, updated_at)
            VALUES (?, ?, ?, 0, ?, ?)
            ON CONFLICT(collection_id) DO UPDATE SET
              display_name = excluded.display_name,
              bookmark     = excluded.bookmark,
              page_index   = 0,
              page_count   = excluded.page_count,
              updated_at   = excluded.updated_at;
            """,
            [
                .text(collectionID),
                .text(displayName),
                .text(bookmark),
                .int(Int64(pageCount)),
                .text(ISOTimestamp.string(from: now)),
            ])
    }

    /// Đổi trang đang đọc. Không báo lỗi nếu collection chưa gắn PDF (reader gọi
    /// liên tục lúc lật trang — một lần gọi thừa không phải lỗi logic).
    public static func updatePage(
        on db: SQLiteDatabase, collectionID: String, pageIndex: Int, now: Date
    ) throws {
        try db.run(
            "UPDATE pdf_sources SET page_index = ?, updated_at = ? WHERE collection_id = ?;",
            [.int(Int64(pageIndex)), .text(ISOTimestamp.string(from: now)), .text(collectionID)])
    }

    /// Ghi lại bookmark mới khi bookmark cũ "stale" (`URL(resolvingBookmarkData:)`
    /// báo `isStale`) — vẫn CÙNG file, chỉ refresh con trỏ hệ thống, nên **không**
    /// đụng `page_index`/`page_count`.
    public static func updateBookmark(
        on db: SQLiteDatabase, collectionID: String, bookmark: String, now: Date
    ) throws {
        try db.run(
            "UPDATE pdf_sources SET bookmark = ?, updated_at = ? WHERE collection_id = ?;",
            [.text(bookmark), .text(ISOTimestamp.string(from: now)), .text(collectionID)])
    }

    /// Gỡ liên kết — chỉ xoá dòng `pdf_sources`. Không đụng file gốc (Reado chưa
    /// từng chép nó) và không đụng vocab/session đã lưu từ PDF đó.
    public static func detach(on db: SQLiteDatabase, collectionID: String) throws {
        try db.run("DELETE FROM pdf_sources WHERE collection_id = ?;", [.text(collectionID)])
    }

    /// PDF đang gắn của một collection, `nil` nếu chưa gắn.
    public static func source(on db: SQLiteDatabase, collectionID: String) throws -> PDFSource? {
        let rows = try db.rows(
            """
            SELECT collection_id, display_name, bookmark, page_index, page_count, updated_at
            FROM pdf_sources WHERE collection_id = ?;
            """, [.text(collectionID)])
        guard let row = rows.first else { return nil }
        return PDFSource(
            collectionID: row["collection_id"].textValue ?? "",
            displayName: row["display_name"].textValue ?? "",
            bookmark: row["bookmark"].textValue ?? "",
            pageIndex: Int(row["page_index"].intValue ?? 0),
            pageCount: Int(row["page_count"].intValue ?? 0),
            updatedAt: ISOTimestamp.date(from: row["updated_at"].textValue ?? "") ?? Date())
    }
}
