import Foundation
import GRDB
import Observation
import UIKit

@MainActor
@Observable
final class AppStore {
    let database: AppDatabase
    var clock: Clock
    var analysisClient: AnalysisClient
    let sessionStore: SessionStore

    var collections: [CollectionRecord] = []
    var agents: [AnalysisAgentRecord] = []
    var settings: SettingsRecord
    var queue = QueueService.Snapshot(
        newToday: 0, dueToday: 0, newBacklog: 0,
        newCards: [], dueCards: [], outsideDue: 0
    )
    var sessions: [ReadingSession] = []
    var streakDays: [DayLog] = []
    var streakStats = StreakStats(current: 0, longest: 0, totalReviews: 0, activeDays: 0)
    var rankedCollections: [RankedCollection] = []
    var inboxCount = 0
    var vocabByCollection: [String: Int] = [:]
    var dueByCollection: [String: Int] = [:]
    var dueAll = 0
    var toast: String?
    var lastUndoLogId: String?
    var pendingHubId: String?
    var pendingReview = false

    var captureTargetId: String?
    var previewImage: UIImage?
    var previewRotation: AngleValue = .zero
    var analyzing = false
    var pickerItems: [PickerItem] = []
    var analysisSegments: [AnalysisSegment] = []
    var analysisSummary = ""
    var pickerDirty = false

    var reviewBranch: ReviewBranch = .due
    var scopeIds: [String]?
    var flipped = false
    var dueSessionDone = false

    init(
        database: AppDatabase,
        clock: Clock = SystemClock(),
        analysisClient: AnalysisClient = MockAnalysisClient(),
        sessionStore: SessionStore = SessionStore()
    ) throws {
        self.database = database
        self.clock = clock
        self.analysisClient = analysisClient
        self.sessionStore = sessionStore
        self.settings = try database.settings()
        sessions = sessionStore.load()
        try reload()
        applyPersistedScope()
    }

    var inbox: CollectionRecord { collections.first(where: \.isDefault)! }

    var pinnedCollections: [CollectionRecord] {
        settings.homePinIds.compactMap { id in collections.first(where: { $0.id == id && !$0.isDefault }) }
    }

    var visibleQueue: [ReviewCardView] {
        reviewBranch == .new ? queue.newCards : queue.dueCards
    }

    var weekday: String {
        LearningDay.weekdayName(instant: clock.now, timeZone: settings.timeZone)
    }

    var scopeTitle: String { title(for: scopeIds) }
    var persistedScopeTitle: String { title(for: settings.persistedScopeIds) }

    func dueInScope(_ ids: [String]?) -> Int {
        guard let ids else { return dueAll }
        return ids.reduce(0) { $0 + (dueByCollection[$1] ?? 0) }
    }

    func reload() throws {
        collections = try database.dbQueue.read { try CollectionRecord.order(Column("created_at")).fetchAll($0) }
        agents = try database.dbQueue.read { try AnalysisAgentRecord.order(Column("created_at")).fetchAll($0) }
        settings = try database.settings()
        queue = try database.dbQueue.read { db in
            try QueueService.snapshot(db: db, settings: settings, clock: clock, scopeIds: scopeIds)
        }
        let unscoped = try database.dbQueue.read { db in
            try QueueService.snapshot(db: db, settings: settings, clock: clock, scopeIds: nil)
        }
        dueAll = unscoped.dueToday
        dueByCollection = Dictionary(grouping: unscoped.dueCards, by: \.vocab.collectionId).mapValues(\.count)
        let items = try database.dbQueue.read { try VocabItemRecord.fetchAll($0) }
        inboxCount = items.filter { $0.collectionId == inbox.id }.count
        vocabByCollection = Dictionary(grouping: items, by: \.collectionId).mapValues(\.count)
        let streak = try database.dbQueue.read { db in
            try StreakService.history(db: db, settings: settings, clock: clock, sessions: sessions)
        }
        streakDays = streak.days
        streakStats = streak.stats
        rankedCollections = try database.dbQueue.read { try StreakService.ranked(db: $0) }
    }

    func applyPersistedScope() {
        scopeIds = settings.persistedScopeIds
        flipped = false
    }

    func notify(_ message: String) {
        toast = message
    }

    func addCollection(name: String) throws -> CollectionRecord {
        let created = try database.dbQueue.write { db in
            try VocabService.addCollection(db: db, name: name, clock: clock)
        }
        try reload()
        return created
    }

    func setCefrLevels(_ levels: [String]) throws {
        var unique: [String] = []
        for level in levels where !unique.contains(level) { unique.append(level) }
        guard !unique.isEmpty else { return }
        try database.dbQueue.write { db in
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            row.cefrLevelsJSON = JSONStringArray.encode(unique)
            row.cefrLevel = unique.joined(separator: ",")
            try row.update(db)
        }
        try reload()
    }

    func toggleCefr(_ level: String) throws {
        var levels = settings.cefrLevels
        if let index = levels.firstIndex(of: level) {
            guard levels.count > 1 else { return }
            levels.remove(at: index)
        } else {
            levels.append(level)
        }
        try setCefrLevels(levels)
    }

    func setDailyNewLimit(_ value: Int) throws {
        guard value >= 1 else { throw AppError.invalidDailyLimit }
        let clamped = min(99, value)
        try database.dbQueue.write { db in
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            row.dailyNewLimit = clamped
            try row.update(db)
        }
        try reload()
    }

    func setDayCutoffHour(_ value: Int) throws {
        let hour = min(23, max(0, value))
        try database.dbQueue.write { db in
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            row.dayCutoffHour = hour
            try row.update(db)
        }
        try reload()
    }

    func setScope(_ ids: [String]?) throws {
        scopeIds = ids
        flipped = false
        try reload()
    }

    func persistReviewAll() throws {
        try database.dbQueue.write { db in
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            row.reviewAll = true
            row.reviewPriorityIdsJSON = "[]"
            try row.update(db)
        }
        scopeIds = nil
        flipped = false
        try reload()
    }

    func togglePriority(_ id: String) throws {
        var ids = settings.reviewAll ? [] : settings.reviewPriorityIds
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            guard ids.count < SchemaSQL.priorityLimit else { throw AppError.priorityLimit }
            ids.append(id)
        }
        try database.dbQueue.write { db in
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            if ids.isEmpty {
                row.reviewAll = true
                row.reviewPriorityIdsJSON = "[]"
            } else {
                row.reviewAll = false
                row.reviewPriorityIdsJSON = JSONStringArray.encode(ids)
            }
            try row.update(db)
        }
        scopeIds = ids.isEmpty ? nil : ids
        flipped = false
        try reload()
    }

    func setBranch(_ branch: ReviewBranch) {
        reviewBranch = branch
        flipped = false
        dueSessionDone = false
    }

    @discardableResult
    func togglePin(_ id: String) throws -> Bool {
        guard let collection = collections.first(where: { $0.id == id }), !collection.isDefault else {
            return false
        }
        var pins = settings.homePinIds
        let pinned: Bool
        if let index = pins.firstIndex(of: id) {
            pins.remove(at: index)
            pinned = false
        } else {
            guard pins.count < SchemaSQL.pinLimit else { throw AppError.pinLimit }
            pins.append(id)
            pinned = true
        }
        try database.dbQueue.write { db in
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            row.homePinIdsJSON = JSONStringArray.encode(pins)
            try row.update(db)
        }
        try reload()
        return pinned
    }

    func beginCapture(collectionId: String?) {
        captureTargetId = collectionId ?? inbox.id
        previewImage = nil
        previewRotation = .zero
        pickerItems = []
        analysisSegments = []
        analysisSummary = ""
        pickerDirty = false
    }

    func setCaptureTarget(_ id: String) {
        captureTargetId = id
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func rotatePreview() {
        previewRotation.degrees += 90
    }

    func analyzePreview() async throws {
        analyzing = true
        defer { analyzing = false }
        let jpeg = previewImage.flatMap { $0.jpegData(compressionQuality: 0.7) } ?? Data()
        let result = try await analysisClient.analyze(imageJPEG: jpeg, cefrLevels: settings.cefrLevels)
        pickerItems = result.vocabulary
        analysisSegments = result.segments
        analysisSummary = result.summaryVi
        pickerDirty = false
        previewImage = nil
    }

    func confirmPicker() throws -> ConfirmDestination {
        let target = captureTargetId ?? inbox.id
        let selected = pickerItems.filter(\.selected)
        let vocabIds = try database.dbQueue.write { db -> [String] in
            try VocabService.insertSelected(db: db, items: selected, collectionId: target, clock: clock)
        }
        let colName = collections.first(where: { $0.id == target })?.name ?? "Collection"
        let snippet = analysisSummary.count > 72 ? String(analysisSummary.prefix(72)) + "…" : analysisSummary
        let session = ReadingSession(
            id: IDs.uuid(),
            collectionId: target,
            title: "\(colName) · mới",
            capturedAt: ISO8601UTC.string(from: clock.now),
            summaryVi: analysisSummary,
            summarySnippet: snippet,
            segments: analysisSegments,
            vocabIds: vocabIds
        )
        sessions = sessionStore.prepend(session)
        pickerDirty = false
        pickerItems = []
        try reload()
        notify("Đã lưu vào \(colName)")
        pendingHubId = target
        return .hub(target)
    }

    func grade(rating: Int) throws {
        guard let card = visibleQueue.first else { return }
        lastUndoLogId = try database.dbQueue.write { db in
            try GradeService.grade(
                db: db,
                cardId: card.card.id,
                rating: rating,
                settings: settings,
                clock: clock
            )
        }
        flipped = false
        try reload()
        if reviewBranch == .due && queue.dueCards.isEmpty {
            dueSessionDone = true
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func undo() throws {
        guard let id = lastUndoLogId else { return }
        try database.dbQueue.write { db in
            try GradeService.undo(db: db, logId: id)
        }
        lastUndoLogId = nil
        dueSessionDone = false
        flipped = false
        try reload()
    }

    func moveInbox(ids: [String], toCollectionId: String) throws {
        try database.dbQueue.write { db in
            try VocabService.moveInboxItems(db: db, ids: ids, toCollectionId: toCollectionId)
        }
        try reload()
        let name = collections.first(where: { $0.id == toCollectionId })?.name ?? ""
        notify("Đã chuyển \(ids.count) từ sang \(name)")
    }

    func vocab(in collectionId: String) throws -> [VocabItemRecord] {
        try database.dbQueue.read { db in
            try VocabItemRecord
                .filter(Column("collection_id") == collectionId)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    func knownTerms() throws -> Set<String> {
        try database.dbQueue.read { db in
            Set(try VocabItemRecord.fetchAll(db).map { TermNormalizer.normalize($0.term) })
        }
    }

    func setActiveAgent(_ id: String) throws {
        try database.dbQueue.write { db in
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            row.activeAgentId = id
            try row.update(db)
        }
        try reload()
    }

    func addAgent(name: String, baseURL: String, model: String, apiKey: String?) throws {
        let id = IDs.uuid()
        try database.dbQueue.write { db in
            try AnalysisAgentRecord(
                id: id,
                kind: "openai_compat",
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "OpenAI-compat" : name,
                baseUrl: baseURL,
                model: model,
                createdAt: ISO8601UTC.string(from: clock.now)
            ).insert(db)
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            row.activeAgentId = id
            try row.update(db)
        }
        if let apiKey, !apiKey.isEmpty {
            AgentKeychain.set(id: id, secret: apiKey)
        }
        try reload()
    }

    func updateAgent(id: String, name: String, baseURL: String, model: String, apiKey: String?) throws {
        try database.dbQueue.write { db in
            guard var agent = try AnalysisAgentRecord.fetchOne(db, key: id), !agent.isProxy else { return }
            agent.name = name
            agent.baseUrl = baseURL
            agent.model = model
            try agent.update(db)
        }
        if let apiKey, !apiKey.isEmpty {
            AgentKeychain.set(id: id, secret: apiKey)
        }
        try reload()
    }

    func deleteAgent(id: String) throws {
        guard let agent = agents.first(where: { $0.id == id }) else { return }
        if agent.isProxy { throw AppError.cannotDeleteProxy }
        try database.dbQueue.write { db in
            try AnalysisAgentRecord.deleteOne(db, key: id)
            var row = try SettingsRecord.fetchOne(db, key: 1)!
            if row.activeAgentId == id {
                row.activeAgentId = SchemaSQL.proxyAgentId
                try row.update(db)
            }
        }
        AgentKeychain.delete(id: id)
        try reload()
    }

    func exportCSV(collectionIds: [String]) throws -> String {
        let allow = Set(collectionIds)
        let items = try database.dbQueue.read { try VocabItemRecord.fetchAll($0) }
            .filter { allow.contains($0.collectionId) }
        let rows = items.map { item in
            VocabCsvRow(
                term: item.term,
                pos: item.pos,
                ipa: item.ipa ?? "",
                meaningVi: item.meaningVi,
                cefr: item.cefr ?? "",
                example: item.example,
                collection: collections.first(where: { $0.id == item.collectionId })?.name ?? ""
            )
        }
        return VocabCSV.serialize(rows)
    }

    func exportJSON() throws -> Data {
        let payload = try database.dbQueue.read { db -> ExportPayload in
            ExportPayload(
                exportedAt: ISO8601UTC.string(from: clock.now),
                settings: try SettingsRecord.fetchOne(db, key: 1)!,
                collections: try CollectionRecord.fetchAll(db),
                vocab: try VocabItemRecord.fetchAll(db),
                cards: try CardRecord.fetchAll(db),
                reviewLogs: try ReviewLogRecord.fetchAll(db)
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    func importCSV(_ text: String) throws -> [VocabCsvRow] {
        switch VocabCSV.parse(text) {
        case .success(let rows): return rows
        case .failure(let error): throw error
        }
    }

    func commitImport(_ rows: [VocabCsvRow]) throws {
        _ = try database.dbQueue.write { db in
            try VocabService.importRows(db: db, rows: rows, clock: clock)
        }
        try reload()
        notify("Đã nhập \(rows.count) từ")
    }

    private func title(for ids: [String]?) -> String {
        guard let ids, !ids.isEmpty else { return "Tất cả kho" }
        let names = ids.compactMap { id in collections.first(where: { $0.id == id })?.name }
        if names.isEmpty { return "Tất cả kho" }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return names.joined(separator: " · ") }
        return "\(names[0]) +\(names.count - 1)"
    }
}

enum ConfirmDestination: Equatable {
    case hub(String)
}

struct AngleValue: Equatable {
    var degrees: Double
    static let zero = AngleValue(degrees: 0)
}

private struct ExportPayload: Encodable {
    var exportedAt: String
    var settings: SettingsRecord
    var collections: [CollectionRecord]
    var vocab: [VocabItemRecord]
    var cards: [CardRecord]
    var reviewLogs: [ReviewLogRecord]
}
