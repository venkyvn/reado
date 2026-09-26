import Foundation

/// Kết quả phân tích ảnh trang sách (FR-02).
/// `segments` và `summary_vi` chỉ hiển thị, KHÔNG lưu (FR-05/FR-06 FR-07 FR-13).
/// Chỉ `vocabulary` được lưu — mỗi item kèm `verification` trạng thái xác minh.
public struct PageAnalysis: Equatable, Sendable {
    public let segments: [Segment]
    public let vocabulary: [VocabularyItemIn]
    public let summaryVI: String
    public let meta: Meta

    public struct Segment: Equatable, Sendable {
        public let sourceEN: String
        public let translationVI: String

        public init(sourceEN: String, translationVI: String) {
            self.sourceEN = sourceEN
            self.translationVI = translationVI
        }
    }

    /// Vocabulary item từ AI — bao gồm `verification` trạng thái xác minh.
    /// FR-02: `example` phải là câu thật trên trang; FR-02/03: unverified không preselect.
    public struct VocabularyItemIn: Equatable, Sendable {
        public let term: String
        public let pos: String
        public let ipa: String?
        public let meaningVI: String
        public let cefr: String?
        public let example: String
        public let verification: VerificationStatus

        public init(
            term: String,
            pos: String,
            ipa: String?,
            meaningVI: String,
            cefr: String?,
            example: String,
            verification: VerificationStatus
        ) {
            self.term = term
            self.pos = pos
            self.ipa = ipa
            self.meaningVI = meaningVI
            self.cefr = cefr
            self.example = example
            self.verification = verification
        }
    }

    public enum VerificationStatus: String, Equatable, Sendable {
        case verified
        case suspect
        case unverified
    }

    public struct Meta: Equatable, Sendable {
        public let imageHash: String
        public let model: String
        public let promptVersion: Int

        public init(imageHash: String, model: String, promptVersion: Int) {
            self.imageHash = imageHash
            self.model = model
            self.promptVersion = promptVersion
        }
    }

    public init(
        segments: [Segment],
        vocabulary: [VocabularyItemIn],
        summaryVI: String,
        meta: Meta
    ) {
        self.segments = segments
        self.vocabulary = vocabulary
        self.summaryVI = summaryVI
        self.meta = meta
    }
}

/// Tiến độ một lần gọi `PageAnalyzer.analyze` (FR-02) — UI dùng để thay đổi
/// thông báo "Đang xử lý ảnh…" thay vì để màn treo im khi model suy nghĩ lâu.
/// `thinking`/`writing` chỉ `OpenAICompatClient` (stream) phát ra.
public enum AnalysisProgress: Sendable, Equatable {
    case readingPage
    case waitingAgent
    case thinking(chars: Int)
    case writing(chars: Int)
}

/// Lỗi analysis (FR-02 — hiển thị lỗi và cho retry, không lưu bản ghi hỏng).
public enum AnalysisError: Error, LocalizedError, Sendable {
    case imageUnreadable
    case notEnglishText
    case schemaViolation(String)
    case providerError(String)
    case rateLimited
    case idempotencyMissing
    case networkError(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .imageUnreadable:
            "Ảnh quá mờ hoặc không đọc được — vui lòng chụp lại"
        case .notEnglishText:
            "Trang không phải tiếng Anh — Reado hiện không hỗ trợ ngôn ngữ này. Lần chụp này không tính phí."
        case let .schemaViolation(detail):
            "Dữ liệu trả về không đúng định dạng: \(detail)"
        case let .providerError(message):
            "Lỗi từ phía AI: \(message)"
        case .rateLimited:
            "Quá nhiều yêu cầu — vui lòng thử lại sau"
        case .idempotencyMissing:
            "Thiếu mã xác thực yêu cầu"
        case let .networkError(message):
            "Lỗi mạng: \(message)"
        case let .invalidResponse(message):
            "Phản hồi không hợp lệ: \(message)"
        }
    }

    /// FR-04: lỗi này có gợi ý **chụp lại** (ảnh khác) thay vì "thử lại" cùng ảnh
    /// không? Ảnh mờ / không phải tiếng Anh không sửa được bằng retry — phải
    /// chụp trang khác; lỗi mạng/schema/provider thì retry cùng ảnh là hợp lý.
    public var suggestsRecapture: Bool {
        switch self {
        case .imageUnreadable, .notEnglishText: true
        default: false
        }
    }
}
