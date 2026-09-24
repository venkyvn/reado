import SwiftUI

struct ThemeDots: View {
    @Binding var accentId: String

    var body: some View {
        HStack(spacing: 14) {
            ForEach(ReadoTheme.accents, id: \.id) { accent in
                Button { accentId = accent.id } label: {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle().stroke(Color.white, lineWidth: accentId == accent.id ? 2 : 0)
                        }
                        .overlay {
                            Circle().stroke(Color.primary, lineWidth: accentId == accent.id ? 2 : 0)
                                .padding(-3)
                        }
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel(accent.name)
            }
            Spacer()
        }
    }
}
