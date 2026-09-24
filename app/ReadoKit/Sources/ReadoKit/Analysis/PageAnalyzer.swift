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

/// Nhà máy chọn analyzer theo agent đang active (FR-21).
public enum AnalyzerFactory {
    public static let proxyBaseURL = "https://proxy.reado.app"

    /// URL thật lúc chạy. Scheme Xcode có thể đặt `READO_PROXY_BASE_URL`
    /// (HTTPS mà iPhone mở được). Trống thì dùng `proxyBaseURL`.
    public static var resolvedProxyBaseURL: String {
        let fromEnv = ProcessInfo.processInfo.environment["READO_PROXY_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fromEnv.isEmpty ? proxyBaseURL : fromEnv
    }

    /// Tạo analyzer cho agent. `openai_compat` thiếu id/url/model thì mock (cấu hình hỏng).
    /// `session` injectable cho test (default URLSession.shared ở production).
    public static func analyzer(
        for kind: String,
        baseURL: String?,
        model: String?,
        agentID: String? = nil,
        session: URLSession = .shared
    ) -> PageAnalyzer {
        switch kind {
        case "openai_compat":
            guard let agentID, let baseURL, let model, !baseURL.isEmpty, !model.isEmpty else {
                return MockAnalyzer()
            }
            return OpenAICompatClient(
                session: session,
                baseURL: baseURL,
                model: model,
                agentID: agentID)
        case "reado_proxy":
            return ReadoProxyClient(session: session, baseURL: baseURL ?? resolvedProxyBaseURL)
        default:
            return MockAnalyzer()
        }
    }

    /// Helper: đọc settings (cefr_levels, active_agent) rồi tạo analyzer đúng agent.
    /// Trả về (analyzer, cefrLevel) với cefrLevel = các level chọn ghép ", " cho
    /// prompt FR-02 (cài cũ chỉ có `cefr_level` đơn → fallback).
    public static func active(
        db: SQLiteDatabase,
        session: URLSession = .shared
    ) throws -> (analyzer: PageAnalyzer, cefrLevel: String) {
        let rows = try db.rows(
            "SELECT cefr_levels, cefr_level, active_agent_id FROM settings WHERE id = 1 LIMIT 1;")
        let cefrLevel = Self.cefrLevelString(from: rows.first)
        let activeAgentID = rows.first?.last?.textValue
        if let activeAgentID {
            let agentRows = try db.rows(
                "SELECT id, kind, base_url, model FROM analysis_agents WHERE id = ? LIMIT 1;",
                [.text(activeAgentID)])
            if let row = agentRows.first, row.count >= 4 {
                return (
                    analyzer(
                        for: row[1].textValue ?? "reado_proxy",
                        baseURL: row[2].textValue,
                        model: row[3].textValue,
                        agentID: row[0].textValue,
                        session: session),
                    cefrLevel)
            }
        }
        // Fallback: agent seed luôn tồn tại (reado_proxy) — không bao giờ tới đây.
        return (ReadoProxyClient(session: session, baseURL: resolvedProxyBaseURL), cefrLevel)
    }

    /// Ghép các CEFR level đã chọn thành chuỗi cho prompt; cột JSON rỗng/cài cũ
    /// → đọc `cefr_level` đơn; cả hai rỗng → "B2".
    private static func cefrLevelString(from row: [SQLValue]?) -> String {
        guard let row else { return "B2" }
        if let json = row[0].textValue,
           let data = json.data(using: .utf8),
           let levels = try? JSONDecoder().decode([CEFRLevel].self, from: data),
           !levels.isEmpty
        {
            return levels.map(\.rawValue).joined(separator: ", ")
        }
        if let single = row[1].textValue, !single.isEmpty { return single }
        return "B2"
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