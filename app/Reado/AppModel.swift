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

/// Kết quả một lần `AppModel.grade` — `logID` cho undo (FR-12), `crossedMastery`
/// cho toast "Thuộc rồi!" (ADR-038).
struct GradeResult: Equatable {
    let logID: String
    let crossedMastery: Bool
}

/// Model mở SQLite, migration, seed và chịu trách nhiệm đọc overview.
/// Scaffold (ROADMAP task 1.2): đồng bộ trên main, dữ liệu nhỏ — màn hình
/// thật (FR-01..03…) sẽ chuyển qua actor/URLSession khi có proxy.
@Observable
final class AppModel {
    private(set) var database: SQLiteDatabase?
    private(set) var failure: String?
    private(set) var collections: [CollectionOverview] = []
    // FR-14: tổng quan Home — đến hạn (quota-aware) + tồn đọng + streak.
    private(set) var dailyProgress: DailyProgress?
    // J-R1-P: lịch streak (lens FR-14) — streak hiện tại + dài nhất + heatmap 18×7.
    private(set) var streakHeatmap: StreakHeatmap?
    /// Pin Home — id collection "đang đọc" (thứ tự user thêm, ≤ 5). Port UI lab
    /// (2026-09-23) nâng từ 2 shortcut (FR-17 cũ) → 5 pin (`HomePinService`).
    private(set) var homePinIDs: [String] = []
    /// Ôn nhanh (port UI lab) — scope ôn mặc định của tab Ôn: 1–3 bộ ưu tiên
    /// hoặc "tất cả" (`reviewAll`).
    private(set) var reviewScopeDefault: ReviewScope = .empty

    // FR-08/FR-17: danh sách từ của collection đang xem (detail view giữ state,
    // một detail mở một lúc nên một biến là đủ).
    private(set) var vocabulary: [VocabRepository.VocabularyListEntry] = []

    // FR-05/06: các phiên đọc song ngữ của collection đang xem (J2 hub).
    private(set) var sessions: [ReadingSession] = []

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
    /// Tiến độ agent đang gọi (đọc trang/chờ/suy nghĩ/viết) — chỉ `openai_compat`
    /// (stream) phát ra; AnalysisView đổi dòng chữ theo đây thay vì đứng im.
    private(set) var analysisProgress: AnalysisProgress?

    // FR-04: yêu cầu mở lại CaptureView sau khi dọn state (ảnh mờ / sai ngôn ngữ).
    var pendingRecapture = false
    /// FR-21: lỗi agent (BYOK 401/timeout/...) → nút "Mở Cài đặt" bật cờ này;
    /// RootView tiêu thụ ở onDismiss của sheet phân tích rồi dọn sạch.
    var pendingSettingsNavigation = false

    // J2: đích collection chọn sẵn cho lần capture từ Collection Hub (nil = kho
    // tạm). AnalysisView đọc làm collection ban đầu rồi dọn sạch sau khi lưu.
    var analysisTargetCollectionID: String?

    /// port UI lab §5.7: sau Lưu → RootView push Hub của bộ vừa lưu (kể cả kho
    /// tạm). Set ở `saveSelection` thành công, dọn ở `handleCapturedImage` (lần
    /// chụp kế tiếp) + sau khi RootView tiêu thụ.
    var pendingHubNavigationID: String?

    /// port UI lab §6: Hub (CollectionDetailView) đang mở set id này để FloatShutter
    /// prefilt đích chụp; rời Hub → nil (chụp từ Home/Kho root = kho tạm).
    var shutterTargetCollectionID: String?

    /// Phiên đọc đang mở (push trong Hub, không vào ShellRoute) → ẩn shutter nổi
    /// (port UI lab §10). ReadingSessionView bật/tắt ở onAppear/onDisappear.
    var suppressFloatShutter = false

    /// Bump mỗi lần reload overview — để CollectionDetailView đang mở tự refresh
    /// (từ/phiên) sau khi lưu mà không cần push hub trùng.
    private(set) var dataRevision = 0

    // FR-11/FR-12: hàng đợi ôn state
    private(set) var isLoadingReview = false
    private(set) var reviewError: String?
    private(set) var reviewItems: [ReviewQueue.ReviewItem] = []
    private(set) var reviewSnapshots: [String: CardSnapshot] = [:]
    private(set) var currentReviewSnapshot: CardSnapshot?

    // FR-18: phạm vi ôn hiện tại (nil = tất cả collection) + nợ due ngoài phạm
    // vi (phải nhìn thấy — research/vocabulary.md 4.2).
    private(set) var reviewScope: Set<String>? = nil
    private(set) var dueOutsideScope = 0

    /// Các review item hiện hàng đợi (hai nhánh) — cách đọc cho ReviewQueueView.
    var reviewQueue: [ReviewQueue.ReviewItem] { reviewItems }

    struct CollectionOverview: Identifiable, Equatable {
        let id: String
        let name: String
        let isDefault: Bool
        let totalItems: Int
        let dueNow: Int
        let lastAddedAt: Date?
        /// Q-08 "đã thuộc" — ý 4 motivation-r1 ("Đã thuộc X/Y" ở hub + Kho).
        let masteredCount: Int
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
            #if DEBUG
            Self.seedDevAIBoxAgentIfNeeded(on: database)
            #endif
            reloadOverview()
        } catch {
            failure = String(describing: error)
            DebugTrace.event("db", "initFailed", ["error": String(describing: error)])
        }
    }

    #if DEBUG
    /// Chỉ debug: máy dev launch với `READO_DEV_AIBOX_KEY` (`scripts/sim_aibox.sh`)
    /// để test luồng OCR→AI-Box trên simulator mà không phải gõ tay key mỗi lần
    /// cài lại. Key không bao giờ nằm trong repo/scheme — chỉ qua env lúc launch;
    /// đã có agent AI-Box (base_url trùng) rồi thì bỏ qua, không thêm trùng.
    private static func seedDevAIBoxAgentIfNeeded(on database: SQLiteDatabase) {
        guard let key = ProcessInfo.processInfo.environment["READO_DEV_AIBOX_KEY"],
              !key.isEmpty
        else { return }
        if let existing = try? AnalysisAgentStore.list(on: database).agents,
           existing.contains(where: { $0.baseURL == AnalysisAgentStore.aiboxBaseURL })
        {
            return
        }
        try? AnalysisAgentStore.add(
            on: database,
            name: "AI-Box (dev)",
            baseURL: AnalysisAgentStore.aiboxBaseURL,
            model: AnalysisAgentStore.aiboxModel,
            apiKey: key)
    }
    #endif

    func reloadOverview() {
        guard let database else { return }
        collections = (try? Self.loadOverview(db: database)) ?? []
        dailyProgress = (try? Self.loadDailyProgress(db: database))
        homePinIDs = (try? HomePinService.ids(on: database)) ?? []
        reviewScopeDefault = (try? ReviewScopeService.load(on: database)) ?? .empty
        dataRevision &+= 1
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
        pendingHubNavigationID = nil
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
        analysisProgress = .readingPage
        defer {
            isAnalyzing = false
            analysisProgress = nil
        }

        let startedAt = Date()
        do {
            // FR-02: agent seed là reado_proxy → ReadoProxyClient. URL lấy từ
            // READO_PROXY_BASE_URL nếu có, không thì AnalyzerFactory.proxyBaseURL.
            let (analyzer, cefrLevel) = try AnalyzerFactory.active(
                db: database,
                onProgress: { [weak self] progress in
                    Task { @MainActor in self?.analysisProgress = progress }
                })
            let result = try await analyzer.analyze(
                image: image.imageData,
                imageMime: image.mimeType,
                cefr: cefrLevel,
                imageHash: image.imageHash)
            analysisResult = result
            DebugTrace.event("analysis", "ok", [
                "segments": result.segments.count,
                "vocabulary": result.vocabulary.count,
                "totalMs": Int(Date().timeIntervalSince(startedAt) * 1000),
            ])
        } catch {
            // FR-04: phân loại lỗi để UI gợi ý đúng (chụp lại vs thử lại); KHÔNG
            // set analysisResult → không bịa dữ liệu, không lưu bản ghi hỏng.
            analysisFailure = (error as? AnalysisError) ?? .providerError(
                (error as? LocalizedError)?.errorDescription
                    ?? String(describing: error))
            DebugTrace.event("analysis", "failed", [
                "error": String(describing: analysisFailure),
                "totalMs": Int(Date().timeIntervalSince(startedAt) * 1000),
            ])
        }
    }

    // MARK: — Chốt phiên duyệt (FR-03/FR-09 + transaction #4)

    /// Lưu các item đã duyệt & chọn vào collection (SD mục 6 khối #4 + #5).
    /// Chỉ item `isSelected` được ghi (FR-03 bỏ chọn = không lưu); validation
    /// trường bắt buộc + chuẩn hoá do `ReviewDraftBuilder.selected` (FR-03).
    /// collectionID nil → kho tạm (is_default, 2.4). `segments`/`summaryVI` ghi
    /// thành phiên đọc (FR-05/06) khi đích là collection có tên. Trả số item đã ghi.
    func saveSelection(
        _ drafts: [ReviewDraft],
        collectionID: String?,
        segments: [PageAnalysis.Segment] = [],
        summaryVI: String = ""
    ) throws -> Int {
        guard let database else { return 0 }
        let items = try ReviewDraftBuilder.selected(drafts)
        let saved = try VocabRepository.saveCapture(
            on: database,
            items: items,
            collectionID: collectionID,
            segments: segments,
            summaryVI: summaryVI,
            now: SystemClock().now)
        DebugTrace.event("save", "selection", [
            "saved": saved, "collectionID": collectionID ?? "kho_tam", "segments": segments.count,
        ])
        if saved > 0 {
            reloadOverview()
            // port UI lab §5.7: Lưu → Hub bộ vừa chọn (kho tạm = hub kho tạm).
            pendingHubNavigationID =
                collectionID ?? collections.first(where: { $0.isDefault })?.id
            lastCapturedImage = nil
            analysisResult = nil
            analysisTargetCollectionID = nil
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
        analysisTargetCollectionID = nil
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
    func loadReviewQueue(scope: Set<String>? = nil) async throws {
        guard let database else {
            throw ReviewError.modelUnavailable
        }
        reviewScope = scope
        isLoadingReview = true
        reviewError = nil
        defer { isLoadingReview = false }
        do {
            let dailyNewLimit = Self.currentSettings(database).dailyNewLimit
            let now = SystemClock().now
            let (items, snapshots) = try ReviewQueue.loadFullQueue(
                on: database, dailyNewLimit: dailyNewLimit, now: now, scope: scope)
            reviewItems = items
            reviewSnapshots = snapshots
            currentReviewSnapshot = items.first.flatMap { snapshots[$0.cardID] }
            dueOutsideScope = try Int(
                ReviewQueue.dueOutsideScopeCount(
                    on: database,
                    dueBeforeIso: ISOTimestamp.string(from: now),
                    scope: scope))
        } catch {
            reviewError = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            DebugTrace.event("review", "loadQueueFailed", ["error": String(describing: error)])
            throw error
        }
    }

    /// Chấm thẻ hiện tại (FR-11): snapshot TRƯỚC + strict rating → outcome;
    /// UPDATE cards + INSERT review_logs cùng transaction (FR-12 undo cần
    /// logID). Trả `GradeResult` để view giữ logID cho undo nổi 1 bước, và
    /// biết thẻ vừa vượt ngưỡng "đã thuộc" (ADR-038) để bật toast.
    func grade(
        cardID: String,
        snapshot: CardSnapshot,
        rating: ReadoRating
    ) throws -> GradeResult {
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
        // ADR-038: tính từ before/after đã có sẵn — không query DB thêm.
        let crossedMastery = Mastery.crossed(
            before: snapshot.stability, after: outcome.stability, stateAfter: outcome.state)
        return GradeResult(logID: logID, crossedMastery: crossedMastery)
    }

    /// Undo một bước (FR-12): trả card về snapshot TRƯỚC + xoá đúng log vừa
    /// ghi — cùng transaction (không UPDATE log cũ).
    func undoReview(cardID: String, logID: String, snapshot: CardSnapshot) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try ReviewService.undo(
            on: database, cardID: cardID, logID: logID, before: snapshot)
    }

    /// FR-15: đọc 3 núm học tập — fallback về seed default khi chưa seed.
    static func currentSettings(_ db: SQLiteDatabase) -> LearningSettings {
        (try? SettingsService.load(on: db)) ?? .defaults
    }

    /// FR-14: số đếm Home — quota-aware + streak + số trang, dùng chung
    /// `dailyNewLimit` đã đọc từ settings.
    static func loadDailyProgress(db: SQLiteDatabase) throws -> DailyProgress {
        let dailyNewLimit = currentSettings(db).dailyNewLimit
        return try DailyProgressService.load(
            on: db, dailyNewLimit: dailyNewLimit, now: SystemClock().now)
    }

    /// J-R1-P: nạp lịch streak (heatmap 18 tuần + streak hiện tại/dài nhất).
    /// Chỉ gọi khi mở màn Lịch streak — query chạm toàn bộ review_logs.
    func loadStreakHeatmap() {
        guard let database else {
            streakHeatmap = nil
            return
        }
        streakHeatmap = try? StreakCalendarService.load(
            on: database, now: SystemClock().now)
    }

    // MARK: — FR-15 Settings

    /// Đọc núm học tập cho SettingsView hiển thị; nil khi chưa mở được DB.
    func loadLearningSettings() -> LearningSettings? {
        guard let database else { return nil }
        return try? SettingsService.load(on: database)
    }

    /// FR-10: term+pos đã thuộc (stability >= 21, state review) trong collection
    /// đang chụp. Chưa chọn bộ → kho tạm. Lỗi DB → tập rỗng, không giấu từ.
    func matureKeysForCapture() -> Set<String> {
        guard let database else { return [] }
        let collectionID: String?
        if let analysisTargetCollectionID {
            collectionID = analysisTargetCollectionID
        } else {
            collectionID = try? database.scalarString(
                "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;")
        }
        guard let collectionID else { return [] }
        return (try? VocabRepository.matureKeys(on: database, collectionID: collectionID)) ?? []
    }

    /// Lưu các núm (CEFR đa level + 3 học tập + 2 nhắc ôn) + reload overview để số
    /// đếm Home nhận hạn mức / giờ chuyển ngày mới NGAY. CEFR có hiệu lực từ lần
    /// `capture` kế tiếp (FR-15: trang đã phân tích không chạy lại).
    func saveLearningSettings(
        cefrLevels: [CEFRLevel],
        dailyNewLimit: Int,
        dayCutoffHour: Int,
        reminderEnabled: Bool,
        reminderMinutes: Int
    ) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try SettingsService.update(
            on: database,
            cefrLevels: cefrLevels,
            dailyNewLimit: dailyNewLimit,
            dayCutoffHour: dayCutoffHour,
            reminderEnabled: reminderEnabled,
            reminderMinutes: reminderMinutes)
        reloadOverview()
        // 3.12: đồng bộ lịch nhắc ngay sau khi lưu (bật → xin quyền + đặt lịch).
        Task { await self.syncReminderSchedule(requestPermission: true) }
    }

    /// Convenience — code cũ (SettingsView đơn level) gọi một CEFR duy nhất.
    func saveLearningSettings(
        cefrLevel: CEFRLevel,
        dailyNewLimit: Int,
        dayCutoffHour: Int,
        reminderEnabled: Bool,
        reminderMinutes: Int
    ) throws {
        try saveLearningSettings(
            cefrLevels: [cefrLevel],
            dailyNewLimit: dailyNewLimit,
            dayCutoffHour: dayCutoffHour,
            reminderEnabled: reminderEnabled,
            reminderMinutes: reminderMinutes)
    }

    /// 3.12: đồng bộ lịch nhắc local notification với settings hiện tại.
    /// Gọi lúc khởi động (ReadoApp `.task`) + sau khi lưu Settings.
    func syncReminderSchedule(requestPermission: Bool = false) async {
        guard let database else { return }
        let settings = (try? SettingsService.load(on: database)) ?? .defaults
        await NotificationScheduler.apply(
            enabled: settings.reminderEnabled,
            minutes: settings.reminderMinutes,
            requestPermission: requestPermission)
    }

    // MARK: — Overview

    /// Scaffold → 3.5: tổng quan collection giờ đọc từ ReadoKit
    /// (`allCollectionSummaries`) — tên, số từ, đến hạn, lần thêm gần nhất.
    static func loadOverview(db: SQLiteDatabase) throws
        -> [CollectionOverview]
    {
        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: SystemClock().now)
        return summaries.map { summary in
            CollectionOverview(
                id: summary.id,
                name: summary.name,
                isDefault: summary.isDefault,
                totalItems: summary.wordCount,
                dueNow: summary.dueNow,
                lastAddedAt: summary.lastAddedAt,
                masteredCount: summary.masteredCount)
        }
    }

    // MARK: — FR-08 Vocabulary List

    /// Nạp danh sách từ của một collection cho detail view. `order = .byTerm`
    /// cho named collection, `.byDateAdded` cho kho tạm (J6 — chọn lô theo thời
    /// điểm thêm).
    func loadVocabulary(
        collectionID: String,
        order: VocabRepository.VocabularyOrder
    ) {
        guard let database else {
            vocabulary = []
            return
        }
        vocabulary = (try? VocabRepository.listVocabulary(
            on: database, collectionID: collectionID, order: order)) ?? []
    }

    /// Nạp các phiên đọc của một collection cho J2 hub (mới nhất trước).
    func loadSessions(collectionID: String) {
        guard let database else {
            sessions = []
            return
        }
        sessions = (try? ReadingSessionRepository.listSessions(
            on: database, collectionID: collectionID)) ?? []
    }

    // MARK: — FR-17 Collection Management

    /// Tạo collection mới (named, không phải kho tạm). Trả id; nil khi tên rỗng
    /// hoặc trùng tên collection khác.
    @discardableResult
    func createCollection(name: String) throws -> String? {
        guard let database else { return nil }
        let id = try VocabRepository.createCollection(on: database, name: name)
        if id != nil { reloadOverview() }
        return id
    }

    /// Đổi tên collection (kho tạm vẫn đổi được). Trả false khi tên rỗng/trùng.
    @discardableResult
    func renameCollection(id: String, name: String) throws -> Bool {
        guard let database else { return false }
        let ok = try VocabRepository.renameCollection(on: database, id: id, name: name)
        if ok { reloadOverview() }
        return ok
    }

    /// Xoá collection; còn từ → `moveTo` chỉ đích chuyển (FR-17). Trả số từ đã
    /// chuyển (0 khi rỗng).
    @discardableResult
    func deleteCollection(id: String, moveTo: String?) throws -> Int {
        guard let database else { return 0 }
        let moved = try VocabRepository.deleteCollection(
            on: database, id: id, moveWordsTo: moveTo)
        reloadOverview()
        return moved
    }

    /// Chuyển một lô từ sang collection khác (giữ nguyên FSRS — FR-17).
    @discardableResult
    func moveItems(
        fromCollectionID: String,
        itemIDs: [String],
        toCollectionID: String
    ) throws -> Int {
        guard let database else { return 0 }
        let moved = try VocabRepository.moveVocabularyItems(
            on: database,
            fromCollectionID: fromCollectionID,
            itemIDs: itemIDs,
            toCollectionID: toCollectionID)
        reloadOverview()
        return moved
    }

    // MARK: — FR-17 Home pin

    /// Các collection đang ghim trên Home, đã resolve theo thứ tự ghim và bỏ
    /// pin trỏ vào collection đã xoá (PRD FR-17: "shortcut lỗi bị bỏ").
    var homePins: [CollectionOverview] {
        homePinIDs.compactMap { id in
            collections.first { $0.id == id }
        }
    }

    /// Ghim thêm collection lên Home. Đã đủ 5 pin → `set` ném `.tooMany` (UI mở
    /// chooser chọn pin hiện có để thay TRƯỚC khi gọi — `HomePinToggle`
    /// kiểm `count < maxPins`).
    @discardableResult
    func addHomePin(_ id: String) throws -> [String] {
        guard let database else { throw ReviewError.modelUnavailable }
        let current = try HomePinService.ids(on: database)
        guard !current.contains(id) else { return current }
        let updated = try HomePinService.set(on: database, ids: current + [id])
        reloadOverview()
        return updated
    }

    /// Bỏ một pin, giữ nguyên thứ tự các pin còn lại (compact).
    @discardableResult
    func removeHomePin(_ id: String) throws -> [String] {
        guard let database else { throw ReviewError.modelUnavailable }
        let current = try HomePinService.ids(on: database)
        guard current.contains(id) else { return current }
        let updated = try HomePinService.set(
            on: database, ids: current.filter { $0 != id })
        reloadOverview()
        return updated
    }

    /// Chooser "đã đủ 5": thay một pin đang có bằng collection mới. Pin cần thay
    /// đã mất (collection xoá) → coi như ghim mới.
    @discardableResult
    func replaceHomePin(existingID: String, with newID: String) throws
        -> [String]
    {
        guard let database else { throw ReviewError.modelUnavailable }
        let current = try HomePinService.ids(on: database)
        guard let index = current.firstIndex(of: existingID) else {
            return try addHomePin(newID)
        }
        var updated = current
        updated[index] = newID
        let result = try HomePinService.set(on: database, ids: updated)
        reloadOverview()
        return result
    }

    /// Ghim/bỏ ghim một collection (max 5, kho tạm bị chặn ở tầng service).
    /// Ghim quá 5 → `HomePinService.set` ném `.tooMany` (không nuốt — UI mở alert).
    func togglePin(_ id: String) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        let current = try HomePinService.ids(on: database)
        let next = current.contains(id)
            ? current.filter { $0 != id }
            : current + [id]
        try HomePinService.set(on: database, ids: next)
        reloadOverview()
    }

    // MARK: — Ôn nhanh (port UI lab: scope ôn mặc định 1–3 bộ / tất cả)

    /// Bật/tắt một collection trong "Ôn nhanh" (tối đa 3). Bật → `reviewAll` tắt.
    /// Đủ 3 mà cố thêm → ném `.tooMany` (UI đã disable, đây là fallback).
    func toggleReviewPriority(_ id: String) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        let scope = try ReviewScopeService.load(on: database)
        var ids = scope.priorityIDs
        if let i = ids.firstIndex(of: id) {
            ids.remove(at: i)
        } else if ids.count < ReviewScopeService.maxPriority {
            ids.append(id)
        } else {
            throw ReviewScopeError.tooMany
        }
        try ReviewScopeService.update(
            on: database, priorityIDs: ids, reviewAll: false)
        reloadOverview()
    }

    /// Bật/tắt "Ôn tất cả" cho Ôn nhanh.
    func setReviewAll(_ on: Bool) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try ReviewScopeService.update(
            on: database, priorityIDs: [], reviewAll: on)
        reloadOverview()
    }

    // MARK: — FR-20 CSV Import

    /// Parse nội dung CSV/TSV (dùng chung delimiter-detect với FR-16).
    func parseImport(_ text: String) throws -> [CSVImport.CSVRow] {
        try CSVImport.parse(text)
    }

    /// Đánh dấu dòng trùng term so với `term_normalized` hiện có — không tự loại.
    func markDuplicateTerms(_ rows: [CSVImport.CSVRow]) -> [CSVImport.CSVRow] {
        guard let database else { return rows }
        let existing = (try? CSVImport.existingTermNormalizedSet(on: database)) ?? []
        return CSVImport.markDuplicateTerms(rows, existing: existing)
    }

    /// Gộp các dòng được chọn vào kho (1 transaction, atomic). Reload overview.
    @discardableResult
    func importRows(_ rows: [CSVImport.CSVRow]) throws -> CSVImport.ImportSummary {
        guard let database else { throw CSVImport.ImportError.emptyFile }
        let summary = try CSVImport.importRows(
            on: database, rows: rows, now: SystemClock().now)
        reloadOverview()
        return summary
    }
}