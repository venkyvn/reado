import Foundation
import ReadoKit

// Núm học tập, agent AI, lịch streak, nhắc ôn (FR-14/15, 3.12, ADR-041).
// Tách từ AppModel.swift (refactor): logic giữ nguyên, chỉ đổi file.

extension AppModel {
    // MARK: — Agent AI (Settings + checklist onboarding)

    /// Danh sách agent + id đang active cho Settings; nil khi chưa mở được DB
    /// hoặc đọc lỗi (view giữ nguyên danh sách cũ).
    func loadAgents() -> (agents: [AnalysisAgent], activeID: String)? {
        guard let database else { return nil }
        return read("danh sách agent", fallback: nil) {
            try AnalysisAgentStore.list(on: database)
        }
    }

    /// Đặt agent active. `knownHasKey` lấy từ `list()` — không hỏi Keychain lần
    /// hai (tránh khựng lúc tap). KHÔNG `reloadOverview` ở đây: view cập nhật lạc
    /// quan và Settings reload overview một lần ở `onDisappear`.
    func setActiveAgent(_ agent: AnalysisAgent) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        // apple-ai-r1 T7 (ADR-063) — hàng Apple bị `.disabled` ở Settings khi
        // không sẵn sàng (không bấm được); chặn lại ở đây cho chắc, phòng khi
        // có đường gọi khác bỏ qua disable đó.
        if agent.isAppleIntelligence, !appleAgentStatus.isAvailable {
            throw AnalysisError.providerError(
                appleAgentStatus.reasonVI ?? "Apple Intelligence chưa sẵn sàng")
        }
        try AnalysisAgentStore.setActive(
            on: database, id: agent.id, knownHasKey: agent.hasKey)
    }

    func deleteAgent(_ agent: AnalysisAgent) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try AnalysisAgentStore.delete(on: database, id: agent.id)
    }

    /// Thêm agent BYOK (Settings + checklist onboarding, ADR-041) — mặc định đặt
    /// active. `nil` = đã lưu, chuỗi = lỗi hiện trong sheet.
    func addAgent(name: String, baseURL: String, model: String, apiKey: String?) -> String? {
        guard let database else { return "Chưa mở được kho" }
        guard let apiKey else { return "Thiếu API key" }
        do {
            try AnalysisAgentStore.add(
                on: database, name: name, baseURL: baseURL, model: model, apiKey: apiKey)
            reloadOverview()
            return nil
        } catch {
            return Self.userMessage(for: error)
        }
    }

    /// Key để trống khi sửa = giữ secret đang có trong Keychain. `nil` = đã lưu,
    /// chuỗi = lỗi hiện trong sheet.
    func updateAgent(
        _ agent: AnalysisAgent, name: String, baseURL: String, model: String, apiKey: String?
    ) -> String? {
        guard let database else { return "Chưa mở được kho" }
        do {
            try AnalysisAgentStore.update(
                on: database, id: agent.id, name: name, baseURL: baseURL, model: model,
                apiKey: apiKey)
            reloadOverview()
            return nil
        } catch {
            return Self.userMessage(for: error)
        }
    }

    /// FR-14: số đếm Home — quota-aware + streak + số trang, dùng chung
    /// `dailyNewLimit` đã đọc từ settings.
    static func loadDailyProgress(
        db: SQLiteDatabase, now: Date
    ) throws -> DailyProgress {
        let dailyNewLimit = try SettingsService.load(on: db).dailyNewLimit
        return try DailyProgressService.load(
            on: db, dailyNewLimit: dailyNewLimit, now: now)
    }

    /// J-R1-P: nạp lịch streak (heatmap 18 tuần + streak hiện tại/dài nhất).
    /// Chỉ gọi khi mở màn Lịch streak — query chạm toàn bộ review_logs.
    func loadStreakHeatmap() {
        guard let database else {
            streakHeatmap = nil
            return
        }
        let now = clock.now
        streakHeatmap = read("lịch streak", fallback: nil) { () throws -> StreakHeatmap? in
            try StreakCalendarService.load(on: database, now: now)
        }
    }

    // MARK: — FR-15 Settings

    /// Đọc núm học tập cho SettingsView hiển thị; nil khi chưa mở được DB.
    func loadLearningSettings() -> LearningSettings? {
        guard let database else { return nil }
        return read("cài đặt học tập", fallback: nil) { () throws -> LearningSettings? in
            try SettingsService.load(on: database)
        }
    }

    /// FR-09 / ADR-066 D1: suất chọn sẵn còn lại hôm nay = daily_new_limit − đã lưu hôm nay.
    func preselectBudgetForCapture() -> (budget: Int, dailyLimit: Int) {
        guard let database else { return (ReviewDraftBuilder.preselectLimit, 0) }
        let now = clock.now
        return read("ngân sách chọn sẵn", fallback: (ReviewDraftBuilder.preselectLimit, 0)) {
            let limit = try SettingsService.load(on: database).dailyNewLimit
            let saved = try VocabRepository.newSavedToday(on: database, now: now)
            return (max(0, limit - saved), limit)
        }
    }

    /// FR-10 / ADR-066: mọi nghĩa đã có trong kho (toàn app, mọi trạng thái) theo khoá
    /// `term|pos`. Không phụ thuộc đích lưu. Lỗi DB -> rỗng, không giấu từ.
    func knownSensesForCapture() -> [String: [KnownSense]] {
        guard let database else { return [:] }
        return read("nghĩa đã có trong kho", fallback: [:]) {
            try VocabRepository.knownSenses(on: database)
        }
    }

    /// (Cũ - ADR-066 đã thay bằng `knownSensesForCapture`, không còn call site.)
    /// FR-10 / Q-13 phương án B: nghĩa trong kho (`meaning_vi`) của mọi term+pos
    /// đã thuộc (stability >= 21, state review) trong collection đang chụp —
    /// khoá `term|pos` → danh sách nghĩa. Chưa chọn bộ → kho tạm. Lỗi DB → rỗng,
    /// không giấu từ.
    func matureSensesForCapture() -> [String: [String]] {
        guard let database else { return [:] }
        let target = capture.analysisTargetCollectionID
        return read("nghĩa đã thuộc của bộ", fallback: [:]) {
            let collectionID: String?
            if let target {
                collectionID = target
            } else {
                collectionID = try VocabRepository.defaultCollectionID(on: database)
            }
            guard let collectionID else { return [:] }
            return try VocabRepository.matureSenses(on: database, collectionID: collectionID)
        }
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

    /// 3.12: đồng bộ lịch nhắc local notification với settings hiện tại.
    /// Gọi lúc khởi động (ReadoApp `.task`) + sau khi lưu Settings.
    func syncReminderSchedule(requestPermission: Bool = false) async {
        guard let database else { return }
        let settings = read("cài đặt nhắc ôn", fallback: LearningSettings.defaults) {
            try SettingsService.load(on: database)
        }
        await NotificationScheduler.apply(
            enabled: settings.reminderEnabled,
            minutes: settings.reminderMinutes,
            requestPermission: requestPermission)
    }
}
