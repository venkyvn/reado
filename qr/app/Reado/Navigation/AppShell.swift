import SwiftUI

enum AppTab: Hashable {
    case home, review, kho
}

enum AppRoute: Hashable {
    case capture(collectionId: String?)
    case vocab
    case settings
    case streak
    case data(String?)
    case hub(String)
    case collectionVocab(String)
    case session(collectionId: String, sessionId: String)
    case organize
}

struct AppShell: View {
    @Environment(AppStore.self) private var store
    @State private var tab: AppTab = .home
    @State private var homePath: [AppRoute] = []
    @State private var khoPath: [AppRoute] = []

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            TabView(selection: $tab) {
                NavigationStack(path: $homePath) {
                    HomeView(path: $homePath, tab: $tab)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(route, path: $homePath)
                        }
                }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

                NavigationStack {
                    ReviewView()
                }
                .tabItem { Label("Ôn", systemImage: "brain") }
                .tag(AppTab.review)

                NavigationStack(path: $khoPath) {
                    CollectionsView(path: $khoPath)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(route, path: $khoPath)
                        }
                }
                .tabItem { Label("Kho", systemImage: "archivebox") }
                .tag(AppTab.kho)
            }
            if showShutter {
                VStack {
                    Spacer()
                    FloatShutter { openCapture() }
                        .padding(.bottom, 84)
                }
            }
            if let toast = store.toast {
                VStack {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .onTapGesture { store.toast = nil }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: store.toast) { _, value in
            guard value != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                if store.toast == value { store.toast = nil }
            }
        }
        .onChange(of: store.pendingHubId) { _, id in
            guard let id else { return }
            tab = .kho
            homePath = []
            khoPath = [.hub(id)]
            store.pendingHubId = nil
        }
        .onChange(of: store.pendingReview) { _, go in
            guard go else { return }
            tab = .review
            store.pendingReview = false
        }
    }

    private var showShutter: Bool {
        switch tab {
        case .review: return false
        case .home: return isCaptureCapable(homePath)
        case .kho: return isCaptureCapable(khoPath)
        }
    }

    private func isCaptureCapable(_ path: [AppRoute]) -> Bool {
        if path.isEmpty { return true }
        if path.count == 1, case .hub = path[0] { return true }
        return false
    }

    private func openCapture() {
        let dest: String
        if tab == .kho, case .hub(let id) = khoPath.last {
            dest = id
        } else if tab == .home, case .hub(let id) = homePath.last {
            dest = id
        } else {
            dest = store.inbox.id
        }
        store.beginCapture(collectionId: dest)
        let route = AppRoute.capture(collectionId: dest)
        if tab == .home {
            homePath.append(route)
        } else {
            khoPath.append(route)
        }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute, path: Binding<[AppRoute]>) -> some View {
        switch route {
        case .capture(let collectionId):
            CaptureView(path: path, collectionId: collectionId)
                .toolbar(.hidden, for: .tabBar)
        case .vocab:
            VocabPickerView(path: path)
                .toolbar(.hidden, for: .tabBar)
        case .settings:
            SettingsView()
        case .streak:
            StreakView(tab: $tab)
        case .data(let col):
            DataView(preselected: col)
        case .hub(let id):
            CollectionHubView(path: path, collectionId: id)
        case .collectionVocab(let id):
            CollectionVocabView(path: path, collectionId: id)
        case .session(let collectionId, let sessionId):
            SessionDetailView(path: path, collectionId: collectionId, sessionId: sessionId)
                .toolbar(.hidden, for: .tabBar)
        case .organize:
            OrganizeInboxView(path: path)
                .toolbar(.hidden, for: .tabBar)
        }
    }
}
