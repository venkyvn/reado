import SwiftUI

/// Chip đích lưu trên camera — tách khỏi file chính (refactor-r4 T1). ux-redesign-r1 T5a: chọn đích
/// đi qua `CollectionDestinationPicker` (Menu dùng chung với màn duyệt từ), bỏ 2 sheet riêng + nút
/// "+" tạo bộ — "Tạo bộ mới…" nằm trong chính menu này.
extension CaptureView {
    var destChip: some View {
        CollectionDestinationPicker {
            HStack(spacing: 8) {
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
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
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
}
