import SwiftUI

/// Chọn đích lưu (chip + 2 sheet) cho `CaptureView` — tách khỏi file chính
/// (refactor-r4 T1, di chuyển thuần, không đổi hành vi).
extension CaptureView {
    var destChip: some View {
        Button {
            showDestPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lưu vào")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                Text(destName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(cameraDestIsInbox ? "Không chọn → kho tạm" : "Trang này vào bộ này")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Đổi bộ lưu, hiện \(destName)")
    }

    /// Tên đích hiện tại cho chip (nil = kho tạm).
    var destName: String {
        if let id = model.capture.analysisTargetCollectionID,
           let c = model.collections.first(where: { $0.id == id }) {
            return c.name
        }
        return "Kho tạm"
    }

    /// Đích hiện tại có phải kho tạm không — chọn dòng gợi ý dưới chip.
    var cameraDestIsInbox: Bool {
        if let id = model.capture.analysisTargetCollectionID,
           let c = model.collections.first(where: { $0.id == id }) {
            return c.isDefault
        }
        return true
    }

    /// Chọn đích + haptic (port UI lab §9: `.selection` lúc đổi dest).
    func selectDest(_ id: String?) {
        UISelectionFeedbackGenerator().selectionChanged()
        model.capture.analysisTargetCollectionID = id
    }

    /// Sheet chọn collection lưu — radio, kho tạm ghi "mặc định" (port UI lab §4.3).
    func destPickerSheet(close: @escaping () -> Void) -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectDest(nil)
                        close()
                    } label: {
                        HStack {
                            Label("Kho tạm", systemImage: "tray")
                                .foregroundStyle(.primary)
                            Spacer()
                            if model.capture.analysisTargetCollectionID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                Section("Bộ") {
                    ForEach(model.collections.filter { !$0.isDefault }) { c in
                        Button {
                            selectDest(c.id)
                            close()
                        } label: {
                            HStack {
                                Text(c.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if model.capture.analysisTargetCollectionID == c.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lưu vào đâu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { close() }
                }
            }
        }
    }

    /// Sheet tạo collection mới — nhập tên, tạo xong chọn luôn làm đích (port §4.2).
    func newCollectionSheet(close: @escaping () -> Void) -> some View {
        NavigationStack {
            Form {
                TextField("Tên bộ", text: $newCollectionName)
                Button {
                    let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let id = model.createCollectionOrAlert(name: name) {
                        selectDest(id)
                    }
                    close()
                } label: {
                    Text("Tạo và chọn làm đích")
                        .frame(maxWidth: .infinity)
                }
                .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Tạo bộ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Huỷ") { close() }
                }
            }
        }
    }
}
