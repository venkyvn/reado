import ReadoKit
import SwiftUI

/// FR-17 (port UI lab: pin 5) — Control "Hiện trên Home" dùng chung giữa
/// Collection Hub và Settings (J-R1-S). Toggle ON:
/// - còn slot trống → ghim mới;
/// - đã đủ 5 → mở chooser chọn pin hiện có để thay (không tự thay ngầm).
/// Toggle OFF → bỏ pin, giữ thứ tự các pin còn lại.
struct HomePinToggle: View {
    /// Collection cần bật/tắt ghim. `label = nil` → "Hiện trên Home" (hợp cho
    /// chi tiết collection); Settings truyền tên collection làm nhãn.
    let collectionID: String
    var label: String? = nil

    @Environment(AppModel.self) private var model
    @State private var showChooser = false

    private var isOn: Bool { model.homePinIDs.contains(collectionID) }

    /// Các pin hiện có (resolve tên) — ứng viên bị thay trong chooser.
    private var currentShortcuts: [AppModel.CollectionOverview] {
        model.homePinIDs.compactMap { id in
            model.collections.first { $0.id == id }
        }
    }

    private var isOnBinding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { newValue in
                if newValue { turnOn() } else { turnOff() }
            })
    }

    var body: some View {
        Toggle(label ?? "Hiện trên Home", isOn: isOnBinding)
            .confirmationDialog(
                "Chọn pin để thay",
                isPresented: $showChooser,
                titleVisibility: .visible
            ) {
                ForEach(currentShortcuts) { existing in
                    Button(existing.name) {
                        model.attempt("thay bộ ghim") {
                            try model.replaceHomePin(
                                existingID: existing.id, with: collectionID)
                        }
                    }
                }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Home giữ tối đa 5 bộ đang đọc.")
            }
    }

    private func turnOn() {
        if model.homePinIDs.count >= HomePinService.maxPins {
            showChooser = true
        } else {
            model.attempt("ghim bộ") { try model.addHomePin(collectionID) }
        }
    }

    private func turnOff() {
        model.attempt("bỏ ghim bộ") { try model.removeHomePin(collectionID) }
    }
}