import ReadoKit
import UIKit

/// ocr-quality-r1 T4 (ADR-064) — bọc `UITextChecker` thật cho `VocabSuspicion`
/// (ReadoKit không có UIKit, xem file đó). `UITextChecker` không được Apple
/// đảm bảo thread-safe; `@MainActor` giữ instance tĩnh dùng lại được (coding-
/// conventions §6 cấm `static let` cho class không `Sendable` khi không có gì
/// đảm bảo truy cập một luồng) mà vẫn đúng với cách gọi thật — luôn từ SwiftUI
/// view body, đã ở MainActor (review tìm được: chưa có gì chặn ai đó sau này
/// gọi hàm này từ `Task` nền song song, lúc đó mới thật sự race).
@MainActor
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
    @MainActor
    var isOCRSuspicious: Bool {
        VocabSuspicion.isSuspicious(term: term, isKnownWord: VocabDictionary.isKnownWord)
    }
}
