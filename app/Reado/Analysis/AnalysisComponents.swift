import SwiftUI
import ReadoKit

// Tách từ AnalysisView.swift (repo-hygiene-r1 B3).

/// Đoạn gốc song ngữ (port UI lab §5.3) — EN luôn; VI mờ tới khi tap mở.
/// FR-22: từ đã có trong kho gạch chân, chạm mở popover. Chạm ngoài từ vẫn lật
/// bản dịch — dùng `onTapGesture` thay `Button` vì `Button` nuốt chạm của link.
struct SegmentBlock: View {
    let segment: PageAnalysis.Segment
    let isRevealed: Bool
    let matcher: EncounterMatcher
    let onSelect: (EncounterSelection) -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            EncounterText(text: segment.sourceEN, matcher: matcher, onSelect: onSelect)
                .font(.callout)
                .foregroundStyle(.primary)
            if isRevealed {
                Text(segment.translationVI)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .revealTransition()
            } else {
                Label("Dịch", systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.tight)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: isRevealed ? "Ẩn bản dịch" : "Hiện bản dịch", onTap)
    }
}

/// Chip trạng thái xác minh (FR-02) — unverified đỏ (ADR-008), suspect cam.
struct VerificationBadge: View {
    let status: PageAnalysis.VerificationStatus

    var body: some View {
        switch status {
        case .verified:
            Pill(text: "Đã kiểm", systemImage: "checkmark.circle.fill", tone: .ok)
        case .suspect:
            Pill(text: "Cần xem", systemImage: "exclamationmark.triangle.fill", tone: .warn)
        case .unverified:
            Pill(text: "Chưa xác minh", systemImage: "questionmark.circle", tone: .danger)
        }
    }
}

/// U7 ux-polish-r1: placeholder hình dạng card duyệt trong lúc chờ agent —
/// đỡ màn trắng đứng im, không đoán trước nội dung thật. Nhấp nháy nhẹ, tôn
/// Reduce Motion (đứng yên).
struct AnalysisSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in row }
        }
        .opacity(dim ? 0.45 : 1)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                dim = true
            }
        }
    }

    // Hình dạng skeleton (frame/radius/khe) mô phỏng row thật — ngoại lệ của thang Spacing/Radius.
    private var row: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.surfaceStrong)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceStrong)
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceStrong)
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
            }
        }
    }
}
