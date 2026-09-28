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
        // Chỉ bốn giá trị này: List không animate mỗi lần Stepper/Picker đổi.
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
        .onChange(of: dailyNewLimit) { saved = false }
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
            Stepper(value: $dailyNewLimit, in: 0...999) {
                HStack {
                    Text("Thẻ mới mỗi ngày")
                    Spacer()
                    Text("\(dailyNewLimit)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            // Giờ chuyển ngày (FR-11/14) — streak & hạn mức quy theo giờ này.
            Stepper(value: $dayCutoffHour, in: 0...23) {
                HStack {
                    Label("Giờ chuyển ngày", systemImage: "bed.double")
                    Spacer()
                    Text(Self.hourLabel(dayCutoffHour))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
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
}

/// Mẫu điền sẵn khi thêm agent mới — AI-Box mặc định (giá cạnh tranh, đã đo
/// timeout thật 2026-09-26). Chỉ hiện lúc thêm mới, không hiện lúc sửa.
enum AgentPreset: String, CaseIterable, Identifiable {
    case aibox, gemini, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .aibox: "AI-Box"
        case .gemini: "Gemini"
        case .custom: "Tuỳ chỉnh"
        }
    }
}

/// Form dùng chung cho thêm/sửa agent OpenAI-compatible.
/// U2 ux-polish-r1 (ADR-041): dùng lại từ `OnboardingChecklistSection`, không
/// còn `private` — nội bộ vẫn chỉ gọi từ cùng target `Reado`.
struct AgentFormSheet: View {
    let agent: AnalysisAgent?
    var onSave: (String, String, String, String?) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var preset: AgentPreset = .aibox
    @State private var name: String
    @State private var baseURL: String
    @State private var model: String
    @State private var apiKey: String
    @State private var error: String?
    @State private var keyStatus: KeyCheck = .idle
    @State private var checkTask: Task<Void, Never>?

    init(
        agent: AnalysisAgent?,
        onSave: @escaping (String, String, String, String?) -> String?
    ) {
        self.agent = agent
        self.onSave = onSave
        _name = State(initialValue: agent?.name ?? "AI-Box")
        _baseURL = State(initialValue: agent?.baseURL ?? AnalysisAgentStore.aiboxBaseURL)
        _model = State(initialValue: agent?.model ?? AnalysisAgentStore.aiboxModel)
        _apiKey = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if agent == nil {
                    Picker("Mẫu", selection: $preset) {
                        ForEach(AgentPreset.allCases) { p in Text(p.label).tag(p) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: preset) { applyPreset() }
                }
                TextField("Tên", text: $name)
                TextField("Base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Thường kết thúc bằng /v1, không kèm /chat/completions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Model", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    SecureField(agent == nil ? "API key" : "API key mới (không bắt buộc)", text: $apiKey)
                    keyMark
                }
                keyCaption
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }
            }
            .navigationTitle(agent == nil ? "Thêm agent" : "Sửa agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(agent == nil ? "Thêm" : "Lưu") { submit() }
                        .disabled(!canSubmit)
                }
            }
            .onChange(of: apiKey) { scheduleKeyCheck() }
            .onChange(of: baseURL) { scheduleKeyCheck() }
            .onDisappear { checkTask?.cancel() }
        }
    }

    @ViewBuilder
    private var keyMark: some View {
        switch keyStatus {
        case .idle:
            if agent != nil {
                Text("Để trống để giữ API key hiện tại.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .checking:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Đang kiểm tra key")
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.ok)
                .symbolEffect(.bounce, value: keyStatus)
                .accessibilityLabel("Key hợp lệ")
        case .invalid:
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.danger)
                .symbolEffect(.bounce, value: keyStatus)
                .accessibilityLabel("Key không hợp lệ")
        }
    }

    @ViewBuilder
    private var keyCaption: some View {
        switch keyStatus {
        case .idle:
            EmptyView()
        case .checking:
            Text("Đang kiểm tra key…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .valid:
            Text("Key dùng được")
                .font(.footnote)
                .foregroundStyle(Theme.ok)
        case let .invalid(message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.danger)
        }
    }

    /// Đổi mẫu → điền sẵn tên/base/model; "Tuỳ chỉnh" giữ nguyên giá trị đang gõ.
    private func applyPreset() {
        switch preset {
        case .aibox:
            name = "AI-Box"
            baseURL = AnalysisAgentStore.aiboxBaseURL
            model = AnalysisAgentStore.aiboxModel
        case .gemini:
            name = "Gemini"
            baseURL = AnalysisAgentStore.geminiBaseURL
            model = AnalysisAgentStore.geminiModel
        case .custom:
            break
        }
    }

    private func scheduleKeyCheck() {
        checkTask?.cancel()
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = baseURL
        guard !key.isEmpty else {
            keyStatus = .idle
            return
        }
        keyStatus = .checking
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            let verdict = await AgentKeyChecker.check(baseURL: base, apiKey: key)
            guard !Task.isCancelled else { return }
            switch verdict {
            case .valid:
                keyStatus = .valid
            case let .invalid(message):
                keyStatus = .invalid(message)
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacementKey = trimmedKey.isEmpty ? nil : trimmedKey
        if let message = onSave(name, baseURL, model, replacementKey) {
            error = message
        } else {
            dismiss()
        }
    }

    private var canSubmit: Bool {
        let fieldsAreValid =
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AgentURLRule.allows(AgentURLRule.storedBase(baseURL))
        guard fieldsAreValid else { return false }
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return agent != nil
        }
        return keyStatus == .valid
    }
}

enum KeyCheck: Equatable {
    case idle
    case checking
    case valid
    case invalid(String)
}