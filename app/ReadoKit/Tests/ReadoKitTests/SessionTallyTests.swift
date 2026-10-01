import ReadoKit
import XCTest

/// motivation-r1 T1 (ADR-038) — `Mastery.crossed` + `SessionTally` (đếm dồn
/// phiên cho màn "Xong hôm nay", KHÔNG phải điểm/XP).
final class SessionTallyTests: XCTestCase {

    // MARK: — Mastery.crossed

    func testCrossedTrueWhenStabilityPassesThresholdInReview() {
        XCTAssertTrue(Mastery.crossed(before: 20.9, after: 21.0, stateAfter: "review"))
    }

    func testCrossedFalseWhenAlreadyPastThresholdBefore() {
        // Đã thuộc từ trước — lượt chấm này không phải lượt VỪA vượt ngưỡng.
        XCTAssertFalse(Mastery.crossed(before: 21, after: 25, stateAfter: "review"))
    }

    func testCrossedFalseWhenStateAfterIsNotReview() {
        // Stability cao nhưng chưa chuyển sang state review → chưa tính mastered.
        XCTAssertFalse(Mastery.crossed(before: 18, after: 30, stateAfter: "learning"))
    }

    // MARK: — SessionTally

    func testRecordThreeRatingsTracksReviewedAgainAccuracyAndMastered() {
        var tally = SessionTally()
        tally.record(rating: .good, crossed: false, term: "apple")
        tally.record(rating: .again, crossed: false, term: "banana")
        tally.record(rating: .good, crossed: true, term: "cherry")

        XCTAssertEqual(tally.reviewed, 3)
        XCTAssertEqual(tally.again, 1)
        XCTAssertEqual(tally.newlyMastered, ["cherry"])
        XCTAssertNotNil(tally.accuracy)
        XCTAssertEqual(tally.accuracy!, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testUndoLastAfterMasteredCardRevertsExactlyOneStep() {
        var tally = SessionTally()
        tally.record(rating: .good, crossed: false, term: "apple")
        tally.record(rating: .again, crossed: false, term: "banana")
        tally.record(rating: .good, crossed: true, term: "cherry")

        tally.undoLast()

        XCTAssertEqual(tally.reviewed, 2)
        XCTAssertEqual(tally.again, 1)
        XCTAssertTrue(tally.newlyMastered.isEmpty)
    }

    func testUndoLastOnNonMasteredCardAfterMasteredCardKeepsMasteredEntry() {
        // FR-12: undo một thẻ KHÔNG mastered sau khi có thẻ khác mastered vẫn
        // phải đúng — không xoá nhầm cái đã ghi trước đó.
        var tally = SessionTally()
        tally.record(rating: .good, crossed: true, term: "cherry")
        tally.record(rating: .good, crossed: false, term: "date")

        tally.undoLast()

        XCTAssertEqual(tally.reviewed, 1)
        XCTAssertEqual(tally.newlyMastered, ["cherry"])
    }

    func testEmptyTallyAccuracyIsNil() {
        let tally = SessionTally()
        XCTAssertNil(tally.accuracy)
        XCTAssertEqual(tally.reviewed, 0)
        XCTAssertTrue(tally.newlyMastered.isEmpty)
    }
}
