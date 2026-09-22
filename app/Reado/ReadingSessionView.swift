import ReadoKit
import SwiftUI

/// FR-05 + FR-06 — đọc lại một phiên đọc song ngữ đã lưu (J2 hub).
/// ADR-007: song ngữ xen kẽ theo đoạn; ADR-030: MỘT nút nhỏ cố định dưới đáy
/// bật/tắt toàn bộ bản dịch (mặc định hiện). FR-06: ý chính thu gọn, chạm mở.
struct ReadingSessionView: View {
    let session: ReadingSession

    @State private var showTranslations = true
    @State private var summaryExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                segmentsSection
                if let summary = session.summary, !summary.isEmpty {
                    summarySection(summary)
                }
            }
            .padding()
        }
        .navigationTitle("Phiên đọc")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { translationToggle }
    }

    // MARK: — Ý chính (FR-06, thu gọn mặc định)

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    summaryExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Ý chính")
                        .font(.headline)
                    Spacer()
                    Image(systemName: summaryExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if summaryExpanded {
                Text(summary)
                    .font(.body)
            }
        }
        .padding()
        .card()
    }

    // MARK: — Song ngữ (ADR-007)

    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(session.segments.enumerated()), id: \.offset) { _, seg in
                VStack(alignment: .leading, spacing: 4) {
                    Text(seg.sourceEN)
                        .font(.title3)
                    if showTranslations {
                        Text(seg.translationVI)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: — Nút cố định dưới đáy (ADR-030)

    private var translationToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTranslations.toggle()
            }
        } label: {
            Label(
                showTranslations ? "Ẩn bản dịch" : "Hiện bản dịch",
                systemImage: showTranslations ? "eye.slash" : "eye")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }
}