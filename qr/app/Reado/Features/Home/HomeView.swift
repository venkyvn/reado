import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [AppRoute]
    @Binding var tab: AppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { path.append(.settings) } label: {
                        Image(systemName: "gearshape").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Cài đặt")
                    Spacer()
                    Text("Reado").font(.headline)
                    Spacer()
                    Button { path.append(.data(nil)) } label: {
                        Image(systemName: "tray").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Dữ liệu")
                }

                VStack(spacing: 0) {
                    homeRow {
                        store.applyPersistedScope()
                        store.setBranch(.due)
                        tab = .review
                    } icon: {
                        Image(systemName: "brain").foregroundStyle(Color.accentColor)
                    } title: {
                        Text("Ôn \(store.persistedScopeTitle)").font(.headline)
                    } subtitle: {
                        Text("\(store.dueInScope(store.settings.persistedScopeIds)) thẻ đến hạn · phạm vi đổi ở Kho")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Divider().padding(.leading, 52)

                    homeRow {
                        path.append(.hub(store.inbox.id))
                    } icon: {
                        Image(systemName: "archivebox").foregroundStyle(Color.accentColor)
                    } title: {
                        HStack(spacing: 6) {
                            Text(store.inbox.name).font(.headline)
                            Text("Mặc định")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    } subtitle: {
                        Text("\(store.inboxCount) từ · trang chưa phân loại")
                            .font(.footnote).foregroundStyle(.secondary)
                    } trailing: {
                        dueBadge(store.dueByCollection[store.inbox.id] ?? 0)
                    }

                    Divider().padding(.leading, 52)

                    homeRow {
                        path.append(.streak)
                    } icon: {
                        Image(systemName: "flame.fill").foregroundStyle(ReadoTheme.due)
                    } title: {
                        Text("\(store.streakStats.current) ngày ôn liên tục")
                            .font(.headline).foregroundStyle(ReadoTheme.due)
                    } subtitle: {
                        Text("\(store.sessions.count) trang đã phân tích")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Đang đọc · \(store.pinnedCollections.count)/\(SchemaSQL.pinLimit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 0) {
                    if store.pinnedCollections.isEmpty {
                        Text("Ghim tối đa \(SchemaSQL.pinLimit) collection từ Kho. Kho tạm luôn ở trên, không tính vào \(SchemaSQL.pinLimit).")
                            .font(.footnote).foregroundStyle(.secondary)
                            .padding(16)
                    } else {
                        ForEach(Array(store.pinnedCollections.enumerated()), id: \.element.id) { index, collection in
                            homeRow {
                                path.append(.hub(collection.id))
                            } icon: {
                                Image(systemName: "mappin").foregroundStyle(Color.accentColor)
                            } title: {
                                Text(collection.name).font(.headline)
                            } subtitle: {
                                Text("\(store.vocabByCollection[collection.id] ?? 0) từ")
                                    .font(.footnote).foregroundStyle(.secondary)
                            } trailing: {
                                dueBadge(store.dueByCollection[collection.id] ?? 0)
                            }
                            if index < store.pinnedCollections.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(18)
            .padding(.bottom, 88)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func dueBadge(_ n: Int) -> some View {
        if n > 0 {
            Text("\(n) đến hạn")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ReadoTheme.due)
        }
    }

    private func homeRow<Icon: View, Title: View, Subtitle: View, Trailing: View>(
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder title: () -> Title,
        @ViewBuilder subtitle: () -> Subtitle,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon().frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    title()
                    subtitle()
                }
                Spacer(minLength: 8)
                trailing()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func homeRow<Icon: View, Title: View, Subtitle: View>(
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder title: () -> Title,
        @ViewBuilder subtitle: () -> Subtitle
    ) -> some View {
        homeRow(action: action, icon: icon, title: title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview {
    let store = try! AppStore(database: AppDatabase(inMemory: true))
    HomeView(path: .constant([]), tab: .constant(.home))
        .environment(store)
}
