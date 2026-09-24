import SwiftUI

enum ReadoTheme {
    static let forest = Color(red: 47 / 255, green: 107 / 255, blue: 79 / 255)
    static let ocean = Color(red: 43 / 255, green: 107 / 255, blue: 138 / 255)
    static let dusk = Color(red: 107 / 255, green: 79 / 255, blue: 114 / 255)
    static let ink = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let due = Color(red: 1, green: 159 / 255, blue: 10 / 255)
    static let again = Color(red: 1, green: 59 / 255, blue: 48 / 255)
    static let hard = Color(red: 1, green: 149 / 255, blue: 0)
    static let good = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
    static let easy = Color(red: 48 / 255, green: 176 / 255, blue: 199 / 255)

    static let accents: [(id: String, name: String, color: Color)] = [
        ("forest", "Rừng", forest),
        ("ocean", "Biển", ocean),
        ("dusk", "Chiều", dusk),
        ("ink", "Mực", ink),
    ]

    static func accent(_ id: String) -> Color {
        accents.first(where: { $0.id == id })?.color ?? forest
    }

    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)

    static func motion(_ reduce: Bool) -> Animation? {
        reduce ? nil : spring
    }
}

struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!enabled)
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

struct Chip: View {
    var title: String
    var on: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(on ? Color.accentColor : Color.primary.opacity(0.06))
                .foregroundStyle(on ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}
