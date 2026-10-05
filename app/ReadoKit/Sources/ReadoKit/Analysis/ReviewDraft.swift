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

/// Q-13 phương án B (ADR-056): một draft khớp khoá `term|pos` đã thuộc
/// (`VocabRepository.matureKey`) — không xoá khỏi màn duyệt, gập xuống nhóm
/// riêng kèm MỌI nghĩa trong kho của khoá đó. Ca lệch spec (Context: khoá có
/// cả dòng đã thuộc lẫn dòng mới) xử lý theo quyết định (i) — liệt kê đủ nghĩa
/// trong kho, không tự suy đoán trang đang dùng nghĩa nào. `draft.isSelected`
/// luôn `false` lúc dựng; chọn tay item này vẫn đi qua `selected(_:)` như mọi
/// draft khác.
public struct MatureHiddenDraft: Equatable, Sendable, Identifiable {
    public var id: String { draft.id }
    public let draft: ReviewDraft
    /// Mọi dòng đã có trong kho cùng khoá `term|pos` (ADR-066: toàn app, mọi trạng thái;
    /// tên `MatureHidden` giữ vì Q4). Ít nhất 1 phần tử.
    public let knownSenses: [KnownSense]
    /// `meaning_vi` của từng dòng đã có.
    public var knownMeanings: [String] { knownSenses.map(\.meaningVI) }

    public init(draft: ReviewDraft, knownMeanings: [String]) {
        self.draft = draft
        self.knownSenses = knownMeanings.map {
            KnownSense(
                vocabItemID: "", meaningVI: $0, collectionName: "",
                isMature: true, isLeech: false)
        }
    }

    public init(draft: ReviewDraft, knownSenses: [KnownSense]) {
        self.draft = draft
        self.knownSenses = knownSenses
    }
}

/// Kết quả `ReviewDraftBuilder.drafts`: `visible` là danh sách chính (sort +
/// preselect như trước — không đổi hành vi khi `matureSenses` rỗng),
/// `matureHidden` là nhóm gập Q-13. `matureHidden` không tính vào
/// `preselectLimit`/preselect count của `visible`.
public struct ReviewDraftResult: Equatable, Sendable {
    public let visible: [ReviewDraft]
    public let matureHidden: [MatureHiddenDraft]
}

/// Dựng draft từ kết quả phân tích + chốt lại thành danh sách sẽ lưu.
/// Logic thuần ở ReadoKit để test được acceptance criteria FR-03/FR-09.
public enum ReviewDraftBuilder {

    /// Enum hợp lệ — trùng `AnalysisResponseDecoder`; Picker UI dùng chung nguồn.
    public static let validPOS: [String] = ["noun", "verb", "adj", "adv", "phrase", "other"]
    public static let validCEFR: [String] = ["A2", "B1", "B2", "C1"]

    /// FR-09 (sửa prompt-v6 T2b, 2026-10-02 — đảo "mặc định tất cả"): số item
    /// chọn sẵn tối đa trên màn duyệt. AI (prompt v6) trả `vocabulary` theo thứ
    /// tự giá trị học giảm dần; người dùng vẫn là người duyệt cuối cho phần còn lại.
    public static let preselectLimit = 5

    /// Từ kết quả AI → danh sách draft:
    /// - SD 10.3: unverified + suspect **lên đầu** (để xử lý trước — ADR-008),
    ///   verified giữ nguyên thứ tự AI trả về (giá trị học giảm dần, prompt v6).
    /// - FR-09: preselect tối đa `preselectLimit` (5) item **đủ điều kiện** đầu
    ///   tiên theo thứ tự AI — không còn "mặc định tất cả". Đủ điều kiện = verified
    ///   + `cefr ∈ selectedLevels` (như cũ, FR-02 + SD 10.3). unverified/suspect
    ///   không bao giờ preselect và không chiếm suất trong 5 item.
    /// - `selectedLevels = nil` → mọi verified đều đủ điều kiện (vẫn cap ở 5,
    ///   tương thích ngược về mặt chữ ký, khác hành vi cũ "chọn hết").
    /// - Q-13 phương án B (ADR-056, 2026-10-02 — đảo "xoá hẳn item khớp khoá đã
    ///   thuộc"): `matureSenses` (khoá `term|pos` → nghĩa trong kho,
    ///   `VocabRepository.matureSenses`) không còn loại item khỏi kết quả — item
    ///   khớp khoá rơi vào `ReviewDraftResult.matureHidden` (không preselect,
    ///   không chiếm suất `preselectLimit` của `visible`) thay vì biến mất.
    public static func drafts(
        from items: [PageAnalysis.VocabularyItemIn],
        selectedLevels: Set<String>? = nil,
        matureSenses: [String: [String]] = [:],
        knownSenses: [String: [KnownSense]] = [:],
        preselectBudget: Int = preselectLimit
    ) -> ReviewDraftResult {
        // ADR-066/Q5: `knownSenses` (toàn app) ưu tiên khi không rỗng; không thì bọc `matureSenses` cũ.
        let lookup: [String: [KnownSense]] = knownSenses.isEmpty
            ? matureSenses.mapValues { meanings in
                meanings.map {
                    KnownSense(
                        vocabItemID: "", meaningVI: $0, collectionName: "",
                        isMature: true, isLeech: false)
                }
            }
            : knownSenses
        // ADR-066 D1/Q1: suất chọn sẵn = min(trần 5/trang, ngân sách ngày còn lại).
        let slots = min(preselectLimit, max(0, preselectBudget))
        var preselectedCount = 0
        var visible: [ReviewDraft] = []
        var matureHidden: [MatureHiddenDraft] = []
        for item in items {
            let key = VocabRepository.matureKey(term: item.term, pos: item.pos)
            if let senses = lookup[key] {
                let draft = ReviewDraft(
                    term: item.term,
                    pos: item.pos,
                    ipa: item.ipa ?? "",
                    meaningVI: item.meaningVI,
                    cefr: item.cefr ?? "",
                    example: item.example,
                    verification: item.verification,
                    isSelected: false)
                matureHidden.append(
                    MatureHiddenDraft(draft: draft, knownSenses: senses))
                continue
            }
            let eligible = isEligibleForPreselect(item, selectedLevels: selectedLevels)
            let isSelected = eligible && preselectedCount < slots
            if isSelected { preselectedCount += 1 }
            visible.append(
                ReviewDraft(
                    term: item.term,
                    pos: item.pos,
                    ipa: item.ipa ?? "",
                    meaningVI: item.meaningVI,
                    cefr: item.cefr ?? "",
                    example: item.example,
                    verification: item.verification,
                    isSelected: isSelected))
        }
        let sortedVisible = visible.filter { $0.verification != .verified }
            + visible.filter { $0.verification == .verified }
        return ReviewDraftResult(visible: sortedVisible, matureHidden: matureHidden)
    }

    /// Đủ điều kiện preselect FR-02: verified (không unverified/suspect) + cefr ∈
    /// levels (nếu có bộ lọc). cefr rỗng/không rõ → không đủ điều kiện dù verified.
    /// Không tự chọn — chỉ `drafts` mới quyết item nào trong số đủ điều kiện rơi
    /// vào `preselectLimit` đầu.
    private static func isEligibleForPreselect(
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

    /// fr10-close-r1: tính lại `visible`/`matureHidden` khi đích lưu đổi (ADR-053 cho
    /// đổi ngay trên màn duyệt) — `matureSenses` của T1 chỉ đọc một lần lúc mở màn
    /// (Q-09 so khớp theo collection, đích đổi thì bộ so khớp cũng phải đổi theo).
    /// Nhận draft **hiện tại** (giữ sửa tay + lựa chọn), không dựng lại từ AI:
    /// - Khoá tính trên term/pos **của draft** — đúng thứ sẽ lưu, không phải bản AI gốc.
    /// - Rời khỏi nhóm gập (bộ mới không có khoá) → về `visible`, **giữ** `isSelected`
    ///   (chọn tay trong nhóm gập không mất khi đổi đích xong lại về danh sách chính).
    ///   Không preselect thêm — suất `preselectLimit` chỉ tính lúc dựng ban đầu.
    /// - Vào nhóm gập (bộ mới có khoá) → **bỏ chọn** (ADR-056: nhóm gập không bao giờ
    ///   mang theo lựa chọn người dùng không nhìn thấy), `knownMeanings` lấy theo
    ///   `matureSenses` mới.
    /// - Item mới rời nhóm gập nối cuối trước khi sort lại unverified/suspect lên đầu.
    public static func regroup(
        visible: [ReviewDraft],
        matureHidden: [MatureHiddenDraft],
        matureSenses: [String: [String]]
    ) -> ReviewDraftResult {
        var newVisible: [ReviewDraft] = []
        var newMatureHidden: [MatureHiddenDraft] = []
        for draft in visible + matureHidden.map(\.draft) {
            let key = VocabRepository.matureKey(term: draft.term, pos: draft.pos)
            if let knownMeanings = matureSenses[key] {
                var hidden = draft
                hidden.isSelected = false
                newMatureHidden.append(MatureHiddenDraft(draft: hidden, knownMeanings: knownMeanings))
            } else {
                newVisible.append(draft)
            }
        }
        let sortedVisible = newVisible.filter { $0.verification != .verified }
            + newVisible.filter { $0.verification == .verified }
        return ReviewDraftResult(visible: sortedVisible, matureHidden: newMatureHidden)
    }
}