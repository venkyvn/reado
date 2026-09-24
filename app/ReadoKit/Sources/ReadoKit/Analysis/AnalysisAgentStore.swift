import Foundation

/// Metadata agent trong SQLite. Secret không nằm ở đây — Keychain theo `id`.
public struct AnalysisAgent: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: String
    public let name: String
    public let baseURL: String?
    public let model: String?
    public let hasKey: Bool

    public var isBuiltinProxy: Bool { kind == "reado_proxy" }
}

/// Save/xoá secret. Production = Keychain. Test truyền bản nhớ để không đụng Keychain máy.
public protocol AgentSecretStore: Sendable {
    func save(agentID: String, apiKey: String) throws
    func contains(agentID: String) -> Bool
    func delete(agentID: String)
}

public struct KeychainAgentSecrets: AgentSecretStore, Sendable {
    public init() {}

    public func save(agentID: String, apiKey: String) throws {
        try KeychainStore.save(agentID: agentID, apiKey: apiKey)
    }

    public func contains(agentID: String) -> Bool {
        KeychainStore.contains(agentID: agentID)
    }

    public func delete(agentID: String) {
        KeychainStore.delete(agentID: agentID)
    }
}

/// FR-21 — nhiều agent OpenAI-compat, đúng một cái active. Proxy seed không xoá được.
/// Login sau này phải namespace key theo tài khoản và xoá key lúc logout; không upload key.
public enum AnalysisAgentStore {
    public static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/openai"
    public static let geminiModel = "gemini-2.5-flash"

    public enum StoreError: Error, LocalizedError {
        case missingField(String)
        case insecureURL
        case cannotDeleteProxy
        case missingKey
        case notFound

        public var errorDescription: String? {
            switch self {
            case let .missingField(name): "Thiếu \(name)"
            case .insecureURL: "Base URL phải là HTTPS (HTTP chỉ cho localhost hoặc mạng LAN)"
            case .cannotDeleteProxy: "Không xoá được proxy mặc định"
            case .missingKey: "Agent này chưa có API key"
            case .notFound: "Không tìm thấy agent"
            }
        }
    }

    public static func list(
        on db: SQLiteDatabase,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws -> (agents: [AnalysisAgent], activeID: String) {
        let activeID = try db.scalarString(
            "SELECT active_agent_id FROM settings WHERE id = 1;") ?? Seeder.readoProxyAgentID
        let rows = try db.rows(
            """
            SELECT id, kind, name, base_url, model
            FROM analysis_agents
            ORDER BY created_at;
            """)
        let agents = rows.map { row in
            let id = row[0].textValue ?? ""
            let kind = row[1].textValue ?? ""
            return AnalysisAgent(
                id: id,
                kind: kind,
                name: row[2].textValue ?? "",
                baseURL: row[3].textValue,
                model: row[4].textValue,
                hasKey: kind == "reado_proxy" || secrets.contains(agentID: id))
        }
        return (agents, activeID)
    }

    /// Thêm agent user và (mặc định) đặt nó làm active cho lần chụp kế tiếp.
    @discardableResult
    public static func add(
        on db: SQLiteDatabase,
        name: String,
        baseURL: String,
        model: String,
        apiKey: String,
        makeActive: Bool = true,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw StoreError.missingField("tên") }
        guard !trimmedModel.isEmpty else { throw StoreError.missingField("model") }
        guard !trimmedKey.isEmpty else { throw StoreError.missingField("API key") }
        let stored = AgentURLRule.storedBase(baseURL)
        guard AgentURLRule.allows(stored) else { throw StoreError.insecureURL }

        let id = Identifier.uuid()
        try db.run(
            """
            INSERT INTO analysis_agents (id, kind, name, base_url, model, created_at)
            VALUES (?, 'openai_compat', ?, ?, ?, ?);
            """,
            [
                .text(id),
                .text(trimmedName),
                .text(stored),
                .text(trimmedModel),
                .text(ISOTimestamp.string(from: Date())),
            ])
        do {
            try secrets.save(agentID: id, apiKey: trimmedKey)
        } catch {
            try? db.run("DELETE FROM analysis_agents WHERE id = ?;", [.text(id)])
            throw error
        }
        if makeActive {
            try setActive(on: db, id: id, secrets: secrets)
        }
        return id
    }

    /// Sửa metadata agent user. `apiKey == nil` giữ nguyên secret hiện tại.
    public static func update(
        on db: SQLiteDatabase,
        id: String,
        name: String,
        baseURL: String,
        model: String,
        apiKey: String? = nil,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws {
        guard id != Seeder.readoProxyAgentID else { throw StoreError.notFound }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacementKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw StoreError.missingField("tên") }
        guard !trimmedModel.isEmpty else { throw StoreError.missingField("model") }
        let stored = AgentURLRule.storedBase(baseURL)
        guard AgentURLRule.allows(stored) else { throw StoreError.insecureURL }
        let rows = try db.rows(
            "SELECT id FROM analysis_agents WHERE id = ? AND kind = 'openai_compat' LIMIT 1;",
            [.text(id)])
        guard !rows.isEmpty else { throw StoreError.notFound }
        if replacementKey?.isEmpty != false, !secrets.contains(agentID: id) {
            throw StoreError.missingKey
        }

        try db.inTransaction {
            try db.run(
                """
                UPDATE analysis_agents
                SET name = ?, base_url = ?, model = ?
                WHERE id = ?;
                """,
                [.text(trimmedName), .text(stored), .text(trimmedModel), .text(id)])
            if let replacementKey, !replacementKey.isEmpty {
                try secrets.save(agentID: id, apiKey: replacementKey)
            }
        }
    }

    public static func setActive(
        on db: SQLiteDatabase,
        id: String,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws {
        let rows = try db.rows(
            "SELECT kind FROM analysis_agents WHERE id = ? LIMIT 1;",
            [.text(id)])
        guard let kind = rows.first?.first?.textValue else {
            throw StoreError.notFound
        }
        if kind == "openai_compat", !secrets.contains(agentID: id) {
            throw StoreError.missingKey
        }
        try db.run(
            "UPDATE settings SET active_agent_id = ? WHERE id = 1;",
            [.text(id)])
    }

    /// Xoá agent user. Đang active thì trỏ về proxy trước, rồi mới xoá key.
    public static func delete(
        on db: SQLiteDatabase,
        id: String,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws {
        guard id != Seeder.readoProxyAgentID else { throw StoreError.cannotDeleteProxy }
        let rows = try db.rows(
            "SELECT id FROM analysis_agents WHERE id = ? LIMIT 1;",
            [.text(id)])
        guard !rows.isEmpty else { throw StoreError.notFound }
        let activeID = try db.scalarString(
            "SELECT active_agent_id FROM settings WHERE id = 1;")
        try db.inTransaction {
            if activeID == id {
                try db.run(
                    "UPDATE settings SET active_agent_id = ? WHERE id = 1;",
                    [.text(Seeder.readoProxyAgentID)])
            }
            try db.run("DELETE FROM analysis_agents WHERE id = ?;", [.text(id)])
        }
        secrets.delete(agentID: id)
    }
}
