import Foundation

/// ADR-041: checklist bắt đầu trên Home — 3 bước, mỗi bước suy trạng thái từ
/// dữ liệu thật (không lưu tiến trình riêng vào DB). Không trang mẫu (NG-03).
public struct OnboardingChecklist: Equatable, Sendable {
    public enum Step: Int, CaseIterable, Sendable {
        case cefr, agent, firstPage
    }

    public let cefrConfirmed: Bool
    public let agentReady: Bool
    public let hasFirstPage: Bool
    public let dismissed: Bool

    public init(
        cefrConfirmed: Bool, agentReady: Bool, hasFirstPage: Bool, dismissed: Bool
    ) {
        self.cefrConfirmed = cefrConfirmed
        self.agentReady = agentReady
        self.hasFirstPage = hasFirstPage
        self.dismissed = dismissed
    }

    /// Đã có trang đầu tiên thì coi như CEFR đã được dùng thật — user cũ
    /// (cài lại app, chưa từng bấm "Đúng") không bị hỏi lại.
    public func isDone(_ step: Step) -> Bool {
        switch step {
        case .cefr: cefrConfirmed || hasFirstPage
        case .agent: agentReady
        case .firstPage: hasFirstPage
        }
    }

    /// Chụp cần agent chạy được — khoá bước 3 tới khi xong bước 2.
    public func isEnabled(_ step: Step) -> Bool {
        step != .firstPage || agentReady
    }

    public var doneCount: Int {
        Step.allCases.filter(isDone).count
    }

    /// Ẩn khi user chủ động tắt, hoặc agent + trang đầu đều đã xong (user cũ
    /// như owner không thấy checklist mỗi lần mở app).
    public var isVisible: Bool {
        !dismissed && !(agentReady && hasFirstPage)
    }
}
