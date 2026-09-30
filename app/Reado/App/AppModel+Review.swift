import Foundation
import ReadoKit

// Hàng đợi ôn, chấm/undo, Cram và "Học thêm" (FR-11/12/18).
// Tách từ AppModel.swift (refactor): logic giữ nguyên, chỉ đổi file.

extension AppModel {
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
            let windowEnd = ReviewQueue.currentDayWindow(on: database, now: now).end
            let (items, snapshots) = try ReviewQueue.loadFullQueue(
                on: database, dailyNewLimit: dailyNewLimit, now: now, scope: scope,
                extraNew: effectiveExtraNew)
            reviewItems = items
            reviewSnapshots = snapshots
            currentReviewSnapshot = items.first.flatMap { snapshots[$0.cardID] }
            dueOutsideScope = try Int(
                ReviewQueue.dueOutsideScopeCount(
                    on: database,
                    dueBeforeIso: windowEnd,
                    scope: scope))
            crammableCount = try Int(
                ReviewQueue.crammableCount(on: database, now: now, scope: scope))
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

    /// U1 ux-polish-r1: nhãn nhịp ôn kế tiếp cho 4 mức chấm (preview
    /// `swift-fsrs` thật qua `IntervalPreview` — không tự tính). Lỗi (DB đóng,
    /// settings hỏng) → rỗng, nút chấm vẫn hoạt động bình thường, chỉ ẩn nhãn.
    func intervalLabels(for snapshot: CardSnapshot) -> [ReadoRating: String] {
        guard let database,
              let settings = try? ReadoFSRS.readSettings(on: database),
              let scheduler = try? ReviewScheduler(settings: settings),
              let outcomes = try? IntervalPreview.outcomes(
                  scheduler: scheduler, snapshot: snapshot, now: SystemClock().now)
        else { return [:] }
        return outcomes.mapValues { IntervalPreview.label(days: $0.scheduledDays) }
    }

    /// Cram (ADR-043): nạp tối đa 20 thẻ đã học nhưng chưa đến hạn trong phạm vi.
    /// Ghi đè `reviewItems`/`reviewSnapshots` như `loadReviewQueue`; `dueOutsideScope`
    /// về 0 vì banner nợ chỉ thuộc đường srs.
    func loadCramQueue(scope: Set<String>? = nil) async throws {
        guard let database else { throw ReviewError.modelUnavailable }
        reviewScope = scope
        isLoadingReview = true
        reviewError = nil
        defer { isLoadingReview = false }
        do {
            let now = SystemClock().now
            let (items, snapshots) = try ReviewQueue.loadCramQueue(
                on: database, now: now, scope: scope)
            reviewItems = items
            reviewSnapshots = snapshots
            currentReviewSnapshot = items.first.flatMap { snapshots[$0.cardID] }
            dueOutsideScope = 0
            crammableCount = try Int(
                ReviewQueue.crammableCount(on: database, now: now, scope: scope))
        } catch {
            reviewError = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            DebugTrace.event("review", "loadCramQueueFailed", ["error": String(describing: error)])
            throw error
        }
    }

    /// Chấm một thẻ ở chế độ Cram: chỉ ghi `review_logs mode='cram'`, KHÔNG đổi
    /// `cards`, KHÔNG kiểm leech (lapses không đổi). `crossedMastery` luôn false.
    func gradeCram(
        cardID: String, snapshot: CardSnapshot, rating: ReadoRating
    ) throws -> GradeResult {
        guard let database else { throw ReviewError.modelUnavailable }
        let logID = try ReviewService.recordCram(
            on: database, cardID: cardID, before: snapshot,
            rating: rating, now: SystemClock().now)
        return GradeResult(logID: logID, crossedMastery: false)
    }

    /// Undo Cram: xoá đúng log cram vừa ghi (`cards` chưa từng đổi).
    func undoCram(cardID: String, logID: String) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try ReviewService.undoCram(on: database, cardID: cardID, logID: logID)
    }

    /// Undo một bước (FR-12): trả card về snapshot TRƯỚC + xoá đúng log vừa
    /// ghi — cùng transaction (không UPDATE log cũ).
    func undoReview(cardID: String, logID: String, snapshot: CardSnapshot) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try ReviewService.undo(
            on: database, cardID: cardID, logID: logID, before: snapshot)
    }

    /// Ý 3 motivation-r1 — user chủ động bấm "Học thêm 10 từ" trên
    /// `SessionDoneView` sau khi hàng đợi hết: nới hạn mức new RIÊNG ngày học
    /// hiện tại (Q-B: N=10 cố định), rồi nạp lại overview đã có (số Home).
    /// Hệ thống KHÔNG bao giờ tự nới — chỉ chạy khi user bấm. Hàng đợi
    /// (`reviewItems`) do caller nạp lại qua `loadReviewQueue`/`loadQueue` của
    /// view — tránh hai tác vụ async cùng ghi `reviewItems` một lúc.
    func learnMore() {
        guard let database else { return }
        let dayStart = ReviewQueue.currentDayStartIso(on: database, now: SystemClock().now)
        // Khác ngày với lần nới trước → `effectiveExtra` trả 0, không cộng dồn
        // từ ngày cũ (Q-A đã chốt).
        let current = ReviewQueue.effectiveExtra(stored: extraNewQuota, currentDayStart: dayStart)
        extraNewQuota = (dayStart: dayStart, count: current + Self.learnMoreBatchSize)
        reloadOverview()
    }
}
