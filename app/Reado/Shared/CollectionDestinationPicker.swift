import ReadoKit
import SwiftUI

/// ux-redesign-r1 T5a: chọn đích lưu (Kho tạm · các bộ · "Tạo bộ mới…") dùng chung cho camera và
/// màn duyệt từ. Là `Menu`, không sheet — màn duyệt đã là sheet, thêm sheet chọn + alert tạo bộ
/// là 3 tầng modal (vượt luật ≤ 2). "Tạo bộ mới…" mở alert có ô nhập (1 tầng); tạo xong bộ đó
/// được chọn luôn. Đích đọc/ghi `model.capture.analysisTargetCollectionID` (nil = kho tạm).
struct CollectionDestinationPicker<Content: View>: View {
    @Environment(AppModel.self) private var model

    private let content: Content

    @State private var showNewCollection = false
    @State private var newCollectionName = ""

    /// `content` = nhãn bấm được (chip trên camera, dòng "Lưu vào" ở màn duyệt) — nơi gọi tự vẽ
    /// và tự đặt `accessibilityLabel`.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var namedCollections: [AppModel.CollectionOverview] {
        model.collections.filter { !$0.isDefault }
    }

    var body: some View {
        Menu {
            Picker(
                "Lưu vào",
                selection: Binding(
                    get: { model.capture.analysisTargetCollectionID },
                    set: { select($0) })
            ) {
                Label("Kho tạm", systemImage: "tray").tag(String?.none)
                ForEach(namedCollections) { collection in
                    Text(collection.name).tag(String?.some(collection.id))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button {
                newCollectionName = ""
                showNewCollection = true
            } label: {
                Label("Tạo bộ mới…", systemImage: "plus")
            }
        } label: {
            content
        }
        .alert("Tạo bộ mới", isPresented: $showNewCollection) {
            TextField("Tên bộ", text: $newCollectionName)
            Button("Tạo") { createAndSelect() }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Tạo xong, bộ này được chọn làm nơi lưu.")
        }
    }

    /// Chọn đích + haptic (port UI lab §9: `.selection` lúc đổi dest).
    private func select(_ id: String?) {
        Haptics.selection()
        model.capture.analysisTargetCollectionID = id
    }

    private func createAndSelect() {
        let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let id = model.createCollectionOrAlert(name: name) {
            select(id)
        }
    }
}
