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
        HStack(spacing: Spacing.xs) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(Spacing.xs)
        .frame(height: Self.height)
        // ux-polish-r1 T4: Liquid Glass (iOS 26+), fallback material dưới đó.
        .chromeGlass(in: Capsule())
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
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
                        .symbolEffect(.bounce, value: reduceMotion ? false : selected)
                } else {
                    VStack(spacing: Spacing.tight) {
                        Image(systemName: selected ? tab.selectedIcon : tab.icon)
                            .font(.title2)
                            .symbolEffect(.bounce, value: reduceMotion ? false : selected)
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
