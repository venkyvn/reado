import ReadoKit
import SwiftUI

/// "Tuần qua" (engagement-r1 T8, ADR-068): kể lại tuần trước bằng vài câu ngắn từ số đo có thật — không phải
/// dashboard, không điểm/XP (vision #6). Đóng được; đóng rồi thì ẩn tới tuần sau (khoá `weekStart` ở nơi gắn).
/// View thuần: nhận `WeekStory` + closure, không đọc model. Nền `card()` đặc như hero.
struct WeekStoryCard: View {
    let story: WeekStory
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tuần qua")
                    .font(Typo.rowTitle)
                Spacer(minLength: Spacing.sm)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(Typo.meta.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Đóng câu chuyện tuần")
            }
            .padding(.bottom, -Spacing.sm)
            ForEach(story.lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .card()
        .accessibilityElement(children: .contain)
    }
}

#Preview("WeekStoryCard") {
    WeekStoryCard(
        story: WeekStory(
            weekStart: "2026-09-13T21:00:00Z", wordsSaved: 12, wordsReencountered: 4,
            recognizedCount: 3, reviewDays: 5, topTerm: "routine"),
        onDismiss: {}
    )
    .padding(Spacing.md)
}
