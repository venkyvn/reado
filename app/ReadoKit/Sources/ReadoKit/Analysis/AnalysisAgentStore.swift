import Foundation

/// Metadata agent trong SQLite. Secret không nằm ở đây — Keychain theo `id`.
public struct AnalysisAgent: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: String
    public let name: String
    public let baseURL: String?
    public let model: String?
    public let hasKey: Bool

    /// ADR-049: hàng seed "chưa chọn agent" — `AnalysisAgentStore.list()` lọc
    /// khỏi danh sách hiển thị; giữ property để store tự nhận diện hàng này.
    public var isPlaceholder: Bool { kind == "reado_proxy" }

    /// apple-ai-r1 T5 (ADR-061) — hàng builtin Apple Intelligence (ngược với
    /// `isPlaceholder`: hàng này CÓ hiện trong `list()`, chỉ không xoá/sửa
    /// được và không cần key).
    public var isAppleIntelligence: Bool { kind == AnalysisAgentStore.appleKind }
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

/// FR-21 — nhiều agent OpenAI-compat, đúng một cái active. Hàng seed placeholder
/// (ADR-049) không xoá được, không hiện trong `list()`.
/// Login sau này phải namespace key theo tài khoản và xoá key lúc logout; không upload key.
public enum AnalysisAgentStore {
    public static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/openai"
    public static let geminiModel = "gemini-2.5-flash"
    /// Đo thật 2026-09-26: tắt suy nghĩ (`OpenAICompatClient.extraBodyParams`)
    /// đưa `deepseek-v4.1-flash` từ 63s xuống 15–18s cho một trang OCR.
    public static let aiboxBaseURL = "https://api.ai-box.vn/v1"
    public static let aiboxModel = "deepseek-v4.1-flash"
    /// apple-ai-r1 T5 (ADR-061).
    public static let appleKind = "apple_intelligence"

    public enum StoreError: Error, LocalizedError, Equatable {
        case missingField(String)
        case insecureURL
        case cannotDeletePlaceholder
        case missingKey
        case notFound
        /// apple-ai-r1 T5 — hàng Apple Intelligence: không xoá/sửa được,
        /// không có key (khác `.cannotDeletePlaceholder` — đó là hàng ẨN,
        /// hàng này vẫn HIỆN trong `list()` nhưng chặn update/delete).
        case builtinAgent

        public var errorDescription: String? {
            switch self {
            case let .missingField(name): "Thiếu \(name)"
            case .insecureURL: "Base URL phải là HTTPS (HTTP chỉ cho localhost hoặc mạng LAN)"
            case .cannotDeletePlaceholder: "Không xoá được agent mặc định"
            case .missingKey: "Agent này chưa có API key"
            case .notFound: "Không tìm thấy agent"
            case .builtinAgent: "Không sửa hay xoá được Apple Intelligence"
            }
        }
    }

    /// `agents` bỏ hàng placeholder (ADR-049) — UI chỉ thấy agent BYOK thật +
    /// hàng Apple Intelligence (builtin, apple-ai-r1 T5). Apple LUÔN đứng đầu
    /// (không theo `created_at`) — Settings luôn thấy nó ở vị trí cố định.
    /// `activeID` KHÔNG lọc: lúc cài mới/vừa xoá agent, nó trỏ về placeholder
    /// — caller (AppModel.activeAgentReady, SettingsView) tự suy "chưa có agent"
    /// khi không tìm thấy activeID trong `agents`.
    public static func list(
        on db: SQLiteDatabase,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws -> (agents: [AnalysisAgent], activeID: String) {
        let activeID = try db.scalarString(
            "SELECT active_agent_id FROM settings WHERE id = 1;") ?? Seeder.placeholderAgentID
        let rows = try db.rows(
            """
            SELECT id, kind, name, base_url, model
            FROM analysis_agents
            ORDER BY (kind = 'apple_intelligence') DESC, created_at;
            """)
        let agents = rows.compactMap { row -> AnalysisAgent? in
            let id = row["id"].textValue ?? ""
            let kind = row["kind"].textValue ?? ""
            guard kind != "reado_proxy" else { return nil }
            // Hàng Apple không có key (local, không BYOK) — bỏ qua Keychain,
            // tránh gọi secrets.contains cho một id không bao giờ có trong đó.
            let hasKey = kind == appleKind ? false : secrets.contains(agentID: id)
            return AnalysisAgent(
                id: id,
                kind: kind,
                name: row["name"].textValue ?? "",
                baseURL: row["base_url"].textValue,
                model: row["model"].textValue,
                hasKey: hasKey)
        }
        return (agents, activeID)
    }

    /// ADR-061 — Apple là mặc định CHỈ KHI chưa chọn agent nào (active đang là
    /// placeholder). Đã chọn BYOK (hoặc đã từng chọn Apple) thì giữ nguyên —
    /// Apple không "giành lại" một lựa chọn chủ động. Trả `true` nếu vừa đổi.
    @discardableResult
    public static func applyDefault(on db: SQLiteDatabase, appleAvailable: Bool) throws -> Bool {
        guard appleAvailable else { return false }
        let activeID = try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;")
        guard activeID == Seeder.placeholderAgentID else { return false }
        try db.run(
            "UPDATE settings SET active_agent_id = ? WHERE id = 1;",
            [.text(Seeder.appleAgentID)])
        return true
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
        guard id != Seeder.placeholderAgentID else { throw StoreError.notFound }
        guard id != Seeder.appleAgentID else { throw StoreError.builtinAgent }
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

    /// `knownHasKey`: khi gọi đã biết sẵn (ví dụ từ `list()`), bỏ qua
    /// `secrets.contains` — tránh gọi Keychain hai lần cho cùng một agent
    /// (list() đã kiểm hết, setActive kiểm lại lần nữa khiến UI khựng khi tap).
    public static func setActive(
        on db: SQLiteDatabase,
        id: String,
        knownHasKey: Bool? = nil,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws {
        let rows = try db.rows(
            "SELECT kind FROM analysis_agents WHERE id = ? LIMIT 1;",
            [.text(id)])
        guard let kind = rows.first?.first?.textValue else {
            throw StoreError.notFound
        }
        if kind == "openai_compat" {
            let hasKey = knownHasKey ?? secrets.contains(agentID: id)
            guard hasKey else { throw StoreError.missingKey }
        }
        try db.run(
            "UPDATE settings SET active_agent_id = ? WHERE id = 1;",
            [.text(id)])
    }

    /// Xoá agent user. Đang active thì trỏ về placeholder trước, rồi mới xoá key.
    public static func delete(
        on db: SQLiteDatabase,
        id: String,
        secrets: AgentSecretStore = KeychainAgentSecrets()
    ) throws {
        guard id != Seeder.placeholderAgentID else { throw StoreError.cannotDeletePlaceholder }
        guard id != Seeder.appleAgentID else { throw StoreError.builtinAgent }
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
                    [.text(Seeder.placeholderAgentID)])
            }
            try db.run("DELETE FROM analysis_agents WHERE id = ?;", [.text(id)])
        }
        secrets.delete(agentID: id)
    }
}
