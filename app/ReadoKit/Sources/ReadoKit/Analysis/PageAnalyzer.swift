import Foundation

/// Cổng giao tiếp với AI (FR-02). UI chỉ thấy protocol này — đổi provider
/// không đụng SwiftUI (ADR-028). Một lần gọi multimodal: OCR + dịch + vocab.
public protocol PageAnalyzer: Sendable {
    func analyze(
        image: Data,
        imageMime: String,
        cefr: String,
        imageHash: String
    ) async throws -> PageAnalysis
}

/// Nhà máy chọn analyzer theo agent đang active (FR-21). Walking skeleton đi
/// proxy mặc định; khi proxy chưa có (0.7) dùng mock để owner test UI trước.
public enum AnalyzerFactory {
    public static let proxyBaseURL = "https://proxy.reado.app"

    /// Tạo analyzer cho agent id. R1: proxy builtin luôn có; mock chỉ cho dev/test.
    public static func analyzer(
        for kind: String,
        baseURL: String?,
        model: String?
    ) -> PageAnalyzer {
        switch kind {
        case "openai_compat":
            // FR-21 — chưa implement UI; walking skeleton chỉ proof UI với mock.
            return MockAnalyzer()
        case "reado_proxy":
            // Proxy hosting chưa deploy (0.7) → mock để owner test walking skeleton.
            return MockAnalyzer()
        default:
            return MockAnalyzer()
        }
    }
}

/// Analyzer giả cho walking skeleton (FR-02 loẹt step UI trước khi proxy 0.7 có).
/// KHÔNG phải bằng chứng A-01/A-02 — prompt baseline chưa dán (rulebook mục 8).
/// Trả về dữ liệu mẫu để owner xem flow UI: segments + vocab + summary.
public struct MockAnalyzer: PageAnalyzer {
    public init() {}

    public func analyze(
        image _: Data,
        imageMime _: String,
        cefr _: String,
        imageHash: String
    ) async throws -> PageAnalysis {
        // Mô phỏng độ trễ network để UI progress dễ thấy.
        try await Task.sleep(nanoseconds: 1_200_000_000)

        let sample =
            "The old lighthouse stood on the cliff, battered by winter storms. "
            + "Each morning the keeper climbed its winding stairs to trim the flame, "
            + "a task that had shaped his life for over forty years."

        return PageAnalysis(
            segments: [
                .init(
                    sourceEN:
                        "The old lighthouse stood on the cliff, battered by winter storms.",
                    translationVI:
                        "Ngọn hải đăng cũ đứng trên vách đá, bị bão mùa đông dày vò."),
                .init(
                    sourceEN:
                        "Each morning the keeper climbed its winding stairs to trim the flame, a task that had shaped his life for over forty years.",
                    translationVI:
                        "Mỗi sáng người gác đèn leo lên cầu thang quanh co để chăm ngọn lửa, một công việc đã định hình cuộc đời ông suốt hơn bốn mươi năm."),
            ],
            vocabulary: [
                .init(
                    term: "battered",
                    pos: "adj",
                    ipa: "/ˈbætərd/",
                    meaningVI: "hư hại, dày vò",
                    cefr: "B2",
                    example:
                        "The old lighthouse stood on the cliff, battered by winter storms.",
                    verification: .verified),
                .init(
                    term: "winding",
                    pos: "adj",
                    ipa: "/ˈwaɪndɪŋ/",
                    meaningVI: "quanh co, uốn khúc",
                    cefr: "B2",
                    example:
                        "Each morning the keeper climbed its winding stairs to trim the flame.",
                    verification: .verified),
                .init(
                    term: "trim",
                    pos: "verb",
                    ipa: "/trɪm/",
                    meaningVI: "chăm sóc, tỉa gọn",
                    cefr: "B2",
                    example:
                        "Each morning the keeper climbed its winding stairs to trim the flame.",
                    verification: .suspect),
                .init(
                    term: "shaped",
                    pos: "verb",
                    ipa: "/ʃeɪpt/",
                    meaningVI: "định hình, hình thành",
                    cefr: "B1",
                    example:
                        "A task that had shaped his life for over forty years",
                    verification: .unverified),
            ],
            summaryVI:
                "Mô tả ngọn hải đăng cổ và người gác đèn già — công việc quen thuộc mỗi sáng đã gắn bó với ông suốt hơn bốn mươi năm.",
            meta: .init(imageHash: imageHash, model: "mock", promptVersion: 1)
        )
    }
}