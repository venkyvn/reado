import ReadoKit
import XCTest

/// pdf-reader-r1 T1 (FR-23, ADR-058) — CRUD `pdf_sources`. Repository không tự
/// chặn kho tạm (app-rule, db.md A.2.2) nên không test ở đây — xem test tầng app.
final class PDFSourceRepositoryTests: XCTestCase {

    func testAttachThenRead() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Atomic Habits")
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "atomic-habits.pdf",
            bookmark: "Zm9v", pageCount: 310, now: Fixtures.fixedNow)

        let source = try XCTUnwrap(
            try PDFSourceRepository.source(on: db, collectionID: collectionID))
        XCTAssertEqual(source.collectionID, collectionID)
        XCTAssertEqual(source.displayName, "atomic-habits.pdf")
        XCTAssertEqual(source.bookmark, "Zm9v")
        XCTAssertEqual(source.pageIndex, 0)
        XCTAssertEqual(source.pageCount, 310)
        XCTAssertEqual(source.updatedAt, Fixtures.fixedNow)
    }

    func testSourceIsNilWhenNotAttached() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Chưa gắn PDF")
        XCTAssertNil(try PDFSourceRepository.source(on: db, collectionID: collectionID))
    }

    func testAttachAgainOverwritesAndResetsPage() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Đổi PDF")
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "cu.pdf",
            bookmark: "Y3U=", pageCount: 100, now: Fixtures.fixedNow)
        try PDFSourceRepository.updatePage(
            on: db, collectionID: collectionID, pageIndex: 42, now: Fixtures.fixedNow)

        // Gắn file khác — UPSERT ghi đè nguyên dòng, page_index về 0 dù trang
        // đọc trước đó là 42 (trang của file cũ vô nghĩa với file mới).
        let later = Fixtures.fixedNow.addingTimeInterval(60)
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "moi.pdf",
            bookmark: "bW9p", pageCount: 200, now: later)

        let source = try XCTUnwrap(
            try PDFSourceRepository.source(on: db, collectionID: collectionID))
        XCTAssertEqual(source.displayName, "moi.pdf")
        XCTAssertEqual(source.bookmark, "bW9p")
        XCTAssertEqual(source.pageIndex, 0)
        XCTAssertEqual(source.pageCount, 200)
        XCTAssertEqual(source.updatedAt, later)
        // Vẫn đúng MỘT dòng — UPSERT, không phải INSERT dòng mới.
        XCTAssertEqual(
            try db.scalarInt64("SELECT COUNT(*) FROM pdf_sources WHERE collection_id = ?;",
                [.text(collectionID)]),
            1)
    }

    func testUpdatePage() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Lật trang")
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "a.pdf",
            bookmark: "YQ==", pageCount: 50, now: Fixtures.fixedNow)

        let later = Fixtures.fixedNow.addingTimeInterval(120)
        try PDFSourceRepository.updatePage(
            on: db, collectionID: collectionID, pageIndex: 9, now: later)

        let source = try XCTUnwrap(
            try PDFSourceRepository.source(on: db, collectionID: collectionID))
        XCTAssertEqual(source.pageIndex, 9)
        XCTAssertEqual(source.updatedAt, later)
        // bookmark/pageCount không đổi — updatePage chỉ chạm page_index/updated_at.
        XCTAssertEqual(source.bookmark, "YQ==")
        XCTAssertEqual(source.pageCount, 50)
    }

    func testUpdateBookmarkKeepsPageIndex() throws {
        // Bookmark "stale" (file bị OS cấp lại handle) vẫn CÙNG file — refresh
        // con trỏ không được làm mất trang đang đọc.
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Bookmark stale")
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "a.pdf",
            bookmark: "cu", pageCount: 50, now: Fixtures.fixedNow)
        try PDFSourceRepository.updatePage(
            on: db, collectionID: collectionID, pageIndex: 7, now: Fixtures.fixedNow)

        try PDFSourceRepository.updateBookmark(
            on: db, collectionID: collectionID, bookmark: "moi",
            now: Fixtures.fixedNow.addingTimeInterval(10))

        let source = try XCTUnwrap(
            try PDFSourceRepository.source(on: db, collectionID: collectionID))
        XCTAssertEqual(source.bookmark, "moi")
        XCTAssertEqual(source.pageIndex, 7)
    }

    func testDetachRemovesRowOnly() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Gỡ PDF")
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "a.pdf",
            bookmark: "YQ==", pageCount: 50, now: Fixtures.fixedNow)

        try PDFSourceRepository.detach(on: db, collectionID: collectionID)

        XCTAssertNil(try PDFSourceRepository.source(on: db, collectionID: collectionID))
        // Collection bản thân không bị đụng tới.
        XCTAssertEqual(
            try db.scalarInt64("SELECT COUNT(*) FROM collections WHERE id = ?;",
                [.text(collectionID)]),
            1)
    }

    func testDetachWhenNotAttachedIsNoop() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Chưa gắn")
        XCTAssertNoThrow(try PDFSourceRepository.detach(on: db, collectionID: collectionID))
    }

    func testDeletingCollectionCascadesPdfSource() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Xoá bộ")
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "a.pdf",
            bookmark: "YQ==", pageCount: 50, now: Fixtures.fixedNow)

        try db.run("DELETE FROM collections WHERE id = ?;", [.text(collectionID)])

        XCTAssertEqual(
            try db.scalarInt64(
                "SELECT COUNT(*) FROM pdf_sources WHERE collection_id = ?;", [.text(collectionID)]),
            0)
    }

    func testUpdatedAtHasZSuffix() throws {
        let db = try Fixtures.seededDB()
        let collectionID = try Fixtures.insertCollection(in: db, name: "Timestamp")
        try PDFSourceRepository.attach(
            on: db, collectionID: collectionID, displayName: "a.pdf",
            bookmark: "YQ==", pageCount: 50, now: Fixtures.fixedNow)

        let raw = try XCTUnwrap(
            try db.scalarString(
                "SELECT updated_at FROM pdf_sources WHERE collection_id = ?;", [.text(collectionID)]))
        XCTAssertTrue(raw.hasSuffix("Z"), "updated_at phải hậu tố Z (UTC) — \(raw)")
    }
}
