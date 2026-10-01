import ReadoKit
import XCTest

/// 3.12 — Reminder ôn tập: ReminderService time/describe, SettingsService persist
/// 2 field mới + validate 0…1439, Migration v2 thêm cột (DB v1 cũ nâng lên).
final class ReminderTests: XCTestCase {

    // MARK: — ReminderService

    func testTimeParsesMinutesIntoHourMinute() throws {
        let r1 = try ReminderService.time(fromMinutes: 1200)
        XCTAssertEqual(r1.hour, 20)
        XCTAssertEqual(r1.minute, 0)

        let r2 = try ReminderService.time(fromMinutes: 0)
        XCTAssertEqual(r2.hour, 0)
        XCTAssertEqual(r2.minute, 0)

        let r3 = try ReminderService.time(fromMinutes: 1439)
        XCTAssertEqual(r3.hour, 23)
        XCTAssertEqual(r3.minute, 59)

        let r4 = try ReminderService.time(fromMinutes: 450)
        XCTAssertEqual(r4.hour, 7)
        XCTAssertEqual(r4.minute, 30)
    }

    func testTimeRejectsOutOfRange() {
        XCTAssertThrowsError(try ReminderService.time(fromMinutes: -1)) { error in
            XCTAssertEqual(error as? SettingsError, .invalidReminderMinutes(-1))
        }
        XCTAssertThrowsError(try ReminderService.time(fromMinutes: 1440)) { error in
            XCTAssertEqual(error as? SettingsError, .invalidReminderMinutes(1440))
        }
    }

    func testDescribeFormats24HourPadded() {
        XCTAssertEqual(ReminderService.describe(minutes: 1200), "20:00")
        XCTAssertEqual(ReminderService.describe(minutes: 450), "07:30")
        XCTAssertEqual(ReminderService.describe(minutes: 0), "00:00")
        XCTAssertEqual(ReminderService.describe(minutes: 1439), "23:59")
    }

    // MARK: — SettingsService

    func testLoadReturnsReminderDefaultsFromSeed() throws {
        let db = try Fixtures.seededDB()
        let settings = try SettingsService.load(on: db)
        XCTAssertFalse(settings.reminderEnabled, "seed default TẮT")
        XCTAssertEqual(settings.reminderMinutes, 1200, "seed default 20:00")
    }

    func testUpdatePersistsReminderFields() throws {
        let db = try Fixtures.seededDB()
        let updated = try SettingsService.update(
            on: db, cefrLevels: [.b2], dailyNewLimit: 10, dayCutoffHour: 4,
            reminderEnabled: true, reminderMinutes: 19 * 60 + 30)
        XCTAssertTrue(updated.reminderEnabled)
        XCTAssertEqual(updated.reminderMinutes, 1170)
        XCTAssertEqual(try SettingsService.load(on: db), updated)
    }

    func testUpdateRejectsReminderMinutesOutOfRange() throws {
        let db = try Fixtures.seededDB()
        XCTAssertThrowsError(
            try SettingsService.update(
                on: db, cefrLevels: [.b2], dailyNewLimit: 10, dayCutoffHour: 4,
                reminderEnabled: true, reminderMinutes: 1440)
        ) { error in
            XCTAssertEqual(error as? SettingsError, .invalidReminderMinutes(1440))
        }
        XCTAssertThrowsError(
            try SettingsService.update(
                on: db, cefrLevels: [.b2], dailyNewLimit: 10, dayCutoffHour: 4,
                reminderEnabled: true, reminderMinutes: -1)
        )
    }

    // MARK: — Migration từ bản cũ (v1 → hiện tại)

    /// Mô phỏng DB v1 cũ (chỉ `id`, chưa có cột nhắc/pin) rồi chạy Migration.run →
    /// v2 phải ALTER thêm cột nhắc (TẮT / 1200), v3 thêm cột `home_pin_ids`; dữ
    /// liệu cũ không bị mất. Bảng tối giản phải có 2 cột ghim cũ để
    /// `migrateLegacyHomePins` đọc được (schema v1 thật có những cột này).
    func testMigrationFromV1AddsReminderAndPinColumns() throws {
        let db = try SQLiteDatabase(inMemory: ())
        try db.exec(
            """
            CREATE TABLE settings (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              home_shortcut_1_id TEXT,
              home_shortcut_2_id TEXT
            );
            """)
        try db.exec("INSERT INTO settings (id) VALUES (1);")
        try db.exec("PRAGMA user_version = 1;")

        try Migration.run(on: db)

        let columns = try db.rows("PRAGMA table_info(settings);")
            .compactMap { $0[1].textValue }
        XCTAssertTrue(columns.contains("reminder_enabled"))
        XCTAssertTrue(columns.contains("reminder_minutes"))
        XCTAssertTrue(columns.contains("home_pin_ids"))
        XCTAssertEqual(
            try db.scalarInt64("SELECT reminder_enabled FROM settings WHERE id = 1;"),
            0)
        XCTAssertEqual(
            try db.scalarInt64("SELECT reminder_minutes FROM settings WHERE id = 1;"),
            1200)
        XCTAssertEqual(
            try db.scalarInt64("PRAGMA user_version;"),
            Migration.currentVersion)
    }
}