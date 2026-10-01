import ReadoKit
import SwiftUI

/// T3a shell-chrome-r1 — thanh tab (kèm nút chụp) ẩn khi cuộn xuống, hiện lại
/// khi cuộn lên nhẹ (kiểu Facebook). Logic cuộn thuần (`ScrollChromeTracker`)
/// sống ở ReadoKit (testable) — file này chỉ còn state SwiftUI + modifier.

/// Sở hữu bởi `RootView` (`@State`), inject `.environment(chrome)` lên `TabView`.
/// Không nhét vào `AppModel` — B4 tách file đang là nợ riêng, không cộng dồn.
@Observable
final class ShellChrome {
    var isHidden = false

    func reveal() {
        isHidden = false
    }
}

private struct ScrollSample: Equatable {
    var offsetY: CGFloat
    var maxOffset: CGFloat
}

private struct ShellScrollChrome: ViewModifier {
    @Environment(ShellChrome.self) private var chrome: ShellChrome?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var tracker = ScrollChromeTracker()

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onScrollGeometryChange(for: ScrollSample.self) { geometry in
                    ScrollSample(
                        offsetY: geometry.contentOffset.y + geometry.contentInsets.top,
                        maxOffset: max(
                            0,
                            geometry.contentSize.height + geometry.contentInsets.top
                                + geometry.contentInsets.bottom - geometry.containerSize.height))
                } action: { _, sample in
                    guard let chrome, !voiceOver else { return }
                    if let hidden = tracker.update(offsetY: sample.offsetY, maxOffset: sample.maxOffset) {
                        chrome.isHidden = hidden
                    }
                }
                .onDisappear { chrome?.reveal() }
        } else {
            // D2 shell-chrome-r1: deployment target 17.0 không có
            // `onScrollGeometryChange` — thanh luôn hiện trên iOS 17.
            content
        }
    }
}

extension View {
    /// Gắn lên đúng `ScrollView`/`List` GỐC của màn (không lên container ngoài) —
    /// ẩn/hiện `ShellChrome` theo hướng cuộn. No-op khi không có `ShellChrome`
    /// trong environment (sheet không inject) hoặc VoiceOver đang bật.
    func shellScrollChrome() -> some View {
        modifier(ShellScrollChrome())
    }
}
