import ReadoKit
import SwiftUI

/// Bản đồ trí nhớ của một collection (engagement-r1 T6, thay thanh 4 màu ở header Hub): mỗi từ một chấm,
/// màu theo 4 mức (vision #6). Chạm hoặc kéo ngón tay trên lưới để chọn chấm — chấm nhỏ hơn 44pt nên
/// nhận chạm trên CẢ vùng lưới (chấm gần nhất), không phải từng chấm một. Chi tiết (từ, nghĩa, câu gốc)
/// hiện ngay dưới lưới — app chưa dùng popover ở đâu, `StreakCalendarView` cùng tiền lệ "dòng chi tiết".
/// VoiceOver chỉ đọc tổng theo mức (cha `progressCard` gộp); chi tiết từng từ vẫn ở danh sách từ bên dưới.
struct MasteryDotGrid: View {
    let dots: [VocabRepository.MasteryDot]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID: String?
    @State private var width: CGFloat = 0

    private let dotSize = Spacing.row
    private let gap = Spacing.xs

    private var columns: Int { max(1, Int((width + gap) / (dotSize + gap))) }
    private var rows: Int { (dots.count + columns - 1) / columns }
    private var gridHeight: CGFloat {
        CGFloat(rows) * dotSize + CGFloat(max(0, rows - 1)) * gap
    }
    private var selected: VocabRepository.MasteryDot? {
        dots.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            grid
            if let selected {
                detail(selected)
                    .revealTransition()
            }
        }
        // Chọn lại khi bộ đổi (đổi mức sau ôn, xoá từ) — id không còn thì bỏ chọn.
        .onChange(of: dots) { _, new in
            if let selectedID, !new.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(dotSize), spacing: gap), count: columns),
            alignment: .leading, spacing: gap
        ) {
            ForEach(dots) { dot in
                Circle()
                    .fill(dot.level.color)
                    .frame(width: dotSize, height: dotSize)
                    .overlay {
                        if dot.id == selectedID {
                            Circle().strokeBorder(Color.primary, lineWidth: 2)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            })
        .frame(height: max(gridHeight, dotSize), alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in select(at: value.location) })
    }

    /// Toạ độ → chỉ số chấm gần nhất (ô lưới chứa điểm chạm); ngoài lưới thì giữ nguyên.
    private func select(at point: CGPoint) {
        let cell = dotSize + gap
        let column = min(columns - 1, max(0, Int(point.x / cell)))
        let row = max(0, Int(point.y / cell))
        let index = row * columns + column
        guard dots.indices.contains(index), dots[index].id != selectedID else { return }
        Haptics.selection()
        Motion.run(reduceMotion: reduceMotion) { selectedID = dots[index].id }
    }

    private func detail(_ dot: VocabRepository.MasteryDot) -> some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("\(dot.term) · \(dot.level.title)")
                    .font(Typo.rowSubtitle.weight(.semibold))
                if !dot.meaningVI.isEmpty {
                    Text(dot.meaningVI)
                        .font(Typo.rowSubtitle)
                }
                if !dot.example.isEmpty {
                    Text(dot.example)
                        .font(Typo.meta.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button {
                Motion.run(reduceMotion: reduceMotion) { selectedID = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(Typo.meta.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Đóng chi tiết")
        }
    }
}
