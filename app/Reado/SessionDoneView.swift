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
    let onHome: () -> Void

    /// Giới hạn hiển thị — danh sách dài quá thì rối, không phải bảng thành tích.
    private static let maxMasteredShown = 5

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                statsGrid
                masteredSection
                Spacer(minLength: 12)
                Button("Về Home", action: onHome)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            Motion.run(reduceMotion: reduceMotion) { appeared = true }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.ok)
            Text("Xong hôm nay")
                .font(.title2.bold())
        }
        .padding(.top, 24)
    }

    // MARK: — 3 số đo (FR-14/Q-08) — không phải điểm ảo, chỉ đếm lại việc đã làm.

    @ViewBuilder
    private var statsGrid: some View {
        HStack(spacing: 12) {
            stat(value: "\(tally.reviewed)", label: "thẻ đã ôn", icon: "rectangle.stack.fill", tint: Color.accentColor)
            if let accuracy = tally.accuracy {
                stat(
                    value: accuracy.formatted(.percent.precision(.fractionLength(0))),
                    label: "không Quên",
                    icon: "checkmark.seal.fill",
                    tint: Theme.ok)
            }
            stat(value: "\(streak)", label: "ngày liên tục", icon: "flame.fill", tint: Theme.due)
        }
    }

    private func stat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card()
    }

    // MARK: — Từ vừa thuộc (Q-08) — tối đa 5, "+N khác" nếu nhiều hơn.

    @ViewBuilder
    private var masteredSection: some View {
        if !tally.newlyMastered.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vừa thuộc")
                    .font(.subheadline.weight(.semibold))
                ForEach(tally.newlyMastered.prefix(Self.maxMasteredShown), id: \.self) { term in
                    Label(term, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                let remaining = tally.newlyMastered.count - Self.maxMasteredShown
                if remaining > 0 {
                    Text("+\(remaining) khác")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .card()
        }
    }
}
