import SwiftUI

struct CollectionsView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Color.clear.frame(width: 44, height: 44)
                    Spacer()
                    Text("Kho").font(.headline)
                    Spacer()
                    Button { showCreate = true } label: {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Tạo collection")
                }

                Text("Ôn nhanh")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Button { try? store.persistReviewAll() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tất cả kho").font(.headline)
                            Text(store.settings.reviewAll || store.settings.reviewPriorityIds.isEmpty
                                 ? "Tab Ôn lấy due mọi collection"
                                 : "Bấm để ôn tất cả · hoặc chọn tối đa 3 thẻ bên dưới")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: (store.settings.reviewAll || store.settings.reviewPriorityIds.isEmpty)
                              ? "circle.inset.filled" : "circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("Ghim Home tối đa \(SchemaSQL.pinLimit). Kho tạm luôn trên Home, không ghim, không tính vào trần.")
                    .font(.footnote).foregroundStyle(.secondary)

                Text("Kho tạm")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                ForEach(store.collections.filter(\.isDefault)) { card(for: $0) }

                Text("Collection")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                ForEach(store.collections.filter { !$0.isDefault }) { card(for: $0) }
            }
            .padding(18)
            .padding(.bottom, 88)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form { TextField("Tên sách / mảng việc", text: $newName) }
                    .navigationTitle("Tạo collection")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") { showCreate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Tạo") { create() }
                                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private func card(for collection: CollectionRecord) -> some View {
        CollectionCard(
            collection: collection,
            wordCount: store.vocabByCollection[collection.id] ?? 0,
            dueCount: store.dueByCollection[collection.id] ?? 0,
            reviewing: store.settings.reviewPriorityIds.contains(collection.id) && !store.settings.reviewAll,
            pinned: store.settings.homePinIds.contains(collection.id),
            onOpen: { path.append(.hub(collection.id)) },
            onTogglePriority: {
                do { try store.togglePriority(collection.id) }
                catch { store.notify(error.localizedDescription) }
            },
            onTogglePin: collection.isDefault ? nil : {
                do {
                    let on = try store.togglePin(collection.id)
                    store.notify(on ? "Đã hiện \(collection.name) trên Home" : "Đã bỏ \(collection.name) khỏi Home")
                } catch {
                    store.notify(error.localizedDescription)
                }
            }
        )
    }

    private func create() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let created = try store.addCollection(name: trimmed)
            newName = ""
            showCreate = false
            path.append(.hub(created.id))
        } catch {
            store.notify(error.localizedDescription)
        }
    }
}

struct CollectionHubView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    var collectionId: String

    var body: some View {
        let col = store.collections.first(where: { $0.id == collectionId })
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button { path.removeLast() } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Quay lại")
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                Text(col?.name ?? "Collection").font(.largeTitle.bold())
                HStack(spacing: 8) {
                    Text("\(store.vocabByCollection[collectionId] ?? 0) từ")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if (store.dueByCollection[collectionId] ?? 0) > 0 {
                        Text("\(store.dueByCollection[collectionId] ?? 0) đến hạn")
                            .font(.caption.weight(.semibold)).foregroundStyle(ReadoTheme.due)
                    }
                    if let col, !col.isDefault {
                        Chip(
                            title: store.settings.homePinIds.contains(col.id) ? "Trên Home" : "Ghim Home",
                            on: store.settings.homePinIds.contains(col.id)
                        ) {
                            do { _ = try store.togglePin(col.id) }
                            catch { store.notify(error.localizedDescription) }
                        }
                    }
                }
                Button {
                    try? store.setScope([collectionId])
                    store.setBranch(.due)
                    store.pendingReview = true
                } label: {
                    Label("Ôn bộ này", systemImage: "brain")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                if (store.dueByCollection[collectionId] ?? 0) == 0, store.dueAll > 0 {
                    Text("Không còn thẻ đến hạn trong bộ này. Còn thẻ đến hạn ngoài phạm vi.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button { path.append(.collectionVocab(collectionId)) } label: {
                        GroupedCard {
                            Eyebrow(text: "Kho từ")
                            Text("\(store.vocabByCollection[collectionId] ?? 0)").font(.title.bold())
                            Text("không trôi theo session").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    if col?.isDefault == true {
                        Button { path.append(.organize) } label: {
                            GroupedCard {
                                Eyebrow(text: "Sắp xếp")
                                Text("Lô").font(.title.bold())
                                Text("chuyển sang sách").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        GroupedCard {
                            Eyebrow(text: "Phiên")
                            Text("\(sessions.count)").font(.title.bold())
                            Text("tối đa 10").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Phiên đọc (\(sessions.count)/10)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                if sessions.isEmpty {
                    Text("Chưa có phiên. Chụp trang để đọc song ngữ tại đây.")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ForEach(sessions) { session in
                        Button {
                            path.append(.session(collectionId: collectionId, sessionId: session.id))
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.title).font(.headline)
                                    Text(session.summarySnippet).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(session.capturedAt.prefix(10).dropFirst(5)))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 88)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }

    private var sessions: [ReadingSession] {
        store.sessions.filter { $0.collectionId == collectionId }
    }
}

struct CollectionVocabView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    var collectionId: String
    @State private var rows: [VocabItemRecord] = []

    var body: some View {
        let col = store.collections.first(where: { $0.id == collectionId })
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Hub") { path.removeLast() }.frame(minHeight: 44)
                    Spacer()
                    Text("Kho từ").font(.headline)
                    Spacer()
                    Button("Xuất bộ này") { path.append(.data(collectionId)) }.frame(minHeight: 44)
                }
                Text(col?.name ?? "").font(.largeTitle.bold())
                Text("Durable — không mất khi session thứ 11 trôi.")
                    .font(.footnote).foregroundStyle(.secondary)
                if rows.isEmpty {
                    Text("Kho trống. Chụp một phiên và xác nhận picker.")
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ForEach(rows) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.term).font(.headline)
                            Text("\(item.pos) · \(item.ipa ?? "") · \(item.cefr ?? "")")
                                .font(.footnote).foregroundStyle(.secondary)
                            Text(item.meaningVi).font(.subheadline)
                            Text(item.example).font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .onAppear { rows = (try? store.vocab(in: collectionId)) ?? [] }
    }
}

#Preview {
    let store = try! AppStore(database: AppDatabase(inMemory: true))
    CollectionsView(path: .constant([]))
        .environment(store)
}
