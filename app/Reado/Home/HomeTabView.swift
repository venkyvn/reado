import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Home tab — tổng quan: Ôn hôm nay → kho tạm (shortcut) → Streak → Đang đọc.
/// Không còn CTA "Chụp trang" to dưới đáy (đã chuyển thành shutter nổi).
struct HomeTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onReview: () -> Void
    let onSettings: () -> Void
    let onData: () -> Void
    let onCapture: () -> Void

    var body: some View {
        Group {
            if model.database == nil, model.failure == nil {
                ProgressView("Đang mở kho…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let failure = model.failure {
                ContentUnavailableView {
                    Label("Không mở được kho", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(failure)
                }
            } else {
                homeList
            }
        }
        .navigationTitle("Reado")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onSettings) {
                    Label("Cài đặt", systemImage: "gearshape")
                }
                .accessibilityLabel("Cài đặt")
            }
            // J-R1-D: cửa Dữ liệu giữ icon tray trên Home (không tab thứ 4).
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onData) {
                    Label("Dữ liệu", systemImage: "externaldrive")
                }
                .accessibilityLabel("Dữ liệu")
            }
        }
    }

    private var homeList: some View {
        List {
            OnboardingChecklistSection(onOpenSettings: onSettings, onCapture: onCapture)
            Section("Hôm nay") {
                dailyProgressRows
                inboxRow
                streakRow
            }
            homePinRows
        }
        .refreshable { model.reloadOverview() }
        .shellScrollChrome()
    }

    // FR-14: tổng quan Daily Progress — "sẽ ôn hôm nay" theo hạn mức (FR-11),
    // tồn đọng RIÊNG, streak theo giờ chuyển ngày. Không tổng due_at thô.
    @ViewBuilder
    private var dailyProgressRows: some View {
        if let progress = model.dailyProgress {
            if progress.dueToday > 0 {
                Button {
                    onReview()
                } label: {
                    HStack(spacing: Spacing.row) {
                        IconTile(systemImage: "brain.head.profile")
                        VStack(alignment: .leading, spacing: Spacing.tight) {
                            Text("Ôn tập hôm nay")
                                .font(Typo.rowTitle)
                                .foregroundStyle(.primary)
                            Text("\(progress.dueToday) thẻ sẽ ôn")
                                .font(Typo.rowSubtitle)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        Spacer()
                        // Nút hành động (đổi tab), không phải push → không vẽ chevron điều hướng.
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                    .animation(reduceMotion ? nil : Motion.reveal, value: progress.dueToday)
                }
                // Plain: Button trong List tô cả label theo tint → chữ mờ xanh, lệch các row khác.
                .buttonStyle(.plain)
            } else if progress.backlog > 0 {
                // FR-14: hết hạn mức hôm nay — tồn đọng hiện RIÊNG, không CTA giả.
                Label(
                    "Đã hết hạn mức hôm nay · \(progress.backlog) thẻ mới đang chờ",
                    systemImage: "hourglass")
                    .font(Typo.rowSubtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Kho tạm luôn hiện trên Home (kể cả khi `dailyProgress` nil) — mở thẳng hub
    /// kho tạm. Không nằm trong `homePins` và không tính vào k/5 (không nút ghim).
    @ViewBuilder
    private var inboxRow: some View {
        if let inbox = model.collections.first(where: \.isDefault) {
            NavigationLink(value: ShellRoute.hub(inbox.id)) {
                HStack(spacing: Spacing.row) {
                    IconTile(systemImage: "tray.fill")
                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        Text(inbox.name)
                            .font(Typo.rowTitle)
                        Text("\(inbox.totalItems) từ · trang chưa phân loại")
                            .font(Typo.rowSubtitle)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if inbox.dueNow > 0 {
                        Pill(text: "\(inbox.dueNow)", tone: .due)
                    }
                }
            }
        }
    }

    /// Ô Streak bấm được → Lịch streak (heatmap 18 tuần). Tách khỏi
    /// `dailyProgressRows` để đứng sau hàng kho tạm; vẫn cần `dailyProgress`
    /// nên ẩn khi nil. Ý 7 motivation-r1: khi streak > 0 và hôm nay CHƯA ôn thẻ
    /// nào, dòng phụ đổi thành lời nhắc giữ streak (gộp từ row nhắc riêng cũ);
    /// đã ôn hoặc streak = 0 thì hiện số trang đã phân tích (không nhắc người mới).
    @ViewBuilder
    private var streakRow: some View {
        if let progress = model.dailyProgress {
            NavigationLink(value: ShellRoute.streak) {
                HStack(spacing: Spacing.row) {
                    IconTile(systemImage: "flame.fill", tint: Theme.due)
                        .symbolEffect(.bounce, value: reduceMotion ? 0 : progress.streak)
                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        Text("\(progress.streak) ngày ôn liên tục")
                            .font(Typo.rowTitle)
                            .contentTransition(.numericText())
                        Text(
                            progress.streak > 0 && !progress.reviewedToday
                                ? "Hôm nay chưa ôn — 1 thẻ là giữ streak"
                                : "\(progress.pagesAnalyzed) trang đã phân tích")
                            .font(Typo.rowSubtitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(reduceMotion ? nil : Motion.reveal, value: progress.streak)
            }
        }
    }

    // Pin Home — "Đang đọc" tối đa 5 (port UI lab), mở thẳng Collection Hub.
    @ViewBuilder
    private var homePinRows: some View {
        if !model.homePins.isEmpty {
            Section("Đang đọc · \(model.homePins.count)/5") {
                ForEach(model.homePins) { collection in
                    NavigationLink(value: ShellRoute.hub(collection.id)) {
                        HStack(spacing: Spacing.row) {
                            // Cùng bề rộng IconTile để mép trái các row thẳng hàng.
                            Image(systemName: "pin.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: IconTile.size)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.tight) {
                                Text(collection.name)
                                    .font(Typo.rowTitle)
                                Text(masteryLabel(collection))
                                    .font(Typo.rowSubtitle)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if collection.totalItems > 0 {
                                MasteryRing(mastered: collection.masteredCount, total: collection.totalItems)
                            }
                            if collection.dueNow > 0 {
                                Pill(text: "\(collection.dueNow)", tone: .due)
                            }
                        }
                    }
                }
            }
        }
    }
}
