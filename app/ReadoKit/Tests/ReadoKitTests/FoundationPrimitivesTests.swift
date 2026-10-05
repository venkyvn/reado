import ReadoKit
import XCTest

/// Primitive của ReadoKit — dialect chốt: ISO-8601 UTC `Z`, uuid thường có
/// gạch nối, "hôm nay" qua Clock + timezone + cutoff (tech-stack mục 10.3).
final class FoundationPrimitivesTests: XCTestCase {

    // MARK: ISOTimestamp

    func testISOFormatUtcZNoFractionAndRoundtrip() {
        let value = ISOTimestamp.string(from: Fixtures.fixedNow)
        XCTAssertTrue(value.hasSuffix("Z"))
        XCTAssertFalse(value.contains("."), "không fractional giây")
        XCTAssertEqual(value.count, 20, "độ dài cố định, so sánh lexicographic được")
        let parsed = ISOTimestamp.date(from: value)
        XCTAssertEqual(parsed, Fixtures.fixedNow)
    }

    func testISOLexicographicOrderMatchesChronology() {
        XCTAssertLessThan(
            "2026-09-18T00:00:00Z", "2026-09-18T00:00:01Z")
        XCTAssertLessThan(
            "2026-09-18T23:59:59Z", "2026-09-19T00:00:00Z")
    }

    // MARK: Identifier

    func testUUIDLowercaseHyphenated() {
        let value = Identifier.uuid()
        let pattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        XCTAssertNotNil(
            value.range(of: pattern, options: .regularExpression),
            "uuid phải thường + gạch nối 8-4-4-4-12, gặp: \(value)")
        XCTAssertEqual(value, value.lowercased())
        XCTAssertNotEqual(Identifier.uuid(), Identifier.uuid())
    }

    // MARK: Clock

    func testFixedClock() {
        let fixed = FixedClock(Fixtures.fixedNow)
        XCTAssertEqual(fixed.now, Fixtures.fixedNow)
    }

    // MARK: DayBoundary — cutoff 4h, VN (+07)

    private func dayAt(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
        timezone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar.date(
            from: DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    func testDayBoundaryBeforeCutoffBelongsToYesterday() throws {
        // 03:59 (trước cutoff 4h) → vẫn thuộc "hôm qua" theo lịch Reado.
        let tz = try XCTUnwrap(TimeZone(identifier: Fixtures.timezoneID))
        let now = dayAt(2026, 9, 18, 3, 59, timezone: tz)
        let window = DayBoundary.window(now: now, timezone: tz, dayCutoffHour: 4)
        XCTAssertEqual(window.start, "2026-09-16T21:00:00Z")
        XCTAssertEqual(window.end, "2026-09-17T21:00:00Z")
    }

    func testDayBoundaryAtCutoffStartsToday() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: Fixtures.timezoneID))
        let now = dayAt(2026, 9, 18, 4, 0, timezone: tz)
        let window = DayBoundary.window(now: now, timezone: tz, dayCutoffHour: 4)
        XCTAssertEqual(window.start, "2026-09-17T21:00:00Z")
        XCTAssertEqual(window.end, "2026-09-18T21:00:00Z")
    }

    func testDayBoundaryEveningBelongsToToday() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: Fixtures.timezoneID))
        let now = dayAt(2026, 9, 18, 22, 30, timezone: tz)
        let window = DayBoundary.window(now: now, timezone: tz, dayCutoffHour: 4)
        XCTAssertEqual(window.start, "2026-09-17T21:00:00Z")
        XCTAssertEqual(window.end, "2026-09-18T21:00:00Z")
    }

    // MARK: DayBoundary.daysBetween — ngày học, không phải nửa đêm (engagement-r1 T3)

    func testDaysBetweenUsesLearningDay() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: Fixtures.timezoneID))
        // 03:59 và 04:01 cùng ngày lịch 18/09 nhưng khác ngày học (cutoff 4h).
        let before = dayAt(2026, 9, 18, 3, 59, timezone: tz)
        let after = dayAt(2026, 9, 18, 4, 1, timezone: tz)
        XCTAssertEqual(DayBoundary.daysBetween(before, after, timezone: tz), 1)
        // Cùng ngày học → 0.
        let sameDay = dayAt(2026, 9, 18, 23, 0, timezone: tz)
        XCTAssertEqual(DayBoundary.daysBetween(after, sameDay, timezone: tz), 0)
        // 12 ngày học.
        let later = dayAt(2026, 9, 30, 10, 0, timezone: tz)
        XCTAssertEqual(DayBoundary.daysBetween(after, later, timezone: tz), 12)
        // Ngược chiều → 0.
        XCTAssertEqual(DayBoundary.daysBetween(later, after, timezone: tz), 0)
    }
}
