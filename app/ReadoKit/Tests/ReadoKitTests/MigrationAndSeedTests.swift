import ReadoKit
import XCTest

/// ROADMAP 1.3 — DDL đúng docs/db.md tầng A + seed lúc cài đặt.
final class MigrationAndSeedTests: XCTestCase {

    // MARK: Migration

    func testMigrationSetsCurrentVersion() throws {
        let db = try SQLiteDatabase(inMemory: ())
        try Migration.run(on: db)
        XCTAssertEqual(try db.scalarInt64("PRAGMA user_version;"), Migration.currentVersion)
    }

    func testMigrationIsIdempotent() throws {
        let db = try SQLiteDatabase(inMemory: ())
        try Migration.run(on: db)
        XCTAssertNoThrow(try Migration.run(on: db))
        XCTAssertEqual(try db.scalarInt64("PRAGMA user_version;"), Migration.currentVersion)
    }

    func testAllEightTablesExist() throws {
        let db = try Fixtures.seededDB()
        let rows = try db.rows(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';"
        )
        let names = Set(rows.compactMap { $0.first?.textValue })
        XCTAssertEqual(
            names,
            Set([
                "collections", "vocab_items", "cards", "review_logs",
                "analysis_agents", "reading_sessions", "settings",
                "encounters",
            ]))
    }

    // MARK: — v4 encounters (reencounter-r1, FR-22)

    func testMigrationV3ToV4CreatesEncountersAndKeepsData() throws {
        // DB đã ở v3 (đủ 7 bảng, chưa có `encounters`) + dữ liệu thật → chạy lại
        // Migration.run phải thêm bảng mà không mất vocab.
        let db = try Fixtures.seededDB()
        let collectionID = try XCTUnwrap(
            db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "keep")
        try db.exec("DROP INDEX idx_encounters_item;")
        try db.exec("DROP TABLE encounters;")
        try db.exec("PRAGMA user_version = 3;")

        try Migration.run(on: db)

        XCTAssertEqual(try db.scalarInt64("PRAGMA user_version;"), 4)
        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM sqlite_master WHERE name = 'encounters';"), 1)
        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM sqlite_master WHERE name = 'idx_encounters_item';"), 1)
        XCTAssertEqual(
            try db.scalarString("SELECT term FROM vocab_items WHERE id = ?;", [.text(vocabID)]),
            "keep")
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM encounters;"), 0)
    }

    func testEncountersKindCheckRejectsUnknownKind() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try XCTUnwrap(
            db.scalarString("SELECT id FROM collections WHERE is_default = 1;"))
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "kind")
        XCTAssertThrowsError(
            try db.run(
                "INSERT INTO encounters (id, vocab_item_id, kind, created_at) VALUES (?, ?, 'bogus', ?);",
                [.text(Identifier.uuid()), .text(vocabID), .text("2026-09-18T02:00:00Z")]))
    }

    func testForeignKeysEnforced() throws {
        // db.md A.1 — PRAGMA foreign_keys ON mỗi connection.
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try Fixtures.insertVocab(
                in: db, collectionID: "khong-ton-tai", term: "hello"))
    }

    func testCardsStateCheckRejectsUnknownState() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try XCTUnwrap(
            db.scalarString(
                "SELECT id FROM collections WHERE is_default = 1;"))
        let vocabID = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "hello")
        XCTAssertThrowsError(
            try Fixtures.insertCard(in: db, vocabItemID: vocabID, state: "bogus"))
    }

    func testNoUniqueConstraintOnVocabTermNormalized() throws {
        // AGENTS mục 3.1 — CỐ Ý không có unique(collection_id, term_normalized):
        // một từ nhiều nghĩa được nhiều dòng; chống trùng ở FR-10.
        let db = try Fixtures.seededDB()
        let collectionID = try XCTUnwrap(
            db.scalarString(
                "SELECT id FROM collections WHERE is_default = 1;"))
        let first = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "run")
        let second = try Fixtures.insertVocab(
            in: db, collectionID: collectionID, term: "run", normalized: "run")
        XCTAssertNotEqual(first, second)
    }

    // MARK: Seed

    func testSeedCreatesExactlyOneDefaultCollection() throws {
        let db = try Fixtures.seededDB()
        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM collections WHERE is_default = 1;"), 1)
        XCTAssertEqual(
            try db.scalarString(
                "SELECT name FROM collections WHERE is_default = 1;"),
            Seeder.defaultCollectionName)
    }

    func testOnlyOneDefaultCollectionAllowed() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try Fixtures.insertCollection(in: db, name: "Khác", isDefault: 1))
    }

    func testSeedIsIdempotent() throws {
        let db = try Fixtures.seededDB()
        try Seeder.seed(on: db, timezone: Fixtures.timezoneID, now: Fixtures.fixedNow)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM collections;"), 1)
        XCTAssertEqual(try db.scalarInt64("SELECT COUNT(*) FROM settings;"), 1)
        XCTAssertEqual(
            try db.scalarInt64("SELECT COUNT(*) FROM analysis_agents;"), 1)
    }

    func testSeedSettingsDefaultsMatchChốt() throws {
        let db = try Fixtures.seededDB()
        let row = try XCTUnwrap(
            db.rows(
                """
                SELECT enable_short_term, fsrs_version, active_agent_id,
                       timezone, day_cutoff_hour, daily_new_limit,
                       request_retention, maximum_interval, enable_fuzz
                FROM settings WHERE id = 1;
                """).first)
        // Q-12 CHỐT: learning steps tắt.
        XCTAssertEqual(row[0].intValue, 0, "enable_short_term phải = 0")
        XCTAssertEqual(row[1].textValue, "fsrs-6")
        XCTAssertEqual(row[2].textValue, Seeder.placeholderAgentID)
        XCTAssertEqual(row[3].textValue, Fixtures.timezoneID)
        XCTAssertEqual(row[4].intValue, 4, "day_cutoff_hour mặc định 4")
        XCTAssertEqual(row[5].intValue, 10, "daily_new_limit mặc định 10")
        XCTAssertEqual(row[6].doubleValue ?? 0, 0.9, accuracy: 0.0001)
        XCTAssertEqual(row[7].intValue, 36_500)
        XCTAssertEqual(row[8].intValue, 1)
    }

    func testCollectionNameUniqueCaseInsensitiveASCII() throws {
        // idx_collections_name COLLATE NOCASE — chuẩn SQLite CHỈ gập ASCII
        // (A-Z/a-z). Gập hoa thường tiếng Việt (sÁch vs sách) KHÔNG do tầng DB
        // đảm bảo — thuộc app-rule FR-20 lúc trim/insert. Ghi nhận ROADMAP mục 4.
        let db = try Fixtures.seededDB()
        try Fixtures.insertCollection(in: db, name: "Sach MOI")
        XCTAssertThrowsError(
            try Fixtures.insertCollection(in: db, name: "sach moi"))
    }
}