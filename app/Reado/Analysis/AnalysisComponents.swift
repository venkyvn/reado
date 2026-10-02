import SwiftUI
import ReadoKit

// Tách từ AnalysisView.swift (repo-hygiene-r1 B3).

/// Đoạn gốc song ngữ (port UI lab §5.3, ADR-030) — EN luôn hiện; VI hiện sẵn theo
/// `isRevealed` (nút đáy của `AnalysisView` bật/tắt toàn bộ, chạm đoạn lật riêng).
/// FR-22: từ đã có trong kho gạch chân, chạm mở popover. FR-05 (prompt-v6 T3):
/// cụm EN↔VI chạm-sáng — chạm cụm EN thì cụm VI tương ứng tô nền, tự hiện bản
/// dịch nếu đang ẩn. Chạm ngoài từ/cụm vẫn lật bản dịch — dùng `onTapGesture`
/// thay `Button` vì `Button` nuốt chạm của link.
struct SegmentBlock: View {
    let segment: PageAnalysis.Segment
    let isRevealed: Bool
    let matcher: EncounterMatcher
    let activePhraseIndex: Int?
    let accent: Color
    let onSelect: (EncounterSelection) -> Void
    let onPhraseTap: (Int) -> Void
    let onTap: () -> Void

    private var phraseSpans: [PhraseLocator.PhraseSpan] { PhraseLocator.spans(for: segment) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            EncounterText(
                text: segment.sourceEN, matcher: matcher, phrases: phraseSpans,
                activePhraseIndex: activePhraseIndex, accent: accent, onSelect: onSelect,
                onPhraseTap: onPhraseTap)
                .font(.callout)
                .foregroundStyle(.primary)
            if isRevealed {
                PhraseHighlightText(
                    text: segment.translationVI, phrases: phraseSpans,
                    activePhraseIndex: activePhraseIndex, accent: accent)
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
        .accessibilityActions {
            // VoiceOver không chạm được link lồng trong Text theo span — thêm action
            // riêng mỗi cụm, tên nói rõ cặp EN/VI để không cần nhìn thấy gạch chân.
            ForEach(phraseSpans, id: \.phraseIndex) { span in
                Button("Cụm \(segment.sourceEN[span.en]): \(segment.translationVI[span.vi])") {
                    onPhraseTap(span.phraseIndex)
                }
            }
        }
    }
}

/// "Ý chính" (FR-06) thu gọn mặc định, chạm mở — cùng cơ chế với phần Ý chính của
/// `ReadingSessionView` (ux-redesign-r1 T5b).
struct SummaryCard: View {
    let summary: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                Motion.run(reduceMotion: reduceMotion) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Ý chính")
                        .font(Typo.rowTitle)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(summary)
                    .font(.body)
                    .revealTransition()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .card()
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
