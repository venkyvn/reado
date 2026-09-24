import ReadoKit
import SwiftUI

/// FR-05 + FR-06 — đọc lại một phiên đọc song ngữ đã lưu (J2 hub).
/// ADR-007: song ngữ xen kẽ theo đoạn; ADR-030: MỘT nút nhỏ cố định dưới đáy
/// bật/tắt toàn bộ bản dịch (mặc định hiện). FR-06: ý chính thu gọn, chạm mở.
struct ReadingSessionView: View {
    let session: ReadingSession

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        // Phiên đọc push bên trong Hub (không vào ShellRoute) → tắt shutter nổi
        // FloatShutter của RootView khi đang đọc (port UI lab §10).
        .onAppear { model.suppressFloatShutter = true }
        .onDisappear { model.suppressFloatShutter = false }
    }

    // MARK: — Ý chính (FR-06, thu gọn mặc định)

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Motion.run(reduceMotion: reduceMotion) {
                    summaryExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Ý chính")
                        .font(.headline)
                    Spacer()
                    Image(systemName: summaryExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)

            if summaryExpanded {
                Text(summary)
                    .font(.body)
                    .revealTransition()
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
                            .revealTransition()
                    }
                }
            }
        }
    }

    // MARK: — Nút cố định dưới đáy (ADR-030)

    private var translationToggle: some View {
        Button {
            Motion.run(reduceMotion: reduceMotion) {
                showTranslations.toggle()
            }
        } label: {
            Label(
                showTranslations ? "Ẩn bản dịch" : "Hiện bản dịch",
                systemImage: showTranslations ? "eye.slash" : "eye")
                .contentTransition(.symbolEffect(.replace))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.background)
        .overlay(alignment: .top) { Divider() }
    }
}