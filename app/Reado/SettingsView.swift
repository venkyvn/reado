import ReadoKit
import SwiftUI

/// FR-15 — J-R1-S: núm học tập (CEFR, hạn mức thẻ mới, giờ chuyển ngày) +
/// 3.12 nhắc ôn tập (toggle + giờ). FSRS không mở núm cho user (R1 dùng tham
/// số mặc định — tránh tự bắn chân). FR-21: nhiều key, một agent đang chọn.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .sheet(isPresented: $showAddAgent) {
            AddAgentSheet { name, base, modelName, key in
                addAgent(name: name, baseURL: base, model: modelName, apiKey: key)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Trình độ")
                    Spacer()
                    Text("\(cefrLevels.count)/4")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
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
            if saved {
                Text("Đã lưu · có hiệu lực từ lần chụp / ôn kế tiếp.")
                    .revealTransition()
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
                .padding(.horizontal, 14)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(agent.name)
                            Text(agent.isBuiltinProxy ? "Proxy Reado" : (agent.model ?? ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if agent.id == activeAgentID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    if !agent.isBuiltinProxy {
                        Button(role: .destructive) { remove(agent) } label: {
                            Text("Xoá")
                        }
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
            Text("Lần chụp kế tiếp dùng agent đang chọn. Một lần gọi đọc trang, dịch và lấy từ. Key nằm trên máy, không vào file xuất.")
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

    private func select(_ agent: AnalysisAgent) {
        guard let database = model.database else { return }
        agentError = nil
        do {
            try AnalysisAgentStore.setActive(on: database, id: agent.id)
            activeAgentID = agent.id
        } catch {
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
    private func addAgent(name: String, baseURL: String, model: String, apiKey: String) -> String? {
        guard let database = self.model.database else { return "Chưa mở được kho" }
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

/// Sheet thêm một key OpenAI-compat. Mặc định điền endpoint Gemini.
private struct AddAgentSheet: View {
    var onSave: (String, String, String, String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name = "Gemini"
    @State private var baseURL = AnalysisAgentStore.geminiBaseURL
    @State private var model = AnalysisAgentStore.geminiModel
    @State private var apiKey = ""
    @State private var error: String?
    @State private var keyStatus: KeyCheck = .idle
    @State private var checkTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tên", text: $name)
                TextField("Base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Model", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    SecureField("API key", text: $apiKey)
                    keyMark
                }
                keyCaption
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }
            }
            .navigationTitle("Thêm key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Thêm") { submit() }
                        .disabled(keyStatus != .valid)
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
            EmptyView()
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
        guard keyStatus == .valid else { return }
        if let message = onSave(name, baseURL, model, apiKey) {
            error = message
        } else {
            dismiss()
        }
    }
}

private enum KeyCheck: Equatable {
    case idle
    case checking
    case valid
    case invalid(String)
}