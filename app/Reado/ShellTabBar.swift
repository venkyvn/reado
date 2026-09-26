import SwiftUI

/// Thanh tab capsule nổi — thay thanh native (cao cố định ~49pt). Gắn qua
/// `safeAreaInset` trên `TabView` nên theo mọi màn push, không đè nội dung.
struct ShellTabBar: View {
    /// Chiều cao capsule (không gồm padding ngoài / home indicator).
    static let height: CGFloat = 64
    /// Padding dưới capsule, phía trên home indicator.
    static let outerBottomPadding: CGFloat = 8
    /// Khe giữa mép trên capsule và FloatShutter. RootView cộng đúng số này lên
    /// trên `.safeAreaPadding(.bottom)` — không cộng thêm `height`/
    /// `outerBottomPadding` (đo bằng screenshot: cộng thêm gây nút cao hơn capsule
    /// ~100pt, vì safe area môi trường ở đó đã gồm sẵn cả ShellTabBar).
    static let shutterGap: CGFloat = 12

    @Binding var selection: AppTab
    var onReselect: (AppTab) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .frame(height: Self.height)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Theme.surfaceStrong, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, Self.outerBottomPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Điều hướng")
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return Button {
            Haptics.selection()
            if selected {
                onReselect(tab)
            } else {
                Motion.run(reduceMotion: reduceMotion) {
                    selection = tab
                }
            }
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: selected ? tab.selectedIcon : tab.icon)
                        .font(.title2)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: selected ? tab.selectedIcon : tab.icon)
                            .font(.title2)
                        Text(tab.title)
                            .font(.caption2)
                    }
                }
            }
            .foregroundStyle(selected ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background {
                if selected {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.14))
                        .matchedGeometryEffect(id: "shell-tab-pill", in: pillNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
