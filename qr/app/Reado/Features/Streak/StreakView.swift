import SwiftUI

struct StreakView: View {
    @Environment(AppStore.self) private var store
    @Binding var tab: AppTab
    @State private var selected = ""

    var body: some View {
        let today = LearningDay.dayString(
            instant: store.clock.now,
            timeZone: store.settings.timeZone,
            cutoffHour: store.settings.dayCutoffHour
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    GroupedCard {
                        Text("Chuỗi hiện tại").font(.footnote).foregroundStyle(.secondary)
                        Text("\(store.streakStats.current) ngày")
                            .font(.title.bold())
                            .foregroundStyle(ReadoTheme.due)
                    }
                    GroupedCard {
                        Text("Dài nhất").font(.footnote).foregroundStyle(.secondary)
                        Text("\(store.streakStats.longest) ngày").font(.title.bold())
                    }
                }
                GroupedCard {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 18), spacing: 3) {
                        ForEach(store.streakDays) { day in
                            Button {
                                if day.date <= today { selected = day.date }
                            } label: {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(heat(day.reviews, future: day.date > today))
                                    .frame(height: 10)
                                    .overlay {
                                        if day.date == selected {
                                            RoundedRectangle(cornerRadius: 2).stroke(Color.primary, lineWidth: 1)
                                        }
                                    }
                            }
                            .disabled(day.date > today)
                            .accessibilityLabel(day.date)
                        }
                    }
                    Text(detail(selected.isEmpty ? today : selected, today: today))
                        .font(.footnote.weight(.semibold))
                        .padding(.top, 8)
                }
                Text("Ôn theo collection")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                if store.rankedCollections.isEmpty {
                    Text("Chưa ôn ngày nào — chụp trang hoặc học thẻ mới.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    let maxR = max(store.rankedCollections.first?.reviews ?? 1, 1)
                    ForEach(Array(store.rankedCollections.enumerated()), id: \.element.id) { index, row in
                        GroupedCard {
                            HStack {
                                Text("\(index == 0 ? "Nhiều nhất · " : "")\(row.name)").font(.headline)
                                Spacer()
                                Text("\(row.reviews) lần ôn").font(.footnote).foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * CGFloat(row.reviews) / CGFloat(maxR), height: 6)
                            }
                            .frame(height: 6)
                        }
                    }
                }
                Text("Ngày tính từ \(String(format: "%02d", store.settings.dayCutoffHour)):00 (giờ chuyển ngày).")
                    .font(.footnote).foregroundStyle(.secondary)
                if store.queue.dueToday > 0 {
                    PrimaryButton(title: "Ôn ngay") {
                        store.setBranch(.due)
                        tab = .review
                    }
                }
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if selected.isEmpty { selected = today } }
    }

    private func heat(_ reviews: Int, future: Bool) -> Color {
        if future { return Color.primary.opacity(0.05) }
        switch reviews {
        case 0: return Color.primary.opacity(0.08)
        case 1...2: return Color.accentColor.opacity(0.25)
        case 3...5: return Color.accentColor.opacity(0.45)
        case 6...9: return Color.accentColor.opacity(0.7)
        default: return Color.accentColor
        }
    }

    private func detail(_ iso: String, today: String) -> String {
        let day = store.streakDays.first { $0.date == iso }
        if iso > today { return "\(iso) — chưa tới" }
        var bits: [String] = []
        bits.append((day?.reviews ?? 0) > 0 ? "\(day!.reviews) thẻ ôn" : "chưa ôn")
        if let captures = day?.captures, captures > 0 { bits.append("\(captures) trang chụp") }
        return "\(iso) — \(bits.joined(separator: " · "))"
    }
}
