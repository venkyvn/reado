import ReadoKit
import SwiftUI

/// FR-23/ADR-059 (pdf-nav-r1) — sheet Mục lục: đọc outline sẵn có trong file
/// PDF (`PDFNavigation.outlineEntries`), KHÔNG tự sinh mục lục từ nội dung.
/// Mục không có `pageIndex` (không trỏ tới trang nào) hiện mờ, không bấm được.
struct PDFOutlineSheet: View {
    let entries: [PDFNavigation.OutlineEntry]
    let currentEntryID: Int?
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(entries) { entry in
                    row(entry)
                }
                .onAppear {
                    guard let currentEntryID else { return }
                    proxy.scrollTo(currentEntryID, anchor: .center)
                }
            }
            .navigationTitle("Mục lục")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .appErrorAlert()
    }

    @ViewBuilder
    private func row(_ entry: PDFNavigation.OutlineEntry) -> some View {
        let isCurrent = entry.id == currentEntryID
        Button {
            guard let pageIndex = entry.pageIndex else { return }
            Haptics.selection()
            dismiss()
            onSelect(pageIndex)
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(entry.label)
                    .font(Typo.rowSubtitle)
                    .lineLimit(1)
                Spacer()
                if let pageIndex = entry.pageIndex {
                    Text("tr. \(pageIndex + 1)")
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                }
                if isCurrent {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, CGFloat(min(entry.depth, 3)) * Spacing.md)
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .disabled(entry.pageIndex == nil)
        .id(entry.id)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }
}
