import SwiftUI

struct DestChip: View {
    var name: String
    var isInbox: Bool
    var onPick: () -> Void
    var onCreate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPick) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline)
                    Text(isInbox ? "Không chọn → kho tạm" : "Trang này vào bộ này")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bộ lưu: \(name)")

            Button(action: onCreate) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityLabel("Tạo collection")
        }
    }
}
