import ReadoKit
import UIKit

/// ocr-quality-r1 T4 (ADR-064) — bọc `UITextChecker` thật cho `VocabSuspicion`
/// (ReadoKit không có UIKit, xem file đó). Instance tĩnh — `UITextChecker`
/// không giữ state riêng theo lần gọi, dùng lại an toàn.
enum VocabDictionary {
    private static let checker = UITextChecker()

    static func isKnownWord(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        return misspelled.location == NSNotFound
    }
}

extension ReviewDraft {
    /// Nhãn "kiểm tra lại" (T4) — tính lúc hiển thị màn Duyệt & lưu, không lưu DB.
    var isOCRSuspicious: Bool {
        VocabSuspicion.isSuspicious(term: term, isKnownWord: VocabDictionary.isKnownWord)
    }
}
