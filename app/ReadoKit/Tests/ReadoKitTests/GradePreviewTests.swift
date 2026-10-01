import ReadoKit
import XCTest

/// fsrs-queue-fix-r1 T2 (D-2) — lane `kit`: logic thuần, không DB/simulator.
final class GradePreviewTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func snapshot(id: String = "card-1", reps: Int = 3) -> CardSnapshot {
        CardSnapshot(
            id: id,
            due: t0.addingTimeInterval(-86_400),
            stability: 5,
            difficulty: 5,
            learningSteps: 0,
            reps: reps,
            lapses: 0,
            state: "review",
            lastReview: t0.addingTimeInterval(-6 * 86_400),
            scheduledDays: 5,
            suspendedAt: nil)
    }

    /// Mặc định `enableFuzz = true` — đúng cấu hình app (fuzz seed theo timestamp).
    private func scheduler() throws -> ReviewScheduler {
        try ReviewScheduler(settings: ReadoFSRS.defaultSettings())
    }

    private func makePreview(snapshot: CardSnapshot) throws -> GradePreview {
        try GradePreview.make(scheduler: scheduler(), snapshot: snapshot, now: t0)
    }

    func testMakeComputesAllFourRatings() throws {
        let preview = try makePreview(snapshot: snapshot())
        XCTAssertEqual(Set(preview.outcomes.keys), Set(ReadoRating.allCases))
        XCTAssertEqual(preview.cardID, "card-1")
        XCTAssertEqual(preview.computedAt, t0)
    }

    func testHitReturnsExactlyThePreviewedOutcomeForEveryRating() throws {
        let snap = snapshot()
        let preview = try makePreview(snapshot: snap)
        // Bấm sau 10 phút: vẫn trong cửa sổ 30 phút → outcome y hệt lúc hiện nhãn
        // (không tính lại ở `now` mới, nên fuzz không thể làm lệch nhãn).
        let tappedAt = t0.addingTimeInterval(10 * 60)
        for rating in ReadoRating.allCases {
            let committed = try XCTUnwrap(
                preview.outcome(for: rating, cardID: "card-1", snapshot: snap, now: tappedAt),
                "rating \(rating) phải trúng cache")
            let previewed = try XCTUnwrap(preview.outcomes[rating])
            XCTAssertEqual(committed, previewed)
            // Nhãn nút == lịch ghi: cùng `scheduledDays`, cùng `due`.
            XCTAssertEqual(committed.scheduledDays, previewed.scheduledDays)
            XCTAssertEqual(committed.due, previewed.due)
        }
    }

    func testMissOnDifferentCard() throws {
        let snap = snapshot()
        let preview = try makePreview(snapshot: snap)
        XCTAssertNil(preview.outcome(for: .good, cardID: "card-2", snapshot: snap, now: t0))
    }

    func testMissOnChangedSnapshot() throws {
        let preview = try makePreview(snapshot: snapshot(reps: 3))
        // Cùng thẻ nhưng snapshot đã khác (vd. vừa chấm/undo) → cache vô hiệu.
        XCTAssertNil(preview.outcome(
            for: .good, cardID: "card-1", snapshot: snapshot(reps: 4), now: t0))
    }

    func testWindowBoundaryIsExclusiveAtThirtyMinutes() throws {
        let snap = snapshot()
        let preview = try makePreview(snapshot: snap)
        let justInside = t0.addingTimeInterval(GradePreview.maxAge - 1)
        let atLimit = t0.addingTimeInterval(GradePreview.maxAge)
        XCTAssertNotNil(preview.outcome(for: .good, cardID: "card-1", snapshot: snap, now: justInside))
        XCTAssertNil(preview.outcome(for: .good, cardID: "card-1", snapshot: snap, now: atLimit))
        XCTAssertEqual(GradePreview.maxAge, 30 * 60)
    }

    func testMissWhenClockGoesBackwards() throws {
        let snap = snapshot()
        let preview = try makePreview(snapshot: snap)
        XCTAssertNil(
            preview.outcome(
                for: .good, cardID: "card-1", snapshot: snap, now: t0.addingTimeInterval(-1)),
            "đồng hồ lùi → không tin cache")
    }
}
