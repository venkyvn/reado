import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DataView: View {
    @Environment(AppStore.self) private var store
    var preselected: String?
    @State private var picked: Set<String> = []
    @State private var drafts: [ImportDraft]?
    @State private var openId: String?
    @State private var parseError: String?
    @State private var noneSelected = false
    @State private var importer = false
    @State private var exporter: SharePayload?

    var body: some View {
        Group {
            if let drafts {
                importPreview(drafts)
            } else {
                exportForm
            }
        }
        .navigationTitle("Dữ liệu")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if picked.isEmpty {
                if let preselected { picked = [preselected] }
                else { picked = Set(store.collections.map(\.id)) }
            }
        }
        .fileImporter(isPresented: $importer, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url):
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    do {
                        let rows = try store.importCSV(text)
                        drafts = rows.map { ImportDraft(id: IDs.uuid(), row: $0, selected: true) }
                        parseError = nil
                    } catch {
                        parseError = error.localizedDescription
                        drafts = nil
                    }
                } else {
                    parseError = "File trống hoặc không đọc được header."
                }
            case .failure(let error):
                parseError = error.localizedDescription
            }
        }
        .sheet(item: $exporter) { payload in
            ShareSheet(items: [payload.url])
        }
    }

    private var exportForm: some View {
        Form {
            Section {
                Text("CSV từ vựng — Anki-shaped. Không phải path capture. JSON FSRS chỉ xuất.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Xuất") {
                ForEach(store.collections) { collection in
                    Toggle(isOn: Binding(
                        get: { picked.contains(collection.id) },
                        set: { on in
                            if on { picked.insert(collection.id) } else { picked.remove(collection.id) }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(collection.name)
                            Text("\(store.vocabByCollection[collection.id] ?? 0) từ\(collection.isDefault ? " · kho tạm" : "")")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("CSV") {
                    if let csv = try? store.exportCSV(collectionIds: Array(picked)),
                       let url = writeTemp("reado-vocab.csv", csv.data(using: .utf8) ?? Data()) {
                        exporter = SharePayload(url: url)
                    }
                }
                Button("JSON FSRS") {
                    if let data = try? store.exportJSON(),
                       let url = writeTemp("reado-fsrs.json", data) {
                        exporter = SharePayload(url: url)
                    }
                }
            }
            Section("Nhập") {
                Button("Chọn file") { importer = true }
                if let parseError {
                    Text(parseError).foregroundStyle(.red).font(.footnote)
                }
            }
        }
    }

    private func importPreview(_ drafts: [ImportDraft]) -> some View {
        let chosen = drafts.filter(\.selected).count
        let known = (try? store.knownTerms()) ?? []
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nhập CSV").font(.title.bold())
                Text("Mặc định chọn hết. Trùng term chỉ cảnh báo — bỏ chọn nếu không muốn gộp.")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    let dup = known.contains(TermNormalizer.normalize(draft.row.term))
                    VStack(alignment: .leading) {
                        HStack {
                            Button {
                                self.drafts?[index].selected.toggle()
                                noneSelected = false
                            } label: {
                                Image(systemName: draft.selected ? "checkmark.square.fill" : "square")
                                    .frame(width: 44, height: 44)
                            }
                            VStack(alignment: .leading) {
                                Text(draft.row.term.isEmpty ? "—" : draft.row.term).font(.headline)
                                Text("\(draft.row.pos) · \(draft.row.meaningVi)")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if dup {
                                Text("đã có").font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.15)).clipShape(Capsule())
                            }
                        }
                    }
                    Divider()
                }
                if noneSelected {
                    Text("0 dòng còn chọn — không ghi.").foregroundStyle(.red)
                }
                PrimaryButton(title: "Nhập \(chosen) dòng") {
                    let rows = drafts.filter(\.selected).map(\.row)
                    if rows.isEmpty {
                        noneSelected = true
                        return
                    }
                    try? store.commitImport(rows)
                    self.drafts = nil
                }
            }
            .padding(18)
        }
    }

    private func writeTemp(_ name: String, _ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

struct ImportDraft: Identifiable {
    var id: String
    var row: VocabCsvRow
    var selected: Bool
}

struct SharePayload: Identifiable {
    var id: String { url.path }
    var url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
