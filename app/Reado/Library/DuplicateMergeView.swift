import ReadoKit
import SwiftUI

// MARK: - FR-24 Gộp từ trùng — J-R1-D Dữ liệu (engagement-r1 T2, ADR-067).
// Mỗi nhóm = một khoá `term+pos` có ≥ 2 dòng trong kho. Fen duyệt từng nhóm: mặc định chọn hết,
// bỏ chọn dòng mang nghĩa khác. Dòng "Giữ thẻ này" luôn là `DuplicateMerge.keeper` của các dòng
// ĐANG CHỌN. Gộp không hoàn tác → hộp thoại nhắc xuất JSON backup trước.

struct DuplicateMergeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var groups: [DuplicateMerge.Group] = []
    @State private var excluded: Set<String> = []
    @State private var loaded = false
    @State private var errorMessage: String?
    @State private var confirming = false
    @State private var isMerging = false

    private func chosen(in group: DuplicateMerge.Group) -> [DuplicateMerge.Member] {
        group.members.filter { !excluded.contains($0.vocabItemID) }
    }

    /// Nhóm còn ≥ 2 dòng chọn → một selection (giữ keeper của các dòng chọn).
    private var selections: [DuplicateMerge.Selection] {
        groups.compactMap { group in
            let picked = chosen(in: group)
            guard picked.count >= 2, let keeper = DuplicateMerge.keeper(of: picked) else {
                return nil
            }
            return DuplicateMerge.Selection(
                keeperID: keeper.vocabItemID,
                mergedIDs: picked.filter { $0.vocabItemID != keeper.vocabItemID }.map(\.vocabItemID))
        }
    }

    private var groupCount: Int { selections.count }
    private var rowCount: Int { selections.reduce(0) { $0 + $1.mergedIDs.count } }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Gộp từ trùng")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gộp (\(groupCount))") { confirming = true }
                            .disabled(groupCount == 0 || isMerging)
                    }
                }
                .confirmationDialog(
                    "Gộp \(groupCount) nhóm (\(rowCount) dòng)?",
                    isPresented: $confirming, titleVisibility: .visible
                ) {
                    Button("Gộp", role: .destructive) { mergeNow() }
                    Button("Huỷ", role: .cancel) {}
                } message: {
                    Text("Không hoàn tác được. Nên Xuất JSON backup ở màn Dữ liệu trước.")
                }
        }
        .appErrorAlert()
        .task { reload() }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if loaded && groups.isEmpty {
                emptyState.transition(.opacity)
            } else {
                list.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: groups.isEmpty)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.row) {
            Image(systemName: "checkmark.seal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Không có từ trùng")
                .foregroundStyle(.secondary)
            Text("Mỗi từ chỉ có một thẻ ôn.")
                .font(Typo.meta)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            Section {
                Text("Mỗi nhóm giữ một thẻ ôn — thẻ nhớ tốt nhất. Câu gốc của dòng gộp vào vẫn còn ở mục \"Gặp lại\". Bỏ chọn dòng nào mang nghĩa khác.")
                    .font(Typo.meta)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.members) { member in
                        memberRow(member, in: group)
                    }
                } header: {
                    Text("\(group.members[0].term) · \(group.members[0].pos)")
                } footer: {
                    if chosen(in: group).count < 2 {
                        Text("Không gộp nhóm này.")
                    }
                }
            }
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.danger)
                }
            }
        }
    }

    private func memberRow(
        _ member: DuplicateMerge.Member, in group: DuplicateMerge.Group
    ) -> some View {
        let isOn = !excluded.contains(member.vocabItemID)
        let isKeeper = isOn && DuplicateMerge.keeper(of: chosen(in: group))?.vocabItemID
            == member.vocabItemID && chosen(in: group).count >= 2
        return Button {
            toggle(member.vocabItemID)
        } label: {
            HStack(alignment: .top, spacing: Spacing.row) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(member.meaningVI)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(member.collectionName) · \(member.level.title)")
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                    if isKeeper {
                        Pill(text: "Giữ thẻ này", systemImage: "checkmark.seal.fill", tone: .accent)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggle(_ id: String) {
        if excluded.contains(id) { excluded.remove(id) } else { excluded.insert(id) }
        Haptics.selection()
    }

    private func reload() {
        groups = model.duplicateGroups()
        loaded = true
    }

    private func mergeNow() {
        isMerging = true
        defer { isMerging = false }
        do {
            try model.mergeDuplicates(selections)
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = "Lỗi gộp: \(error.localizedDescription)"
            Haptics.error()
            reload()
        }
    }
}
