import ReadoKit
import SwiftUI

// Tách từ ReviewQueueView.swift (repo-hygiene-r1 B3).

/// FR-18: picker phạm vi ôn — tất cả / một / vài collection (multi-select).
/// nil = tất cả; Set 1 phần tử = một; Set nhiều = trộn (J5). Phần cuối chỉnh phạm vi MẶC ĐỊNH khi
/// bấm Ôn (ux-redesign-r1 T4 — trước ở Kho, mục "Ôn nhanh"); phần trên chỉ áp cho phiên này.
struct ScopePickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var scope: Set<String>?
    let onApply: () -> Void

    @State private var isAll: Bool
    @State private var selected: Set<String>

    init(scope: Binding<Set<String>?>, onApply: @escaping () -> Void) {
        _scope = scope
        self.onApply = onApply
        let current = scope.wrappedValue
        _isAll = State(initialValue: current == nil)
        _selected = State(initialValue: current ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isAll = true
                        selected = []
                        Haptics.selection()
                    } label: {
                        HStack {
                            Label("Tất cả bộ", systemImage: "square.stack.3d.up")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isAll {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                Section("Hoặc trộn một / vài bộ") {
                    ForEach(model.collections) { collection in
                        Button {
                            if selected.contains(collection.id) {
                                selected.remove(collection.id)
                            } else {
                                selected.insert(collection.id)
                            }
                            isAll = false
                            Haptics.selection()
                        } label: {
                            HStack {
                                Text(collection.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if collection.dueNow > 0 {
                                    Text("\(collection.dueNow) đến hạn")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if selected.contains(collection.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button {
                        model.attempt("đổi phạm vi ôn mặc định") {
                            try model.setReviewAll(!model.reviewScopeDefault.reviewAll)
                        }
                        Haptics.selection()
                    } label: {
                        HStack {
                            Label(defaultScopeLabel, systemImage: "square.stack.3d.up")
                                .foregroundStyle(.primary)
                            Spacer()
                            if model.reviewScopeDefault.reviewAll {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                } header: {
                    Text("Mặc định khi bấm Ôn")
                } footer: {
                    Text("Vuốt một bộ trong Thư viện để ưu tiên.")
                }
            }
            .navigationTitle("Phạm vi ôn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Áp dụng") {
                        // Bỏ chọn hết ≡ tất cả (không sinh Set rỗng).
                        scope = (isAll || selected.isEmpty) ? nil : selected
                        dismiss()
                        onApply()
                    }
                }
            }
        }
        // Gốc sheet — alert của RootView không hiện được khi sheet đang che.
        .appErrorAlert()
    }

    /// "Tất cả kho" hoặc "N/3 bộ ưu tiên" — phản ánh phạm vi mặc định đang lưu.
    private var defaultScopeLabel: String {
        let scope = model.reviewScopeDefault
        if scope.reviewAll || scope.priorityIDs.isEmpty { return "Tất cả kho" }
        return "\(scope.priorityIDs.count)/\(ReviewScopeService.maxPriority) bộ ưu tiên"
    }
}
