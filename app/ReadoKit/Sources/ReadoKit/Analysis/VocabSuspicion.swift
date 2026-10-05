import Foundation

/// ocr-quality-r1 T4 — nhãn "kiểm tra lại" trên từ vựng: `term` không được từ
/// điển nhận ra thì coi là nghi ngờ (lỗi OCR/AI đoán nhầm còn sót sau prompt
/// v6 + ADR-042). Hàm thuần, không lưu DB — tính lúc hiển thị màn Duyệt & lưu.
///
/// ReadoKit không có UIKit (lane `kit` chạy macOS, không boot simulator), nên
/// nhận `isKnownWord` làm closure thay vì gọi `UITextChecker` trực tiếp — app
/// bọc `UITextChecker(en_US)` thật truyền vào, test truyền tập từ giả.
public enum VocabSuspicion {
    /// `isKnownWord`: nhận 1 từ đã lowercase (bỏ dấu câu quanh), trả `true`
    /// nếu từ điển nhận ra. Cụm nhiều từ ("machine learning") nghi ngờ nếu có
    /// ÍT NHẤT 1 từ không hợp lệ; từng từ đều hợp lệ thì cụm không nghi ngờ
    /// (tự nhiên khi loop hết mà không gặp từ bị nghi).
    public static func isSuspicious(term: String, isKnownWord: (String) -> Bool) -> Bool {
        let words = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
        guard !words.isEmpty else { return false }
        for word in words where !shouldSkip(word) {
            if !isKnownWord(word.lowercased()) { return true }
        }
        return false
    }

    /// Bỏ qua: chữ viết hoa đầu (tên riêng, VD "Nescafé" — không phải lỗi
    /// OCR), chữ có số (VD "B12" — không phải từ điển tiếng Anh thường).
    private static func shouldSkip(_ word: String) -> Bool {
        guard let first = word.first else { return true }
        if first.isUppercase { return true }
        if word.contains(where: \.isNumber) { return true }
        return false
    }
}
