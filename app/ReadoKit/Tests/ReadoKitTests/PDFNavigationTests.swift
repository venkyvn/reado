import CoreGraphics
import PDFKit
import ReadoKit
import XCTest

/// pdf-nav-r1 (FR-23/ADR-059) — `PDFNavigation`: clamp/gõ số trang (hàm
/// thuần) + outline → Mục lục (dựng `PDFOutline` tay trên một PDF 5 trang từ
/// `PDFTestSupport`).
final class PDFNavigationTests: XCTestCase {

    // MARK: — clamp

    func testClampNegativeGoesToZero() {
        XCTAssertEqual(PDFNavigation.clamp(-1, pageCount: 5), 0)
    }

    func testClampZeroStaysZero() {
        XCTAssertEqual(PDFNavigation.clamp(0, pageCount: 5), 0)
    }

    func testClampPastEndGoesToLastIndex() {
        XCTAssertEqual(PDFNavigation.clamp(5, pageCount: 5), 4)
    }

    func testClampWithZeroPageCountReturnsZero() {
        XCTAssertEqual(PDFNavigation.clamp(3, pageCount: 0), 0)
    }

    // MARK: — pageIndex(fromInput:)

    func testPageIndexParsesFirstPage() {
        XCTAssertEqual(PDFNavigation.pageIndex(fromInput: "1", pageCount: 254), 0)
    }

    func testPageIndexTrimsWhitespace() {
        XCTAssertEqual(PDFNavigation.pageIndex(fromInput: " 42 ", pageCount: 254), 41)
    }

    func testPageIndexParsesLastPage() {
        XCTAssertEqual(PDFNavigation.pageIndex(fromInput: "254", pageCount: 254), 253)
    }

    func testPageIndexRejectsOutOfRangeHigh() {
        XCTAssertNil(PDFNavigation.pageIndex(fromInput: "255", pageCount: 254))
    }

    func testPageIndexRejectsZero() {
        XCTAssertNil(PDFNavigation.pageIndex(fromInput: "0", pageCount: 254))
    }

    func testPageIndexRejectsNegative() {
        XCTAssertNil(PDFNavigation.pageIndex(fromInput: "-3", pageCount: 254))
    }

    func testPageIndexRejectsEmpty() {
        XCTAssertNil(PDFNavigation.pageIndex(fromInput: "", pageCount: 254))
    }

    func testPageIndexRejectsNonNumeric() {
        XCTAssertNil(PDFNavigation.pageIndex(fromInput: "abc", pageCount: 254))
    }

    func testPageIndexRejectsDecimal() {
        XCTAssertNil(PDFNavigation.pageIndex(fromInput: "4.5", pageCount: 254))
    }

    // MARK: — outlineEntries / currentEntryID

    func testOutlineEntriesFlattensInDocumentOrderWithEmptyLabelPassthrough() throws {
        let document = try Self.makeFivePageDocument()
        document.outlineRoot = try Self.makeOutlineFixture(document: document)

        let entries = PDFNavigation.outlineEntries(in: document)

        guard entries.count == 5 else {
            return XCTFail("Kỳ vọng 5 mục (bỏ mục nhãn rỗng), nhận \(entries.count): \(entries)")
        }
        XCTAssertEqual(entries[0], .init(id: 0, label: "Chapter 1", depth: 0, pageIndex: 0))
        XCTAssertEqual(entries[1], .init(id: 1, label: "1.1", depth: 1, pageIndex: 1))
        XCTAssertEqual(entries[2], .init(id: 2, label: "2.x", depth: 0, pageIndex: 2))
        XCTAssertEqual(entries[3], .init(id: 3, label: "Chapter 3", depth: 0, pageIndex: nil))
        XCTAssertEqual(entries[4], .init(id: 4, label: "Chapter 4", depth: 0, pageIndex: 3))
    }

    func testOutlineEntriesReturnsEmptyWhenDocumentHasNoOutline() throws {
        let document = try Self.makeFivePageDocument()
        XCTAssertEqual(PDFNavigation.outlineEntries(in: document), [])
    }

    func testCurrentEntryIDPicksLatestEntryAtOrBeforeCurrentPage() throws {
        let document = try Self.makeFivePageDocument()
        document.outlineRoot = try Self.makeOutlineFixture(document: document)
        let entries = PDFNavigation.outlineEntries(in: document)

        XCTAssertEqual(PDFNavigation.currentEntryID(in: entries, pageIndex: 0), 0)
        XCTAssertEqual(PDFNavigation.currentEntryID(in: entries, pageIndex: 1), 1)
        XCTAssertEqual(PDFNavigation.currentEntryID(in: entries, pageIndex: 2), 2)
        XCTAssertEqual(PDFNavigation.currentEntryID(in: entries, pageIndex: 3), 4)
        XCTAssertEqual(PDFNavigation.currentEntryID(in: entries, pageIndex: 4), 4)
    }

    func testCurrentEntryIDReturnsNilWhenCurrentPageBeforeFirstEntry() {
        let entries = [
            PDFNavigation.OutlineEntry(id: 0, label: "Chapter 1", depth: 0, pageIndex: 2),
        ]
        XCTAssertNil(PDFNavigation.currentEntryID(in: entries, pageIndex: 0))
    }

    // MARK: — fixtures

    private static func makeFivePageDocument() throws -> PDFDocument {
        let pages: [[(text: String, origin: CGPoint)]] = (0 ..< 5).map { i in
            [(text: "Page \(i)", origin: CGPoint(x: 50, y: 700))]
        }
        let data = try PDFTestSupport.makeTestPDF(pages: pages)
        return try XCTUnwrap(PDFDocument(data: data))
    }

    /// root → Ch1 (trang 0) [con: 1.1 (trang 1)], mục nhãn rỗng (trang 2)
    /// [con: 2.x (trang 2)], Ch3 (không destination/action), Ch4 dùng
    /// `PDFActionGoTo` (trang 3) — PDF chuyển từ EPUB thường dùng action thay
    /// destination.
    private static func makeOutlineFixture(document: PDFDocument) throws -> PDFOutline {
        let root = PDFOutline()

        let ch1 = PDFOutline()
        ch1.label = "Chapter 1"
        ch1.destination = PDFDestination(page: try XCTUnwrap(document.page(at: 0)), at: .zero)
        root.insertChild(ch1, at: root.numberOfChildren)

        let sub11 = PDFOutline()
        sub11.label = "1.1"
        sub11.destination = PDFDestination(page: try XCTUnwrap(document.page(at: 1)), at: .zero)
        ch1.insertChild(sub11, at: ch1.numberOfChildren)

        let emptyLabel = PDFOutline()
        emptyLabel.label = "   "
        emptyLabel.destination = PDFDestination(page: try XCTUnwrap(document.page(at: 2)), at: .zero)
        root.insertChild(emptyLabel, at: root.numberOfChildren)

        let sub2x = PDFOutline()
        sub2x.label = "2.x"
        sub2x.destination = PDFDestination(page: try XCTUnwrap(document.page(at: 2)), at: .zero)
        emptyLabel.insertChild(sub2x, at: emptyLabel.numberOfChildren)

        let ch3 = PDFOutline()
        ch3.label = "Chapter 3"
        root.insertChild(ch3, at: root.numberOfChildren)

        let ch4 = PDFOutline()
        ch4.label = "Chapter 4"
        let destination = PDFDestination(page: try XCTUnwrap(document.page(at: 3)), at: .zero)
        ch4.action = PDFActionGoTo(destination: destination)
        root.insertChild(ch4, at: root.numberOfChildren)

        return root
    }
}
