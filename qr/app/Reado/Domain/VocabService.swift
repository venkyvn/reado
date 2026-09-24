import Foundation
import GRDB

struct PickerItem: Identifiable, Equatable, Hashable {
    var id: String
    var term: String
    var pos: String
    var ipa: String
    var meaningVi: String
    var cefr: String
    var example: String
    var verified: Bool
    var suspect: Bool
    var selected: Bool
}

enum VocabService {
    static func insertSelected(
        db: Database,
        items: [PickerItem],
        collectionId: String,
        clock: Clock
    ) throws -> [String] {
        let now = ISO8601UTC.string(from: clock.now)
        var ids: [String] = []
        for item in items where item.selected {
            let vocabId = IDs.uuid()
            try VocabItemRecord(
                id: vocabId,
                collectionId: collectionId,
                term: item.term,
                termNormalized: TermNormalizer.normalize(item.term),
                pos: item.pos.isEmpty ? "other" : item.pos,
                ipa: item.ipa.isEmpty ? nil : item.ipa,
                meaningVi: item.meaningVi,
                example: item.example,
                cefr: item.cefr.isEmpty ? nil : item.cefr,
                createdAt: now
            ).insert(db)
            try CardRecord(
                id: IDs.uuid(),
                vocabItemId: vocabId,
                direction: "receptive",
                state: "new",
                stability: 0,
                difficulty: 0,
                reps: 0,
                lapses: 0,
                learningSteps: 0,
                scheduledDays: 0,
                lastReviewAt: nil,
                dueAt: now,
                suspendedAt: nil
            ).insert(db)
            ids.append(vocabId)
        }
        return ids
    }

    static func addCollection(db: Database, name: String, clock: Clock) throws -> CollectionRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = CollectionRecord(
            id: IDs.uuid(),
            name: trimmed,
            isDefault: false,
            createdAt: ISO8601UTC.string(from: clock.now)
        )
        try record.insert(db)
        return record
    }

    static func moveInboxItems(db: Database, ids: [String], toCollectionId: String) throws {
        for id in ids {
            try db.execute(
                sql: "UPDATE vocab_items SET collection_id = ? WHERE id = ?",
                arguments: [toCollectionId, id]
            )
        }
    }

    static func importRows(
        db: Database,
        rows: [VocabCsvRow],
        clock: Clock
    ) throws -> Int {
        guard !rows.isEmpty else { throw AppError.emptyImport }
        let now = ISO8601UTC.string(from: clock.now)
        var collections = try CollectionRecord.fetchAll(db)
        func resolve(_ raw: String) throws -> CollectionRecord {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return collections.first(where: { $0.isDefault })!
            }
            if let hit = collections.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                return hit
            }
            let created = try addCollection(db: db, name: trimmed, clock: clock)
            collections.append(created)
            return created
        }
        var count = 0
        for row in rows {
            let collection = try resolve(row.collection)
            let vocabId = IDs.uuid()
            try VocabItemRecord(
                id: vocabId,
                collectionId: collection.id,
                term: row.term,
                termNormalized: TermNormalizer.normalize(row.term),
                pos: row.pos.isEmpty ? "other" : row.pos,
                ipa: row.ipa.isEmpty ? nil : row.ipa,
                meaningVi: row.meaningVi,
                example: row.example,
                cefr: row.cefr.isEmpty ? nil : row.cefr,
                createdAt: now
            ).insert(db)
            try CardRecord(
                id: IDs.uuid(),
                vocabItemId: vocabId,
                direction: "receptive",
                state: "new",
                stability: 0,
                difficulty: 0,
                reps: 0,
                lapses: 0,
                learningSteps: 0,
                scheduledDays: 0,
                lastReviewAt: nil,
                dueAt: now,
                suspendedAt: nil
            ).insert(db)
            count += 1
        }
        return count
    }
}
