import ReadoKit
import SwiftUI

// Tách từ ReviewQueueView.swift (repo-hygiene-r1 B3).

extension ReadoRating {
    var label: String {
        switch self {
        case .again: "Quên"
        case .hard: "Khó"
        case .good: "Được"
        case .easy: "Dễ"
        }
    }
    /// Confidence ramp đơn sắc — bỏ đèn giao thông (vision "Journey Over Summary"):
    /// chỉ Easy nổi bật (accent filled); Again đỏ nhạt (nghĩa "sai", không phải
    /// tone game); Hard/Good trung tính.
    var buttonBackground: Color {
        switch self {
        case .again: Theme.danger.opacity(0.12)
        case .hard: Theme.surfaceStrong
        case .good: Color.accentColor.opacity(0.18)
        case .easy: Color.accentColor
        }
    }
    var buttonForeground: Color {
        switch self {
        case .again: Theme.danger
        case .hard: .primary
        case .good: Color.accentColor
        // Accent dark mode là bản nhạt — chữ trắng trên đó gần như không đọc được.
        case .easy: Color(.systemBackground)
        }
    }
}
