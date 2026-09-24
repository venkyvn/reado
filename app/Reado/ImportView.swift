import ReadoKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FR-20 CSV Import — J-R1-D Dữ liệu.
// Chọn file CSV/TSV → preview (mặc định chọn hết, sửa field được, bỏ dòng được,
// cảnh báo term trùng) → "Gộp (N)" vào kho. File hỏng → báo lỗi, không hiện preview.

struct ImportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rows: [CSVImport.CSVRow] = []
    @State private var parseError: String?
    @State private var showFilePicker = false
    @State private var isImporting = false

    private var selectedCount: Int { rows.filter(\.isSelected).count }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Nhập CSV")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gộp (\(selectedCount))") { importSelected() }
                            .disabled(selectedCount == 0 || isImporting)
                    }
                }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handlePicked(result)
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if let parseError {
                errorState(parseError)
                    .transition(.opacity)
            } else if rows.isEmpty {
                emptyState
                    .transition(.opacity)
            } else {
                previewList
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: parseError)
        .animation(reduceMotion ? nil : Motion.reveal, value: rows.isEmpty)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Chọn file CSV từ vựng để nhập")
                .foregroundStyle(.secondary)
            Text("Cùng 7 cột với Xuất CSV: term, pos, ipa, meaning_vi, cefr, example, collection")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Chọn file…") { showFilePicker = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.warn)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Chọn file khác") { showFilePicker = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewList: some View {
        List {
            Section {
                ForEach($rows) { $row in
                    ImportRowView(row: $row)
                }
            } header: {
                Text("\(selectedCount) dòng sẽ gộp")
            } footer: {
                Text("Dòng báo \"trùng\" đã có term tương tự trong kho — bỏ chọn nếu không muốn gộp thêm.")
            }
        }
    }

    // MARK: — Logic

    private func handlePicked(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                parseError = "Không đọc được file (không phải UTF-8)"
                rows = []
                Haptics.error()
                return
            }
            let parsed = try model.parseImport(text)
            rows = model.markDuplicateTerms(parsed)
            parseError = nil
        } catch {
            rows = []
            parseError = "Lỗi nhập: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    private func importSelected() {
        isImporting = true
        defer { isImporting = false }
        do {
            _ = try model.importRows(rows)
            Haptics.success()
            dismiss()
        } catch {
            parseError = "Lỗi gộp: \(error.localizedDescription)"
            Haptics.error()
        }
    }
}

/// Một dòng preview — checkbox + cảnh báo trùng + các field sửa được.
private struct ImportRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var row: CSVImport.CSVRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    row.isSelected.toggle()
                    Haptics.selection()
                } label: {
                    Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(row.isSelected ? Color.accentColor : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.isSelected ? "Bỏ chọn \(row.term)" : "Chọn \(row.term)")
                .accessibilityValue(row.isSelected ? "Đã chọn" : "Chưa chọn")
                .accessibilityAddTraits(row.isSelected ? .isSelected : [])
                TextField("term", text: $row.term)
                    .font(.headline)
                if row.duplicateTerm {
                    Label("trùng", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.warn)
                }
            }
            TextField("nghĩa tiếng Việt", text: $row.meaningVI, axis: .vertical)
                .font(.subheadline)
            metadataFields
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var metadataFields: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Từ loại", text: $row.pos)
                TextField("IPA", text: $row.ipa)
                TextField("CEFR", text: $row.cefr)
                TextField("Ví dụ", text: $row.example, axis: .vertical)
                TextField("Collection", text: $row.collection)
            }
            .font(.body)
        } else {
            HStack(spacing: 8) {
                TextField("pos", text: $row.pos)
                TextField("ipa", text: $row.ipa)
                TextField("cefr", text: $row.cefr)
            }
            .font(.caption)
            HStack(spacing: 8) {
                TextField("example", text: $row.example)
                TextField("collection", text: $row.collection)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}