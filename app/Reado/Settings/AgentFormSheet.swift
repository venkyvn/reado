import ReadoKit
import SwiftUI

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
/// U2 ux-polish-r1 (ADR-041): dùng lại từ hero Home (`HomeTabView`, bước kết nối agent), không
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
