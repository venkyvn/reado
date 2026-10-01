import Foundation
import ReadoKit

// Overview, danh sách từ, quản lý collection, pin Home, Ôn nhanh, import CSV (FR-08/17/20).
// Tách từ AppModel.swift (refactor): logic giữ nguyên, chỉ đổi file.

extension AppModel {
    // MARK: — Overview

    /// Scaffold → 3.5: tổng quan collection giờ đọc từ ReadoKit
    /// (`allCollectionSummaries`) — tên, số từ, đến hạn, lần thêm gần nhất.
    static func loadOverview(db: SQLiteDatabase, now: Date) throws
        -> [CollectionOverview]
    {
        let summaries = try VocabRepository.allCollectionSummaries(
            on: db, now: now)
        return summaries.map { summary in
            CollectionOverview(
                id: summary.id,
                name: summary.name,
                isDefault: summary.isDefault,
                totalItems: summary.wordCount,
                dueNow: summary.dueNow,
                lastAddedAt: summary.lastAddedAt,
                masteredCount: summary.masteredCount,
                learningCount: summary.learningCount,
                reviewingCount: summary.reviewingCount,
                notStartedCount: summary.notStartedCount,
                absorbedCount: summary.absorbedCount,
                addedLast7Days: summary.addedLast7Days,
                crammableCount: summary.crammableCount)
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
        vocabulary = read("danh sách từ", fallback: []) {
            try VocabRepository.listVocabulary(
                on: database, collectionID: collectionID, order: order)
        }
    }

    /// Nạp lần ôn kế tiếp của một collection cho ô "Lần ôn tiếp" ở header hub.
    func loadNextDue(collectionID: String) {
        guard let database else {
            collectionNextDue = nil
            return
        }
        let now = clock.now
        collectionNextDue = read("lần ôn kế tiếp", fallback: nil) {
            () throws -> VocabRepository.NextDue? in
            try VocabRepository.nextDue(on: database, collectionID: collectionID, now: now)
        }
    }

    /// Nạp các phiên đọc của một collection cho J2 hub (mới nhất trước).
    func loadSessions(collectionID: String) {
        guard let database else {
            sessions = []
            return
        }
        sessions = read("phiên đọc", fallback: []) {
            try ReadingSessionRepository.listSessions(
                on: database, collectionID: collectionID)
        }
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

    // MARK: — Cho UI: báo lỗi / tên trùng thay vì im lặng (refactor-r3 #1)

    private static let badNameMessage = "Tên bộ để trống hoặc đã có bộ khác dùng tên này."

    /// Tạo bộ; `nil` = không tạo được và ĐÃ báo người dùng (tên trống/trùng, lỗi DB).
    func createCollectionOrAlert(name: String) -> String? {
        guard let outcome = attempt("tạo bộ", { try createCollection(name: name) }) else {
            return nil
        }
        guard let id = outcome else {
            alertMessage = Self.badNameMessage
            return nil
        }
        return id
    }

    /// Đổi tên bộ; `false` = chưa đổi và ĐÃ báo người dùng.
    @discardableResult
    func renameCollectionOrAlert(id: String, name: String) -> Bool {
        guard let renamed = attempt("đổi tên bộ", { try renameCollection(id: id, name: name) }) else {
            return false
        }
        if !renamed { alertMessage = Self.badNameMessage }
        return renamed
    }

    /// Xoá bộ (có thể chuyển từ sang `moveTo`); `false` = chưa xoá và ĐÃ báo.
    @discardableResult
    func deleteCollectionOrAlert(id: String, moveTo: String?) -> Bool {
        attempt("xoá bộ") { try deleteCollection(id: id, moveTo: moveTo) } != nil
    }

    /// Chuyển một lô từ; `false` = chưa chuyển và ĐÃ báo.
    @discardableResult
    func moveItemsOrAlert(
        fromCollectionID: String, itemIDs: [String], toCollectionID: String
    ) -> Bool {
        attempt("chuyển từ") {
            try moveItems(
                fromCollectionID: fromCollectionID, itemIDs: itemIDs,
                toCollectionID: toCollectionID)
        } != nil
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
        let existing = read("từ đã có trong kho", fallback: Set<String>()) {
            try CSVImport.existingTermNormalizedSet(on: database)
        }
        return CSVImport.markDuplicateTerms(rows, existing: existing)
    }

    /// Gộp các dòng được chọn vào kho (1 transaction, atomic). Reload overview.
    @discardableResult
    func importRows(_ rows: [CSVImport.CSVRow]) throws -> CSVImport.ImportSummary {
        guard let database else { throw CSVImport.ImportError.emptyFile }
        let summary = try CSVImport.importRows(
            on: database, rows: rows, now: clock.now)
        reloadOverview()
        return summary
    }

    // MARK: — Export (FR-16, J-R1-D)

    /// TSV các collection đã chọn (`nil` = tất cả).
    func exportTSV(collectionIDs: [String]?) throws -> String {
        guard let database else { throw ReviewError.modelUnavailable }
        return try ExportService.buildTSV(on: database, collectionIDs: collectionIDs)
    }

    /// JSON backup — LUÔN toàn bộ máy (J-R1-D #4), không lọc collection.
    func exportJSON() throws -> Data {
        guard let database else { throw ReviewError.modelUnavailable }
        return try ExportService.buildJSON(on: database, now: clock.now)
    }
}
