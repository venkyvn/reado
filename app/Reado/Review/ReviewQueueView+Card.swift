import ReadoKit
import SwiftUI

// Tách từ ReviewQueueView.swift (repo-hygiene-r1 B3).

extension ReviewQueueView {
    // MARK: — Card

    var cardView: some View {
        let item = items[currentIndex]
        return VStack(spacing: Spacing.lg) {
            debtBanner
            masteredToastBanner

            // Progress: thanh + "n/N" (thanh ẩn khỏi VoiceOver — chữ đã đọc đủ).
            HStack(spacing: Spacing.row) {
                ProgressView(value: Double(currentIndex), total: Double(max(items.count, 1)))
                    .accessibilityHidden(true)
                Text("\(currentIndex + 1)/\(items.count)")
                    .font(Typo.meta)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                if mode == .cram {
                    Text("Ôn thêm")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .accessibilityLabel("Chế độ ôn thêm, không đổi lịch")
                }
                // FR-12: undo nút nổi 1 bước.
                if showUndoToast {
                    Button("Hoàn tác") {
                        performUndo()
                    }
                    .buttonStyle(.bordered)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)

            Spacer(minLength: 0)

            // Card body. Thẻ kế nằm dưới, phóng dần khi thẻ trên bị kéo — cảm giác chồng bài.
            GeometryReader { geo in
                ZStack {
                    if currentIndex + 1 < items.count {
                        cardFace(item: items[currentIndex + 1], back: false, size: geo.size)
                            .scaleEffect(0.96 + 0.04 * swipeProgress)
                            .offset(y: 14 * (1 - swipeProgress))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    // .id: thẻ mới không kế thừa offset của thẻ vừa bay ra.
                    faceStack(item: item, size: geo.size)
                        .id(item.cardID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .overlay(swipeStamp)
                        // Xoay trước, kéo sau. Ngược lại rotationEffect xoay quanh tâm
                        // gốc (chưa offset) và thẻ đi theo cung tròn, lệch khỏi tay.
                        // Neo tâm: neo dưới đáy + offset đủ sẽ làm thẻ chạy nhanh hơn ngón tay.
                        .rotationEffect(.degrees(dragAngle))
                        .offset(dragOffset)
                }
            }
            .padding(.horizontal, Spacing.md)
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .gesture(swipeGesture)
            // Tap chỉ thuộc vùng thẻ. Đặt trên VStack cha sẽ khiến nút chấm/
            // Hoàn tác có thể đồng thời kích hoạt flip.
            .onTapGesture {
                guard !isCommitting else { return }
                flipCard()
            }
            .frontGradeActions(enabled: !isFlipped, grade: performGrade)
            .accessibilityAction(named: Text(isFlipped ? "Hiện mặt trước" : "Lật thẻ")) {
                flipCard()
            }

            Spacer(minLength: 0)

            // Bottom controls.
            if isFlipped {
                gradeButtons
                    .revealTransition()
            } else {
                Text("Chạm để lật · trái Quên · phải Được")
                    .foregroundStyle(.secondary)
                    .font(Typo.meta)
                    .revealTransition()
            }
        }
    }

    /// U1: nạp lại nhãn nhịp ôn cho thẻ đang đứng ở `lastSnapshot`.
    func refreshIntervals() {
        // Cram không đổi lịch → nhãn "ôn lại sau …" sẽ sai, ẩn hẳn.
        guard mode == .srs else { intervalLabels = [:]; return }
        intervalLabels = lastSnapshot.map { model.intervalLabels(for: $0) } ?? [:]
    }

    private func flipCard() {
        let target: Double = flipDegrees == 0 ? 180 : 0
        // Reduce Motion: đổi mặt tức thì, không quay 3D.
        Motion.run(reduceMotion: reduceMotion,
                   .spring(response: 0.4, dampingFraction: 0.8)) {
            flipDegrees = target
        }
        Haptics.selection()
    }

    /// Hai mặt thẻ, đổi đúng mốc 90° (không crossfade).
    private func faceStack(item: ReviewQueue.ReviewItem, size: CGSize) -> some View {
        ZStack {
            cardFace(item: item, back: false, size: size)
                .rotation3DEffect(.degrees(flipDegrees),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(flipDegrees < 90 ? 1 : 0)
            cardFace(item: item, back: true, size: size)
                .rotation3DEffect(.degrees(flipDegrees - 180),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(flipDegrees >= 90 ? 1 : 0)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isCommitting, !reduceMotion else { return }
                dragOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height * SwipeMotion.verticalDamp)
                let passed = abs(value.translation.width) >= SwipeCommit.threshold
                if passed, !didPassThreshold {
                    Haptics.threshold()
                }
                didPassThreshold = passed
            }
            .onEnded { value in
                guard !isCommitting else { return }
                // Ngưỡng theo điểm thoát dự đoán: hất nhanh dưới 110pt vẫn chấm.
                let predicted = value.predictedEndTranslation.width
                guard let rating = SwipeCommit.rating(predictedWidth: predicted) else {
                    snapBack()
                    return
                }
                if reduceMotion {
                    performGrade(rating)
                } else {
                    commitSwipe(rating, predictedWidth: predicted)
                }
            }
    }

    /// 0…1 theo quãng kéo ngang. Stamp, thẻ kế, và haptic cùng một thước.
    private var swipeProgress: CGFloat {
        min(abs(dragOffset.width) / SwipeCommit.threshold, 1)
    }

    /// Tilt theo tay: ~1° mỗi 15pt, kẹp ±12° để thẻ không xoay quá giả.
    private var dragAngle: Double {
        min(max(Double(dragOffset.width) / SwipeMotion.pointsPerDegree,
                -SwipeMotion.maxTilt),
            SwipeMotion.maxTilt)
    }

    /// Stamp "Quên"/"Được" hiện theo hướng kéo, đậm dần tới ngưỡng chấm.
    @ViewBuilder
    private var swipeStamp: some View {
        if swipeProgress > 0.02 {
            ZStack {
                if dragOffset.width < 0 {
                    badgeLabel(stampText(.again), color: Theme.danger)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .rotationEffect(.degrees(-10))
                } else {
                    badgeLabel(stampText(.good), color: Theme.ok)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .rotationEffect(.degrees(10))
                }
            }
            .padding(Spacing.lg)
            .opacity(swipeProgress)
        }
    }

    /// U1: nhãn stamp kèm nhịp ôn khi có sẵn — "Quên · 1 ngày" thay vì trơ "Quên".
    private func stampText(_ rating: ReadoRating) -> String {
        guard let hint = intervalLabels[rating] else { return rating.label }
        return "\(rating.label) · \(hint)"
    }

    private func badgeLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(color, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 2))
    }

    private func commitSwipe(_ rating: ReadoRating, predictedWidth: CGFloat) {
        isCommitting = true
        Haptics.action()
        let dir = SwipeCommit.direction(predictedWidth: predictedWidth)
        // Giữ height đang damp — lấy translation.height thô sẽ làm thẻ nhảy dọc lúc bay.
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: dir * SwipeMotion.flyDistance, height: dragOffset.height)
        } completion: {
            isCommitting = false
            // gradeNow, không performGrade: cờ vừa hạ, đọc lại @State trong cùng lượt có thể vẫn thấy true.
            gradeNow(rating)
        }
    }

    private func snapBack() {
        didPassThreshold = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            dragOffset = .zero
        }
    }

    private func cardFace(item: ReviewQueue.ReviewItem, back: Bool, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color(.systemBackground))
                .cardShadow()
            if !back {
                // FR-12: mặt trước = term + pos.
                VStack(spacing: Spacing.row) {
                    Text(item.term)
                        .font(Typo.cardTerm)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                    Pill(text: item.pos, tone: .neutral)
                    // ADR-040: nghe cách đọc — không luyện nói, không chấm.
                    SpeakButton(term: item.term)
                }
                .padding(Spacing.lg)
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        backFaceContent(item)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    backFaceContent(item)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// FR-12: mặt sau = meaning_vi, IPA, câu gốc, tên collection.
    private func backFaceContent(_ item: ReviewQueue.ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            // Nhắc lại từ: đáp án (nghĩa) là dòng to nhất, từ chỉ là ngữ cảnh.
            Text(item.term)
                .font(Typo.rowTitle)
                .foregroundStyle(.secondary)
            Text(item.meaningVI)
                .font(Typo.cardAnswer)
            HStack(spacing: Spacing.sm) {
                if let ipa = item.ipa, !ipa.isEmpty {
                    Text("/\(ipa)/").font(Typo.rowSubtitle).foregroundStyle(.secondary)
                }
                SpeakButton(term: item.term)
            }
            Text(item.example)
                .font(.body)
                .italic()
            Divider()
            Text(item.collectionName)
                .font(Typo.meta)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        // Cùng khung với mặt trước, neo trên-trái thay vì trôi giữa thẻ.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private extension View {
    /// Action Quên/Được chỉ khi mặt trước — mặt sau đã có bốn nút, tránh trùng rotor.
    @ViewBuilder
    func frontGradeActions(
        enabled: Bool,
        grade: @escaping (ReadoRating) -> Void
    ) -> some View {
        if enabled {
            self
                .accessibilityAction(named: Text("Quên")) { grade(.again) }
                .accessibilityAction(named: Text("Được")) { grade(.good) }
        } else {
            self
        }
    }
}

/// Cảm giác kéo — không thuộc quyết định chấm (cái đó là `SwipeCommit`).
private enum SwipeMotion {
    static let verticalDamp: CGFloat = 0.35
    static let flyDistance: CGFloat = 720
    static let maxTilt: Double = 12
    /// ~1° mỗi 15pt.
    static let pointsPerDegree: Double = 15
}
