import SwiftUI
import UIKit

// visual-polish-r1 (docs/plans/visual-polish-r1.md): thang khoảng cách / bo góc / vai trò
// chữ + vài component dùng chung. Màu semantic vẫn ở `Theme` (ReadoApp.swift).
// View không viết số lẻ 3/6/7/10/14/20/28/36 — đi qua token ở đây.

/// Thang khoảng cách (MASTER.md §Spacing + 12 cho khe row của iOS).
enum Spacing {
    /// Giữa các dòng chữ trong một khối.
    static let tight: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    /// Icon ↔ text trong row, khe giữa các nút.
    static let row: CGFloat = 12
    /// Padding chuẩn, inset ngang.
    static let md: CGFloat = 16
    /// Giữa các khối trong ScrollView.
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Bo góc — luôn đi với `style: .continuous`.
enum Radius {
    /// Ô nhập, icon tile.
    static let sm: CGFloat = 8
    /// Card, nút lớn, banner (= mặc định của `card()`).
    static let md: CGFloat = 12
    /// Card Ôn tập.
    static let lg: CGFloat = 20
}

/// Vai trò chữ — map về text style hệ thống nên giữ Dynamic Type.
enum Typo {
    static let rowTitle = Font.headline
    /// Kèm `.secondary`.
    static let rowSubtitle = Font.subheadline
    /// Chữ đọc phụ, kèm `.secondary`. Thay `.caption` cho chữ đọc.
    static let meta = Font.footnote
    /// `.caption` chỉ còn dùng trong pill và nhãn nhỏ.
    static let pill = Font.caption.weight(.semibold)
    static let cardTerm = Font.largeTitle.bold()
    static let cardAnswer = Font.title2.weight(.semibold)
    static let metric = Font.title2.bold().monospacedDigit()
    /// Symbol trang trí lớn (màn xong, trạng thái rỗng).
    static let heroSymbol = Font.system(size: 56)
}

extension View {
    /// Bóng cho card nổi (card Ôn). Đặt ngoài `clipShape` để không bị cắt.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

/// Nhãn nhỏ dạng viên thuốc — thay mọi capsule copy tay (due, CEFR, POS, trạng thái).
/// Chữ luôn `.primary`: nền tint nhạt + chữ màu cam/xanh không đạt contrast 4.5:1.
struct Pill: View {
    enum Tone {
        case neutral, due, level, ok, warn, danger, accent

        var color: Color {
            switch self {
            case .neutral: Theme.surfaceStrong
            case .due: Theme.due
            case .level: Theme.level
            case .ok: Theme.ok
            case .warn: Theme.warn
            case .danger: Theme.danger
            case .accent: Color.accentColor
            }
        }

        /// Nền neutral đã là fill hệ thống — không nhân thêm alpha.
        var fillOpacity: Double { self == .neutral ? 1 : 0.15 }
    }

    let text: String
    var systemImage: String?
    var tone: Tone = .neutral

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tone == .neutral ? Color.secondary : tone.color)
                    .accessibilityHidden(true)
            }
            Text(text)
        }
        .font(Typo.pill)
        .monospacedDigit()
        .foregroundStyle(.primary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.tight)
        .background(tone.color.opacity(tone.fillOpacity), in: Capsule())
    }
}

/// Ô icon đầu row (Home, Kho) — cùng cỡ để mép trái các row thẳng hàng.
struct IconTile: View {
    static let size: CGFloat = 32

    /// Accent dark mode là bản nhạt (AppTheme) → symbol trắng chìm; đổi sang mực đậm.
    private static let symbolColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : .white
    })

    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(Self.symbolColor)
            .frame(width: Self.size, height: Self.size)
            .background(tint, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Khối nội dung một từ — dùng chung cho row Kho và row duyệt từ (Analysis) để hai nơi
/// cùng thứ tự dòng: term (+POS +CEFR) → nghĩa → IPA → ví dụ.
/// Nhận giá trị thuần, không nhận model — nơi gọi tự map.
struct VocabSummary: View {
    let term: String
    var pos: String = ""
    var cefr: String = ""
    var ipa: String = ""
    let meaning: String
    var example: String = ""

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Nghĩa và ví dụ tối đa 2 dòng; Dynamic Type cỡ lớn thì không cắt.
    private var lineLimit: Int? { dynamicTypeSize.isAccessibilitySize ? nil : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) {
                    Text(term).font(Typo.rowTitle)
                    pills
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(term).font(Typo.rowTitle)
                    pills
                }
            }
            if !meaning.isEmpty {
                Text(meaning)
                    .font(Typo.rowSubtitle)
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)
            }
            if !ipa.isEmpty {
                Text("/\(ipa)/")
                    .font(Typo.meta)
                    .foregroundStyle(.secondary)
            }
            if !example.isEmpty {
                Text(example)
                    .font(Typo.meta.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(lineLimit)
            }
        }
    }

    @ViewBuilder
    private var pills: some View {
        HStack(spacing: Spacing.xs) {
            if !pos.isEmpty { Pill(text: pos, tone: .neutral) }
            if !cefr.isEmpty { Pill(text: cefr.uppercased(), tone: .level) }
        }
    }
}

#Preview("Pill / IconTile") {
    VStack(alignment: .leading, spacing: Spacing.row) {
        HStack {
            Pill(text: "noun")
            Pill(text: "B2", tone: .level)
            Pill(text: "12", systemImage: "flame.fill", tone: .due)
            Pill(text: "Đã kiểm", systemImage: "checkmark.circle.fill", tone: .ok)
            Pill(text: "Trùng", systemImage: "exclamationmark.triangle.fill", tone: .warn)
        }
        HStack {
            IconTile(systemImage: "rectangle.stack.fill")
            IconTile(systemImage: "tray.fill")
            IconTile(systemImage: "flame.fill", tint: Theme.due)
        }
    }
    .padding(Spacing.md)
}

#Preview("VocabSummary") {
    List {
        VocabSummary(
            term: "keystone", pos: "noun", cefr: "c1", ipa: "ˈkiːstəʊn",
            meaning: "nền tảng then chốt",
            example: "Sleep is the keystone of every good routine.")
        VocabSummary(term: "compound", pos: "verb", meaning: "làm trầm trọng thêm; cộng dồn")
    }
}
