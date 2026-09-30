import Foundation
import ReadoKit

// Núm học tập, agent AI, lịch streak, nhắc ôn (FR-14/15, 3.12, ADR-041).
// Tách từ AppModel.swift (refactor): logic giữ nguyên, chỉ đổi file.

extension AppModel {
    /// ADR-041: thêm agent BYOK từ checklist onboarding — cùng logic với
    /// `SettingsView.addAgent` (mặc định đặt active). `nil` = đã lưu, chuỗi =
    /// lỗi hiện trong sheet.
    func addAgent(name: String, baseURL: String, model: String, apiKey: String?) -> String? {
        guard let database else { return "Chưa mở được kho" }
        guard let apiKey else { return "Thiếu API key" }
        do {
            try AnalysisAgentStore.add(
                on: database, name: name, baseURL: baseURL, model: model, apiKey: apiKey)
            reloadOverview()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// FR-15: đọc 3 núm học tập — fallback về seed default khi chưa seed.
    static func currentSettings(_ db: SQLiteDatabase) -> LearningSettings {
        (try? SettingsService.load(on: db)) ?? .defaults
    }

    /// FR-14: số đếm Home — quota-aware + streak + số trang, dùng chung
    /// `dailyNewLimit` đã đọc từ settings. `extraNew` (ý 3): phần nới "Học
    /// thêm" còn hiệu lực hôm nay để số Home khớp đúng hàng đợi thật.
    static func loadDailyProgress(db: SQLiteDatabase, extraNew: Int = 0) throws -> DailyProgress {
        let dailyNewLimit = currentSettings(db).dailyNewLimit
        return try DailyProgressService.load(
            on: db, dailyNewLimit: dailyNewLimit, now: SystemClock().now, extraNew: extraNew)
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
}
