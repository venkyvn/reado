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
/// `@MainActor`: state `@Observable` cho UI và một kết nối SQLite dùng chung —
/// mọi truy cập đi qua main actor, không còn hàm async chạy ngoài main thread.
@MainActor
@Observable
final class AppModel {
    private(set) var database: SQLiteDatabase?
    private(set) var failure: String?
    /// Lỗi người dùng cần thấy (alert ở `RootView` + sheet) — xem `AppModel+Errors`.
    /// Đặt về nil khi người dùng đóng alert.
    var alertMessage: String?
    /// Các lần đọc đang lỗi (`read`) — để chỉ alert một lần tới khi đọc lại được.
    @ObservationIgnored var failingReads: Set<String> = []
    /// Đồng hồ duy nhất của app target — mọi `now` đi qua đây (một lần chấm /
    /// một lần nạp dùng đúng một giá trị), không gọi `SystemClock()` rải rác.
    /// Qualify `ReadoKit.Clock` để không nhầm với `Swift.Clock`.
    let clock: any ReadoKit.Clock = SystemClock()
    private(set) var collections: [CollectionOverview] = []
    // FR-14: tổng quan Home — đến hạn (quota-aware) + tồn đọng + streak.
    private(set) var dailyProgress: DailyProgress?
    // J-R1-P: lịch streak (lens FR-14) — streak hiện tại + dài nhất + heatmap 18×7.
    var streakHeatmap: StreakHeatmap?
    /// Pin Home — id collection "đang đọc" (thứ tự user thêm, ≤ 5). Port UI lab
    /// (2026-09-23) nâng từ 2 shortcut (FR-17 cũ) → 5 pin (`HomePinService`).
    private(set) var homePinIDs: [String] = []
    /// Ôn nhanh (port UI lab) — scope ôn mặc định của tab Ôn: 1–3 bộ ưu tiên
    /// hoặc "tất cả" (`reviewAll`).
    private(set) var reviewScopeDefault: ReviewScope = .empty
    /// FR-22 / Home: số TỪ khác nhau được gặp lại (`seen` hoặc `recognized`) trong 7
    /// ngày gần nhất — dòng "Gặp lại N từ tuần này" (ẩn khi 0).
    private(set) var reencounteredThisWeek = 0
    /// ADR-041: agent đang active chạy được thật — proxy mặc định chưa deploy
    /// nên chỉ agent BYOK có key mới tính "sẵn sàng". TODO: khi proxy deploy
    /// xong, đổi điều kiện thành `hasKey` (proxy luôn `hasKey = true`).
    private(set) var activeAgentReady = false

    // FR-08/FR-17: danh sách từ của collection đang xem (detail view giữ state,
    // một detail mở một lúc nên một biến là đủ).
    var vocabulary: [VocabRepository.VocabularyListEntry] = []

    // FR-05/06: các phiên đọc song ngữ của collection đang xem (J2 hub).
    var sessions: [ReadingSession] = []
    /// Lần ôn kế tiếp của collection đang mở ở hub (header, cram-collection-r1).
    var collectionNextDue: VocabRepository.NextDue?

    // FR-01: capture state
    var lastCapturedImage: CapturedImage?
    var captureError: String?

    // FR-02: analysis state
    var isAnalyzing = false
    var analysisResult: PageAnalysis?
    /// FR-04: giữ nguyên loại lỗi để UI chọn CTA đúng (chụp lại vs thử lại).
    var analysisFailure: AnalysisError?
    /// Chuỗi hiển thị cho lỗi phân tích — chỉ để UI đọc, không lưu.
    var analysisError: String? { analysisFailure?.errorDescription }
    /// Tiến độ agent đang gọi (đọc trang/chờ/suy nghĩ/viết) — chỉ `openai_compat`
    /// (stream) phát ra; AnalysisView đổi dòng chữ theo đây thay vì đứng im.
    var analysisProgress: AnalysisProgress?

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
    var isLoadingReview = false
    var reviewError: String?
    var reviewItems: [ReviewQueue.ReviewItem] = []
    var reviewSnapshots: [String: CardSnapshot] = [:]
    var currentReviewSnapshot: CardSnapshot?
    /// Lịch 4 nút của thẻ đang hiện — `grade` dùng lại để nhãn == lịch ghi
    /// (T2 fsrs-queue-fix-r1). Chỉ cache nội bộ, UI không quan sát.
    @ObservationIgnored var gradePreview: GradePreview?

    // FR-18: phạm vi ôn hiện tại (nil = tất cả collection) + nợ due ngoài phạm
    // vi (phải nhìn thấy — research/vocabulary.md 4.2).
    var reviewScope: Set<String>? = nil
    var dueOutsideScope = 0
    /// Số thẻ Cram được trong phạm vi hiện tại (đã học, chưa đến hạn) — quyết
    /// định nút "Ôn thêm" ở màn hết thẻ (ADR-043).
    var crammableCount = 0

    /// Ý 3 motivation-r1 ("Học thêm 10 từ", Q-A/Q-B đã chốt): phần nới hạn mức
    /// new RIÊNG ngày học hiện tại — chỉ bộ nhớ app, KHÔNG lưu DB/migration.
    /// Gắn theo `dayStart` (giờ chuyển ngày FR-11, không nửa đêm hệ thống) —
    /// qua ngày mới tự mất qua `ReviewQueue.effectiveExtra`.
    var extraNewQuota: (dayStart: String, count: Int)?
    /// Q-B đã chốt: N = 10 từ cố định, một nút "Học thêm 10 từ".
    static let learnMoreBatchSize = 10

    struct CollectionOverview: Identifiable, Equatable {
        let id: String
        let name: String
        let isDefault: Bool
        let totalItems: Int
        let dueNow: Int
        let lastAddedAt: Date?
        /// Q-08 "đã thuộc" — ý 4 motivation-r1 ("Đã thuộc X/Y" ở hub + Kho).
        let masteredCount: Int
        /// Header collection (cram-collection-r1 T3): thanh 4 màu theo từ.
        let learningCount: Int
        let reviewingCount: Int
        let notStartedCount: Int
        /// "Đã thấm" (FR-22): từ Q-08 + ≥1 lần nhận ra — tập con của `masteredCount`.
        let absorbedCount: Int
        let addedLast7Days: Int
        /// Thẻ Cram được (đếm thẻ) — quyết định CTA "Ôn thêm".
        let crammableCount: Int
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
            Self.seedDevDemoCSVIfNeeded(on: database)
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

    /// Chỉ debug: launch với `READO_DEV_DEMO_CSV=<đường dẫn CSV 7 cột>`
    /// (`scripts/sim_screens.sh`) để có dữ liệu mẫu chụp màn hình. Chỉ nạp khi kho
    /// còn trống (không có từ nào) — cài lại app mới seed lại, không nhân đôi.
    private static func seedDevDemoCSVIfNeeded(on database: SQLiteDatabase) {
        guard let path = ProcessInfo.processInfo.environment["READO_DEV_DEMO_CSV"],
              !path.isEmpty,
              let text = try? String(contentsOfFile: path, encoding: .utf8),
              let existing = try? CSVImport.existingTermNormalizedSet(on: database),
              existing.isEmpty,
              let rows = try? CSVImport.parse(text)
        else { return }
        _ = try? CSVImport.importRows(on: database, rows: rows, now: SystemClock().now)
    }
    #endif

    func reloadOverview() {
        guard let database else { return }
        let now = clock.now
        collections = read("danh sách bộ", fallback: []) {
            try Self.loadOverview(db: database, now: now)
        }
        dailyProgress = read("tiến độ hôm nay", fallback: nil) { () throws -> DailyProgress? in
            try Self.loadDailyProgress(db: database, now: now, extraNew: effectiveExtraNew)
        }
        reencounteredThisWeek = read("số từ gặp lại", fallback: 0) {
            try EncounterRepository.distinctWordsEncountered(
                on: database, since: now.addingTimeInterval(-7 * 86_400))
        }
        homePinIDs = read("bộ ghim ở Home", fallback: []) {
            try HomePinService.ids(on: database)
        }
        reviewScopeDefault = read("phạm vi ôn", fallback: .empty) {
            try ReviewScopeService.load(on: database)
        }
        // ADR-041: proxy mặc định chưa deploy → chỉ agent BYOK có key mới
        // tính "sẵn sàng" cho checklist onboarding.
        let agents: (agents: [AnalysisAgent], activeID: String)? =
            read("danh sách agent", fallback: nil) {
                try AnalysisAgentStore.list(on: database)
            }
        activeAgentReady = agents.flatMap { list in
            list.agents.first { $0.id == list.activeID }
                .map { !$0.isBuiltinProxy && $0.hasKey }
        } ?? false
        dataRevision &+= 1
    }

    /// ADR-041: đã có ít nhất một trang phân tích hoặc một từ trong kho —
    /// dùng để ẩn checklist onboarding cho user cũ (không đếm riêng).
    var hasFirstPage: Bool {
        (dailyProgress?.pagesAnalyzed ?? 0) > 0 || collections.contains { $0.totalItems > 0 }
    }

    /// Phần nới "Học thêm" còn hiệu lực HÔM NAY (0 nếu qua ngày mới hoặc chưa
    /// bấm) — hàm thuần `ReviewQueue.effectiveExtra` test riêng, ở đây chỉ nối
    /// với `dayStart` thật của DB đang mở.
    var effectiveExtraNew: Int {
        guard let database else { return 0 }
        let dayStart = ReviewQueue.currentDayStartIso(on: database, now: clock.now)
        return ReviewQueue.effectiveExtra(stored: extraNewQuota, currentDayStart: dayStart)
    }
}
