import Foundation
import ReadoKit

// FR-22 — gặp lại từ cũ khi đọc (reencounter-r1 T2, ADR-048).

extension AppModel {
    /// Matcher dựng từ kho hiện tại (xuyên collection, bỏ vocab có thẻ leech).
    /// Rỗng khi chưa mở được DB hoặc đọc lỗi — màn đọc khi đó không gạch chân gì.
    func makeEncounterMatcher() -> EncounterMatcher {
        guard let database,
              let lexicon = try? EncounterRepository.loadLexicon(on: database)
        else { return EncounterMatcher(lexicon: []) }
        return EncounterMatcher(lexicon: lexicon)
    }

    /// Hôm nay (ngày học hiện tại) đã "nhận ra" từ này chưa.
    func hasRecognizedToday(_ vocabItemID: String) -> Bool {
        guard let database else { return false }
        return (try? EncounterRepository.recognizedToday(
            on: database, vocabItemID: vocabItemID, now: clock.now)) ?? false
    }

    /// Ghi một lần "nhận ra" khi đọc. `true` = vừa ghi; `false` = hôm nay đã ghi
    /// rồi hoặc lỗi. Không đụng lịch ôn (FR-22).
    @discardableResult
    func recognizeWord(_ vocabItemID: String) -> Bool {
        guard let database else { return false }
        do {
            return try EncounterRepository.recordRecognized(
                on: database, vocabItemID: vocabItemID, now: clock.now)
        } catch {
            DebugTrace.event("encounter", "recognizeFailed", ["error": String(describing: error)])
            return false
        }
    }
}
