import Foundation
import XCTest
import ReadoKit

/// FR-03/FR-09, ROADMAP 2.3 — `ReviewDraftBuilder` (sort/preselect/validate).
final class ReviewDraftBuilderTests: XCTestCase {

    private func vocabIn(
        term: String,
        pos: String = "noun",
        ipa: String? = nil,
        meaning: String = "nghĩa",
        cefr: String? = nil,
        example: String = "câu ví dụ",
        verification: PageAnalysis.VerificationStatus
    ) -> PageAnalysis.VocabularyItemIn {
        PageAnalysis.VocabularyItemIn(
            term: term,
            pos: pos,
            ipa: ipa,
            meaningVI: meaning,
            cefr: cefr,
            example: example,
            verification: verification)
    }

    func testDraftBuilderPutsUnverifiedAndSuspectFirstAndDeselected() {
        // SD 10.3: unverified/suspect lên đầu và bỏ chọn sẵn; verified giữ thứ
        // tự AI và chọn sẵn vì dưới `preselectLimit` (FR-09, prompt-v6 T2b).
        let items = [
            vocabIn(term: "alpha", verification: .verified),
            vocabIn(term: "bravo", verification: .unverified),
            vocabIn(term: "charlie", verification: .suspect),
            vocabIn(term: "delta", verification: .verified),
        ]
        let drafts = ReviewDraftBuilder.drafts(from: items).visible
        XCTAssertEqual(drafts.map(\.term), ["bravo", "charlie", "alpha", "delta"])
        XCTAssertEqual(drafts.map(\.isSelected), [false, false, true, true])
    }

    /// FR-09 (prompt-v6 T2b, 2026-10-02): chỉ 5 item đủ điều kiện ĐẦU TIÊN theo
    /// thứ tự AI được chọn sẵn — không còn "mặc định tất cả". 8 verified → đúng
    /// 5 đầu, 3 cuối hiện nhưng không tick.
    func testDraftBuilderPreselectsTopFiveOfEightVerified() {
        let items = (1...8).map { vocabIn(term: "t\($0)", verification: .verified) }
        let drafts = ReviewDraftBuilder.drafts(from: items).visible
        XCTAssertEqual(drafts.map(\.term), items.map(\.term), "verified giữ thứ tự AI")
        XCTAssertEqual(
            drafts.map(\.isSelected),
            [true, true, true, true, true, false, false, false])
    }

    /// Dưới ngưỡng `preselectLimit` → chọn sẵn hết, không bị cắt oan.
    func testDraftBuilderPreselectsAllWhenFewerThanLimit() {
        let items = (1...3).map { vocabIn(term: "t\($0)", verification: .verified) }
        let drafts = ReviewDraftBuilder.drafts(from: items).visible
        XCTAssertEqual(drafts.map(\.isSelected), [true, true, true])
    }

    /// Item verified nhưng ngoài CEFR lọc không được tính vào 5 suất — chỉ item
    /// ĐỦ ĐIỀU KIỆN (verified + cefr ∈ levels) mới chiếm suất, dù đứng trước trong
    /// thứ tự AI.
    func testDraftBuilderCefrFilterAppliesBeforeCountingLimit() {
        let items = [
            vocabIn(term: "e1", cefr: "B2", verification: .verified),
            vocabIn(term: "x1", cefr: "C1", verification: .verified),  // ngoài level, không chiếm suất
            vocabIn(term: "e2", cefr: "B2", verification: .verified),
            vocabIn(term: "e3", cefr: "B2", verification: .verified),
            vocabIn(term: "x2", cefr: "C1", verification: .verified),  // ngoài level, không chiếm suất
            vocabIn(term: "e4", cefr: "B2", verification: .verified),
            vocabIn(term: "e5", cefr: "B2", verification: .verified),
            vocabIn(term: "e6", cefr: "B2", verification: .verified),
            vocabIn(term: "e7", cefr: "B2", verification: .verified),
        ]
        let drafts = ReviewDraftBuilder.drafts(from: items, selectedLevels: ["B2"]).visible
        let selected = Dictionary(
            drafts.map { ($0.term, $0.isSelected) }, uniquingKeysWith: { a, _ in a })
        for term in ["e1", "e2", "e3", "e4", "e5"] {
            XCTAssertEqual(selected[term], true, "\(term) phải trong 5 đủ điều kiện đầu")
        }
        for term in ["e6", "e7"] {
            XCTAssertEqual(selected[term], false, "\(term) vượt 5 suất")
        }
        XCTAssertEqual(selected["x1"], false)
        XCTAssertEqual(selected["x2"], false)
    }

    /// unverified/suspect đứng trước trong mảng gốc vẫn không chiếm suất của 5 —
    /// chỉ verified mới được tính (SD 10.3 + FR-02).
    func testDraftBuilderUnverifiedDoesNotConsumePreselectSlot() {
        let items = [vocabIn(term: "u1", verification: .unverified)]
            + (1...5).map { vocabIn(term: "v\($0)", verification: .verified) }
        let drafts = ReviewDraftBuilder.drafts(from: items).visible
        let selected = Dictionary(
            drafts.map { ($0.term, $0.isSelected) }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(selected["u1"], false)
        for i in 1...5 {
            XCTAssertEqual(selected["v\(i)"], true, "v\(i) phải được chọn sẵn (không bị u1 chiếm suất)")
        }
    }

    /// Q-13 phương án B (ADR-056): item khớp khoá `matureSenses` KHÔNG biến mất
    /// — rơi vào `matureHidden` (gập), không preselect, không chiếm suất 5 của
    /// `visible`.
    func testDraftBuilderMatureItemGoesToMatureHiddenNotPreselected() throws {
        let mature = vocabIn(
            term: "mature-word", pos: "noun", meaning: "bờ sông",
            verification: .verified)
        let items = [mature] + (1...5).map {
            vocabIn(term: "v\($0)", pos: "noun", verification: .verified)
        }
        let result = ReviewDraftBuilder.drafts(
            from: items,
            matureSenses: [
                VocabRepository.matureKey(term: "mature-word", pos: "noun"): ["ngân hàng"]
            ])
        XCTAssertFalse(result.visible.contains { $0.term == "mature-word" })
        XCTAssertEqual(result.visible.map(\.isSelected), [true, true, true, true, true])
        XCTAssertEqual(result.matureHidden.count, 1)
        let hidden = try XCTUnwrap(result.matureHidden.first)
        XCTAssertEqual(hidden.draft.term, "mature-word")
        XCTAssertEqual(hidden.draft.meaningVI, "bờ sông", "nghĩa AI trả về trang này")
        XCTAssertEqual(hidden.knownMeanings, ["ngân hàng"], "nghĩa trong kho")
        XCTAssertFalse(hidden.draft.isSelected, "không preselect")
    }

    /// Ca lệch spec ở Context + quyết định (i): khoá `term|pos` có NHIỀU nghĩa
    /// trong kho (vd một dòng "ngân hàng" đã thuộc + một dòng "bờ sông" vừa lưu,
    /// chưa thuộc) → vẫn vào `matureHidden`, liệt kê ĐỦ nghĩa kèm mức thuộc của
    /// từng dòng — không tự suy đoán trang đang dùng nghĩa nào.
    func testDraftBuilderMatureHiddenListsAllKnownMeaningsForMixedMaturity() throws {
        let item = vocabIn(
            term: "bank", pos: "noun", meaning: "bờ sông", verification: .verified)
        let result = ReviewDraftBuilder.drafts(
            from: [item],
            matureSenses: [
                VocabRepository.matureKey(term: "bank", pos: "noun"): [
                    "ngân hàng", "bờ sông",
                ]
            ])
        XCTAssertTrue(result.visible.isEmpty)
        let hidden = try XCTUnwrap(result.matureHidden.first)
        XCTAssertEqual(hidden.knownMeanings, ["ngân hàng", "bờ sông"])
    }

    /// port UI lab §5.5: preselect = verified VÀ cefr ∈ selectedLevels — verified
    /// nhưng ngoài level chọn thì vẫn bỏ chọn sẵn; cefr rỗng cũng bỏ.
    func testDraftBuilderPreselectsOnlyVerifiedInSelectedLevels() {
        let items = [
            vocabIn(term: "a-b2", cefr: "B2", verification: .verified),
            vocabIn(term: "b-b2", cefr: "B2", verification: .unverified),
            vocabIn(term: "c-c1", cefr: "C1", verification: .verified),
            vocabIn(term: "d-none", cefr: nil, verification: .verified),
        ]
        let drafts = ReviewDraftBuilder.drafts(
            from: items, selectedLevels: ["B2"]).visible
        // c-c1 (verified, ngoài B2) và d-none (verified, cefr rỗng) bỏ chọn sẵn.
        let selected = Dictionary(
            drafts.map { ($0.term, $0.isSelected) },
            uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(selected["a-b2"], true)
        XCTAssertEqual(selected["b-b2"], false)
        XCTAssertEqual(selected["c-c1"], false)
        XCTAssertEqual(selected["d-none"], false)
    }

    /// `selectedLevels = nil` → mọi verified đều đủ điều kiện; dưới `preselectLimit`
    /// (2 < 5) nên vẫn chọn cả hai — cap chỉ lộ ra khi đủ điều kiện vượt 5
    /// (`testDraftBuilderPreselectsTopFiveOfEightVerified`).
    func testDraftBuilderNilLevelsSelectsAllVerified() {
        let drafts = ReviewDraftBuilder.drafts(from: [
            vocabIn(term: "a", cefr: "B2", verification: .verified),
            vocabIn(term: "b", cefr: "C1", verification: .verified),
        ]).visible
        XCTAssertEqual(drafts.map(\.isSelected), [true, true])
    }

    func testSelectedReturnsOnlySelectedItemsInDisplayOrder() throws {
        let drafts = [
            ReviewDraft(
                term: "alpha", pos: "noun", ipa: "", meaningVI: "a",
                cefr: "", example: "ex-a", verification: .verified,
                isSelected: false),
            ReviewDraft(
                term: "beta", pos: "verb", ipa: "", meaningVI: "b",
                cefr: "", example: "ex-b", verification: .verified,
                isSelected: true),
            ReviewDraft(
                term: "gamma", pos: "adj", ipa: "", meaningVI: "g",
                cefr: "", example: "ex-g", verification: .unverified,
                isSelected: true),  // user chủ động chọn lại item chưa xác minh
        ]
        let items = try ReviewDraftBuilder.selected(drafts)
        XCTAssertEqual(items.map(\.term), ["beta", "gamma"])
    }

    func testSelectedNormalizesFields() throws {
        // FR-03: trim mọi field; pos rỗng → other (FR-02); cefr upper + rỗng → nil;
        // ipa rỗng → nil.
        let draft = ReviewDraft(
            term: "  Trimmed  ", pos: " ", ipa: "  ", meaningVI: "  nghĩa ",
            cefr: "  b2 ", example: "  ví dụ ", verification: .verified,
            isSelected: true)
        let items = try ReviewDraftBuilder.selected([draft])
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.term, "Trimmed")
        XCTAssertEqual(item.pos, "other")
        XCTAssertEqual(item.ipa, nil)
        XCTAssertEqual(item.meaningVI, "nghĩa")
        XCTAssertEqual(item.cefr, "B2")
        XCTAssertEqual(item.example, "ví dụ")
    }

    func testSelectedThrowsForEmptyRequiredFieldsWithDisplayIndex() {
        // Trường bắt buộc rỗng sau khi user sửa → chặn lưu bản ghi hỏng (FR-02/03).
        // Index 1-based theo thứ tự hiển thị — item đầu không chọn không đếm.
        let unselected = ReviewDraft(
            term: "ok", pos: "noun", ipa: "", meaningVI: "m",
            cefr: "", example: "e", verification: .verified, isSelected: false)
        let cases: [(ReviewDraft, ReviewDraftError.Field)] = [
            (
                ReviewDraft(
                    term: "  ", pos: "noun", ipa: "", meaningVI: "m",
                    cefr: "", example: "e", verification: .verified,
                    isSelected: true),
                .term
            ),
            (
                ReviewDraft(
                    term: "t", pos: "noun", ipa: "", meaningVI: " ",
                    cefr: "", example: "e", verification: .verified,
                    isSelected: true),
                .meaning
            ),
            (
                ReviewDraft(
                    term: "t", pos: "noun", ipa: "", meaningVI: "m",
                    cefr: "", example: "\n", verification: .verified,
                    isSelected: true),
                .example
            ),
        ]
        for (bad, field) in cases {
            XCTAssertThrowsError(
                try ReviewDraftBuilder.selected([unselected, bad])
            ) { error in
                guard let draftError = error as? ReviewDraftError else {
                    return XCTFail("mong đợi ReviewDraftError, nhận \(error)")
                }
                XCTAssertEqual(draftError.index, 2)
                XCTAssertEqual(draftError.field, field)
            }
        }
    }

    func testSaveCapturePersistsOnlySelectedItemsAsNewCardsDueToday() throws {
        // FR-09: item được chọn khi lưu → SRS queue state=new, due_at hôm nay;
        // 2.4: không chọn collection → kho tạm (is_default). FR-03: bỏ chọn = không lưu.
        let db = try Fixtures.seededDB()
        let drafts = ReviewDraftBuilder.drafts(from: [
            vocabIn(term: " keep ", verification: .verified),
            vocabIn(term: "drop", verification: .unverified),  // không preselect
        ]).visible
        let items = try ReviewDraftBuilder.selected(drafts)
        XCTAssertEqual(items.map(\.term), ["keep"])

        let saved = try VocabRepository.saveCapture(
            on: db, items: items, collectionID: nil, now: Fixtures.fixedNow)
        XCTAssertEqual(saved, 1)

        let rows = try db.rows(
            """
            SELECT v.term, v.collection_id, c.state, c.due_at
            FROM cards c
            JOIN vocab_items v ON v.id = c.vocab_item_id;
            """)
        XCTAssertEqual(rows.count, 1, "bỏ chọn trong màn duyệt thì không được lưu")
        let inboxID = try db.scalarString(
            "SELECT id FROM collections WHERE is_default = 1 LIMIT 1;")
        XCTAssertEqual(rows[0][1].textValue, inboxID, "đích ngầm = kho tạm")
        XCTAssertEqual(rows[0][2].textValue, "new")
        XCTAssertEqual(rows[0][3].textValue, "2026-09-18T02:00:00Z")
    }

    // MARK: - regroup (fr10-close-r1: đổi đích trên màn duyệt, ADR-053)

    /// Đích đổi sang bộ có khoá đã thuộc → item rời `visible`, vào `matureHidden`
    /// VÀ bị bỏ chọn (ADR-056: nhóm gập không mang lựa chọn người dùng không thấy).
    func testRegroupMovesVisibleItemToMatureHiddenAndDeselects() {
        let draft = ReviewDraft(
            term: "bank", pos: "noun", ipa: "", meaningVI: "bờ sông",
            cefr: "", example: "ex", verification: .verified, isSelected: true)
        let result = ReviewDraftBuilder.regroup(
            visible: [draft],
            matureHidden: [],
            matureSenses: [VocabRepository.matureKey(term: "bank", pos: "noun"): ["ngân hàng"]])
        XCTAssertTrue(result.visible.isEmpty)
        let hidden = result.matureHidden.first
        XCTAssertEqual(hidden?.draft.id, draft.id, "giữ nguyên id cho binding")
        XCTAssertEqual(hidden?.knownMeanings, ["ngân hàng"])
        XCTAssertEqual(hidden?.draft.isSelected, false)
    }

    /// Đích đổi sang bộ không có khoá → item rời `matureHidden`, về `visible`,
    /// GIỮ `isSelected` (chọn tay trước đó không mất khi quay lại danh sách chính).
    func testRegroupMovesMatureHiddenItemToVisibleKeepingSelection() {
        let draft = ReviewDraft(
            term: "setback", pos: "noun", ipa: "", meaningVI: "trở ngại",
            cefr: "", example: "ex", verification: .verified, isSelected: true)
        let hidden = MatureHiddenDraft(draft: draft, knownMeanings: ["thất bại"])
        let result = ReviewDraftBuilder.regroup(
            visible: [], matureHidden: [hidden], matureSenses: [:])
        XCTAssertTrue(result.matureHidden.isEmpty)
        let visible = result.visible.first
        XCTAssertEqual(visible?.id, draft.id)
        XCTAssertEqual(visible?.isSelected, true, "chọn tay trong nhóm gập không mất")
    }

    /// Khoá tính theo term/pos ĐÃ SỬA của draft — không phải bản AI gốc.
    func testRegroupUsesEditedTermAndPosForKey() {
        var draft = ReviewDraft(
            term: "oldterm", pos: "verb", ipa: "", meaningVI: "m",
            cefr: "", example: "ex", verification: .verified, isSelected: true)
        draft.term = "bank"
        draft.pos = "noun"
        let result = ReviewDraftBuilder.regroup(
            visible: [draft], matureHidden: [],
            matureSenses: [VocabRepository.matureKey(term: "bank", pos: "noun"): ["ngân hàng"]])
        XCTAssertTrue(result.visible.isEmpty, "phải khớp theo term/pos đã sửa, không phải oldterm/verb")
        XCTAssertEqual(result.matureHidden.first?.draft.term, "bank")
    }

    /// Sửa tay (meaning/example) sống sót qua regroup dù item đổi nhóm.
    func testRegroupPreservesEditedFieldsAcrossGroupChange() {
        var draft = ReviewDraft(
            term: "bank", pos: "noun", ipa: "", meaningVI: "nghĩa gốc",
            cefr: "", example: "ví dụ gốc", verification: .verified, isSelected: false)
        draft.meaningVI = "nghĩa đã sửa"
        draft.example = "ví dụ đã sửa"
        let result = ReviewDraftBuilder.regroup(
            visible: [draft], matureHidden: [],
            matureSenses: [VocabRepository.matureKey(term: "bank", pos: "noun"): ["ngân hàng"]])
        XCTAssertEqual(result.matureHidden.first?.draft.meaningVI, "nghĩa đã sửa")
        XCTAssertEqual(result.matureHidden.first?.draft.example, "ví dụ đã sửa")
    }

    /// `knownMeanings` lấy theo `matureSenses` MỚI (bộ mới) — không giữ nghĩa của
    /// bộ cũ nếu item đã ở sẵn trong `matureHidden`.
    func testRegroupRefreshesKnownMeaningsFromNewMatureSenses() {
        let draft = ReviewDraft(
            term: "bank", pos: "noun", ipa: "", meaningVI: "m",
            cefr: "", example: "ex", verification: .verified, isSelected: false)
        let hidden = MatureHiddenDraft(draft: draft, knownMeanings: ["nghĩa bộ cũ"])
        let result = ReviewDraftBuilder.regroup(
            visible: [], matureHidden: [hidden],
            matureSenses: [VocabRepository.matureKey(term: "bank", pos: "noun"): ["nghĩa bộ mới"]])
        XCTAssertEqual(result.matureHidden.first?.knownMeanings, ["nghĩa bộ mới"])
    }

    /// `matureSenses` rỗng (vd đổi sang Kho tạm chưa có từ nào đã thuộc) → mọi
    /// item về `visible`, kể cả item đang nằm trong `matureHidden`.
    func testRegroupWithEmptyMatureSensesMovesEverythingToVisible() {
        let a = ReviewDraft(
            term: "a", pos: "noun", ipa: "", meaningVI: "m", cefr: "",
            example: "ex", verification: .verified, isSelected: true)
        let b = ReviewDraft(
            term: "b", pos: "noun", ipa: "", meaningVI: "m", cefr: "",
            example: "ex", verification: .verified, isSelected: false)
        let result = ReviewDraftBuilder.regroup(
            visible: [a], matureHidden: [MatureHiddenDraft(draft: b, knownMeanings: ["x"])],
            matureSenses: [:])
        XCTAssertTrue(result.matureHidden.isEmpty)
        XCTAssertEqual(Set(result.visible.map(\.id)), Set([a.id, b.id]))
    }

    /// Gọi `regroup` hai lần liên tiếp với cùng input (vd đổi đích hai lần về
    /// cùng một bộ) → kết quả không đổi, không nhân đôi/mất item.
    func testRegroupIsIdempotentForSameInput() {
        let a = ReviewDraft(
            term: "a", pos: "noun", ipa: "", meaningVI: "m", cefr: "",
            example: "ex", verification: .verified, isSelected: true)
        let senses = [VocabRepository.matureKey(term: "mature", pos: "noun"): ["x"]]
        let mature = ReviewDraft(
            term: "mature", pos: "noun", ipa: "", meaningVI: "m", cefr: "",
            example: "ex", verification: .verified, isSelected: true)
        let first = ReviewDraftBuilder.regroup(
            visible: [a, mature], matureHidden: [], matureSenses: senses)
        let second = ReviewDraftBuilder.regroup(
            visible: first.visible, matureHidden: first.matureHidden, matureSenses: senses)
        XCTAssertEqual(first, second)
    }

    /// `visible` vẫn sort unverified/suspect lên đầu sau regroup (không riêng lúc dựng).
    func testRegroupKeepsUnverifiedFirstSortOrder() {
        let verified = ReviewDraft(
            term: "v", pos: "noun", ipa: "", meaningVI: "m", cefr: "",
            example: "ex", verification: .verified, isSelected: false)
        let unverified = ReviewDraft(
            term: "u", pos: "noun", ipa: "", meaningVI: "m", cefr: "",
            example: "ex", verification: .unverified, isSelected: false)
        let result = ReviewDraftBuilder.regroup(
            visible: [verified, unverified], matureHidden: [], matureSenses: [:])
        XCTAssertEqual(result.visible.map(\.term), ["u", "v"])
    }
}
