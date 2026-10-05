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

    /// Số lần gặp lại (`seen`) + tối đa 2 câu gần nhất của một từ — popover FR-22
    /// (vocab-identity-r1 T4, Q9 "Gặp lại N lần").
    func encounterSummary(
        _ vocabItemID: String
    ) -> (seenCount: Int, recent: [EncounterRepository.EncounterContextRow]) {
        guard let database else { return (0, []) }
        return readQuietly("ngữ cảnh gặp lại", fallback: (0, [])) {
            (
                try EncounterRepository.count(
                    on: database, vocabItemID: vocabItemID, kind: .seen),
                try EncounterRepository.recentContexts(
                    on: database, vocabItemID: vocabItemID, limit: 2)
            )
        }
    }

    /// Kết quả một lần bấm "Nhận ra": `recorded` = vừa ghi (false = hôm nay đã ghi rồi hoặc lỗi);
    /// `reachedAbsorbed` = lần này đưa từ lên mức **Đã thấm** (engagement-r1 T3).
    struct RecognizeResult {
        let recorded: Bool
        let reachedAbsorbed: Bool
    }

    /// Mức hiện tại của một từ (4 mức, vision #6). nil khi từ không còn thẻ hoặc đọc lỗi.
    func masteryLevel(_ vocabItemID: String) -> Mastery.Level? {
        guard let database else { return nil }
        return readQuietly("mức của từ", fallback: nil) { () throws -> Mastery.Level? in
            try EncounterRepository.masteryLevel(on: database, vocabItemID: vocabItemID)
        }
    }

    /// Số NGÀY HỌC (FR-11) từ `iso` tới giờ — "N ngày trước". nil khi không đọc được mốc.
    func daysSince(_ iso: String?) -> Int? {
        guard let database, let iso, let date = ISOTimestamp.date(from: iso) else { return nil }
        let (timezone, cutoffHour) = DayContext.read(on: database)
        return DayBoundary.daysBetween(
            date, clock.now, timezone: timezone, dayCutoffHour: cutoffHour)
    }

    /// Ghi một lần "nhận ra" khi đọc. Không đụng lịch ôn (FR-22).
    @discardableResult
    func recognizeWord(_ vocabItemID: String) -> RecognizeResult {
        guard let database else { return RecognizeResult(recorded: false, reachedAbsorbed: false) }
        let now = clock.now
        let before = masteryLevel(vocabItemID)
        let recorded = attempt("ghi lần nhận ra") {
            try EncounterRepository.recordRecognized(
                on: database, vocabItemID: vocabItemID, now: now)
        } ?? false
        // Đã thấm / "Gặp lại N từ" đổi theo → nạp lại số liệu Home + Hub.
        guard recorded else { return RecognizeResult(recorded: false, reachedAbsorbed: false) }
        reloadOverview()
        return RecognizeResult(
            recorded: true,
            reachedAbsorbed: Mastery.reachedAbsorbed(before: before, after: masteryLevel(vocabItemID)))
    }
}
