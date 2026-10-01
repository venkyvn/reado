import ReadoKit
import XCTest

/// reencounter-r1 T3 — thang Mới · Đang học · Đã nhớ · Đã thấm (vision #6).
/// `Mastery.level` là hàm thuần, nguồn luật duy nhất → lane `kit`.
final class MasteryLevelTests: XCTestCase {

    func testNewCardIsNewRegardlessOfRecognition() {
        XCTAssertEqual(Mastery.level(state: "new", stability: 0, recognizedCount: 0), .new)
        XCTAssertEqual(Mastery.level(state: "new", stability: 0, recognizedCount: 3), .new)
    }

    func testReviewBelowThresholdIsLearning() {
        XCTAssertEqual(Mastery.level(state: "review", stability: 20.99, recognizedCount: 0), .learning)
        XCTAssertEqual(Mastery.level(state: "review", stability: 5, recognizedCount: 0), .learning)
    }

    func testThresholdIsInclusiveAndWithoutRecognitionIsRemembered() {
        XCTAssertEqual(Mastery.level(state: "review", stability: Mastery.stabilityThreshold, recognizedCount: 0), .remembered)
        XCTAssertEqual(Mastery.level(state: "review", stability: 90, recognizedCount: 0), .remembered)
    }

    func testRememberedPlusRecognitionIsAbsorbed() {
        XCTAssertEqual(Mastery.level(state: "review", stability: 21, recognizedCount: 1), .absorbed)
        XCTAssertEqual(Mastery.level(state: "review", stability: 60, recognizedCount: 5), .absorbed)
    }

    func testRecognitionAloneNeverLiftsAWordAboveLearning() {
        // Chưa đạt Q-08 thì nhận ra khi đọc không đưa lên "đã nhớ"/"đã thấm".
        XCTAssertEqual(Mastery.level(state: "review", stability: 5, recognizedCount: 4), .learning)
    }

    func testDroppingBelowThresholdFallsBackToLearning() {
        // Đã thấm → stability tụt (lapse) → tự về Đang học, dù đã có lần nhận ra.
        XCTAssertEqual(Mastery.level(state: "review", stability: 25, recognizedCount: 2), .absorbed)
        XCTAssertEqual(Mastery.level(state: "review", stability: 8, recognizedCount: 2), .learning)
    }

    func testLearningAndRelearningNeverCountEvenWithHighStability() {
        for state in ["learning", "relearning"] {
            XCTAssertEqual(Mastery.level(state: state, stability: 99, recognizedCount: 2), .learning,
                           "\(state) chưa tính Q-08 — khớp `Mastery.crossed`/`matureKeys`")
        }
    }

    func testFourLevelsAreExhaustive() {
        XCTAssertEqual(Set(Mastery.Level.allCases), [.new, .learning, .remembered, .absorbed])
    }
}
