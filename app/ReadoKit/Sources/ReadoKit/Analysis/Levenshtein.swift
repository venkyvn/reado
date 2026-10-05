import Foundation

/// Hàm thuần dùng chung — trước đây `OCRFixApplier.editDistance` (ký tự) và
/// `OCRProbeTests` (từ, cho WER/CER, ocr-quality-r1 T2) mỗi nơi tự viết một
/// bản DP riêng giống hệt nhau (review tìm được: 2 nguồn sự thật cho cùng một
/// thuật toán, dễ lệch khi một bên sửa mà bên kia không theo). Generic nên
/// dùng chung cho cả mảng `Character` lẫn mảng từ (`String`).
public enum EditDistance {
    public static func levenshtein<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    current[j] = previous[j - 1]
                } else {
                    current[j] = min(previous[j - 1] + 1, previous[j] + 1, current[j - 1] + 1)
                }
            }
            previous = current
        }
        return previous[b.count]
    }
}
