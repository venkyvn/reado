import ReadoKit
import SwiftUI

/// FR-15 — J-R1-S: núm học tập (CEFR, hạn mức thẻ mới, giờ chuyển ngày) +
/// 3.12 nhắc ôn tập (toggle + giờ). FSRS không mở núm cho user (R1 dùng tham
/// số mặc định — tránh tự bắn chân). FR-21: nhiều key, một agent đang chọn.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    /// Chủ đề màu nhấn — đổi ngay (UserDefaults), KHÔNG nằm trong luồng "Lưu".
    /// Mặc định mới là rừng (không còn "Hệ thống"); user cũ được migrate một
    /// lần ở ReadoApp.
    @AppStorage("appTheme") private var appTheme = AppTheme.forest.rawValue

    @State private var cefrLevels: [CEFRLevel] = [.b2]
    @State private var dailyNewLimit = 10
    @State private var dayCutoffHour = 4
    @FocusState private var limitFieldFocused: Bool
    // 3.12 — nhắc ôn tập (local notification), default TẮT + 20:00.
    @State private var reminderEnabled = false
    @State private var reminderMinutes = 20 * 60
    @State private var didLoad = false
    @State private var saveError: String?
    @State private var saved = false
    @State private var agents: [AnalysisAgent] = []
    @State private var activeAgentID = ""
    @State private var showAddAgent = false
    @State private var editingAgent: AnalysisAgent?
    @State private var agentError: String?

    var body: some View {
        List {
            learningSection
            reminderSection
            themeSection
            agentSection
            if let message = saveError {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .shellScrollChrome()
        // Chỉ bốn giá trị này: List không animate mỗi lần ô nhập/Picker đổi.
        .animation(reduceMotion ? nil : Motion.reveal, value: saveError)
        .animation(reduceMotion ? nil : Motion.reveal, value: saved)
        .animation(reduceMotion ? nil : Motion.reveal, value: reminderEnabled)
        .animation(reduceMotion ? nil : Motion.reveal, value: agentError)
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") { save() }
                    .disabled(!didLoad)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong") { limitFieldFocused = false }
            }
        }
        .onAppear { load() }
        // Push (không còn sheet) — reload Home khi pop, kể cả khi không bấm Lưu
        // (theme / agent đổi sống). `saveLearningSettings` cũng reload sẵn.
        .onDisappear { model.reloadOverview() }
        .sheet(isPresented: $showAddAgent) {
            AgentFormSheet(agent: nil) { name, base, modelName, key in
                addAgent(name: name, baseURL: base, model: modelName, apiKey: key)
            }
        }
        .sheet(item: $editingAgent) { agent in
            AgentFormSheet(agent: agent) { name, base, modelName, key in
                updateAgent(
                    agent,
                    name: name,
                    baseURL: base,
                    model: modelName,
                    apiKey: key)
            }
        }
        .onChange(of: cefrLevels) { saved = false }
        .onChange(of: dailyNewLimit) { _, newValue in
            saved = false
            let clamped = Self.clampNewLimit(newValue)
            if clamped != newValue { dailyNewLimit = clamped }
        }
        .onChange(of: dayCutoffHour) { saved = false }
        .onChange(of: reminderEnabled) { saved = false }
        .onChange(of: reminderMinutes) { saved = false }
    }

    /// Giờ nhắc chọn được — bước 15' từ 00:00 tới 23:45 (khớp `reminderMinutes`).
    private static let reminderOptions = Array(stride(from: 0, to: 24 * 60, by: 15))

    // MARK: — Học tập (editable)

    private var learningSection: some View {
        Section {
            // CEFR đa level (port UI lab §8) — target cho lần phân tích trang KẾ
            // TIẾP (FR-15). Tối thiểu 1 level (không bỏ chip cuối cùng).
            VStack(alignment: .leading, spacing: Spacing.row) {
                HStack {
                    Text("Trình độ")
                    Spacer()
                    Text("\(cefrLevels.count)/4")
                        .font(Typo.meta)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: Spacing.sm) {
                    ForEach(CEFRLevel.allCases) { level in
                        levelChip(level)
                    }
                }
            }

            // Hạn mức thẻ mới/ngày (FR-11) — 0 hợp lệ (D-lim-0), trần 999.
            HStack {
                Text("Thẻ mới mỗi ngày")
                Spacer()
                TextField("0", value: $dailyNewLimit, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 80)
                    .focused($limitFieldFocused)
            }

            // Giờ chuyển ngày (FR-11/14) — streak & hạn mức quy theo giờ này.
            // Cùng kiểu wheel với "Giờ nhắc" bên dưới — đồng bộ UI.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("Giờ chuyển ngày", systemImage: "bed.double")
                Picker("Giờ chuyển ngày", selection: $dayCutoffHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(Self.hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 120)
            }
        } header: {
            Label("Học tập", systemImage: "book.closed")
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Streak và hạn mức thẻ mới tính từ giờ này, không phải nửa đêm.")
                if saved {
                    Text("Đã lưu · có hiệu lực từ lần chụp / ôn kế tiếp.")
                        .revealTransition()
                }
            }
        }
    }

    /// Chip CEFR — bật/tắt; level đang chọn tô accent. Giữ tối thiểu 1 level.
    private func levelChip(_ level: CEFRLevel) -> some View {
        let isSelected = cefrLevels.contains(level)
        return Button {
            let previous = cefrLevels
            toggleLevel(level)
            if cefrLevels != previous { Haptics.selection() }
        } label: {
            Text(level.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, Spacing.row)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(
                        isSelected ? Color.accentColor : Theme.surfaceStrong))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trình độ \(level.rawValue)")
        .accessibilityValue(isSelected ? "đang chọn" : "bỏ chọn")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggleLevel(_ level: CEFRLevel) {
        if cefrLevels.contains(level) {
            guard cefrLevels.count > 1 else { return }  // giữ tối thiểu 1
            cefrLevels.removeAll { $0 == level }
        } else {
            cefrLevels.append(level)
        }
    }

    // MARK: — Nhắc ôn tập (3.12)

    private var reminderSection: some View {
        Section {
            Toggle("Bật nhắc ôn tập", isOn: $reminderEnabled)
            if reminderEnabled {
                Picker("Giờ nhắc", selection: $reminderMinutes) {
                    ForEach(Self.reminderOptions, id: \.self) { minutes in
                        Text(ReminderService.describe(minutes: minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .revealTransition()
            }
        } header: {
            Label("Nhắc ôn tập", systemImage: "bell")
        } footer: {
            Text(reminderEnabled
                 ? "Nhận thông báo mỗi ngày lúc \(ReminderService.describe(minutes: reminderMinutes))."
                 : "Bật để nhận lời nhắc ôn từ vựng hằng ngày.")
        }
    }

    // MARK: — Agent phân tích (FR-21)

    private var agentSection: some View {
        Section {
            ForEach(agents) { agent in
                Button {
                    select(agent)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.tight) {
                            Text(agent.name)
                            Text(agent.isBuiltinProxy ? "Proxy Reado" : (agent.model ?? ""))
                                .font(Typo.meta)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if agent.id == activeAgentID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !agent.isBuiltinProxy {
                        Button {
                            editingAgent = agent
                        } label: {
                            Label("Sửa", systemImage: "pencil")
                        }
                        .tint(Color.accentColor)

                        Button(role: .destructive) { remove(agent) } label: {
                            Label("Xoá", systemImage: "trash")
                        }
                        .tint(Theme.danger)
                    }
                }
            }
            Button("Thêm key") { showAddAgent = true }
            if let agentError {
                Text(agentError)
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
                    .revealTransition()
            }
        } header: {
            Label("Agent phân tích", systemImage: "sparkles")
        } footer: {
            Text("Lần chụp kế tiếp dùng agent đang chọn. OCR trên máy, agent dịch và lấy từ. Key nằm trên máy, không vào file xuất.")
        }
    }

    // MARK: — Chủ đề (màu nhấn)

    private var themeSection: some View {
        Section {
            Picker("Chủ đề", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.title, systemImage: theme.icon)
                        .tag(theme.rawValue)
                }
            }
        } header: {
            Label("Chủ đề", systemImage: "paintpalette")
        } footer: {
            Text("Màu nhấn toàn app — áp ngay, không cần bấm Lưu.")
        }
    }

    // MARK: — Load / save

    private func load() {
        guard let database = model.database else { return }
        if let settings = try? SettingsService.load(on: database) {
            cefrLevels = settings.cefrLevels
            dailyNewLimit = settings.dailyNewLimit
            dayCutoffHour = settings.dayCutoffHour
            reminderEnabled = settings.reminderEnabled
            reminderMinutes = settings.reminderMinutes
            didLoad = true
        }
        reloadAgents()
    }

    private func reloadAgents() {
        guard let database = model.database else { return }
        if let listed = try? AnalysisAgentStore.list(on: database) {
            agents = listed.agents
            activeAgentID = listed.activeID
        }
    }

    /// Cập nhật lạc quan: dấu check đổi ngay lúc tap, không đợi DB/Keychain trả
    /// về mới vẽ lại (từng thấy khựng vì `setActive` kiểm Keychain lần hai —
    /// `agent.hasKey` ở đây đã có sẵn từ `list()`). Lỗi thì trả checkmark về chỗ cũ.
    private func select(_ agent: AnalysisAgent) {
        guard let database = model.database else { return }
        agentError = nil
        let previousActiveID = activeAgentID
        activeAgentID = agent.id
        do {
            try AnalysisAgentStore.setActive(on: database, id: agent.id, knownHasKey: agent.hasKey)
        } catch {
            activeAgentID = previousActiveID
            agentError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func remove(_ agent: AnalysisAgent) {
        guard let database = model.database else { return }
        agentError = nil
        do {
            try AnalysisAgentStore.delete(on: database, id: agent.id)
            reloadAgents()
        } catch {
            agentError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// `nil` = đã lưu. Chuỗi = lỗi hiện trong sheet.
    private func addAgent(
        name: String,
        baseURL: String,
        model: String,
        apiKey: String?
    ) -> String? {
        guard let database = self.model.database else { return "Chưa mở được kho" }
        guard let apiKey else { return "Thiếu API key" }
        do {
            try AnalysisAgentStore.add(
                on: database,
                name: name,
                baseURL: baseURL,
                model: model,
                apiKey: apiKey)
            agentError = nil
            reloadAgents()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// Key để trống khi sửa = giữ secret đang có trong Keychain.
    private func updateAgent(
        _ agent: AnalysisAgent,
        name: String,
        baseURL: String,
        model: String,
        apiKey: String?
    ) -> String? {
        guard let database = self.model.database else { return "Chưa mở được kho" }
        do {
            try AnalysisAgentStore.update(
                on: database,
                id: agent.id,
                name: name,
                baseURL: baseURL,
                model: model,
                apiKey: apiKey)
            agentError = nil
            reloadAgents()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func save() {
        saveError = nil
        dailyNewLimit = Self.clampNewLimit(dailyNewLimit)
        do {
            try model.saveLearningSettings(
                cefrLevels: cefrLevels,
                dailyNewLimit: dailyNewLimit,
                dayCutoffHour: dayCutoffHour,
                reminderEnabled: reminderEnabled,
                reminderMinutes: reminderMinutes)
            saved = true
            Haptics.success()
            dismiss()
        } catch {
            saveError =
                (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            Haptics.error()
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    /// Kẹp ô nhập "Thẻ mới mỗi ngày" — D-lim-0 hợp lệ, trần 999.
    static func clampNewLimit(_ value: Int) -> Int {
        min(max(value, 0), 999)
    }
}
