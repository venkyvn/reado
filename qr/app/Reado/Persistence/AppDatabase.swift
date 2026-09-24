import Foundation
import GRDB

final class AppDatabase {
    let dbQueue: DatabaseQueue

    init(inMemory: Bool, clock: Clock = SystemClock(), timeZone: TimeZone = .current) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        if inMemory {
            dbQueue = try DatabaseQueue(configuration: config)
        } else {
            let folder = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Reado", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("reado.sqlite")
            dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        }
        try migrator.migrate(dbQueue)
        try seedIfNeeded(clock: clock, timeZone: timeZone)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: SchemaSQL.create)
        }
        migrator.registerMigration("v2_lab_ia") { db in
            try db.execute(sql: """
            CREATE TABLE analysis_agents (
              id          TEXT NOT NULL PRIMARY KEY,
              kind        TEXT NOT NULL CHECK (kind IN ('reado_proxy', 'openai_compat')),
              name        TEXT NOT NULL,
              base_url    TEXT,
              model       TEXT,
              created_at  TEXT NOT NULL
            );
            """)
            try db.execute(sql: #"ALTER TABLE settings ADD COLUMN cefr_levels TEXT NOT NULL DEFAULT '["B2"]'"#)
            try db.execute(sql: #"ALTER TABLE settings ADD COLUMN home_pin_ids TEXT NOT NULL DEFAULT '[]'"#)
            try db.execute(sql: #"ALTER TABLE settings ADD COLUMN review_priority_ids TEXT NOT NULL DEFAULT '[]'"#)
            try db.execute(sql: "ALTER TABLE settings ADD COLUMN review_all INTEGER NOT NULL DEFAULT 0")
            try db.execute(sql: "ALTER TABLE settings ADD COLUMN active_agent_id TEXT")
        }
        return migrator
    }

    func seedIfNeeded(clock: Clock, timeZone: TimeZone) throws {
        try dbQueue.write { db in
            let now = ISO8601UTC.string(from: clock.now)
            if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM analysis_agents") == 0 {
                try AnalysisAgentRecord(
                    id: SchemaSQL.proxyAgentId,
                    kind: "reado_proxy",
                    name: "Reado proxy",
                    baseUrl: nil,
                    model: nil,
                    createdAt: now
                ).insert(db)
            }
            if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM settings") == 0 {
                let inboxId = IDs.uuid()
                try CollectionRecord(
                    id: inboxId,
                    name: "Kho tạm",
                    isDefault: true,
                    createdAt: now
                ).insert(db)
                try SettingsRecord(
                    id: 1,
                    cefrLevel: "B2",
                    dailyNewLimit: 10,
                    requestRetention: 0.9,
                    maximumInterval: 36500,
                    enableFuzz: true,
                    dayCutoffHour: 4,
                    timezone: timeZone.identifier,
                    enableShortTerm: false,
                    knownStability: nil,
                    leechLapses: nil,
                    fsrsParams: nil,
                    fsrsVersion: "fsrs-6",
                    homeShortcut1Id: nil,
                    homeShortcut2Id: nil,
                    cefrLevelsJSON: JSONStringArray.encode(["B2"]),
                    homePinIdsJSON: "[]",
                    reviewPriorityIdsJSON: "[]",
                    reviewAll: true,
                    activeAgentId: SchemaSQL.proxyAgentId
                ).insert(db)
            } else {
                var row = try SettingsRecord.fetchOne(db, key: 1)!
                var dirty = false
                if JSONStringArray.decode(row.homePinIdsJSON).isEmpty {
                    let legacy = [row.homeShortcut1Id, row.homeShortcut2Id].compactMap { $0 }
                    if !legacy.isEmpty {
                        row.homePinIdsJSON = JSONStringArray.encode(legacy)
                        dirty = true
                    }
                }
                if JSONStringArray.decode(row.cefrLevelsJSON).isEmpty {
                    let mapped = row.cefrLevel == "A2" ? "A" : row.cefrLevel
                    row.cefrLevelsJSON = JSONStringArray.encode([mapped])
                    dirty = true
                }
                if row.activeAgentId == nil {
                    row.activeAgentId = SchemaSQL.proxyAgentId
                    dirty = true
                }
                if dirty { try row.update(db) }
            }
        }
    }

    func inbox() throws -> CollectionRecord {
        try dbQueue.read { db in
            guard let row = try CollectionRecord.filter(Column("is_default") == true).fetchOne(db) else {
                throw AppError.missingInbox
            }
            return row
        }
    }

    func settings() throws -> SettingsRecord {
        try dbQueue.read { db in
            guard let row = try SettingsRecord.fetchOne(db, key: 1) else {
                throw AppError.missingSettings
            }
            return row
        }
    }
}

enum AppError: LocalizedError {
    case missingInbox
    case missingSettings
    case invalidDailyLimit
    case emptyImport
    case csv(String)
    case pinLimit
    case priorityLimit
    case cannotDeleteProxy

    var errorDescription: String? {
        switch self {
        case .missingInbox: return "Thiếu kho tạm."
        case .missingSettings: return "Thiếu settings."
        case .invalidDailyLimit: return "daily_new_limit phải ≥ 1 — 0 sẽ tắt nhánh Học."
        case .emptyImport: return "0 dòng còn chọn — không ghi."
        case .csv(let message): return message
        case .pinLimit: return "Tối đa \(SchemaSQL.pinLimit) collection ghim trên Home."
        case .priorityLimit: return "Ưu tiên tối đa \(SchemaSQL.priorityLimit) collection."
        case .cannotDeleteProxy: return "Không xoá được Reado proxy."
        }
    }
}
