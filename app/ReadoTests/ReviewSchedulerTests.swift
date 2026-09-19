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
        XCTAssertEqual(scheduler.parameters.w.count, 21)
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

    func testStateCodesRoundTripAllFour() {
        for code in CardStateCode.allCodes {
            guard let state = CardStateCode.toState(code) else {
                return XCTFail("không map được \(code)")
            }
            XCTAssertEqual(CardStateCode.from(state), code)
        }
        XCTAssertNil(CardStateCode.toState("bogus"))
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
}