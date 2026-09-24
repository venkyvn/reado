import Foundation
@testable import Reado
import Testing

struct SeedTests {
    @Test func seedCreatesInboxAndSettings() throws {
        let db = try AppDatabase(inMemory: true, timeZone: TimeZone(identifier: "Asia/Ho_Chi_Minh")!)
        let inbox = try db.inbox()
        let settings = try db.settings()
        #expect(inbox.isDefault)
        #expect(inbox.name == "Kho tạm")
        #expect(settings.cefrLevel == "B2")
        #expect(settings.dailyNewLimit == 10)
        #expect(settings.fsrsVersion == "fsrs-6")
        #expect(settings.enableShortTerm == false)
        #expect(settings.knownStability == nil)
        #expect(settings.timezone == "Asia/Ho_Chi_Minh")
    }
}

struct VocabAndQueueTests {
    @Test func confirmPickerCreatesNewCardsDueToday() throws {
        let clock = FixedClock(now: ISO8601UTC.date(from: "2026-09-17T10:00:00Z")!)
        let db = try AppDatabase(inMemory: true, clock: clock, timeZone: TimeZone(identifier: "UTC")!)
        let inbox = try db.inbox()
        let items = [
            PickerItem(id: "1", term: "habit", pos: "noun", ipa: "", meaningVi: "thói quen", cefr: "B1", example: "A habit.", verified: true, suspect: false, selected: true),
            PickerItem(id: "2", term: "skip", pos: "verb", ipa: "", meaningVi: "bỏ", cefr: "A2", example: "Skip this.", verified: false, suspect: false, selected: false),
        ]
        let inserted = try db.dbQueue.write { db in
            try VocabService.insertSelected(db: db, items: items, collectionId: inbox.id, clock: clock)
        }
        #expect(inserted.count == 1)
        let settings = try db.settings()
        let snap = try db.dbQueue.read { db in
            try QueueService.snapshot(db: db, settings: settings, clock: clock, scopeIds: nil)
        }
        #expect(snap.newToday == 1)
        #expect(snap.dueToday == 0)
        #expect(snap.newCards.first?.vocab.term == "habit")
    }

    @Test func dailyNewLimitCapsNewQueue() throws {
        let clock = FixedClock(now: ISO8601UTC.date(from: "2026-09-17T10:00:00Z")!)
        let db = try AppDatabase(inMemory: true, clock: clock, timeZone: TimeZone(identifier: "UTC")!)
        try db.dbQueue.write { db in
            var settings = try SettingsRecord.fetchOne(db, key: 1)!
            settings.dailyNewLimit = 2
            try settings.update(db)
        }
        let inbox = try db.inbox()
        let items = (1...5).map {
            PickerItem(id: "\($0)", term: "word\($0)", pos: "noun", ipa: "", meaningVi: "n\($0)", cefr: "B1", example: "word\($0)", verified: true, suspect: false, selected: true)
        }
        _ = try db.dbQueue.write { db in
            try VocabService.insertSelected(db: db, items: items, collectionId: inbox.id, clock: clock)
        }
        let settings = try db.settings()
        let snap = try db.dbQueue.read { db in
            try QueueService.snapshot(db: db, settings: settings, clock: clock, scopeIds: nil)
        }
        #expect(snap.newToday == 2)
        #expect(snap.newBacklog == 3)
    }

    @Test func sameTermCanHaveTwoRows() throws {
        let clock = FixedClock(now: ISO8601UTC.date(from: "2026-09-17T10:00:00Z")!)
        let db = try AppDatabase(inMemory: true, clock: clock)
        let inbox = try db.inbox()
        let items = [
            PickerItem(id: "1", term: "run", pos: "verb", ipa: "", meaningVi: "chạy", cefr: "A2", example: "I run.", verified: true, suspect: false, selected: true),
            PickerItem(id: "2", term: "run", pos: "noun", ipa: "", meaningVi: "lượt chạy", cefr: "B1", example: "A run.", verified: true, suspect: false, selected: true),
        ]
        let inserted = try db.dbQueue.write { db in
            try VocabService.insertSelected(db: db, items: items, collectionId: inbox.id, clock: clock)
        }
        #expect(inserted.count == 2)
    }
}

struct GradeTests {
    @Test func gradeWritesPreStateLogAndUndoRestores() throws {
        let clock = FixedClock(now: ISO8601UTC.date(from: "2026-09-17T10:00:00Z")!)
        let db = try AppDatabase(inMemory: true, clock: clock, timeZone: TimeZone(identifier: "UTC")!)
        let inbox = try db.inbox()
        _ = try db.dbQueue.write { db in
            try VocabService.insertSelected(
                db: db,
                items: [PickerItem(id: "1", term: "habit", pos: "noun", ipa: "", meaningVi: "thói quen", cefr: "B1", example: "A habit.", verified: true, suspect: false, selected: true)],
                collectionId: inbox.id,
                clock: clock
            )
        }
        let card = try db.dbQueue.read { try CardRecord.fetchOne($0)! }
        #expect(card.state == "new")
        let settings = try db.settings()
        let logId = try db.dbQueue.write { db in
            try GradeService.grade(db: db, cardId: card.id, rating: 3, settings: settings, clock: clock)
        }
        let after = try db.dbQueue.read { try CardRecord.fetchOne($0)! }
        let log = try db.dbQueue.read { try ReviewLogRecord.fetchOne($0)! }
        #expect(log.id == logId)
        #expect(log.stateBefore == "new")
        #expect(log.rating == 3)
        #expect(after.state != "new" || after.dueAt != card.dueAt || after.reps == 1)
        #expect(after.reps == 1)
        try db.dbQueue.write { db in
            try GradeService.undo(db: db, logId: logId)
        }
        let restored = try db.dbQueue.read { try CardRecord.fetchOne($0)! }
        let remainingLogs = try db.dbQueue.read { try ReviewLogRecord.fetchCount($0) }
        #expect(restored.state == "new")
        #expect(restored.reps == 0)
        #expect(remainingLogs == 0)
    }
}

struct ExampleVerifierTests {
    @Test func fabricatedExampleIsUnverified() {
        let status = ExampleVerifier.status(
            term: "resilient",
            example: "A resilient person bounces back quickly from failure.",
            segments: MockPage.segments
        )
        #expect(status == .unverified)
    }

    @Test func authenticExampleIsVerified() {
        let status = ExampleVerifier.status(
            term: "trajectory",
            example: "You should be far more concerned with your current trajectory than with your current results.",
            segments: MockPage.segments
        )
        #expect(status == .verified)
    }
}

struct CsvTests {
    @Test func roundTripAndMissingHeader() {
        let rows = [VocabCsvRow(term: "a", pos: "noun", ipa: "", meaningVi: "á", cefr: "B1", example: "a.", collection: "Work")]
        let text = VocabCSV.serialize(rows)
        let parsed = VocabCSV.parse(text)
        guard case .success(let back) = parsed else {
            Issue.record("parse failed")
            return
        }
        #expect(back == rows)
        let bad = VocabCSV.parse("foo,bar\n1,2")
        guard case .failure = bad else {
            Issue.record("expected failure")
            return
        }
    }
}

@MainActor
struct LabIATests {
    @Test func sixthPinFails() throws {
        let db = try AppDatabase(inMemory: true)
        let store = try AppStore(database: db)
        var ids: [String] = []
        for i in 1...6 {
            ids.append(try store.addCollection(name: "Book \(i)").id)
        }
        for i in 0..<5 {
            #expect(try store.togglePin(ids[i]) == true)
        }
        do {
            _ = try store.togglePin(ids[5])
            Issue.record("sixth pin should fail")
        } catch AppError.pinLimit {
            // expected
        } catch {
            Issue.record("wrong error: \(error)")
        }
        #expect(store.settings.homePinIds.count == 5)
    }

    @Test func confirmPickerAlwaysHubAndSession() throws {
        let clock = FixedClock(now: ISO8601UTC.date(from: "2026-09-17T10:00:00Z")!)
        let db = try AppDatabase(inMemory: true, clock: clock, timeZone: TimeZone(identifier: "UTC")!)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("reado-test-sessions-\(UUID().uuidString).json")
        let store = try AppStore(database: db, clock: clock, sessionStore: SessionStore(url: tmp))
        store.beginCapture(collectionId: store.inbox.id)
        store.pickerItems = [
            PickerItem(id: "1", term: "habit", pos: "noun", ipa: "", meaningVi: "thói quen", cefr: "B1", example: "A habit.", verified: true, suspect: false, selected: true),
        ]
        store.analysisSummary = "summary"
        let dest = try store.confirmPicker()
        #expect(dest == .hub(store.inbox.id))
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.collectionId == store.inbox.id)
        #expect(store.pendingHubId == store.inbox.id)
    }

    @Test func cefrMultiPreselectsVerifiedOnlyInLevels() async throws {
        let client = MockAnalysisClient()
        let result = try await client.analyze(imageJPEG: Data(), cefrLevels: ["B1"])
        let multiply = result.vocabulary.first { $0.term == "multiply" }
        let trajectory = result.vocabulary.first { $0.term == "trajectory" }
        let resilient = result.vocabulary.first { $0.term == "resilient" }
        #expect(multiply?.verified == true)
        #expect(multiply?.selected == true)
        #expect(trajectory?.cefr == "C1")
        #expect(trajectory?.selected == false)
        #expect(resilient?.verified == false)
        #expect(resilient?.selected == false)
    }
}
