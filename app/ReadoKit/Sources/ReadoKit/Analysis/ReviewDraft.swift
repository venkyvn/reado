import Foundation

/// Bản nháp của một vocabulary item trên màn duyệt & sửa trước khi lưu (FR-03/FR-09).
/// Tách khỏi `PageAnalysis.VocabularyItemIn` (immutable, từ AI) vì user sửa được
/// mọi field rồi mới chốt lưu — AI sai được, user là người chốt (FR-03).
public struct ReviewDraft: Equatable, Sendable, Identifiable {
    public let id: String
    public var term: String
    public var pos: String
    public var ipa: String
    public var meaningVI: String
    /// "" = không rõ — lưu NULL (schema cho phép); giá trị hợp lệ A2/B1/B2/C1.
    public var cefr: String
    public var example: String
    /// Trạng thái xác minh gắn từ lúc phân tích (FR-02). KHÔNG tự đổi khi user sửa:
    /// lựa chọn 2.3 — sửa tay hoặc bấm chọn item chính là hành vi user chủ động
    /// (SD 10.3 note FR-03), không cần nhãn thứ hai gây nhiễu.
    public let verification: PageAnalysis.VerificationStatus
    public var isSelected: Bool

    public init(
        id: String = Identifier.uuid(),
        term: String,
        pos: String,
        ipa: String,
        meaningVI: String,
        cefr: String,
        example: String,
        verification: PageAnalysis.VerificationStatus,
        isSelected: Bool
    ) {
        self.id = id
        self.term = term
        self.pos = pos
        self.ipa = ipa
        self.meaningVI = meaningVI
        self.cefr = cefr
        self.example = example
        self.verification = verification
        self.isSelected = isSelected
    }
}

/// Lỗi khi chốt danh sách đã chọn — trường bắt buộc rỗng sau khi user sửa.
public struct ReviewDraftError: Error, LocalizedError, Equatable, Sendable {
    public enum Field: Equatable, Sendable {
        case term
        case meaning
        case example

        /// Nhãn hiển thị cho alert (app layer hiển thị thẳng).
        var displayName: String {
            switch self {
            case .term: "term"
            case .meaning: "nghĩa tiếng Việt"
            case .example: "câu ví dụ"
            }
        }
    }

    /// 1-based, theo thứ tự hiển thị trên màn duyệt.
    public let index: Int
    public let field: Field

    public static func empty(_ field: Field, at index: Int) -> ReviewDraftError {
        .init(index: index, field: field)
    }

    public var errorDescription: String? {
        "Từ thứ \(index) thiếu \(field.displayName) — sửa lại hoặc bỏ chọn từ đó."
    }
}

/// Dựng draft từ kết quả phân tích + chốt lại thành danh sách sẽ lưu.
/// Logic thuần ở ReadoKit để test được acceptance criteria FR-03/FR-09.
public enum ReviewDraftBuilder {

    /// Enum hợp lệ — trùng `AnalysisResponseDecoder`; Picker UI dùng chung nguồn.
    public static let validPOS: [String] = ["noun", "verb", "adj", "adv", "phrase", "other"]
    public static let validCEFR: [String] = ["A2", "B1", "B2", "C1"]

    /// Từ kết quả AI → danh sách draft:
    /// - SD 10.3: unverified + suspect **lên đầu** (để xử lý trước — ADR-008),
    ///   verified giữ nguyên thứ tự gốc (thứ tự xuất hiện trên trang).
    /// - FR-09 mặc định chọn tất cả, nhưng FR-02 + SD 10.3: unverified/suspect
    ///   **bỏ chọn sẵn** — user chủ động chọn lại nếu giữ.
    /// - port UI lab (2026-09-23): preselect còn lọc theo CEFR — chỉ `verified`
    ///   **và** `cefr ∈ selectedLevels` mới được chọn sẵn. `selectedLevels = nil`
    ///   → giữ hành vi cũ (chọn mọi verified) cho test tương thích.
    public static func drafts(
        from items: [PageAnalysis.VocabularyItemIn],
        selectedLevels: Set<String>? = nil
    ) -> [ReviewDraft] {
        let all = items.map { item in
            ReviewDraft(
                term: item.term,
                pos: item.pos,
                ipa: item.ipa ?? "",
                meaningVI: item.meaningVI,
                cefr: item.cefr ?? "",
                example: item.example,
                verification: item.verification,
                isSelected: preselect(item, selectedLevels: selectedLevels))
        }
        return all.filter { $0.verification != .verified }
            + all.filter { $0.verification == .verified }
    }

    /// Preselect FR-02: verified (không unverified/suspect) + cefr ∈ levels
    /// (nếu có bộ lọc). cefr rỗng/không rõ → không preselect dù verified.
    private static func preselect(
        _ item: PageAnalysis.VocabularyItemIn,
        selectedLevels: Set<String>?
    ) -> Bool {
        guard item.verification == .verified else { return false }
        guard let levels = selectedLevels else { return true }
        guard let cefr = item.cefr, !cefr.isEmpty else { return false }
        return levels.contains(cefr)
    }

    /// Chốt: chỉ item `isSelected` (FR-03 bỏ chọn = không lưu; FR-09 chọn = review card).
    /// Trim + chuẩn hoá. Term/nghĩa/ví dụ rỗng sau trim → throw thay vì lưu bản
    /// ghi hỏng (tinh thần FR-02 "không lưu bản ghi hỏng"). Pos rỗng → "other"
    /// (FR-02: pos phải có giá trị, dùng other nếu không xác định được).
    public static func selected(
        _ drafts: [ReviewDraft]
    ) throws -> [PageAnalysis.VocabularyItemIn] {
        var result: [PageAnalysis.VocabularyItemIn] = []
        for (index, draft) in drafts.enumerated() where draft.isSelected {
            let term = trim(draft.term)
            guard !term.isEmpty else {
                throw ReviewDraftError.empty(.term, at: index + 1)
            }
            let meaning = trim(draft.meaningVI)
            guard !meaning.isEmpty else {
                throw ReviewDraftError.empty(.meaning, at: index + 1)
            }
            let example = trim(draft.example)
            guard !example.isEmpty else {
                throw ReviewDraftError.empty(.example, at: index + 1)
            }
            let pos = trim(draft.pos).lowercased()
            let cefr = trim(draft.cefr).uppercased()
            let ipa = trim(draft.ipa)
            result.append(
                PageAnalysis.VocabularyItemIn(
                    term: term,
                    pos: pos.isEmpty ? "other" : pos,
                    ipa: ipa.isEmpty ? nil : ipa,
                    meaningVI: meaning,
                    cefr: cefr.isEmpty ? nil : cefr,
                    example: example,
                    verification: draft.verification))
        }
        return result
    }

    static func trim(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}