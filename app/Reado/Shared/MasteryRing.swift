import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Ý 4 motivation-r1 (U9 ux-polish-r1): "N từ · Đã thuộc X/Y" — bộ rỗng bỏ
/// hẳn phần "Đã thuộc" (0/0 trông như lỗi, không phải tiến bộ). Dùng chung
/// Home (pin) và Kho (danh sách).
func masteryLabel(_ collection: AppModel.CollectionOverview) -> String {
    guard collection.totalItems > 0 else { return "\(collection.totalItems) từ" }
    return "\(collection.totalItems) từ · Đã thuộc \(collection.masteredCount)/\(collection.totalItems)"
}

/// U9 ux-polish-r1: vòng tỉ lệ "đã thuộc" (Q-08) của một bộ — chỉ vẽ khi
/// `total > 0` (caller kiểm trước khi dùng).
struct MasteryRing: View {
    let mastered: Int
    let total: Int

    var body: some View {
        let ratio = total > 0 ? Double(mastered) / Double(total) : 0
        ZStack {
            Circle().stroke(Theme.surfaceStrong, lineWidth: 3)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
        .accessibilityElement()
        .accessibilityLabel("Đã thuộc \(mastered) trên \(total) từ")
    }
}
