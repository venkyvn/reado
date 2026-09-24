import SwiftUI

struct SessionDetailView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    var collectionId: String
    var sessionId: String
    @State private var open: Set<String> = []
    @State private var showSummary = false

    var body: some View {
        let session = store.sessions.first { $0.id == sessionId && $0.collectionId == collectionId }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Hub") { path.removeLast() }.frame(minHeight: 44)
                    Spacer()
                    Text(session?.title ?? "Phiên").font(.headline)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                if session == nil {
                    Text("Session đã trôi — song ngữ và summary không còn. Từ đã lưu vẫn ở kho collection.")
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button("Mở kho từ") { path.append(.collectionVocab(collectionId)) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if let session {
                    ForEach(session.segments) { segment in
                        SegmentBlock(
                            sourceEn: segment.sourceEn,
                            translationVi: segment.translationVi,
                            emphasized: true,
                            open: Binding(
                                get: { open.contains(segment.id) },
                                set: { on in
                                    if on { open.insert(segment.id) } else { open.remove(segment.id) }
                                }
                            )
                        )
                    }
                    if showSummary {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Ý chính")
                            Text(session.summaryVi)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Button("Xem tóm tắt") { showSummary = true }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    Eyebrow(text: "Từ phiên này")
                    sessionVocab(session)
                }
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func sessionVocab(_ session: ReadingSession) -> some View {
        let items = (try? store.vocab(in: collectionId))?.filter { session.vocabIds.contains($0.id) } ?? []
        if items.isEmpty {
            Text("Không giữ từ nào lúc picker.").font(.footnote).foregroundStyle(.secondary)
        } else {
            ForEach(items) { item in
                VStack(alignment: .leading) {
                    Text(item.term).font(.headline)
                    Text("\(item.pos) · \(item.meaningVi)").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }
}
