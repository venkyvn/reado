import ReadoKit
import SwiftUI

/// ADR-041: Section "Bắt đầu với Reado" đầu Home — 3 bước, mỗi bước suy trạng
/// thái từ dữ liệu thật. Không trang mẫu (NG-03) — chỉ trỏ vào đúng luồng
/// thật (CEFR/agent/chụp).
struct OnboardingChecklistSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reado.onboarding.cefrConfirmed") private var cefrConfirmed = false
    @AppStorage("reado.onboarding.dismissed") private var dismissed = false
    @State private var showAgentForm = false
    @State private var cefrSubtitle = ""

    let onOpenSettings: () -> Void
    let onCapture: () -> Void

    private var checklist: OnboardingChecklist {
        OnboardingChecklist(
            cefrConfirmed: cefrConfirmed,
            agentReady: model.activeAgentReady,
            hasFirstPage: model.hasFirstPage,
            dismissed: dismissed)
    }

    var body: some View {
        if checklist.isVisible {
            Section {
                cefrRow
                agentRow
                firstPageRow
            } header: {
                Text("Bắt đầu với Reado · \(checklist.doneCount)/3")
            } footer: {
                Button("Ẩn hướng dẫn") {
                    Motion.run(reduceMotion: reduceMotion) { dismissed = true }
                }
                .font(.caption)
            }
            .onAppear { loadCefrSubtitle() }
            .sheet(isPresented: $showAgentForm) {
                AgentFormSheet(agent: nil) { name, base, modelName, key in
                    model.addAgent(name: name, baseURL: base, model: modelName, apiKey: key)
                }
            }
        }
    }

    private func loadCefrSubtitle() {
        let levels = model.loadLearningSettings()?.cefrLevels ?? [.b2]
        cefrSubtitle = "Đang lọc từ theo: " + levels.map(\.rawValue).joined(separator: ", ")
    }

    // MARK: — Bước 1: CEFR

    private var cefrRow: some View {
        checklistRow(
            done: checklist.isDone(.cefr),
            number: 1,
            title: "Trình độ đọc",
            subtitle: cefrSubtitle
        ) {
            if !checklist.isDone(.cefr) {
                HStack(spacing: 8) {
                    Button("Đổi") {
                        cefrConfirmed = true
                        onOpenSettings()
                    }
                    Button("Đúng") { cefrConfirmed = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: — Bước 2: Agent

    private var agentRow: some View {
        checklistRow(
            done: checklist.isDone(.agent),
            number: 2,
            title: "Kết nối agent phân tích",
            subtitle: checklist.isDone(.agent)
                ? "Đã kết nối — sẵn sàng phân tích trang"
                : "Mặc định AI-Box — dán API key một lần."
        ) {
            if !checklist.isDone(.agent) {
                Button("Thêm") { showAgentForm = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: — Bước 3: Trang đầu tiên

    private var firstPageRow: some View {
        checklistRow(
            done: checklist.isDone(.firstPage),
            number: 3,
            title: "Chụp trang sách đầu tiên",
            subtitle: checklist.isEnabled(.firstPage)
                ? "Trang giấy hoặc màn hình đều chụp được."
                : "Cần kết nối agent trước."
        ) {
            if !checklist.isDone(.firstPage) {
                Button("Chụp", action: onCapture)
                    .buttonStyle(.borderedProminent)
                    .disabled(!checklist.isEnabled(.firstPage))
            }
        }
    }

    // MARK: — Hàng dùng chung

    @ViewBuilder
    private func checklistRow<Actions: View>(
        done: Bool,
        number: Int,
        title: String,
        subtitle: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: 12) {
            // Icon + tiêu đề gộp lại một phần tử VoiceOver — nút hành động
            // GIỮ riêng bên ngoài, gộp chung sẽ làm VoiceOver không bấm được.
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                    .font(.title3)
                    .foregroundStyle(done ? Theme.ok : Color.accentColor)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(done ? "Đã xong" : "Chưa xong")
            Spacer()
            actions()
        }
        .buttonStyle(.borderless)
        .animation(reduceMotion ? nil : Motion.reveal, value: done)
    }
}
