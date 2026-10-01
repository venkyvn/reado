import SwiftUI

/// Thanh tab nổi — thay thanh native (cao cố định ~49pt). Một hàng gồm capsule 2 tab + nút chụp
/// tròn cùng chiều cao (ux-redesign-r1 T1b, kiểu nút Search tách của iOS 26). Gắn qua
/// `safeAreaInset` trên `TabView` nên theo mọi màn push, không đè nội dung.
struct ShellTabBar: View {
    /// Chiều cao capsule = đường kính nút chụp (không gồm padding ngoài / home indicator).
    static let height: CGFloat = 64
    /// Padding dưới thanh, phía trên home indicator.
    static let outerBottomPadding: CGFloat = 8
    /// Khe cần chừa ở CUỐI trang cho màn không có `safeAreaInset` xuyên qua `TabView` — nội dung
    /// tự áp `.safeAreaPadding` bằng số này để hàng nút cuối không chui xuống dưới thanh.
    /// Hiện không màn nào cần (cover ôn thay tab Ôn, T1a); giữ lại làm hằng số đo của thanh.
    // TODO(đo ảnh): đo lại sau khi nút chụp vào hàng — nghi vẫn đúng vì nút cao bằng capsule.
    static let reservedHeight = height + outerBottomPadding + Spacing.sm

    @Binding var selection: AppTab
    var onReselect: (AppTab) -> Void = { _ in }
    /// T3a shell-chrome-r1 — true khi vừa cuộn xuống, ẩn cả hàng (tab + nút chụp) khỏi màn hình.
    var isHidden: Bool = false
    /// Nút chụp chỉ hiện trên "bề mặt chụp" (root hai tab + Hub) — vào sâu (lịch streak, cài đặt,
    /// dữ liệu, phiên đọc) thì ẩn, capsule giãn ra chiếm cả hàng.
    var showsCapture: Bool = true
    var onCapture: () -> Void = {}
    /// Tab có chấm báo (Q-e: chấm khi có thẻ đến hạn, không ghi số — số đỏ tạo áp lực, lệch
    /// Retention "không cần học hết").
    var badgedTabs: Set<AppTab> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var pillNamespace

    var body: some View {
        // TODO(đo ảnh): khe giữa capsule và nút chụp (đang Spacing.sm) — xem ảnh iPhone nhỏ + AX-XL
        // rồi chỉnh cho khớp nút Search tách của iOS 26.
        HStack(spacing: Spacing.sm) {
            tabCapsule
            if showsCapture {
                ShellCaptureButton(action: onCapture)
                    // Scale nhẹ: nút tròn nở ra tại chỗ, không trượt như nội dung.
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: showsCapture)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Self.outerBottomPadding)
        // D3 shell-chrome-r1: KHÔNG đổi frame/padding khi ẩn — safe area (dùng bởi
        // HomeTabView `.safeAreaPadding`) phải đứng yên, chỉ trượt + mờ cả hàng.
        // +40 phủ home indicator (~34pt), không cần GeometryReader.
        .offset(y: isHidden && !reduceMotion ? Self.height + Self.outerBottomPadding + 40 : 0)
        .opacity(isHidden ? 0 : 1)
        .allowsHitTesting(!isHidden)
        .accessibilityHidden(isHidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Điều hướng")
    }

    private var tabCapsule: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(Spacing.xs)
        .frame(height: Self.height)
        // ux-polish-r1 T4: Liquid Glass (iOS 26+), fallback material dưới đó.
        .chromeGlass(in: Capsule())
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let selected = selection == tab
        let badged = badgedTabs.contains(tab)
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
                    tabIcon(tab, selected: selected, badged: badged)
                } else {
                    VStack(spacing: Spacing.tight) {
                        tabIcon(tab, selected: selected, badged: badged)
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
        .accessibilityValue(badged ? "Có thẻ đến hạn" : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func tabIcon(_ tab: AppTab, selected: Bool, badged: Bool) -> some View {
        Image(systemName: selected ? tab.selectedIcon : tab.icon)
            .font(.title2)
            .symbolEffect(.bounce, value: reduceMotion ? false : selected)
            .overlay(alignment: .topTrailing) {
                if badged {
                    Circle()
                        .fill(Theme.due)
                        .frame(width: Spacing.sm, height: Spacing.sm)
                        .offset(x: Spacing.xs, y: -Spacing.tight)
                        .accessibilityHidden(true)
                }
            }
    }
}
