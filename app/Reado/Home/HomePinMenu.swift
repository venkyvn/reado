import ReadoKit
import SwiftUI

// FR-17 (port UI lab: pin 5) — ghim một bộ lên màn Hôm nay. ux-redesign-r1 T6: từ Toggle "Hiện
// trên Home" chiếm hẳn một Section ở Hub thành MỘT mục trong menu ⋯ (CTA chính của Hub là Ôn).
// Luật không đổi: còn slot trống → ghim mới; đã đủ 5 → mở chooser chọn pin hiện có để thay (không
// tự thay ngầm); đang ghim → bỏ ghim, giữ thứ tự các pin còn lại.

/// Mục "Ghim lên Hôm nay" / "Bỏ ghim" trong `Menu`. Đủ 5 pin thì gọi `onFull` — nơi dùng mở chooser
/// bằng `.homePinChooser` gắn lên view ngoài menu (confirmationDialog trong nội dung Menu sẽ biến
/// mất cùng menu).
struct HomePinMenuButton: View {
    let collectionID: String
    let onFull: () -> Void

    @Environment(AppModel.self) private var model

    private var isPinned: Bool { model.homePinIDs.contains(collectionID) }

    var body: some View {
        Button {
            model.setHomePinned(!isPinned, collectionID: collectionID, onFull: onFull)
        } label: {
            Label(
                isPinned ? "Bỏ ghim" : "Ghim lên Hôm nay",
                systemImage: isPinned ? "pin.slash" : "pin")
        }
    }
}

extension AppModel {
    /// Ghim/bỏ ghim một bộ. Lỗi → alert (`attempt`); đã đủ 5 mà đang bật → `onFull` (mở chooser).
    func setHomePinned(_ pinned: Bool, collectionID: String, onFull: () -> Void) {
        if !pinned {
            attempt("bỏ ghim bộ") { try removeHomePin(collectionID) }
        } else if homePinIDs.count >= HomePinService.maxPins {
            onFull()
        } else {
            attempt("ghim bộ") { try addHomePin(collectionID) }
        }
    }
}

/// Chooser "đã đủ 5": chọn một pin hiện có để thay bằng `collectionID`.
private struct HomePinChooser: ViewModifier {
    let collectionID: String
    @Binding var isPresented: Bool

    @Environment(AppModel.self) private var model

    /// Các pin hiện có (resolve tên) — ứng viên bị thay.
    private var currentPins: [AppModel.CollectionOverview] {
        model.homePinIDs.compactMap { id in
            model.collections.first { $0.id == id }
        }
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Chọn pin để thay",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            ForEach(currentPins) { existing in
                Button(existing.name) {
                    model.attempt("thay bộ ghim") {
                        try model.replaceHomePin(existingID: existing.id, with: collectionID)
                    }
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Hôm nay giữ tối đa 5 bộ đang đọc.")
        }
    }
}

extension View {
    func homePinChooser(collectionID: String, isPresented: Binding<Bool>) -> some View {
        modifier(HomePinChooser(collectionID: collectionID, isPresented: isPresented))
    }
}
