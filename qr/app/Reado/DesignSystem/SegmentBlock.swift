import SwiftUI

struct SegmentBlock: View {
    var sourceEn: String
    var translationVi: String
    var emphasized: Bool = false
    @Binding var open: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(sourceEn)
                    .font(emphasized ? .title2 : .body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    open.toggle()
                } label: {
                    Text("dịch")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .frame(minHeight: 28)
                        .foregroundStyle(open ? Color.white : Color.accentColor.opacity(0.9))
                        .background(open ? Color.accentColor : Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                        .opacity(open ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? "Ẩn dịch" : "Hiện dịch")
            }
            if open {
                Text(translationVi)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { open.toggle() }
        .animation(ReadoTheme.spring, value: open)
    }
}
