import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("reado.accent") private var accentId = "forest"
    @AppStorage("reado.notifyLocal") private var notifyLocal = false
    @State private var limitDraft = ""
    @State private var agentSheet: AgentSheet?

    var body: some View {
        Form {
            Section("Giao diện") {
                ThemeDots(accentId: $accentId)
                Text(ReadoTheme.accents.first(where: { $0.id == accentId })?.name ?? "Rừng")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Agent phân tích") {
                Picker("Agent", selection: Binding(
                    get: { store.settings.activeAgentId ?? SchemaSQL.proxyAgentId },
                    set: { try? store.setActiveAgent($0) }
                )) {
                    ForEach(store.agents) { agent in
                        Text(agentLabel(agent)).tag(agent.id)
                    }
                }
                HStack {
                    Button("Thêm") { agentSheet = .add }
                    Spacer()
                    if let current, !current.isProxy {
                        Button("Sửa") {
                            agentSheet = .edit(current)
                        }
                        Button("Xoá", role: .destructive) {
                            agentSheet = .delete(current)
                        }
                    }
                }
                Text("Key vào Keychain, không SQLite. Proxy vẫn mock — chưa gọi OpenAI.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Học tập") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trình độ")
                    LevelChips(selected: store.settings.cefrLevels) { level in
                        try? store.toggleCefr(level)
                    }
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("Thẻ mới / ngày")
                        Text("1–99 · onSubmit").font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("10", text: $limitDraft)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .onSubmit { commitLimit() }
                        .onChange(of: limitDraft) { _, _ in
                            if let n = Int(limitDraft), (1...99).contains(n), n != store.settings.dailyNewLimit {
                                try? store.setDailyNewLimit(n)
                            }
                        }
                }
                Stepper(value: Binding(
                    get: { store.settings.dayCutoffHour },
                    set: { try? store.setDayCutoffHour($0) }
                ), in: 0...23) {
                    VStack(alignment: .leading) {
                        Text("Giờ cắt ngày")
                        Text(String(format: "%02d:00", store.settings.dayCutoffHour))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Nhắc") {
                Toggle("Nhắc ôn (local, chưa APNs)", isOn: $notifyLocal)
            }
        }
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { limitDraft = String(store.settings.dailyNewLimit) }
        .sheet(item: $agentSheet) { sheet in
            AgentSheetView(sheet: sheet) { agentSheet = nil }
        }
    }

    private var current: AnalysisAgentRecord? {
        let id = store.settings.activeAgentId ?? SchemaSQL.proxyAgentId
        return store.agents.first(where: { $0.id == id })
    }

    private func agentLabel(_ agent: AnalysisAgentRecord) -> String {
        if agent.isProxy { return agent.name }
        return agent.hasKey ? "\(agent.name) · key" : "\(agent.name) · chưa key"
    }

    private func commitLimit() {
        if let n = Int(limitDraft), n >= 1 {
            try? store.setDailyNewLimit(n)
            limitDraft = String(store.settings.dailyNewLimit)
        } else {
            store.notify("daily_new_limit phải ≥ 1 — 0 sẽ tắt nhánh Học.")
            limitDraft = String(store.settings.dailyNewLimit)
        }
    }
}

enum AgentSheet: Identifiable {
    case add
    case edit(AnalysisAgentRecord)
    case delete(AnalysisAgentRecord)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let a): return "edit-\(a.id)"
        case .delete(let a): return "delete-\(a.id)"
        }
    }
}

struct AgentSheetView: View {
    @Environment(AppStore.self) private var store
    var sheet: AgentSheet
    var onClose: () -> Void
    @State private var name = ""
    @State private var base = "https://api.openai.com/v1"
    @State private var model = "gpt-4o-mini"
    @State private var key = ""

    var body: some View {
        NavigationStack {
            Group {
                if case .delete(let agent) = sheet {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Xoá \(agent.name)? Keychain trên máy cũng gỡ theo.")
                        Spacer()
                    }
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Huỷ", action: onClose) }
                        ToolbarItem(placement: .destructiveAction) {
                            Button("Xoá", role: .destructive) {
                                try? store.deleteAgent(id: agent.id)
                                onClose()
                            }
                        }
                    }
                } else {
                    Form {
                        TextField("Tên", text: $name)
                        TextField("Base URL", text: $base)
                        TextField("Model", text: $model)
                        SecureField("API key — Keychain, không SQLite", text: $key)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Huỷ", action: onClose) }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") { save() }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { prefill() }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: String {
        switch sheet {
        case .add: return "Thêm agent"
        case .edit: return "Sửa agent"
        case .delete: return "Xoá agent?"
        }
    }

    private func prefill() {
        if case .edit(let agent) = sheet {
            name = agent.name
            base = agent.baseUrl ?? ""
            model = agent.model ?? ""
        }
    }

    private func save() {
        switch sheet {
        case .add:
            try? store.addAgent(name: name, baseURL: base, model: model, apiKey: key.isEmpty ? nil : key)
        case .edit(let agent):
            try? store.updateAgent(id: agent.id, name: name, baseURL: base, model: model, apiKey: key.isEmpty ? nil : key)
        case .delete:
            break
        }
        onClose()
    }
}
