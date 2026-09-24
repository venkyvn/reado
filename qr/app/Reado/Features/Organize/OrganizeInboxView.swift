import SwiftUI

struct OrganizeInboxView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    @State private var rows: [VocabItemRecord] = []
    @State private var picked: Set<String> = []
    @State private var target = ""
    @State private var newName = ""

    var body: some View {
        let dest = store.collections.filter { !$0.isDefault }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Hub") { path.removeLast() }.frame(minHeight: 44)
                    Spacer()
                    Text(rows.isEmpty ? "Kho tạm" : "Chuyển lô").font(.headline)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                if rows.isEmpty {
                    Text("Kho tạm trống. Capture nhanh sẽ đổ từ vào đây.")
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    PrimaryButton(title: "Chụp trang") {
                        store.beginCapture(collectionId: store.inbox.id)
                        path.append(.capture(collectionId: store.inbox.id))
                    }
                } else {
                    Text("Collection là nhãn — FSRS trên thẻ không reset. Không xoá được kho tạm.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(rows) { item in
                        Button {
                            if picked.contains(item.id) { picked.remove(item.id) } else { picked.insert(item.id) }
                        } label: {
                            HStack {
                                Image(systemName: picked.contains(item.id) ? "checkmark.square.fill" : "square")
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading) {
                                    Text(item.term).font(.headline)
                                    Text("\(item.pos) · \(item.meaningVi)").font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Eyebrow(text: "Chuyển sang")
                    Picker("Đích", selection: $target) {
                        ForEach(dest) { collection in
                            Text(collection.name).tag(collection.id)
                        }
                    }
                    .pickerStyle(.menu)
                    PrimaryButton(
                        title: "Chuyển \(picked.isEmpty ? "" : "\(picked.count) ")lô",
                        enabled: !picked.isEmpty && !target.isEmpty
                    ) {
                        try? store.moveInbox(ids: Array(picked), toCollectionId: target)
                        picked = []
                        reload()
                    }
                    HStack {
                        TextField("Tạo collection mới", text: $newName)
                            .textFieldStyle(.roundedBorder)
                        Button("Tạo và chuyển") {
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty, !picked.isEmpty,
                                  let created = try? store.addCollection(name: trimmed)
                            else { return }
                            try? store.moveInbox(ids: Array(picked), toCollectionId: created.id)
                            newName = ""
                            picked = []
                            reload()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || picked.isEmpty)
                        .frame(minHeight: 44)
                    }
                }
            }
            .padding(18)
        }
        .navigationBarHidden(true)
        .onAppear {
            reload()
            if target.isEmpty { target = dest.first?.id ?? "" }
        }
    }

    private func reload() {
        rows = (try? store.vocab(in: store.inbox.id)) ?? []
    }
}
