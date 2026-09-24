import Foundation
import GRDB

struct CollectionRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Hashable {
    static let databaseTableName = "collections"

    var id: String
    var name: String
    var isDefault: Bool
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case isDefault = "is_default"
        case createdAt = "created_at"
    }
}

struct VocabItemRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Hashable {
    static let databaseTableName = "vocab_items"

    var id: String
    var collectionId: String
    var term: String
    var termNormalized: String
    var pos: String
    var ipa: String?
    var meaningVi: String
    var example: String
    var cefr: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case collectionId = "collection_id"
        case term
        case termNormalized = "term_normalized"
        case pos, ipa
        case meaningVi = "meaning_vi"
        case example, cefr
        case createdAt = "created_at"
    }
}

struct CardRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Hashable {
    static let databaseTableName = "cards"

    var id: String
    var vocabItemId: String
    var direction: String
    var state: String
    var stability: Double
    var difficulty: Double
    var reps: Int
    var lapses: Int
    var learningSteps: Int
    var scheduledDays: Int
    var lastReviewAt: String?
    var dueAt: String
    var suspendedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case vocabItemId = "vocab_item_id"
        case direction, state, stability, difficulty, reps, lapses
        case learningSteps = "learning_steps"
        case scheduledDays = "scheduled_days"
        case lastReviewAt = "last_review_at"
        case dueAt = "due_at"
        case suspendedAt = "suspended_at"
    }
}

struct ReviewLogRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Hashable {
    static let databaseTableName = "review_logs"

    var id: String
    var cardId: String
    var mode: String
    var rating: Int
    var stateBefore: String
    var stabilityBefore: Double
    var difficultyBefore: Double
    var learningStepsBefore: Int
    var dueBefore: String
    var elapsedDays: Int
    var scheduledDays: Int
    var reviewedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case mode, rating
        case stateBefore = "state_before"
        case stabilityBefore = "stability_before"
        case difficultyBefore = "difficulty_before"
        case learningStepsBefore = "learning_steps_before"
        case dueBefore = "due_before"
        case elapsedDays = "elapsed_days"
        case scheduledDays = "scheduled_days"
        case reviewedAt = "reviewed_at"
    }
}

struct AnalysisAgentRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Hashable {
    static let databaseTableName = "analysis_agents"

    var id: String
    var kind: String
    var name: String
    var baseUrl: String?
    var model: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, kind, name, model
        case baseUrl = "base_url"
        case createdAt = "created_at"
    }

    var isProxy: Bool { kind == "reado_proxy" }
    var hasKey: Bool { isProxy || AgentKeychain.hasKey(id: id) }
}

struct SettingsRecord: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "settings"

    var id: Int
    var cefrLevel: String
    var dailyNewLimit: Int
    var requestRetention: Double
    var maximumInterval: Int
    var enableFuzz: Bool
    var dayCutoffHour: Int
    var timezone: String
    var enableShortTerm: Bool
    var knownStability: Double?
    var leechLapses: Int?
    var fsrsParams: String?
    var fsrsVersion: String?
    var homeShortcut1Id: String?
    var homeShortcut2Id: String?
    var cefrLevelsJSON: String
    var homePinIdsJSON: String
    var reviewPriorityIdsJSON: String
    var reviewAll: Bool
    var activeAgentId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cefrLevel = "cefr_level"
        case dailyNewLimit = "daily_new_limit"
        case requestRetention = "request_retention"
        case maximumInterval = "maximum_interval"
        case enableFuzz = "enable_fuzz"
        case dayCutoffHour = "day_cutoff_hour"
        case timezone
        case enableShortTerm = "enable_short_term"
        case knownStability = "known_stability"
        case leechLapses = "leech_lapses"
        case fsrsParams = "fsrs_params"
        case fsrsVersion = "fsrs_version"
        case homeShortcut1Id = "home_shortcut_1_id"
        case homeShortcut2Id = "home_shortcut_2_id"
        case cefrLevelsJSON = "cefr_levels"
        case homePinIdsJSON = "home_pin_ids"
        case reviewPriorityIdsJSON = "review_priority_ids"
        case reviewAll = "review_all"
        case activeAgentId = "active_agent_id"
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timezone) ?? .current
    }

    var cefrLevels: [String] {
        let decoded = JSONStringArray.decode(cefrLevelsJSON)
        return decoded.isEmpty ? [cefrLevel] : decoded
    }

    var homePinIds: [String] {
        let decoded = JSONStringArray.decode(homePinIdsJSON)
        if !decoded.isEmpty { return decoded }
        return [homeShortcut1Id, homeShortcut2Id].compactMap { $0 }
    }

    var reviewPriorityIds: [String] {
        JSONStringArray.decode(reviewPriorityIdsJSON)
    }

    var persistedScopeIds: [String]? {
        if reviewAll || reviewPriorityIds.isEmpty { return nil }
        return reviewPriorityIds
    }
}

struct ReviewCardView: Equatable, Identifiable, Hashable {
    var id: String { card.id }
    var card: CardRecord
    var vocab: VocabItemRecord
    var collectionName: String

    var branch: ReviewBranch {
        card.state == "new" ? .new : .due
    }
}

enum ReviewBranch: String, Hashable {
    case new
    case due
}

enum CefrLevel: String, CaseIterable, Identifiable {
    case a = "A"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
    var id: String { rawValue }
}

struct RankedCollection: Equatable, Identifiable {
    var id: String
    var name: String
    var reviews: Int
}
