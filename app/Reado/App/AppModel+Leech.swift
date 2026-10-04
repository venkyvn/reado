import Foundation
import ReadoKit

// FR-19 — "Từ hay quên": đưa lại hàng đợi / xoá hẳn (home-eevas-r1 T3).

extension AppModel {
    /// Đưa một card leech trở lại hàng đợi ôn tập (`LeechService.unsuspend`).
    func requeueLeech(_ card: LeechCard) {
        guard let database else { return }
        let ok = attempt("đưa từ lại hàng đợi") {
            try LeechService.unsuspend(on: database, cardID: card.cardID)
        } != nil
        if ok { reloadOverview() }
    }

    /// Xoá hẳn từ (cả vocab_item, CASCADE dọn cards/review_logs/encounters —
    /// `LeechService.deleteWord`). KHÔNG dùng `deleteCard` (để lại vocab_item mồ côi).
    func deleteLeechWord(_ card: LeechCard) {
        guard let database else { return }
        let ok = attempt("xoá từ hay quên") {
            try LeechService.deleteWord(on: database, vocabItemID: card.vocabItemID)
        } != nil
        if ok { reloadOverview() }
    }
}
