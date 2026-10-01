import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Ý 4 motivation-r1 (U9 ux-polish-r1): "N từ · Đã nhớ X/Y" — bộ rỗng bỏ
/// hẳn phần "Đã nhớ" (0/0 trông như lỗi, không phải tiến bộ). Dùng chung
/// Home (pin) và Kho (danh sách). "Đã nhớ" = nhãn UI của Q-08 (vision #6) nên X
/// gồm cả từ đã thấm.
func masteryLabel(_ collection: AppModel.CollectionOverview) -> String {
    guard collection.totalItems > 0 else { return "\(collection.totalItems) từ" }
    return "\(collection.totalItems) từ · Đã nhớ \(collection.masteredCount)/\(collection.totalItems)"
}

/// U9 ux-polish-r1: vòng tỉ lệ "đã nhớ" (Q-08) của một bộ — chỉ vẽ khi
/// `total > 0` (caller kiểm trước khi dùng). `absorbed` (FR-22, tập con của
/// `mastered`) vẽ thêm một cung đậm hơn chồng lên phần "đã thấm".
struct MasteryRing: View {
    let mastered: Int
    let total: Int
    var absorbed: Int = 0

    var body: some View {
        let ratio = total > 0 ? Double(mastered) / Double(total) : 0
        let absorbedRatio = total > 0 ? Double(min(absorbed, mastered)) / Double(total) : 0
        ZStack {
            Circle().stroke(Theme.surfaceStrong, lineWidth: 3)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(Color.accentColor.opacity(absorbed > 0 ? 0.45 : 1),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if absorbed > 0 {
                Circle()
                    .trim(from: 0, to: absorbedRatio)
                    .stroke(Theme.ok, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityElement()
        .accessibilityLabel(
            absorbed > 0
                ? "Đã nhớ \(mastered) trên \(total) từ, trong đó đã thấm \(absorbed)"
                : "Đã nhớ \(mastered) trên \(total) từ")
    }
}
