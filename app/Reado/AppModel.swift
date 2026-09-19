import Foundation
import ReadoKit

/// Model mở SQLite, migration, seed và chịu trách nhiệm đọc overview.
/// Scaffold (ROADMAP task 1.2): đồng bộ trên main, dữ liệu nhỏ — màn hình
/// thật (FR-01..03…) sẽ chuyển qua actor/URLSession khi có proxy.
@Observable
final class AppModel {
    private(set) var database: SQLiteDatabase?
    private(set) var failure: String?
    private(set) var collections: [CollectionOverview] = []

    // FR-01: capture state
    var lastCapturedImage: CapturedImage?
    var captureError: String?

    // FR-02: analysis state
    private(set) var isAnalyzing = false
    private(set) var analysisResult: PageAnalysis?
    private(set) var analysisError: String?

    struct CollectionOverview: Identifiable, Equatable {
        let id: String
        let name: String
        let isDefault: Bool
        let totalItems: Int
        let dueNow: Int
    }

    init() {
        do {
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
            let directory = supportURL.appendingPathComponent(
                "Reado", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let database = try SQLiteDatabase(
                path: directory.appendingPathComponent("reado.sqlite3").path)
            try Migration.run(on: database)
            try Seeder.seed(
                on: database, timezone: TimeZone.current.identifier)
            self.database = database
            reloadOverview()
        } catch {
            failure = String(describing: error)
        }
    }

    func reloadOverview() {
        guard let database else { return }
        collections = (try? Self.loadOverview(db: database)) ?? []
    }

    // MARK: — FR-01 Capture

    /// Nhận ảnh đã crop + nén xong từ CaptureView, giữ tạm trong bộ nhớ.
    /// NFR-04: ảnh không persist; buffer memory solution sau (SD mục 8).
    /// 2.2 sẽ dùng ảnh này gọi PageAnalyzer.
    func handleCapturedImage(_ image: CapturedImage) {
        lastCapturedImage = image
        captureError = nil
        analysisResult = nil
        analysisError = nil
    }

    // MARK: — FR-02 AI Analysis

    /// Gọi analyzer cho ảnh hiện tại (proxy khi deploy, mock khi chưa — SD 2.1).
    /// FR-02: hiện progress, nhận 3 nhóm dữ liệu; lỗi → báo + cho retry.
    func analyzeCurrentImage() async {
        guard let image = lastCapturedImage, let database else {
            analysisError = "Chưa có ảnh để phân tích"
            return
        }
        isAnalyzing = true
        analysisError = nil
        analysisResult = nil
        defer { isAnalyzing = false }

        do {
            // FR-02: đọc cefr_level từ settings (seed = 'B2'; FR-15 chưa có UI).
            let (_, cefrLevel) = try AnalyzerFactory.active(db: database)
            // 0.7 CHƯA CÓ: proxy chưa deploy → dùng MockAnalyzer (owner chốt 2026-09-19:
            // "chưa integrate với gemini thì trong quá trình phân tích cứ tạo mock data").
            // Gỡ khi proxy deploy: `let analyzer = AnalyzerFactory.active(db:).analyzer`.
            let analyzer: PageAnalyzer = MockAnalyzer()
            let result = try await analyzer.analyze(
                image: image.imageData,
                imageMime: image.mimeType,
                cefr: cefrLevel,
                imageHash: image.imageHash)
            analysisResult = result
        } catch {
            analysisError = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
        }
    }

    // MARK: — Chốt phiên duyệt (FR-03/FR-09 + transaction #4)

    /// Lưu các item đã duyệt & chọn vào collection (SD mục 6 khối #4).
    /// Chỉ item `isSelected` được ghi (FR-03 bỏ chọn = không lưu); validation
    /// trường bắt buộc + chuẩn hoá do `ReviewDraftBuilder.selected` (FR-03).
    /// collectionID nil → kho tạm (is_default, 2.4). Trả số item đã ghi.
    func saveSelection(
        _ drafts: [ReviewDraft],
        collectionID: String?
    ) throws -> Int {
        guard let database else { return 0 }
        let items = try ReviewDraftBuilder.selected(drafts)
        let saved = try VocabRepository.saveCapture(
            on: database,
            items: items,
            collectionID: collectionID,
            now: SystemClock().now)
        if saved > 0 {
            reloadOverview()
            lastCapturedImage = nil
            analysisResult = nil
        }
        return saved
    }

    /// FR-03: user chủ động bỏ kết quả khi chưa confirm — dọn state để lần
    /// chụp sau bắt đầu sạch, không còn analysis cũ trong bộ nhớ.
    func discardAnalysis() {
        analysisResult = nil
        analysisError = nil
        lastCapturedImage = nil
        captureError = nil
    }

    // MARK: — Overview

    /// Scaffold: tổng số từ + số card `due_at <= now` (chưa phải hàng đợi
    /// FR-11 chính thức — chỉ để chứng minh wiring DB → UI).
    static func loadOverview(db: SQLiteDatabase) throws
        -> [CollectionOverview]
    {
        let nowIso = ISOTimestamp.string(from: SystemClock().now)
        let rows = try db.rows(
            """
            SELECT c.id, c.name, c.is_default,
                   (SELECT COUNT(*) FROM vocab_items v
                     WHERE v.collection_id = c.id),
                   (SELECT COUNT(*) FROM cards ca
                     JOIN vocab_items v ON v.id = ca.vocab_item_id
                     WHERE v.collection_id = c.id
                       AND ca.suspended_at IS NULL
                       AND ca.due_at <= ?)
            FROM collections c
            ORDER BY c.is_default DESC, c.name COLLATE NOCASE;
            """,
            [.text(nowIso)])
        return try rows.map { row in
            guard row.count >= 5 else {
                throw DatabaseError.failed(
                    "overview thiếu cột", statement: "overview")
            }
            return CollectionOverview(
                id: row[0].textValue ?? "",
                name: row[1].textValue ?? "",
                isDefault: (row[2].intValue ?? 0) != 0,
                totalItems: Int(row[3].intValue ?? 0),
                dueNow: Int(row[4].intValue ?? 0))
        }
    }
}