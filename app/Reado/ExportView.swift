import ReadoKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FR-16 Data Export + FR-20 CSV Import — J-R1-D Dữ liệu
// Màn xuất: chọn collection + nút CSV + nút JSON. Màn nhập: ImportView (FR-20, task 3.10).

struct ExportView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedCollectionIDs: Set<String>
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportedCSV: Data?
    @State private var exportedJSON: Data?
    @State private var showShareCSV = false
    @State private var showShareJSON = false
    @State private var showImport = false

    /// Collection chọn sẵn khi mở từ "Xuất bộ này" (J-R1-D/J2 #9); rỗng = tất cả.
    init(initialCollectionIDs: Set<String> = []) {
        _selectedCollectionIDs = State(initialValue: initialCollectionIDs)
    }

    var body: some View {
        List {
            scopeSection
            actionsSection
            importSection
            if let err = exportError {
                errorSection(err)
            }
        }
        .navigationTitle("Dữ liệu")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareCSV) {
            if let data = exportedCSV {
                ShareSheet(activityItems: [data])
            }
        }
        .sheet(isPresented: $showShareJSON) {
            if let data = exportedJSON {
                ShareSheet(activityItems: [data])
            }
        }
        .sheet(isPresented: $showImport) {
            ImportView()
        }
        .onAppear { model.reloadOverview() }
    }

    // MARK: — Chọn phạm vi (theo collection; empty = tất cả)

    private var scopeSection: some View {
        Section {
            // Nút "Tất cả"
            Button {
                if selectedCollectionIDs.count == model.collections.count {
                    selectedCollectionIDs.removeAll()
                } else {
                    selectedCollectionIDs = Set(model.collections.map(\.id))
                }
            } label: {
                HStack {
                    Text(selectedCollectionIDs.count == model.collections.count
                         ? "Bỏ chọn tất cả"
                         : "Chọn tất cả")
                        .font(.subheadline)
                    Spacer()
                    if selectedCollectionIDs.count == model.collections.count {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }

            ForEach(model.collections) { c in
                Button {
                    toggle(c.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name)
                            Text("\(c.totalItems) từ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedCollectionIDs.contains(c.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .disabled(c.totalItems == 0)
            }
        } header: {
            Text("Phạm vi xuất")
        } footer: {
            if selectedCollectionIDs.isEmpty {
                Text("Không chọn collection nào → xuất tất cả.")
                    .font(.footnote)
            }
        }
    }

    private var actionsSection: some View {
        Section("Xuất") {
            // FR-16 #1: CSV/TSV theo collection
            Button {
                exportCSV()
            } label: {
                Label(isExporting ? "Đang xuất…" : "Xuất CSV (Anki)",
                      systemImage: "doc.text")
            }
            .disabled(isExporting || model.collections.isEmpty)

            // FR-16 #3: JSON FSRS — toàn bộ máy (không lọc collection)
            Button {
                exportJSON()
            } label: {
                Label("Xuất JSON FSRS (backup)",
                      systemImage: "doc.badge.gearshape")
            }
            .disabled(isExporting)
        }
    }

    private var importSection: some View {
        Section("Nhập") {
            Button {
                showImport = true
            } label: {
                Label("Nhập CSV từ vựng (FR-20)", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: — Logic

    private func toggle(_ id: String) {
        if selectedCollectionIDs.contains(id) {
            selectedCollectionIDs.remove(id)
        } else {
            selectedCollectionIDs.insert(id)
        }
    }

    private func exportCSV() {
        guard let db = model.database else {
            exportError = "Không có cơ sở dữ liệu"
            return
        }
        isExporting = true
        exportError = nil
        exportedCSV = nil
        defer { isExporting = false }
        do {
            let ids = selectedCollectionIDs.isEmpty ? nil : Array(selectedCollectionIDs)
            let tsv = try ExportService.buildTSV(on: db, collectionIDs: ids)
            guard let data = tsv.data(using: .utf8) else {
                exportError = "Không mã hoá được UTF-8"
                return
            }
            exportedCSV = data
            showShareCSV = true
        } catch {
            exportError = "Lỗi xuất CSV: \(error.localizedDescription)"
        }
    }

    private func exportJSON() {
        guard let db = model.database else {
            exportError = "Không có cơ sở dữ liệu"
            return
        }
        isExporting = true
        exportError = nil
        exportedJSON = nil
        defer { isExporting = false }
        do {
            // JSON backup LUÔN toàn bộ máy (J-R1-D #4) — không lọc collection.
            let data = try ExportService.buildJSON(on: db, now: SystemClock().now)
            exportedJSON = data
            showShareJSON = true
        } catch {
            exportError = "Lỗi xuất JSON: \(error.localizedDescription)"
        }
    }
}

// MARK: - UIViewControllerRepresentable — system share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
