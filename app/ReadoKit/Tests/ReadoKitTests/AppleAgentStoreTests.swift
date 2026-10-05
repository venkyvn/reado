import ReadoKit
import XCTest

/// apple-ai-r1 T5 (ADR-063) — migration v5→v6 (kind `apple_intelligence` + hàng
/// builtin) và các luật `AnalysisAgentStore` quanh hàng đó.
final class AppleAgentStoreTests: XCTestCase {

    // MARK: - Migration v5 → v6

    func testMigrationV5ToV6KeepsByokAgentAndAddsAppleRow() throws {
        let db = try SQLiteDatabase(inMemory: ())
        try Migration.run(on: db, upTo: 5)
        try Seeder.seed(on: db, timezone: Fixtures.timezoneID, now: Fixtures.fixedNow)
        let secrets = MemorySecrets()
        let byokID = try AnalysisAgentStore.add(
            on: db, name: "Gemini", baseURL: "https://example.com/v1",
            model: "gemini", apiKey: "secret", secrets: secrets)
        XCTAssertEqual(try db.scalarInt64("PRAGMA user_version;"), 5)

        try Migration.run(on: db)

        XCTAssertEqual(try db.scalarInt64("PRAGMA user_version;"), 6)
        let byokRow = try db.rows(
            "SELECT kind, name, base_url, model FROM analysis_agents WHERE id = ?;", [.text(byokID)])
        XCTAssertEqual(byokRow.first?["kind"].textValue, "openai_compat")
        XCTAssertEqual(byokRow.first?["name"].textValue, "Gemini")
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"), byokID)
        let appleRow = try db.rows(
            "SELECT kind, name FROM analysis_agents WHERE id = ?;", [.text(Seeder.appleAgentID)])
        XCTAssertEqual(appleRow.count, 1)
        XCTAssertEqual(appleRow.first?["kind"].textValue, "apple_intelligence")
        XCTAssertEqual(appleRow.first?["name"].textValue, Seeder.appleAgentName)
        XCTAssertTrue(try db.rows("PRAGMA foreign_key_check;").isEmpty)
        XCTAssertEqual(try db.scalarInt64("PRAGMA foreign_keys;"), 1)
    }

    func testCheckRejectsUnknownKindAfterV6() throws {
        let db = try Fixtures.seededDB()
        XCTAssertNoThrow(
            try db.run(
                "INSERT INTO analysis_agents (id, kind, name, base_url, model, created_at) VALUES (?, 'apple_intelligence', 'x', NULL, NULL, ?);",
                [.text(Identifier.uuid()), .text("2026-10-05T00:00:00Z")]))
        XCTAssertThrowsError(
            try db.run(
                "INSERT INTO analysis_agents (id, kind, name, base_url, model, created_at) VALUES (?, 'rac', 'x', NULL, NULL, ?);",
                [.text(Identifier.uuid()), .text("2026-10-05T00:00:00Z")]))
    }

    func testForeignKeyStillEnforcedAfterRebuild() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try db.run(
                "UPDATE settings SET active_agent_id = 'khong-ton-tai' WHERE id = 1;"))
    }

    func testFreshInstallHasApplePlusPlaceholder() throws {
        let db = try Fixtures.seededDB()
        let rows = try db.rows("SELECT kind FROM analysis_agents ORDER BY kind;")
        let kinds = rows.compactMap { $0["kind"].textValue }
        XCTAssertEqual(kinds, ["apple_intelligence", "reado_proxy"])
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"),
            Seeder.placeholderAgentID)
    }

    // MARK: - Store: hàng Apple

    func testListPutsAppleFirstWithoutKey() throws {
        let db = try Fixtures.seededDB()
        let secrets = MemorySecrets()
        _ = try AnalysisAgentStore.add(
            on: db, name: "Gemini", baseURL: "https://example.com/v1", model: "gemini",
            apiKey: "k", secrets: secrets)
        let agents = try AnalysisAgentStore.list(on: db, secrets: secrets).agents
        let first = try XCTUnwrap(agents.first)
        XCTAssertTrue(first.isAppleIntelligence)
        XCTAssertFalse(first.hasKey)
    }

    func testDeleteAndUpdateAppleThrowBuiltinAgent() throws {
        let db = try Fixtures.seededDB()
        let secrets = MemorySecrets()
        XCTAssertThrowsError(
            try AnalysisAgentStore.delete(on: db, id: Seeder.appleAgentID, secrets: secrets)
        ) { error in
            XCTAssertEqual(error as? AnalysisAgentStore.StoreError, .builtinAgent)
        }
        XCTAssertThrowsError(
            try AnalysisAgentStore.update(
                on: db, id: Seeder.appleAgentID, name: "x", baseURL: "https://example.com", model: "y",
                secrets: secrets)
        ) { error in
            XCTAssertEqual(error as? AnalysisAgentStore.StoreError, .builtinAgent)
        }
    }

    func testSetActiveAppleDoesNotNeedKey() throws {
        let db = try Fixtures.seededDB()
        try AnalysisAgentStore.setActive(on: db, id: Seeder.appleAgentID, secrets: MemorySecrets())
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"),
            Seeder.appleAgentID)
    }

    // MARK: - applyDefault (ADR-063)

    func testApplyDefaultPromotesAppleOnlyWhenPlaceholderActive() throws {
        let db = try Fixtures.seededDB()
        XCTAssertTrue(try AnalysisAgentStore.applyDefault(on: db, appleAvailable: true))
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"),
            Seeder.appleAgentID)
    }

    func testApplyDefaultNoOpWhenAppleUnavailable() throws {
        let db = try Fixtures.seededDB()
        XCTAssertFalse(try AnalysisAgentStore.applyDefault(on: db, appleAvailable: false))
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"),
            Seeder.placeholderAgentID)
    }

    func testApplyDefaultKeepsChosenByok() throws {
        let db = try Fixtures.seededDB()
        let secrets = MemorySecrets()
        let byokID = try AnalysisAgentStore.add(
            on: db, name: "Gemini", baseURL: "https://example.com/v1", model: "gemini",
            apiKey: "k", secrets: secrets)
        XCTAssertFalse(try AnalysisAgentStore.applyDefault(on: db, appleAvailable: true))
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"), byokID)
    }

    func testApplyDefaultKeepsAppleActiveWhenLaterUnavailable() throws {
        let db = try Fixtures.seededDB()
        try AnalysisAgentStore.setActive(on: db, id: Seeder.appleAgentID, secrets: MemorySecrets())
        XCTAssertFalse(try AnalysisAgentStore.applyDefault(on: db, appleAvailable: false))
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"),
            Seeder.appleAgentID)
    }

    func testDeletingActiveByokFallsBackThenApplyDefaultPromotesApple() throws {
        let db = try Fixtures.seededDB()
        let secrets = MemorySecrets()
        let byokID = try AnalysisAgentStore.add(
            on: db, name: "Gemini", baseURL: "https://example.com/v1", model: "gemini",
            apiKey: "k", secrets: secrets)
        try AnalysisAgentStore.delete(on: db, id: byokID, secrets: secrets)
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"),
            Seeder.placeholderAgentID)
        XCTAssertTrue(try AnalysisAgentStore.applyDefault(on: db, appleAvailable: true))
        XCTAssertEqual(
            try db.scalarString("SELECT active_agent_id FROM settings WHERE id = 1;"),
            Seeder.appleAgentID)
    }

    // MARK: - AnalyzerFactory (apple-ai-r1 T7)

    func testActiveWithAppleAgentReturnsAppleIntelligenceAnalyzer() throws {
        let db = try Fixtures.seededDB()
        try AnalysisAgentStore.setActive(on: db, id: Seeder.appleAgentID, secrets: MemorySecrets())
        let (analyzer, _) = try AnalyzerFactory.active(db: db)
        XCTAssertTrue(analyzer is AppleIntelligenceAnalyzer)
    }

    func testMakeAnalyzerReportsStatusOverrideUnavailable() async throws {
        AppleIntelligence.statusOverride = .unavailable(.notEnabled)
        defer { AppleIntelligence.statusOverride = nil }
        let analyzer = AppleIntelligence.makeAnalyzer()
        do {
            _ = try await analyzer.analyze(
                image: Data(), imageMime: "image/jpeg", cefr: "B2", imageHash: "h")
            XCTFail("mong đợi providerError")
        } catch {
            guard case let AnalysisError.providerError(message) = error else {
                return XCTFail("mong đợi providerError, nhận \(error)")
            }
            XCTAssertTrue(message.contains("Chưa bật"))
        }
    }
}
