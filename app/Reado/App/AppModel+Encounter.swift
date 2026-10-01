import Foundation
import ReadoKit

// FR-22 — gặp lại từ cũ khi đọc (reencounter-r1 T2, ADR-048).

extension AppModel {
    /// Matcher dựng từ kho hiện tại (xuyên collection, bỏ vocab có thẻ leech).
    /// Rỗng khi chưa mở được DB hoặc đọc lỗi — màn đọc khi đó không gạch chân gì.
    func makeEncounterMatcher() -> EncounterMatcher {
        guard let database else { return EncounterMatcher(lexicon: []) }
        // Gạch chân là phụ trợ: lỗi → không gạch gì, chỉ ghi trace.
        let lexicon = readQuietly("từ điển gặp lại", fallback: []) {
            try EncounterRepository.loadLexicon(on: database)
        }
        return EncounterMatcher(lexicon: lexicon)
    }

    /// Hôm nay (ngày học hiện tại) đã "nhận ra" từ này chưa.
    func hasRecognizedToday(_ vocabItemID: String) -> Bool {
        guard let database else { return false }
        let now = clock.now
        return readQuietly("đã nhận ra hôm nay", fallback: false) {
            try EncounterRepository.recognizedToday(
                on: database, vocabItemID: vocabItemID, now: now)
        }
    }

    /// Ghi một lần "nhận ra" khi đọc. `true` = vừa ghi; `false` = hôm nay đã ghi
    /// rồi hoặc lỗi. Không đụng lịch ôn (FR-22).
    @discardableResult
    func recognizeWord(_ vocabItemID: String) -> Bool {
        guard let database else { return false }
        let now = clock.now
        let recorded = attempt("ghi lần nhận ra") {
            try EncounterRepository.recordRecognized(
                on: database, vocabItemID: vocabItemID, now: now)
        } ?? false
        // Đã thấm / "Gặp lại N từ" đổi theo → nạp lại số liệu Home + Hub.
        if recorded { reloadOverview() }
        return recorded
    }
}
