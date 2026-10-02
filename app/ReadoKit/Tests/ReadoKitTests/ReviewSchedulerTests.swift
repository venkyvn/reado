import ReadoKit
import XCTest

/// ROADMAP 1.4 — swift-fsrs defaultWv6, bốn state, log snapshot TRƯỚC.
final class ReviewSchedulerTests: XCTestCase {

    private func makeScheduler(fuzz: Bool = false) throws -> ReviewScheduler {
        try ReviewScheduler(
            settings: SchedulingSettings(
                requestRetention: 0.9,
                maximumInterval: 36_500,
                enableFuzz: fuzz,
                fsrsParams: nil,
                fsrsVersion: nil))
    }

    func testDefaultWeightsAre21AndEngineIsV6() throws {
        // tech-stack mục 3.1 — defaultWv6 = 21 trọng số (FSRS-6), không FSRS-5.
        XCTAssertEqual(ReadoFSRS.defaultWeights.count, 21)
        let scheduler = try makeScheduler()
        XCTAssertTrue(scheduler.isV6)
        XCTAssertEqual(scheduler.weightCount, 21)
    }

    func testShortTermOffEveryGradeLandsInReview() throws {
        // Q-12 CHỐT: steps tắt → 'learning' KHÔNG xuất hiện ở R1.
        let now = Fixtures.fixedNow
        let scheduler = try makeScheduler()
        for rating in ReadoRating.allCases {
            let outcome = try scheduler.grade(
                rating, snapshot: Fixtures.cardSnapshot(due: now), now: now)
            XCTAssertEqual(outcome.state, "review", "grade \(rating)")
        }
    }

    func testFirstGoodReviewCountsRepAndNotLapse() throws {
        let now = Fixtures.fixedNow
        let scheduler = try makeScheduler()
        let outcome = try scheduler.grade(
            .good, snapshot: Fixtures.cardSnapshot(due: now), now: now)
        XCTAssertEqual(outcome.state, "review", "SAU chấm là review")
        XCTAssertEqual(outcome.reps, 1)
        XCTAssertEqual(outcome.lapses, 0)
    }

    func testGoodSchedulesPositiveIntervalAndStability() throws {
        let now = Fixtures.fixedNow
        let scheduler = try makeScheduler()
        let outcome = try scheduler.grade(
            .good, snapshot: Fixtures.cardSnapshot(due: now), now: now)
        XCTAssertGreaterThan(outcome.scheduledDays, 0, "good phải cách ngày dương")
        XCTAssertGreaterThan(outcome.stability, 0)
        XCTAssertGreaterThan(outcome.difficulty, 0)
        XCTAssertGreaterThan(outcome.due, now)
    }

    func testAgainIncrementsLapsesOnReviewCard() throws {
        let scheduler = try makeScheduler()
        let start = Fixtures.iso("2026-09-10T02:00:00Z")
        // Thẻ mới → good → thành review.
        let first = try scheduler.grade(
            .good, snapshot: Fixtures.cardSnapshot(due: start), now: start)
        // Thẻ review 2 ngày sau, chấm again.
        let later = Fixtures.iso("2026-09-12T02:00:00Z")
        let reviewSnapshot = Fixtures.cardSnapshot(
            due: first.due,
            stability: first.stability,
            difficulty: first.difficulty,
            reps: 1,
            lapses: 0,
            state: "review",
            lastReview: start)
        let again = try scheduler.grade(.again, snapshot: reviewSnapshot, now: later)
        XCTAssertEqual(again.lapses, 1, "again trên thẻ review phải tăng lapses")
        XCTAssertEqual(again.state, "review")
    }

    func testElapsedDaysReflectTimeSinceLastReview() throws {
        // Snapshot thẻ review 2 ngày sau last_review → log elapsed_days = 2.
        let scheduler = try makeScheduler()
        let lastReview = Fixtures.iso("2026-09-10T02:00:00Z")
        let later = Fixtures.iso("2026-09-12T03:00:00Z")
        let snapshot = Fixtures.cardSnapshot(
            due: later, stability: 5, difficulty: 4, reps: 1, state: "review",
            lastReview: lastReview)
        let outcome = try scheduler.grade(.good, snapshot: snapshot, now: later)
        XCTAssertEqual(outcome.elapsedDaysRounded, 2)
    }

    /// Guard lib drift: `elapsed_days` = hiệu ngày lịch **UTC** (floor theo
    /// `startOfDay` UTC), KHÔNG phải |Δ|/24h làm tròn — hành vi của
    /// `Date.dateDiffInDays` trong swift-fsrs @`4fbaf20`
    /// (`FSRSHelper.swift:98`). Nếu nâng lib mà công thức đổi, test này đỏ.
    func testElapsedDaysIsUTCCalendarDiffNotRounded24h() throws {
        let scheduler = try makeScheduler()
        func elapsedDays(from: String, to: String) throws -> Int {
            let snapshot = Fixtures.cardSnapshot(
                due: Fixtures.iso(to), stability: 5, difficulty: 4, reps: 1,
                state: "review", lastReview: Fixtures.iso(from))
            return try scheduler.grade(
                .good, snapshot: snapshot, now: Fixtures.iso(to)
            ).elapsedDaysRounded
        }
        // Cách 1h nhưng vắt qua nửa đêm UTC → 1 ngày lịch, dù |Δ|/24h làm tròn ra 0.
        XCTAssertEqual(
            try elapsedDays(from: "2026-09-10T23:30:00Z", to: "2026-09-11T00:30:00Z"), 1)
        // Cách 23h, cùng ngày lịch UTC → 0 ngày, dù gần trọn 1 ngày.
        XCTAssertEqual(
            try elapsedDays(from: "2026-09-10T00:30:00Z", to: "2026-09-10T23:30:00Z"), 0)
        // Cách 47h, hai ranh giới ngày → 2 ngày lịch.
        XCTAssertEqual(
            try elapsedDays(from: "2026-09-10T02:00:00Z", to: "2026-09-12T01:00:00Z"), 2)
    }

    func testStateCodesRoundTripAllFour() {
        for code in CardStateCode.allCodes {
            XCTAssertTrue(CardStateCode.isValid(code), "không map được \(code)")
        }
        XCTAssertFalse(CardStateCode.isValid("bogus"))
    }

    func testSnapshotRejectsUnknownStateCode() throws {
        let scheduler = try makeScheduler()
        let bad = Fixtures.cardSnapshot(state: "bogus")
        XCTAssertThrowsError(
            try scheduler.grade(.good, snapshot: bad, now: Fixtures.fixedNow))
    }

    func testRatingRangeOneToFour() {
        XCTAssertEqual(ReadoRating.allCases.map(\.rawValue), [1, 2, 3, 4])
    }

    func testCustomParamsWrongVersionThrows() {
        // nâng lib mà không đổi mảng = silent breakage → phải ném.
        let settings = SchedulingSettings(
            requestRetention: 0.9,
            maximumInterval: 36_500,
            enableFuzz: false,
            fsrsParams: ReadoFSRS.defaultWeights,
            fsrsVersion: "fsrs-5")
        XCTAssertThrowsError(try ReviewScheduler(settings: settings)) { error in
            guard
                let reviewError = error as? ReviewSchedulerError,
                case .unsupportedParamsVersion = reviewError
            else {
                return XCTFail("sai loại lỗi: \(error)")
            }
        }
    }

    func testCustomParamsWrongWidthThrows() {
        // 19 trọng số (FSRS-5) gắn nhãn fsrs-6 → từ chối.
        let settings = SchedulingSettings(
            requestRetention: 0.9,
            maximumInterval: 36_500,
            enableFuzz: false,
            fsrsParams: Array(repeating: 0.5, count: 19),
            fsrsVersion: "fsrs-6")
        XCTAssertThrowsError(try ReviewScheduler(settings: settings)) { error in
            guard
                let reviewError = error as? ReviewSchedulerError,
                case .unsupportedParamsVersion = reviewError
            else {
                return XCTFail("sai loại lỗi: \(error)")
            }
        }
    }

    func testFuzzDisabledIsDeterministic() throws {
        // enable_fuzz = 0 → hai scheduler cùng input ra cùng kết quả.
        let first = try makeScheduler(fuzz: false)
        let second = try makeScheduler(fuzz: false)
        let now = Fixtures.fixedNow
        let one = try first.grade(
            .good, snapshot: Fixtures.cardSnapshot(due: now), now: now)
        let two = try second.grade(
            .good, snapshot: Fixtures.cardSnapshot(due: now), now: now)
        XCTAssertEqual(one, two)
    }

    // MARK: — U1 ux-polish-r1: IntervalPreview (nhãn nhịp ôn trên nút chấm)

    func testIntervalPreviewMatchesGradeForNewCard() throws {
        let scheduler = try makeScheduler(fuzz: false)
        let now = Fixtures.fixedNow
        let snapshot = Fixtures.cardSnapshot(due: now)
        let outcomes = try IntervalPreview.outcomes(
            scheduler: scheduler, snapshot: snapshot, now: now)
        for rating in ReadoRating.allCases {
            let direct = try scheduler.grade(rating, snapshot: snapshot, now: now)
            XCTAssertEqual(outcomes[rating], direct, "lệch ở \(rating)")
        }
    }

    func testIntervalPreviewMatchesGradeForReviewCard() throws {
        let scheduler = try makeScheduler(fuzz: false)
        let now = Fixtures.fixedNow
        let snapshot = Fixtures.cardSnapshot(
            due: now, stability: 10, difficulty: 4, reps: 3, state: "review",
            lastReview: now.addingTimeInterval(-10 * 86400))
        let outcomes = try IntervalPreview.outcomes(
            scheduler: scheduler, snapshot: snapshot, now: now)
        for rating in ReadoRating.allCases {
            let direct = try scheduler.grade(rating, snapshot: snapshot, now: now)
            XCTAssertEqual(outcomes[rating], direct, "lệch ở \(rating)")
        }
    }

    func testIntervalPreviewOrderedAgainToEasy() throws {
        // Thẻ review đã có lịch sử — nhịp phải tăng dần Again ≤ Hard ≤ Good ≤ Easy.
        let scheduler = try makeScheduler(fuzz: false)
        let now = Fixtures.fixedNow
        let snapshot = Fixtures.cardSnapshot(
            due: now, stability: 10, difficulty: 4, reps: 3, state: "review",
            lastReview: now.addingTimeInterval(-10 * 86400))
        let outcomes = try IntervalPreview.outcomes(
            scheduler: scheduler, snapshot: snapshot, now: now)
        let days = ReadoRating.allCases.map { outcomes[$0]!.scheduledDays }
        XCTAssertEqual(days, days.sorted(), "nhịp phải tăng dần Again→Easy: \(days)")
    }

    func testIntervalLabelBuckets() {
        XCTAssertEqual(IntervalPreview.label(days: 0), "<1 ngày")
        XCTAssertEqual(IntervalPreview.label(days: 1), "1 ngày")
        XCTAssertEqual(IntervalPreview.label(days: 29), "29 ngày")
        XCTAssertEqual(IntervalPreview.label(days: 30), "1 tháng")
        XCTAssertEqual(IntervalPreview.label(days: 45), "2 tháng")
        XCTAssertEqual(IntervalPreview.label(days: 364), "12 tháng")
        XCTAssertEqual(IntervalPreview.label(days: 365), "1 năm")
        XCTAssertEqual(IntervalPreview.label(days: 548), "1,5 năm")
        XCTAssertEqual(IntervalPreview.label(days: 730), "2 năm")
    }
}

/// ADR-033 — ngưỡng vuốt và hướng bay. Hướng phải theo predicted, không theo
/// vị trí tay lúc nhả (hất ngược sẽ lệch stamp với điểm chấm).
final class SwipeCommitTests: XCTestCase {

    func testSlowDragBelowThresholdDoesNotGrade() {
        XCTAssertNil(SwipeCommit.rating(predictedWidth: -110))
        XCTAssertNil(SwipeCommit.rating(predictedWidth: 110))
        XCTAssertNil(SwipeCommit.rating(predictedWidth: 0))
    }

    func testPredictedPastThresholdMapsLeftAgainRightGood() {
        XCTAssertEqual(SwipeCommit.rating(predictedWidth: -111), .again)
        XCTAssertEqual(SwipeCommit.rating(predictedWidth: 111), .good)
    }

    func testFlyOffDirectionFollowsPredictedNotReleasePosition() {
        // Tay còn ở bên trái (translation âm) nhưng hất sang phải: predicted dương
        // → Good và bay phải. Ngược lại cũng vậy.
        XCTAssertEqual(SwipeCommit.rating(predictedWidth: 400), .good)
        XCTAssertEqual(SwipeCommit.direction(predictedWidth: 400), 1)
        XCTAssertEqual(SwipeCommit.rating(predictedWidth: -400), .again)
        XCTAssertEqual(SwipeCommit.direction(predictedWidth: -400), -1)
    }
}