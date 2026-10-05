import ReadoKit
import SwiftUI

/// ADR-038: màn "Xong hôm nay" (ý 1+2 motivation-r1) — ăn mừng TIẾN BỘ ĐO ĐƯỢC
/// (thẻ ôn, % không-Again, từ vừa thuộc Q-08, streak FR-14). Không điểm/XP,
/// không leaderboard (NG-04). Chỉ hiện khi phiên vừa chấm hết ít nhất 1 thẻ
/// (`tally.reviewed > 0`) — vào hàng đợi đã hết sẵn từ đầu thì giữ màn cũ
/// (`ReviewQueueView.doneView`), không ăn mừng cái mình không làm.
struct SessionDoneView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tally: SessionTally
    let streak: Int
    /// extra-review-r1: số thẻ Ôn thêm còn lấy được trong phạm vi hiện tại
    /// (`ReviewQueue.extraAvailableCount`, CHƯA kẹp — view tự kẹp ở
    /// `ReviewQueue.extraBatchSize` khi hiện số). 0 → ẩn CTA.
    let extraAvailable: Int
    /// engagement-r1 T5: tiêu đề + CTA "Ôn tiếp (còn N)" của phiên ôn nhanh. Mặc định = màn cũ.
    var title = "Xong hôm nay"
    var continueCount = 0
    var onContinue: (() -> Void)? = nil
    let onExtra: () -> Void
    /// Đóng cover phiên ôn — về đúng chỗ đã mở nó, không phải "Về Home".
    let onDone: () -> Void

    /// Giới hạn hiển thị — danh sách dài quá thì rối, không phải bảng thành tích.
    private static let maxMasteredShown = 5

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : Motion.reveal, value: appeared)
                statsGrid
                masteredSection
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : Motion.reveal.delay(0.16), value: appeared)
                Spacer(minLength: Spacing.row)
                if let onContinue, continueCount > 0 {
                    Button(action: onContinue) {
                        Text("Ôn tiếp (còn \(continueCount))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else if extraAvailable > 0 {
                    Button(action: onExtra) {
                        Text("Ôn thêm \(min(extraAvailable, ReviewQueue.extraBatchSize)) thẻ")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                Button(action: onDone) {
                    Text("Xong").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(Spacing.md)
        }
        .background { doneBackground.ignoresSafeArea() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Motion.run(reduceMotion: reduceMotion) { appeared = true }
        }
    }

    /// ux-polish-r1 T4: nền mesh nhẹ (iOS 18+) chỉ cho màn ăn mừng — vẫn số
    /// thật (ADR-038), không đổi màu nút grade, không confetti.
    @ViewBuilder
    private var doneBackground: some View {
        if #available(iOS 18, *) {
            MeshGradient(
                width: 2, height: 2,
                points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                colors: [
                    Color.accentColor.opacity(0.18), Theme.ok.opacity(0.10),
                    Color(.systemBackground), Color(.systemBackground),
                ])
        } else {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color(.systemBackground)],
                startPoint: .top, endPoint: .center)
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(Typo.heroSymbol)
                .foregroundStyle(Theme.ok)
                .symbolEffect(.bounce, value: reduceMotion ? false : appeared)
            Text(title)
                .font(.title2.bold())
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: — 3 số đo (FR-14/Q-08) — không phải điểm ảo, chỉ đếm lại việc đã làm.

    @ViewBuilder
    private var statsGrid: some View {
        HStack(spacing: Spacing.row) {
            stat(value: "\(tally.reviewed)", label: "thẻ đã ôn", icon: "rectangle.stack.fill", tint: Color.accentColor, index: 0)
            if let accuracy = tally.accuracy {
                stat(
                    value: accuracy.formatted(.percent.precision(.fractionLength(0))),
                    label: "không Quên",
                    icon: "checkmark.seal.fill",
                    tint: Theme.ok, index: 1)
            }
            stat(value: "\(streak)", label: "ngày liên tục", icon: "flame.fill", tint: Theme.due, index: 2)
        }
        // Các ô cao bằng nhau dù nhãn xuống dòng hay thiếu ô "không Quên".
        .fixedSize(horizontal: false, vertical: true)
    }

    /// `index`: thứ tự hiện lần lượt (0.08s mỗi ô) — không phải bảng thành tích,
    /// chỉ giúp mắt bắt kịp 3 số đo cùng lúc đổ ra.
    private func stat(value: String, label: String, icon: String, tint: Color, index: Int) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(Typo.metric)
            Text(label)
                .font(Typo.meta)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Spacing.row)
        .card()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(reduceMotion ? nil : Motion.reveal.delay(Double(index) * 0.08), value: appeared)
    }

    // MARK: — Từ vừa thuộc (Q-08) — tối đa 5, "+N khác" nếu nhiều hơn.

    @ViewBuilder
    private var masteredSection: some View {
        if !tally.newlyMastered.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Vừa thuộc")
                    .font(.subheadline.weight(.semibold))
                ForEach(tally.newlyMastered.prefix(Self.maxMasteredShown), id: \.self) { term in
                    Label(term, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                let remaining = tally.newlyMastered.count - Self.maxMasteredShown
                if remaining > 0 {
                    Text("+\(remaining) khác")
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .card()
        }
    }
}
