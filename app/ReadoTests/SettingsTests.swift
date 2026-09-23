import ReadoKit
import XCTest

/// FR-15 — Learning Settings: load/update các núm user chỉnh được (CEFR ĐA level,
/// hạn mức thẻ mới, giờ chuyển ngày); `request_retention` + núm FSRS ngoài phạm
/// vi update (R1 không mở user, PRD mục 10).
/// port UI lab (2026-09-23): CEFR từ đơn → đa (`cefrLevels`, tối thiểu 1).
final class SettingsTests: XCTestCase {

    func testLoadReturnsSeedDefaults() throws {
        let db = try Fixtures.seededDB()
        let settings = try SettingsService.load(on: db)
        XCTAssertEqual(settings, LearningSettings.defaults)
        XCTAssertEqual(settings.cefrLevels, [.b2])
        XCTAssertEqual(settings.cefrLevel, .b2)
        XCTAssertEqual(settings.dailyNewLimit, 10)
        XCTAssertEqual(settings.dayCutoffHour, 4)
    }

    func testLoadThrowsWhenNotSeeded() throws {
        let db = try SQLiteDatabase(inMemory: ())
        try Migration.run(on: db)  // DDL xong nhưng chưa seed → settings rỗng.
        XCTAssertThrowsError(try SettingsService.load(on: db)) { error in
            XCTAssertEqual(error as? SettingsError, .notSeeded)
        }
    }

    func testUpdatePersistsAllFields() throws {
        let db = try Fixtures.seededDB()
        let updated = try SettingsService.update(
            on: db, cefrLevels: [.b1, .c1], dailyNewLimit: 25, dayCutoffHour: 6)
        XCTAssertEqual(
            updated,
            LearningSettings(
                cefrLevels: [.b1, .c1], dailyNewLimit: 25, dayCutoffHour: 6))
        XCTAssertEqual(try SettingsService.load(on: db), updated)
    }

    /// port UI lab §8: nhiều level giữ được thứ tự user chọn, `cefrLevel` (= level
    /// đầu) vẫn còn cho code cũ / prompt.
    func testUpdatePersistsMultipleCefrLevels() throws {
        let db = try Fixtures.seededDB()
        let updated = try SettingsService.update(
            on: db, cefrLevels: [.a2, .b2, .c1], dailyNewLimit: 10, dayCutoffHour: 4)
        XCTAssertEqual(updated.cefrLevels, [.a2, .b2, .c1])
        XCTAssertEqual(updated.cefrLevel, .a2)
        XCTAssertEqual(try SettingsService.load(on: db).cefrLevels, [.a2, .b2, .c1])
    }

    /// port UI lab §8: CEFR phải chọn ít nhất một level.
    func testUpdateRejectsEmptyCefrLevels() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try SettingsService.update(
                on: db, cefrLevels: [], dailyNewLimit: 10, dayCutoffHour: 4)
        ) { error in
            XCTAssertEqual(error as? SettingsError, .emptyCefrLevels)
        }
    }

    /// FR-15 crit 2: đổi level → capture KẾ TIẾP dùng level mới (AnalyzerFactory
    /// đọc settings live mỗi lần phân tích); nhiều level được ghép ", ".
    func testUpdatedCefrFeedsNextAnalysis() throws {
        let db = try Fixtures.seededDB()
        try SettingsService.update(
            on: db, cefrLevels: [.a2, .b1], dailyNewLimit: 10, dayCutoffHour: 4)
        let (_, cefr) = try AnalyzerFactory.active(db: db)
        XCTAssertEqual(cefr, "A2, B1")
    }

    func testUpdateRejectsNegativeDailyNewLimit() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try SettingsService.update(
                on: db, cefrLevels: [.b2], dailyNewLimit: -1, dayCutoffHour: 4)
        ) { error in
            XCTAssertEqual(error as? SettingsError, .invalidDailyNewLimit(-1))
        }
    }

    func testUpdateRejectsDailyNewLimitOver999() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try SettingsService.update(
                on: db, cefrLevels: [.b2], dailyNewLimit: 1000, dayCutoffHour: 4)
        ) { error in
            XCTAssertEqual(error as? SettingsError, .invalidDailyNewLimit(1000))
        }
    }

    func testUpdateRejectsInvalidDayCutoffHour() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try SettingsService.update(
                on: db, cefrLevels: [.b2], dailyNewLimit: 10, dayCutoffHour: 24)
        ) { error in
            XCTAssertEqual(error as? SettingsError, .invalidDayCutoffHour(24))
        }
        XCTAssertThrowsError(
            try SettingsService.update(
                on: db, cefrLevels: [.b2], dailyNewLimit: 10, dayCutoffHour: -1)
        )
    }

    /// FR-15 crit 4: `request_retention` để mặc định + núm FSRS chỉ-đọc —
    /// update KHÔNG chạm bất kỳ cột FSRS nào.
    func testUpdateDoesNotTouchReadOnlyFSRSFields() throws {
        let db = try Fixtures.seededDB()
        try SettingsService.update(
            on: db, cefrLevels: [.c1], dailyNewLimit: 7, dayCutoffHour: 4)
        let row = try XCTUnwrap(
            db.rows(
                """
                SELECT request_retention, maximum_interval, enable_fuzz,
                       fsrs_params, fsrs_version
                FROM settings WHERE id = 1;
                """
            ).first)
        XCTAssertEqual(row[0].doubleValue ?? 0, 0.9, accuracy: 0.0001)
        XCTAssertEqual(row[1].intValue, 36_500)
        XCTAssertEqual(row[2].intValue, 1)
        XCTAssertTrue(row[3].isNull, "fsrs_params vẫn null (tham số mặc định)")
        XCTAssertEqual(row[4].textValue, "fsrs-6")
    }

    /// D-lim-0: hạn mức 0 hợp lệ — nhánh thẻ MỚI rỗng, thẻ ÔN LẠI vẫn tới.
    func testDailyNewLimitZeroYieldsEmptyNewBranch() throws {
        let db = try Fixtures.seededDB()
        let col = try Fixtures.insertCollection(in: db, name: "A")

        let newVocab = try Fixtures.insertVocab(in: db, collectionID: col, term: "new")
        try Fixtures.insertCard(in: db, vocabItemID: newVocab, state: "new")
        let dueVocab = try Fixtures.insertVocab(in: db, collectionID: col, term: "due")
        try Fixtures.insertCard(
            in: db, vocabItemID: dueVocab, state: "review",
            dueIso: "2026-09-17T00:00:00Z")

        let settings = try SettingsService.update(
            on: db, cefrLevels: [.b2], dailyNewLimit: 0, dayCutoffHour: 4)
        let (items, _) = try ReviewQueue.loadFullQueue(
            on: db, dailyNewLimit: settings.dailyNewLimit, now: Fixtures.fixedNow)

        XCTAssertEqual(items.map(\.term), ["due"], "limit 0 → chỉ thẻ due, không thẻ new")
    }
}