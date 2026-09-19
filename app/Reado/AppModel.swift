import Foundation
import ReadoKit

/// Model mở SQLite, migration, seed và chịu trách nhiệm đọc overview.
/// Scaffold (ROADMAP task 1.2): đồng bộ trên main, dữ liệu nhỏ — màn hình
/// thật (FR-01..03…) sẽ chuyển qua actor/URLSession khi có proxy.
@Observable
final class AppModel {
    private(set) var database: SQLiteDatabase?
    private(set) var failure: String?
    private(set) var collections: [CollectionOverview] = []

    struct CollectionOverview: Identifiable, Equatable {
        let id: String
        let name: String
        let isDefault: Bool
        let totalItems: Int
        let dueNow: Int
    }

    init() {
        do {
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
            let directory = supportURL.appendingPathComponent(
                "Reado", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let database = try SQLiteDatabase(
                path: directory.appendingPathComponent("reado.sqlite3").path)
            try Migration.run(on: database)
            try Seeder.seed(
                on: database, timezone: TimeZone.current.identifier)
            self.database = database
            reloadOverview()
        } catch {
            failure = String(describing: error)
        }
    }

    func reloadOverview() {
        guard let database else { return }
        collections = (try? Self.loadOverview(db: database)) ?? []
    }

    /// Scaffold: tổng số từ + số card `due_at <= now` (chưa phải hàng đợi
    /// FR-11 chính thức — chỉ để chứng minh wiring DB → UI).
    static func loadOverview(db: SQLiteDatabase) throws
        -> [CollectionOverview]
    {
        let nowIso = ISOTimestamp.string(from: SystemClock().now)
        let rows = try db.rows(
            """
            SELECT c.id, c.name, c.is_default,
                   (SELECT COUNT(*) FROM vocab_items v
                     WHERE v.collection_id = c.id),
                   (SELECT COUNT(*) FROM cards ca
                     JOIN vocab_items v ON v.id = ca.vocab_item_id
                     WHERE v.collection_id = c.id
                       AND ca.suspended_at IS NULL
                       AND ca.due_at <= ?)
            FROM collections c
            ORDER BY c.is_default DESC, c.name COLLATE NOCASE;
            """,
            [.text(nowIso)])
        return try rows.map { row in
            guard row.count >= 5 else {
                throw DatabaseError.failed(
                    "overview thiếu cột", statement: "overview")
            }
            return CollectionOverview(
                id: row[0].textValue ?? "",
                name: row[1].textValue ?? "",
                isDefault: (row[2].intValue ?? 0) != 0,
                totalItems: Int(row[3].intValue ?? 0),
                dueNow: Int(row[4].intValue ?? 0))
        }
    }
}