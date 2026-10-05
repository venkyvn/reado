import Foundation
import ReadoKit

// Hàng đợi ôn, chấm/undo, Ôn thêm (FR-11/12/18 — extra-review-r1 đảo ADR-011/043).
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
        review.scope = scope
        review.isLoading = true
        review.error = nil
        defer { review.isLoading = false }
        do {
            let dailyNewLimit = try SettingsService.load(on: database).dailyNewLimit
            let now = clock.now
            let windowEnd = ReviewQueue.currentDayWindow(on: database, now: now).end
            let (items, snapshots) = try ReviewQueue.loadFullQueue(
                on: database, dailyNewLimit: dailyNewLimit, now: now, scope: scope)
            review.items = items
            review.snapshots = snapshots
            review.currentSnapshot = items.first.flatMap { snapshots[$0.cardID] }
            review.dueOutsideScope = try Int(
                ReviewQueue.dueOutsideScopeCount(
                    on: database,
                    dueBeforeIso: windowEnd,
                    scope: scope))
            review.extraAvailableCount = try Int(
                ReviewQueue.extraAvailableCount(on: database, now: now, scope: scope))
        } catch {
            review.error = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            DebugTrace.event("review", "loadQueueFailed", ["error": String(describing: error)])
            throw error
        }
    }

    /// Phiên ôn nhanh (engagement-r1 T5): chỉ `ReviewQueue.quickSessionSize` thẻ đầu của hàng đợi hôm
    /// nay. Ghi đè `review.items`/`snapshots` như `loadReviewQueue`; `quickRemaining` = số thẻ còn lại.
    func loadQuickQueue(scope: Set<String>? = nil) async throws {
        guard let database else { throw ReviewError.modelUnavailable }
        review.scope = scope
        review.isLoading = true
        review.error = nil
        defer { review.isLoading = false }
        do {
            let dailyNewLimit = try SettingsService.load(on: database).dailyNewLimit
            let now = clock.now
            let windowEnd = ReviewQueue.currentDayWindow(on: database, now: now).end
            let (items, snapshots, remaining) = try ReviewQueue.loadQuickQueue(
                on: database, dailyNewLimit: dailyNewLimit, now: now, scope: scope)
            review.items = items
            review.snapshots = snapshots
            review.currentSnapshot = items.first.flatMap { snapshots[$0.cardID] }
            review.quickRemaining = remaining
            review.dueOutsideScope = try Int(
                ReviewQueue.dueOutsideScopeCount(
                    on: database, dueBeforeIso: windowEnd, scope: scope))
            review.extraAvailableCount = try Int(
                ReviewQueue.extraAvailableCount(on: database, now: now, scope: scope))
        } catch {
            review.error = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            DebugTrace.event("review", "loadQuickQueueFailed", ["error": String(describing: error)])
            throw error
        }
    }

    /// Chấm thẻ hiện tại (FR-11, và Ôn thêm — extra-review-r1 đảo ADR-011: MỌI
    /// lượt chấm đều ghi lịch thật, không còn đường `mode='cram'` chỉ-log):
    /// snapshot TRƯỚC + strict rating → outcome; UPDATE cards + INSERT
    /// review_logs + leech suspend (FR-19) cùng MỘT transaction (FR-12 undo cần
    /// logID). Trả `GradeResult` để view giữ logID cho undo nổi 1 bước, và biết
    /// thẻ vừa vượt ngưỡng "đã thuộc" (ADR-038) để bật toast.
    ///
    /// Một `now` cho cả lần chấm. Nếu nhãn 4 nút đã tính cho đúng thẻ + snapshot
    /// này trong 30 phút (`GradePreview`), dùng lại outcome đó → `scheduled_days`
    /// ghi == nhãn đã hiện (fuzz seed theo timestamp nên tính lại có thể lệch).
    /// `reviewed_at`/`last_review_at` luôn là `now` (giờ bấm thật).
    func grade(
        cardID: String,
        snapshot: CardSnapshot,
        rating: ReadoRating
    ) throws -> GradeResult {
        guard let database else { throw ReviewError.modelUnavailable }
        let now = clock.now
        let outcome: ReviewOutcome
        if let previewed = review.gradePreview?.outcome(
            for: rating, cardID: cardID, snapshot: snapshot, now: now)
        {
            outcome = previewed
        } else {
            let settings = try ReadoFSRS.readSettings(on: database)
            let scheduler = try ReviewScheduler(settings: settings)
            outcome = try scheduler.grade(rating, snapshot: snapshot, now: now)
        }
        let recorded = try ReviewService.record(
            on: database, cardID: cardID, before: snapshot, outcome: outcome,
            leechThreshold: LeechService.readThreshold(on: database), now: now)
        // Thẻ đã đổi → cache cũ vô nghĩa; thẻ kế tiếp nạp lại qua `intervalLabels`.
        review.gradePreview = nil
        if recorded.becameLeech {
            DebugTrace.event("review", "leech", ["cardID": cardID, "lapses": outcome.lapses])
        }
        // ADR-038: tính từ before/after đã có sẵn — không query DB thêm.
        let crossedMastery = Mastery.crossed(
            before: snapshot.stability, after: outcome.stability, stateAfter: outcome.state)
        return GradeResult(logID: recorded.logID, crossedMastery: crossedMastery)
    }

    /// U1 ux-polish-r1: nhãn nhịp ôn kế tiếp cho 4 mức chấm (preview
    /// `swift-fsrs` thật qua `GradePreview`/`IntervalPreview` — không tự tính).
    /// Kết quả được giữ lại để `grade` ghi đúng lịch đã hiện. Lỗi (DB đóng,
    /// settings hỏng) → rỗng + xoá cache, nút chấm vẫn hoạt động bình thường
    /// (tính lại lúc bấm), chỉ ẩn nhãn.
    func intervalLabels(for snapshot: CardSnapshot) -> [ReadoRating: String] {
        review.gradePreview = nil
        guard let database else { return [:] }
        // Nhãn xem trước là phụ trợ: lỗi chỉ ghi trace, nút chấm vẫn dùng được.
        let now = clock.now
        guard let preview = readQuietly("nhãn xem trước", fallback: nil, {
            () throws -> GradePreview? in
            let settings = try ReadoFSRS.readSettings(on: database)
            let scheduler = try ReviewScheduler(settings: settings)
            return try GradePreview.make(scheduler: scheduler, snapshot: snapshot, now: now)
        }) else { return [:] }
        review.gradePreview = preview
        return preview.outcomes.mapValues { IntervalPreview.label(days: $0.scheduledDays) }
    }

    /// Ôn thêm (extra-review-r1, đảo ADR-011/043): nạp tối đa 20 thẻ trộn mới +
    /// ôn sớm trong phạm vi. Ghi đè `review.items`/`review.snapshots` như
    /// `loadReviewQueue`; `dueOutsideScope` về 0 vì banner nợ chỉ thuộc đường
    /// hàng đợi chính. Chấm/undo dùng chung `grade`/`undoReview` — Ôn thêm
    /// KHÔNG còn đường ghi-log-riêng.
    func loadExtraQueue(scope: Set<String>? = nil) async throws {
        guard let database else { throw ReviewError.modelUnavailable }
        review.scope = scope
        review.isLoading = true
        review.error = nil
        defer { review.isLoading = false }
        do {
            let now = clock.now
            let (items, snapshots) = try ReviewQueue.loadExtraQueue(
                on: database, now: now, scope: scope)
            review.items = items
            review.snapshots = snapshots
            review.currentSnapshot = items.first.flatMap { snapshots[$0.cardID] }
            review.dueOutsideScope = 0
            review.extraAvailableCount = try Int(
                ReviewQueue.extraAvailableCount(on: database, now: now, scope: scope))
        } catch {
            review.error = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            DebugTrace.event("review", "loadExtraQueueFailed", ["error": String(describing: error)])
            throw error
        }
    }

    /// Undo một bước (FR-12): trả card về snapshot TRƯỚC + xoá đúng log vừa
    /// ghi — cùng transaction (không UPDATE log cũ). Dùng chung cho cả hàng đợi
    /// chính lẫn Ôn thêm (extra-review-r1: cùng một đường ghi/undo).
    func undoReview(cardID: String, logID: String, snapshot: CardSnapshot) throws {
        guard let database else { throw ReviewError.modelUnavailable }
        try ReviewService.undo(
            on: database, cardID: cardID, logID: logID, before: snapshot)
    }
}
