import ReadoKit
import SwiftUI

// Tách từ RootView.swift (repo-hygiene-r1 B3).

/// Home tab — tổng quan: Ôn hôm nay → kho tạm (shortcut) → Streak → Đang đọc.
/// Không còn CTA "Chụp trang" to dưới đáy (đã chuyển thành shutter nổi).
struct HomeTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// ux-redesign-r1 T1a: "Ôn tập hôm nay" / "Ôn thêm" mở phiên ôn toàn màn qua `RootView`,
    /// không còn đổi sang tab Ôn.
    @Environment(\.startReview) private var startReview
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
                reencounterRow
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
                    // Phạm vi mặc định đã lưu (Ôn nhanh ở Kho) — như tab Ôn cũ vẫn đọc.
                    startReview(ReviewRequest(scope: model.reviewScopeDefault.scopeSet, mode: .srs))
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
                        // Nút hành động (mở phiên ôn), không phải push → không vẽ chevron điều hướng.
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                    .animation(reduceMotion ? nil : Motion.reveal, value: progress.dueToday)
                }
                // Plain: Button trong List tô cả label theo tint → chữ mờ xanh, lệch các row khác.
                .buttonStyle(.plain)
            } else if model.homeExtraAvailableCount > 0 {
                // extra-review-r1 B2: xong phần hôm nay nhưng vẫn còn từ mới/ôn
                // sớm toàn kho — CTA "Ôn thêm" thay cho nhãn trung tính cũ.
                Button {
                    startReview(ReviewRequest(scope: model.reviewScopeDefault.scopeSet, mode: .extra))
                } label: {
                    HStack(spacing: Spacing.row) {
                        IconTile(systemImage: "arrow.clockwise")
                        VStack(alignment: .leading, spacing: Spacing.tight) {
                            Text("Xong phần hôm nay")
                                .font(Typo.rowTitle)
                                .foregroundStyle(.primary)
                            Text(
                                "Ôn thêm "
                                    + "\(min(model.homeExtraAvailableCount, ReviewQueue.extraBatchSize))"
                                    + " thẻ")
                                .font(Typo.rowSubtitle)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            } else if progress.backlog > 0 {
                // FR-14: hết hạn mức hôm nay, không còn gì Ôn thêm được — không
                // CTA giả. new-order-r1: bỏ con số tồn (vision Retention "không
                // cần học hết"); FR-14 cho phép không hiện tồn.
                Label("Xong phần hôm nay", systemImage: "checkmark.circle.fill")
                    .font(Typo.rowSubtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// FR-22: "Gặp lại N từ tuần này" — số từ khác nhau được gặp lại khi đọc
    /// (7 ngày gần nhất). Ẩn khi 0 (0 trông như lỗi, không phải tiến bộ).
    @ViewBuilder
    private var reencounterRow: some View {
        if model.reencounteredThisWeek > 0 {
            HStack(spacing: Spacing.row) {
                IconTile(systemImage: "eye", tint: Theme.ok)
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text("Gặp lại \(model.reencounteredThisWeek) từ tuần này")
                        .font(Typo.rowTitle)
                        .contentTransition(.numericText())
                    Text("Từ đã lưu xuất hiện lại khi bạn đọc")
                        .font(Typo.rowSubtitle)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
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
                                MasteryRing(
                                    mastered: collection.masteredCount,
                                    total: collection.totalItems,
                                    absorbed: collection.absorbedCount)
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
