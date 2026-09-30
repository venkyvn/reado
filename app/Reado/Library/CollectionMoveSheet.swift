import ReadoKit
import SwiftUI

/// Đích của một lần "chuyển từ" — chuyển lô (kho tạm) hoặc chuyển rồi xoá.
enum MoveIntention: Identifiable {
    case batch(itemIDs: [String])
    case deleteCollection

    var id: String {
        switch self {
        case .batch: "batch"
        case .deleteCollection: "delete"
        }
    }
}

/// Sheet chọn collection đích (hoặc tạo mới ngay) cho thao tác chuyển từ.
struct CollectionMoveSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let excludedID: String
    let onCommit: (String) -> Void

    @State private var newCollectionName = ""
    @State private var showCreate = false

    private var candidates: [AppModel.CollectionOverview] {
        model.collections.filter { $0.id != excludedID }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Chuyển tới") {
                    ForEach(candidates) { collection in
                        Button {
                            onCommit(collection.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(collection.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(collection.totalItems) từ")
                                    .font(Typo.meta)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Tạo bộ mới", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
            }
            .alert("Tạo bộ", isPresented: $showCreate) {
                TextField("Tên bộ", text: $newCollectionName)
                Button("Tạo") {
                    let newID: String? =
                        (try? model.createCollection(name: newCollectionName))
                        ?? nil
                    if let newID {
                        onCommit(newID)
                        dismiss()
                    }
                    newCollectionName = ""
                }
                Button("Huỷ", role: .cancel) {}
            }
        }
    }
}
