import SwiftUI

struct CollectionCard: View {
    var collection: CollectionRecord
    var wordCount: Int
    var dueCount: Int
    var reviewing: Bool
    var pinned: Bool
    var onOpen: () -> Void
    var onTogglePriority: () -> Void
    var onTogglePin: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(collection.name).font(.headline)
                        if collection.isDefault {
                            Text("Mặc định")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if dueCount > 0 {
                            Text("\(dueCount) đến hạn")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ReadoTheme.due)
                        }
                    }
                    Text("\(wordCount) từ")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Chip(title: reviewing ? "Đang ôn" : "Ôn nhanh", on: reviewing, action: onTogglePriority)
                if let onTogglePin, !collection.isDefault {
                    Chip(title: pinned ? "Home" : "Ghim", on: pinned, action: onTogglePin)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
