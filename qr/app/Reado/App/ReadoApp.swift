import SwiftUI

@main
struct ReadoApp: App {
    @AppStorage("reado.accent") private var accentId = "forest"
    @State private var store: AppStore?

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    AppShell()
                        .environment(store)
                } else {
                    ProgressView("Đang mở kho…")
                }
            }
            .tint(ReadoTheme.accent(accentId))
            .task {
                if store == nil {
                    store = try? AppStore(database: AppDatabase(inMemory: false))
                }
            }
        }
    }
}
