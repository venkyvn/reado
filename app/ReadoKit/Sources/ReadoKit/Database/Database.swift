import CSQLite
import Foundation

/// SQLITE_TRANSIENT dưới dạng giá trị Swift (macro C dễ bị importer bỏ qua)
private let sqliteTransient = unsafeBitCast(
    -1, to: sqlite3_destructor_type.self)

/// Giá trị bind/đọc từ SQLite — map dialect đã chốt (db.md A.1):
/// boolean → INTEGER 0/1, uuid/timestamp/JSON → TEXT, REAL → Double.
public enum SQLValue: Equatable, Sendable {
    case null
    case int(Int64)
    case double(Double)
    case text(String)

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public var textValue: String? {
        if case let .text(value) = self { return value }
        return nil
    }

    public var intValue: Int64? {
        if case let .int(value) = self { return value }
        return nil
    }

    public var doubleValue: Double? {
        if case let .double(value) = self { return value }
        return nil
    }
}

public enum DatabaseError: Error, LocalizedError, Equatable {
    case openFailed(String)
    case statementNotReady
    case failed(String, statement: String?)

    public var errorDescription: String? {
        switch self {
        case let .openFailed(message): "Không mở được SQLite: \(message)"
        case .statementNotReady: "Statement chưa sẵn sàng"
        case let .failed(message, statement):
            if let statement { "SQLite: \(message) — SQL: \(statement)" }
            else { "SQLite: \(message)" }
        }
    }
}

/// Một kết nối SQLite. Mở là bật `PRAGMA foreign_keys = ON`
/// (db.md A.1 — SQLite mặc định TẮT nên phải bật mỗi connection).
/// Dùng C API hệ thống, KHÔNG thêm dependency bên ngoài (AGENTS mục 3.6).
public final class SQLiteDatabase: @unchecked Sendable {
    /// Cần cho SQLiteStatement (cùng file) — không phải API công khai cho feature.
    fileprivate var handle: OpaquePointer?

    public init(path: String) throws {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(
            path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let db else {
            let message =
                db.map { String(cString: sqlite3_errmsg($0)) }
                ?? "sqlite3_open_v2 rc=\(rc)"
            sqlite3_close_v2(db)
            throw DatabaseError.openFailed(message)
        }
        self.handle = db
        sqlite3_busy_timeout(db, 3_000)
        try exec("PRAGMA foreign_keys = ON;")
    }

    /// DB trong bộ nhớ — cho unit test.
    public convenience init(inMemory: Void) throws {
        try self.init(path: ":memory:")
    }

    deinit {
        if let handle { sqlite3_close_v2(handle) }
    }

    /// Chạy SQL không biến (DDL/PRAGMA). Nhiều câu cách nhau bởi `;` được phép.
    @discardableResult
    public func exec(_ sql: String) throws -> Self {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard rc == SQLITE_OK else {
            let message =
                errorMessage.map { String(cString: $0) }
                ?? "sqlite error \(rc)"
            sqlite3_free(errorMessage)
            throw DatabaseError.failed(message, statement: sql)
        }
        return self
    }

    public func prepare(_ sql: String) throws -> SQLiteStatement {
        try SQLiteStatement(database: self, sql: sql)
    }

    /// Chạy INSERT/UPDATE/DELETE có tham số.
    public func run(_ sql: String, _ parameters: [SQLValue] = []) throws {
        let statement = try prepare(sql)
        try statement.bind(parameters)
        let rc = try statement.step()
        guard rc == SQLITE_DONE else {
            throw DatabaseError.failed(
                "mong đợi SQLITE_DONE, nhận \(rc)", statement: sql)
        }
    }

    /// Truy vấn trả mảng dòng; `limit > 0` thì dừng sau `limit` dòng.
    public func rows(
        _ sql: String, _ parameters: [SQLValue] = [], limit: Int = 0
    ) throws -> [[SQLValue]] {
        let statement = try prepare(sql)
        try statement.bind(parameters)
        var result: [[SQLValue]] = []
        while try statement.step() == SQLITE_ROW {
            var row: [SQLValue] = []
            for index in 0..<statement.columnCount() {
                row.append(try statement.columnValue(Int32(index)))
            }
            result.append(row)
            if limit > 0 && result.count >= limit { break }
        }
        return result
    }

    /// Một giá trị đầu tiên của dòng đầu; không có dòng → nil.
    public func scalar(_ sql: String, _ parameters: [SQLValue] = []) throws
        -> SQLValue?
    {
        let statement = try prepare(sql)
        try statement.bind(parameters)
        guard try statement.step() == SQLITE_ROW else { return nil }
        return try statement.columnValue(0)
    }

    public func scalarInt64(_ sql: String, _ parameters: [SQLValue] = []) throws
        -> Int64?
    {
        guard let value = try scalar(sql, parameters) else { return nil }
        guard case let .int(result) = value else {
            throw DatabaseError.failed("mong đợi INTEGER", statement: sql)
        }
        return result
    }

    public func scalarString(_ sql: String, _ parameters: [SQLValue] = []) throws
        -> String?
    {
        guard let value = try scalar(sql, parameters) else { return nil }
        guard case let .text(result) = value else {
            throw DatabaseError.failed("mong đợi TEXT", statement: sql)
        }
        return result
    }

    /// Giao dịch; lỗi thì ROLLBACK và ném tiếp lỗi gốc.
    public func inTransaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN DEFERRED TRANSACTION;")
        do {
            let value = try body()
            try exec("COMMIT;")
            return value
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }
}

public final class SQLiteStatement: @unchecked Sendable {
    private let database: SQLiteDatabase
    private var stmt: OpaquePointer?

    fileprivate init(database: SQLiteDatabase, sql: String) throws {
        self.database = database
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(database.handle, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            throw DatabaseError.failed(
                database.lastErrorMessage(), statement: sql)
        }
        self.stmt = stmt
    }

    deinit {
        sqlite3_finalize(stmt)
    }

    public func bind(_ parameters: [SQLValue]) throws {
        guard let stmt else { throw DatabaseError.statementNotReady }
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        for (index, value) in parameters.enumerated() {
            let position = Int32(index + 1)
            let rc: Int32
            switch value {
            case .null: rc = sqlite3_bind_null(stmt, position)
            case let .int(v): rc = sqlite3_bind_int64(stmt, position, v)
            case let .double(v): rc = sqlite3_bind_double(stmt, position, v)
            case let .text(v):
                rc = sqlite3_bind_text(
                    stmt, position, v, -1, sqliteTransient)
            }
            guard rc == SQLITE_OK else {
                throw DatabaseError.failed(
                    database.lastErrorMessage(), statement: "bind #\(position)")
            }
        }
    }

    /// SQLITE_ROW nếu còn dòng, SQLITE_DONE nếu hết. Lỗi SQLite thì ném.
    @discardableResult
    public func step() throws -> Int32 {
        guard let stmt else { throw DatabaseError.statementNotReady }
        let rc = sqlite3_step(stmt)
        switch rc {
        case SQLITE_ROW, SQLITE_DONE: return rc
        default:
            throw DatabaseError.failed(
                database.lastErrorMessage(), statement: "step")
        }
    }

    public func columnCount() -> Int32 {
        guard let stmt else { return 0 }
        return sqlite3_column_count(stmt)
    }

    public func columnValue(_ index: Int32) throws -> SQLValue {
        guard let stmt else { throw DatabaseError.statementNotReady }
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_NULL: return .null
        case SQLITE_INTEGER: return .int(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT: return .double(sqlite3_column_double(stmt, index))
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(stmt, index) else {
                return .null
            }
            return .text(String(cString: text))
        default:
            throw DatabaseError.failed(
                "kiểu cột không hỗ trợ (BLOB) tại \(index)", statement: nil)
        }
    }
}

extension SQLiteDatabase {
    fileprivate func lastErrorMessage() -> String {
        guard let handle else { return "không có kết nối" }
        return String(cString: sqlite3_errmsg(handle))
    }
}