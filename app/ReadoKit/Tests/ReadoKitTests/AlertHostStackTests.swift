import Foundation
import ReadoKit
import XCTest

final class AlertHostStackTests: XCTestCase {
    func testEmptyStackIsNeverTop() {
        let stack = AlertHostStack()
        XCTAssertFalse(stack.isTop(UUID()))
    }

    func testSinglePushIsTop() {
        var stack = AlertHostStack()
        let id = UUID()
        stack.push(id)
        XCTAssertTrue(stack.isTop(id))
    }

    func testNestedPushOnlyTopIsTop() {
        var stack = AlertHostStack()
        let root = UUID()
        let sheet = UUID()
        stack.push(root)
        stack.push(sheet)
        XCTAssertFalse(stack.isTop(root))
        XCTAssertTrue(stack.isTop(sheet))
    }

    func testPopTopRestoresPrevious() {
        var stack = AlertHostStack()
        let root = UUID()
        let sheet = UUID()
        stack.push(root)
        stack.push(sheet)
        stack.pop(sheet)
        XCTAssertTrue(stack.isTop(root))
    }

    func testPopNonExistentIDIsNoop() {
        var stack = AlertHostStack()
        let root = UUID()
        stack.push(root)
        stack.pop(UUID())
        XCTAssertTrue(stack.isTop(root))
    }
}
