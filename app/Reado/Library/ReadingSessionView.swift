import ReadoKit
import SwiftUI

/// FR-05 + FR-06 — đọc lại một phiên đọc song ngữ đã lưu (J2 hub).
/// ADR-007: song ngữ xen kẽ theo đoạn; ADR-030: MỘT nút nhỏ cố định dưới đáy
/// bật/tắt toàn bộ bản dịch (mặc định hiện) — nút đặt mặc định, chạm một đoạn
/// lật riêng đoạn đó. FR-06: ý chính thu gọn, chạm mở.
struct ReadingSessionView: View {
    let session: ReadingSession

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTranslations = true
    /// Đoạn đang đi ngược nút đáy. Bấm nút đáy xoá hết — nếu không, sau vài lần
    /// chạm lẻ thì nút không còn nói đúng trạng thái đang thấy trên màn hình.
    @State private var overriddenSegments: Set<Int> = []
    @State private var summaryExpanded = false
    // FR-22: từ đã có trong kho gạch chân; chạm mở popover + "Nhận ra".
    @State private var encounterMatcher = EncounterMatcher(lexicon: [])
    @State private var encounterSelection: EncounterSelection?
    // FR-05 (prompt-v6 T3): cụm EN↔VI đang chạm-sáng — tối đa một cụm sáng trên cả màn.
    @State private var activePhrase: ActivePhrase?
    @AppStorage("appTheme") private var appTheme = AppTheme.forest.rawValue

    private struct ActivePhrase: Equatable {
        let segmentIndex: Int
        let phraseIndex: Int
    }

    /// View tự vẽ nền tô sáng — đọc trực tiếp `@AppStorage` (MASTER §Màu ngoại lệ
    /// ux-redesign-r1 T10), không `Color.accentColor` trần.
    private var accent: Color { AppTheme(rawValue: appTheme)?.accent ?? Color.accentColor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                segmentsSection
                if let summary = session.summary, !summary.isEmpty {
                    summarySection(summary)
                }
            }
            .padding(Spacing.md)
        }
        .navigationTitle("Phiên đọc")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { translationToggle }
        // Phiên đọc push bên trong Hub (không vào ShellRoute) → tắt nút chụp trong thanh tab của
        // RootView khi đang đọc (port UI lab §10).
        .onAppear {
            model.shell.suppressFloatShutter = true
            encounterMatcher = model.makeEncounterMatcher()
        }
        .onDisappear { model.shell.suppressFloatShutter = false }
        .sheet(item: $encounterSelection) { EncounterSheet(selection: $0) }
    }

    // MARK: — Ý chính (FR-06, thu gọn mặc định)

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
        .padding(Spacing.md)
        .card()
    }

    // MARK: — Song ngữ (ADR-007)

    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            RevisitedWordsLine(
                count: encounterMatcher.matchedTermCount(in: session.segments.map(\.sourceEN)))
            ForEach(Array(session.segments.enumerated()), id: \.offset) { index, seg in
                // `onTapGesture` thay `Button`: Button nuốt chạm của link từ cũ (FR-22).
                let phraseSpans = PhraseLocator.spans(for: seg)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    EncounterText(
                        text: seg.sourceEN, matcher: encounterMatcher, phrases: phraseSpans,
                        activePhraseIndex: activePhrase?.segmentIndex == index
                            ? activePhrase?.phraseIndex : nil,
                        accent: accent, onSelect: { encounterSelection = $0 },
                        onPhraseTap: { togglePhrase(segment: index, phrase: $0) })
                        .font(.title3)
                    if isRevealed(index) {
                        PhraseHighlightText(
                            text: seg.translationVI, phrases: phraseSpans,
                            activePhraseIndex: activePhrase?.segmentIndex == index
                                ? activePhrase?.phraseIndex : nil,
                            accent: accent)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .revealTransition()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { toggleSegment(index) }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(isRevealed(index) ? seg.translationVI : "Bản dịch đang ẩn")
                .accessibilityHint(isRevealed(index) ? "Ẩn bản dịch đoạn này" : "Hiện bản dịch đoạn này")
                .accessibilityAction { toggleSegment(index) }
                .accessibilityActions {
                    // VoiceOver không chạm được link lồng trong Text theo span — action riêng mỗi cụm.
                    ForEach(phraseSpans, id: \.phraseIndex) { span in
                        Button("Cụm \(seg.sourceEN[span.en]): \(seg.translationVI[span.vi])") {
                            togglePhrase(segment: index, phrase: span.phraseIndex)
                        }
                    }
                }
            }
        }
    }

    private func isRevealed(_ index: Int) -> Bool {
        overriddenSegments.contains(index) ? !showTranslations : showTranslations
    }

    private func toggleSegment(_ index: Int) {
        Motion.run(reduceMotion: reduceMotion) {
            if overriddenSegments.contains(index) {
                overriddenSegments.remove(index)
            } else {
                overriddenSegments.insert(index)
            }
            // Ẩn bản dịch của đoạn đang có cụm sáng → tắt luôn highlight.
            if !isRevealed(index), activePhrase?.segmentIndex == index {
                activePhrase = nil
            }
        }
        Haptics.selection()
    }

    /// Lật riêng đoạn `index` sang hiện, KHÔNG đổi nếu đã hiện — không phát
    /// haptics (dùng khi chạm cụm cần tự hiện bản dịch).
    private func revealIfNeeded(_ index: Int) {
        guard !isRevealed(index) else { return }
        if overriddenSegments.contains(index) {
            overriddenSegments.remove(index)
        } else {
            overriddenSegments.insert(index)
        }
    }

    /// FR-05 (prompt-v6 T3) — chạm cụm EN: sáng/tắt cụm này, tự hiện bản dịch
    /// đoạn nếu đang ẩn. Tối đa một cụm sáng trên cả màn.
    private func togglePhrase(segment index: Int, phrase: Int) {
        let target = ActivePhrase(segmentIndex: index, phraseIndex: phrase)
        Motion.run(reduceMotion: reduceMotion) {
            if activePhrase == target {
                activePhrase = nil
            } else {
                activePhrase = target
                revealIfNeeded(index)
            }
        }
        Haptics.selection()
    }

    // MARK: — Nút cố định dưới đáy (ADR-030)

    private var translationToggle: some View {
        Button {
            Motion.run(reduceMotion: reduceMotion) {
                showTranslations.toggle()
                overriddenSegments.removeAll()
                activePhrase = nil
            }
        } label: {
            Label(
                showTranslations ? "Ẩn bản dịch" : "Hiện bản dịch",
                systemImage: showTranslations ? "eye.slash" : "eye")
                .contentTransition(.symbolEffect(.replace))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.row)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        // Màn push qua NavigationLink không thừa hưởng safeAreaInset của ShellTabBar
        // (cùng bug đã xác nhận ở StreakCalendarView) — tự cộng reservedHeight.
        .padding(.bottom, Spacing.sm + ShellTabBar.reservedHeight)
        .background(.background)
        .overlay(alignment: .top) { Divider() }
    }
}