import SwiftUI
import UIKit

struct FloatShutter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 4)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color(.systemBackground)))
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 48, height: 48)
            }
            .scaleEffect(pressed ? 0.92 : 1)
            .animation(ReadoTheme.motion(reduceMotion), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel("Chụp")
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}
