import Foundation
import ReadoKit

enum ReviewError: Error, LocalizedError {
    case modelUnavailable
    var errorDescription: String? {
        switch self {
        case .modelUnavailable: "Không có kết nối dữ liệu"
        }
    }
}

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
    /// FR-04: giữ nguyên loại lỗi để UI chọn CTA đúng (chụp lại vs thử lại).
    private(set) var analysisFailure: AnalysisError?
    /// Chuỗi hiển thị cho lỗi phân tích — chỉ để UI đọc, không lưu.
    var analysisError: String? { analysisFailure?.errorDescription }

    // FR-04: yêu cầu mở lại CaptureView sau khi dọn state (ảnh mờ / sai ngôn ngữ).
    var pendingRecapture = false

    // FR-11/FR-12: hàng đợi ôn state
    private(set) var isLoadingReview = false
    private(set) var reviewError: String?
    private(set) var reviewItems: [ReviewQueue.ReviewItem] = []
    private(set) var reviewSnapshots: [String: CardSnapshot] = [:]
    private(set) var currentReviewSnapshot: CardSnapshot?

    /// Các review item hiện hàng đợi (hai nhánh) — cách đọc cho ReviewQueueView.
    var reviewQueue: [ReviewQueue.ReviewItem] { reviewItems }

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
        analysisFailure = nil
    }

    // MARK: — FR-02 AI Analysis

    /// Gọi analyzer cho ảnh hiện tại (proxy khi deploy, mock khi chưa — SD 2.1).
    /// FR-02: hiện progress, nhận 3 nhóm dữ liệu; lỗi → báo + cho retry.
    func analyzeCurrentImage() async {
        guard let image = lastCapturedImage, let database else {
            // FR-04: không có ảnh → UI rơi về empty state "Chưa có trang để phân
            // tích" (đây không phải lỗi phân tích, không cần đặt analysisFailure).
            return
        }
        isAnalyzing = true
        analysisFailure = nil
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
            // FR-04: phân loại lỗi để UI gợi ý đúng (chụp lại vs thử lại); KHÔNG
            // set analysisResult → không bịa dữ liệu, không lưu bản ghi hỏng.
            analysisFailure = (error as? AnalysisError) ?? .providerError(
                (error as? LocalizedError)?.errorDescription
                    ?? String(describing: error))
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
        analysisFailure = nil
        lastCapturedImage = nil
        captureError = nil
    }

    /// FR-04: dọn state phân tích + báo RootView mở lại CaptureView (ảnh mờ /
    /// trang không phải tiếng Anh → cần ảnh khác, retry cùng ảnh vô nghĩa).
    func prepareRecapture() {
        discardAnalysis()
        pendingRecapture = true
    }

    // MARK: — FR-11/FR-12 Ôn tập (hàng đợi)

    /// Tải toàn bộ hàng đợi hôm nay (hai nhánh: new quota + due không giới
    /// hạn) kèm snapshot TRƯỚC cho FR-12 undo. Quota mới đọc từ settings
    /// `daily_new_limit` (seed = 10; FR-15 chưa có UI).
    func loadReviewQueue() async throws {
        guard let database else {
            throw ReviewError.modelUnavailable
        }
        isLoadingReview = true
        reviewError = nil
        defer { isLoadingReview = false }
        do {
            let dailyNewLimit = try Self.readDailyNewLimit(on: database) ?? 10
            let (items, snapshots) = try ReviewQueue.loadFullQueue(
                on: database, dailyNewLimit: dailyNewLimit, now: SystemClock().now)
            reviewItems = items
            reviewSnapshots = snapshots
            currentReviewSnapshot = items.first.flatMap { snapshots[$0.cardID] }
        } catch {
            reviewError = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            throw error
        }
    }

    /// Chấm thẻ hiện tại (FR-11): snapshot TRƯỚC + strict rating → outcome;
    /// UPDATE cards + INSERT review_logs cùng transaction (FR-12 undo cần
    /// logID). Trả logID để view giữ cho undo nổi 1 bước.
    func grade(
        cardID: String,
        snapshot: CardSnapshot,
        rating: ReadoRating
    ) throws -> String {
        guard let database else { throw ReviewError.modelUnavailable }
        let settings = try ReadoFSRS.readSettings(on: database)
        let scheduler = try ReviewScheduler(settings: settings)
        let outcome = try scheduler.grade(rating, snapshot: snapshot, now: SystemClock().now)
        let logID = try ReviewService.record(
            on: database, cardID: cardID, before: snapshot,
            outcome: outcome, now: SystemClock().now)
        // FR-19: kiểm tra leech SAU khi đã ghi log + update cards.
        // Nếu lapses >= ngưỡng → suspend card (ra khỏi hàng đợi).
        _ = try LeechService.evaluateAfterGrade(on: database, cardID: cardID)
        return logID
    }

    /// Undo một bước (FR-12): trả card về snapshot TRƯỚC + xoá đúng log vừa
    /// ghi — cùng transaction (không UPDATE log cũ).
    func undoReview(cardID: String, logID: String, snapshot: CardSnapshot) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try ReviewService.undo(
            on: database, cardID: cardID, logID: logID, before: snapshot)
    }

    /// Đọc `daily_new_limit` từ settings (id = 1); nil nếu chưa seed.
    static func readDailyNewLimit(on db: SQLiteDatabase) throws -> Int? {
        guard let v = try db.scalarInt64(
            "SELECT daily_new_limit FROM settings WHERE id = 1;") else {
            return nil
        }
        return Int(v)
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