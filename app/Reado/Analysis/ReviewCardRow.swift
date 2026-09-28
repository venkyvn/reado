import SwiftUI
import ReadoKit

// Tách từ AnalysisView.swift (repo-hygiene-r1 B3).

// MARK: - Card duyệt (ADR-008)

/// Một dòng trong danh sách duyệt: checkbox (FR-09) + thông tin tắt + chip trạng
/// thái xác minh (FR-02); chạm card mở inline 6 field (FR-03). Thiết kế hàng tách
/// bấm chọn với bấm mở — checkbox KHÔNG nằm trong vùng mở card.
struct ReviewCardRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var draft: ReviewDraft
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.row) {
                selectButton
                Button {
                    onToggleExpand()
                } label: {
                    summaryLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(draft.term), \(draft.meaningVI)")
                .accessibilityValue(isExpanded ? "Đang mở" : "Đang thu gọn")
                .accessibilityHint(isExpanded ? "Thu gọn thông tin" : "Mở để sửa thông tin")
            }

            if isExpanded {
                editor
                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 44)
                    .revealTransition()
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// FR-09: chọn item thành review card. Unverified/suspect không preselect —
    /// bấm chọn nghĩa là user chủ động giữ (FR-02/03).
    private var selectButton: some View {
        Button {
            draft.isSelected.toggle()
            Haptics.selection()
        } label: {
            Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(
                    draft.isSelected ? Color.accentColor : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            draft.isSelected ? "Bỏ chọn \(draft.term)" : "Chọn \(draft.term) để ôn tập")
        .accessibilityValue(draft.isSelected ? "Đã chọn" : "Chưa chọn")
        .accessibilityAddTraits(draft.isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var summaryLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                summaryText
                HStack {
                    VerificationBadge(status: draft.verification)
                    Spacer()
                    expandChevron
                }
            }
        } else {
            HStack(alignment: .top, spacing: Spacing.sm) {
                summaryText
                Spacer(minLength: Spacing.xs)
                VerificationBadge(status: draft.verification)
                expandChevron
            }
        }
    }

    /// Cùng khối `VocabSummary` với row Kho. Mở card thì IPA + ví dụ ẩn (editor bên dưới
    /// đã có đủ field), chỉ còn từ + nghĩa.
    private var summaryText: some View {
        VocabSummary(
            term: draft.term,
            pos: draft.pos,
            cefr: draft.cefr,
            ipa: isExpanded ? "" : draft.ipa,
            meaning: draft.meaningVI,
            example: isExpanded ? "" : draft.example)
    }

    private var expandChevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .frame(width: 44, height: 44)
            .animation(
                reduceMotion ? nil : Motion.reveal,
                value: isExpanded)
    }

    /// FR-03: sửa được mọi field ngay dưới card, không rời danh sách.
    private var editor: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            editorField("Từ") {
                TextField("Từ mới", text: $draft.term)
            }
            editorField("Từ loại") {
                Picker("Từ loại", selection: $draft.pos) {
                    ForEach(ReviewDraftBuilder.validPOS, id: \.self) { pos in
                        Text(pos).tag(pos)
                    }
                }
                .pickerStyle(.menu)
            }
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                editorField("Phiên âm (IPA)") {
                    TextField("VD: /ˈwɪndɪŋ/", text: $draft.ipa)
                }
                // ADR-040: nghe cách đọc từ đang sửa — không luyện nói, không chấm.
                SpeakButton(term: draft.term)
            }
            editorField("Nghĩa tiếng Việt") {
                TextField("Nghĩa", text: $draft.meaningVI, axis: .vertical)
                    .lineLimit(1...3)
            }
            editorField("CEFR") {
                Picker("CEFR", selection: $draft.cefr) {
                    Text("Không rõ").tag("")
                    ForEach(ReviewDraftBuilder.validCEFR, id: \.self) { cefr in
                        Text(cefr).tag(cefr)
                    }
                }
                .pickerStyle(.menu)
            }
            editorField("Câu ví dụ") {
                TextField("Câu gốc trên trang", text: $draft.example, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
    }

    private func editorField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .font(.subheadline)
                .padding(Spacing.sm)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
    }
}
