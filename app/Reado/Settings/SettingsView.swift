import ReadoKit
import SwiftUI

/// FR-15 — J-R1-S: núm học tập (CEFR, hạn mức thẻ mới, giờ chuyển ngày) +
/// 3.12 nhắc ôn tập (toggle + giờ). FSRS không mở núm cho user (R1 dùng tham
/// số mặc định — tránh tự bắn chân). FR-21: nhiều key, một agent đang chọn.
/// ux-redesign-r1 T8 (Q-c): TỰ LƯU — không còn nút "Lưu", mọi núm lưu ngay khi đổi (ô số khi xong
/// nhập), nhất quán với chủ đề vốn đã áp ngay. Đổi giá trị không đóng màn.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Chủ đề màu nhấn — đổi ngay (UserDefaults).
    /// Mặc định mới là rừng (không còn "Hệ thống"); user cũ được migrate một
    /// lần ở ReadoApp.
    @AppStorage("appTheme") private var appTheme = AppTheme.forest.rawValue
    /// ADR-060/062 — tông nền đọc PDF, cùng key `@AppStorage` mà
    /// `PDFReaderView` đọc để vẽ lớp phủ (đổi ở đây thì reader áp ngay lần mở
    /// kế tiếp, giống cách `ShellTabBar` đọc chung `appTheme`). Dọn ra khỏi
    /// toolbar reader theo fen: "đem mấy config đó ra ngoài setting luôn đi".
    @AppStorage("readoPDFPageTintHue") private var pdfPageTintHueRaw = PDFPageTintHue.sepia.rawValue
    @AppStorage("readoPDFPageTintIntensity") private var pdfPageTintIntensity: Double = 0
    /// apple-ai-r1 T4 (ADR-061) — cùng key `AppleIntelligence.ocrFixDefaultsKey`
    /// mà `AppModel+Capture.runAnalysis` đọc. Mặc định BẬT (fen chốt 2026-10-05).
    @AppStorage(AppleIntelligence.ocrFixDefaultsKey) private var ocrFixEnabled = true

    @State private var cefrLevels: [CEFRLevel] = [.b2]
    @State private var dailyNewLimit = 10
    @State private var dayCutoffHour = 4
    @FocusState private var limitFieldFocused: Bool
    // 3.12 — nhắc ôn tập (local notification), default TẮT + 20:00.
    @State private var reminderEnabled = false
    @State private var reminderMinutes = 20 * 60
    @State private var didLoad = false
    /// Agent lên đầu danh sách khi VÀO màn mà chưa có agent chạy được (không có nó thì chụp không
    /// phân tích được). Chốt một lần lúc mở (`load`): thêm key xong section không nhảy xuống cuối.
    @State private var pinnedAgentFirst: Bool?
    /// Ảnh chụp giá trị đã nằm trong DB — chỉ lưu khi khác (đổi giá trị do `load()` không kéo theo
    /// lần lưu thừa) và để biết còn thay đổi chưa lưu lúc rời màn.
    @State private var lastSaved: Snapshot?
    @State private var autosaveTask: Task<Void, Never>?
    /// Lỗi lưu hiện inline ngay dưới section vừa đổi; giá trị trên UI giữ nguyên để sửa lại.
    @State private var learningError: String?
    @State private var reminderError: String?
    @State private var agents: [AnalysisAgent] = []
    @State private var activeAgentID = ""
    @State private var showAddAgent = false
    @State private var editingAgent: AnalysisAgent?
    @State private var agentError: String?

    /// Các giá trị lưu chung một lần ghi (`saveLearningSettings` nhận cả năm).
    private struct Snapshot: Equatable {
        var cefrLevels: [CEFRLevel]
        var dailyNewLimit: Int
        var dayCutoffHour: Int
        var reminderEnabled: Bool
        var reminderMinutes: Int
    }

    /// Nhóm núm vừa đổi — quyết định lỗi lưu hiện dưới section nào.
    private enum SettingsGroup {
        case learning, reminder
    }

    private var agentFirst: Bool { pinnedAgentFirst ?? !model.activeAgentReady }

    private var current: Snapshot {
        Snapshot(
            cefrLevels: cefrLevels,
            dailyNewLimit: Self.clampNewLimit(dailyNewLimit),
            dayCutoffHour: dayCutoffHour,
            reminderEnabled: reminderEnabled,
            reminderMinutes: reminderMinutes)
    }

    var body: some View {
        List {
            if agentFirst {
                agentSection
            }
            learningSection
            reminderSection
            themeSection
            pdfReadingSection
            if !agentFirst {
                agentSection
            }
        }
        .shellScrollChrome()
        // Chỉ các giá trị này: List không animate mỗi lần ô nhập/Picker đổi.
        .animation(reduceMotion ? nil : Motion.reveal, value: learningError)
        .animation(reduceMotion ? nil : Motion.reveal, value: reminderError)
        .animation(reduceMotion ? nil : Motion.reveal, value: reminderEnabled)
        .animation(reduceMotion ? nil : Motion.reveal, value: agentError)
        .animation(reduceMotion ? nil : Motion.reveal, value: pdfPageTintIntensity > 0)
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong") { limitFieldFocused = false }
            }
        }
        .onAppear { load() }
        // Push (không còn sheet) — rời màn thì lưu nốt phần còn chờ rồi reload Home (theme / agent
        // đổi sống). `saveLearningSettings` cũng reload sẵn.
        .onDisappear {
            saveNow()
            model.reloadOverview()
        }
        .sheet(isPresented: $showAddAgent) {
            AgentFormSheet(agent: nil) { name, base, modelName, key in
                finishAgentEdit(
                    model.addAgent(name: name, baseURL: base, model: modelName, apiKey: key))
            }
        }
        .sheet(item: $editingAgent) { agent in
            AgentFormSheet(agent: agent) { name, base, modelName, key in
                finishAgentEdit(
                    model.updateAgent(
                        agent, name: name, baseURL: base, model: modelName, apiKey: key))
            }
        }
        .onChange(of: cefrLevels) { scheduleAutosave(.learning) }
        .onChange(of: dailyNewLimit) { _, newValue in
            // Ô số: chỉ kẹp khi gõ, lưu lúc xong nhập (onSubmit / mất focus) — không lưu từng chữ số.
            let clamped = Self.clampNewLimit(newValue)
            if clamped != newValue { dailyNewLimit = clamped }
        }
        .onChange(of: limitFieldFocused) { _, focused in
            if !focused { saveNow(.learning) }
        }
        .onChange(of: dayCutoffHour) { scheduleAutosave(.learning) }
        .onChange(of: reminderEnabled) { scheduleAutosave(.reminder) }
        .onChange(of: reminderMinutes) { scheduleAutosave(.reminder) }
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
                    .onSubmit { saveNow(.learning) }
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
                Text("Trình độ áp cho lần chụp kế tiếp. Streak và hạn mức thẻ mới tính từ giờ chuyển ngày, không phải nửa đêm.")
                errorLine(learningError)
            }
        }
    }

    /// Dòng lỗi đỏ inline dưới section vừa đổi (không alert chặn).
    @ViewBuilder
    private func errorLine(_ message: String?) -> some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(Typo.meta)
                .foregroundStyle(Theme.danger)
                .revealTransition()
        }
    }

    /// Chip CEFR — bật/tắt; level đang chọn tô accent. Bỏ hết chip thì không lưu và hiện
    /// "Chọn ít nhất 1 mức" (FR-15 cần ≥ 1 mức) — xem `saveNow`.
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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(reminderEnabled
                     ? "Nhận thông báo mỗi ngày lúc \(ReminderService.describe(minutes: reminderMinutes))."
                     : "Bật để nhận lời nhắc ôn từ vựng hằng ngày.")
                errorLine(reminderError)
            }
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
                            Text(agent.model ?? "")
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
                    // ADR-049: `agents` chỉ chứa agent BYOK thật — hàng placeholder
                    // đã bị `AnalysisAgentStore.list()` lọc, không cần check ở đây.
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
            Button("Thêm key") { showAddAgent = true }
            if model.ocrFixAvailable {
                Toggle("Sửa lỗi OCR bằng Apple Intelligence", isOn: $ocrFixEnabled)
            }
            if let agentError {
                Text(agentError)
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
                    .revealTransition()
            }
        } header: {
            Label("Agent phân tích", systemImage: "sparkles")
        } footer: {
            // apple-ai-r1 T4 (ADR-061) — câu soát OCR chỉ hiện khi máy có Apple
            // Intelligence (ocrFixAvailable), nối sau câu gốc.
            Text(
                "Lần chụp kế tiếp dùng agent đang chọn. OCR trên máy, agent dịch và lấy từ. Key nằm trên máy, không vào file xuất."
                    + (model.ocrFixAvailable
                        ? " Apple Intelligence soát lỗi chữ OCR trên máy trước khi gửi agent."
                        : ""))
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
            Label("Giao diện", systemImage: "paintpalette")
        } footer: {
            Text("Màu nhấn toàn app — áp ngay.")
        }
    }

    // MARK: — Đọc PDF (tông nền, ADR-060/062)

    /// `.white` gộp vào cùng một Picker với các tông — chọn "Trắng" là tắt
    /// phủ (`pdfPageTintIntensity = 0`), chọn một tông là bật lại với độ đậm
    /// đã lưu (hoặc mặc định nếu đang tắt).
    private enum PDFPageTintChoice: Hashable {
        case white
        case hue(PDFPageTintHue)
    }

    private var pdfTintSelection: Binding<PDFPageTintChoice> {
        Binding(
            get: {
                pdfPageTintIntensity > 0
                    ? .hue(PDFPageTintHue(rawValue: pdfPageTintHueRaw) ?? .sepia)
                    : .white
            },
            set: { choice in
                switch choice {
                case .white:
                    pdfPageTintIntensity = 0
                case let .hue(hue):
                    pdfPageTintHueRaw = hue.rawValue
                    if pdfPageTintIntensity == 0 {
                        pdfPageTintIntensity = PDFPageTintHue.defaultIntensity
                    }
                }
            })
    }

    private var pdfReadingSection: some View {
        Section {
            Picker("Tông giấy", selection: pdfTintSelection) {
                Text("Trắng").tag(PDFPageTintChoice.white)
                ForEach(PDFPageTintHue.allCases) { hue in
                    Text(hue.label).tag(PDFPageTintChoice.hue(hue))
                }
            }
            // Chỉ hiện khi đã chọn một tông — kéo thả chỉnh độ đậm lớp phủ
            // (fen: "kéo thả độ màu của giấy").
            if pdfPageTintIntensity > 0 {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Độ đậm")
                        Spacer()
                        Text("\(Int(pdfPageTintIntensity * 100))%")
                            .font(Typo.meta)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $pdfPageTintIntensity, in: 0.05 ... 1)
                }
            }
        } header: {
            Label("Đọc PDF", systemImage: "doc.text")
        } footer: {
            Text("Tông nền trang khi đọc PDF trong Reado — áp ngay, không theo từng bộ.")
        }
    }

    // MARK: — Load / save

    private func load() {
        if pinnedAgentFirst == nil { pinnedAgentFirst = !model.activeAgentReady }
        if let settings = model.loadLearningSettings() {
            cefrLevels = settings.cefrLevels
            dailyNewLimit = settings.dailyNewLimit
            dayCutoffHour = settings.dayCutoffHour
            reminderEnabled = settings.reminderEnabled
            reminderMinutes = settings.reminderMinutes
            lastSaved = current
            didLoad = true
        }
        reloadAgents()
    }

    private func reloadAgents() {
        if let listed = model.loadAgents() {
            agents = listed.agents
            activeAgentID = listed.activeID
        }
    }

    /// Cập nhật lạc quan: dấu check đổi ngay lúc tap, không đợi DB/Keychain trả
    /// về mới vẽ lại (từng thấy khựng vì `setActive` kiểm Keychain lần hai —
    /// `agent.hasKey` ở đây đã có sẵn từ `list()`). Lỗi thì trả checkmark về chỗ cũ.
    private func select(_ agent: AnalysisAgent) {
        agentError = nil
        let previousActiveID = activeAgentID
        activeAgentID = agent.id
        do {
            try model.setActiveAgent(agent)
        } catch {
            activeAgentID = previousActiveID
            agentError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func remove(_ agent: AnalysisAgent) {
        agentError = nil
        do {
            try model.deleteAgent(agent)
            reloadAgents()
        } catch {
            agentError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// Kết quả `model.addAgent`/`updateAgent`: `nil` = đã lưu → xoá lỗi cũ + nạp
    /// lại danh sách; chuỗi = lỗi hiện trong sheet. Trả nguyên cho `AgentFormSheet`.
    private func finishAgentEdit(_ error: String?) -> String? {
        if error == nil {
            agentError = nil
            reloadAgents()
        }
        return error
    }

    /// Lưu sau một nhịp ngắn không đổi thêm — bánh xe giờ/giờ nhắc đổi liên tục lúc cuộn, mỗi lần lưu
    /// lại nạp overview + xếp lại lịch thông báo; chỉ giá trị cuối mới đáng ghi.
    private func scheduleAutosave(_ group: SettingsGroup) {
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            saveNow(group)
        }
    }

    /// Ghi các núm vào DB nếu có thay đổi chưa lưu. Lỗi → dòng đỏ dưới section `group`, giá trị trên UI
    /// GIỮ NGUYÊN (`lastSaved` không đổi nên lần đổi kế tiếp tự thử lại). Không bao giờ đóng màn.
    /// `group` nil (rời màn) → lỗi không có chỗ hiện, vẫn ghi DebugTrace qua model.
    private func saveNow(_ group: SettingsGroup? = nil) {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard didLoad else { return }
        dailyNewLimit = Self.clampNewLimit(dailyNewLimit)
        learningError = nil
        reminderError = nil
        guard !cefrLevels.isEmpty else {
            learningError = "Chọn ít nhất 1 mức"
            return
        }
        let snapshot = current
        guard snapshot != lastSaved else { return }
        do {
            try model.saveLearningSettings(
                cefrLevels: snapshot.cefrLevels,
                dailyNewLimit: snapshot.dailyNewLimit,
                dayCutoffHour: snapshot.dayCutoffHour,
                reminderEnabled: snapshot.reminderEnabled,
                reminderMinutes: snapshot.reminderMinutes)
            lastSaved = snapshot
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            switch group {
            case .reminder: reminderError = message
            case .learning, nil: learningError = message
            }
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
