import SwiftUI

struct VocabPickerView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    @State private var openId: String?
    @State private var openSegments: Set<String> = []
    @State private var leave = false

    var body: some View {
        @Bindable var store = store
        let chosen = store.pickerItems.filter(\.selected).count
        let destName = store.collections.first(where: { $0.id == (store.captureTargetId ?? store.inbox.id) })?.name ?? "Kho tạm"
        let allOn = !store.pickerItems.isEmpty && store.pickerItems.allSatisfy(\.selected)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Đóng") { tryBack() }.frame(minHeight: 44)
                    Spacer()
                    Text("Duyệt & lưu").font(.headline)
                    Spacer()
                    Button("Lưu (\(chosen))") { save() }
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                Text("Lưu vào «\(destName)». Đổi bộ lúc chụp.")
                    .font(.footnote).foregroundStyle(.secondary)

                Text("Bản gốc")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                ForEach(store.analysisSegments) { segment in
                    SegmentBlock(
                        sourceEn: segment.sourceEn,
                        translationVi: segment.translationVi,
                        open: Binding(
                            get: { openSegments.contains(segment.id) },
                            set: { on in
                                if on { openSegments.insert(segment.id) } else { openSegments.remove(segment.id) }
                            }
                        )
                    )
                }

                HStack {
                    Text("Từ vựng")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    Spacer()
                    Button(allOn ? "Bỏ chọn" : "Chọn tất cả") {
                        let next = !allOn
                        for index in store.pickerItems.indices {
                            store.pickerItems[index].selected = next
                        }
                        store.pickerDirty = true
                    }
                    .font(.footnote.weight(.semibold))
                    Text("Đã chọn \(chosen)/\(store.pickerItems.count)")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                ForEach($store.pickerItems) { $item in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 8) {
                            Button {
                                item.selected.toggle()
                                store.pickerDirty = true
                            } label: {
                                Image(systemName: item.selected ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(item.selected ? Color.accentColor : Color.secondary)
                            }
                            .accessibilityLabel(item.selected ? "Bỏ chọn \(item.term)" : "Chọn \(item.term)")
                            Button {
                                withAnimation(ReadoTheme.spring) {
                                    openId = openId == item.id ? nil : item.id
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(item.term).font(.headline)
                                        Text(item.pos)
                                            .font(.caption)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                        if !item.cefr.isEmpty {
                                            Text(item.cefr)
                                                .font(.caption)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                        if !item.verified {
                                            Text(item.suspect ? "nghi" : "chưa khớp")
                                                .font(.caption.bold())
                                                .padding(.horizontal, 8).padding(.vertical, 4)
                                                .background(Color.orange.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(item.meaningVi).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        if openId == item.id {
                            editFields($item).padding(.bottom, 12)
                        }
                        Divider()
                    }
                }

                Text("Ý chính")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Text(store.analysisSummary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .alert("Chưa lưu", isPresented: $leave) {
            Button("Thoát", role: .destructive) { if !path.isEmpty { path.removeLast() } }
            Button("Ở lại", role: .cancel) {}
        } message: {
            Text("Thoát sẽ mất kết quả analysis của phiên này.")
        }
    }

    private func tryBack() {
        if store.pickerDirty { leave = true } else if !path.isEmpty { path.removeLast() }
    }

    private func save() {
        do { _ = try store.confirmPicker() }
        catch { store.notify(error.localizedDescription) }
    }

    @ViewBuilder
    private func editFields(_ item: Binding<PickerItem>) -> some View {
        VStack(spacing: 8) {
            labeled("term", text: item.term)
            labeled("pos", text: item.pos)
            labeled("ipa", text: item.ipa)
            labeled("meaning_vi", text: item.meaningVi)
            labeled("cefr", text: item.cefr)
            labeled("example", text: item.example)
        }
    }

    private func labeled(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: title)
            TextField(title, text: text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .onChange(of: text.wrappedValue) { _, _ in store.pickerDirty = true }
        }
    }
}
