import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Nút chụp nổi — chỉ nút này dùng hình shutter tròn (máy ảnh thật = hệ thống).
struct FloatShutter: View {
    static let size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        // ux-polish-r1 T4: Liquid Glass interactive (iOS 26+) — glass tự phản
        // hồi khi nhấn, bỏ ShutterPressStyle thủ công. iOS < 26 giữ nguyên.
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: Self.size, height: Self.size)
            }
            .glassEffect(.regular.tint(Color.accentColor).interactive(), in: Circle())
            .accessibilityLabel("Chụp trang")
        } else {
            Button(action: action) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: Self.size, height: Self.size)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ShutterPressStyle())
            .accessibilityLabel("Chụp trang")
        }
    }
}

/// port UI lab §9: shutter thu nhỏ nhẹ khi nhấn, bật trở lại bằng spring.
private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(
                .spring(response: 0.32, dampingFraction: 0.86),
                value: configuration.isPressed)
    }
}
