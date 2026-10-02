# Plan: fr10-close-r1 — khép FR-10 (task 3.8): tính lại nhóm "Đã thuộc" khi đổi đích + đồng bộ docs

> **Trạng thái:** closed (2026-10-02) - T1 xong: `ReviewDraftBuilder.regroup` + `AnalysisView.onChange` + 9
> test. Full `scripts/test.sh` 424/426 xanh (2 skip cũ). Ảnh fixture tĩnh + fen xem tay đổi đích thật trên
> simulator (chạm "Lưu vào ⏷" đổi bộ rồi đổi lại Kho tạm) — pass, không còn nợ xác minh.

## Context
ROADMAP 3.8 và PRD FR-10 ghi "chưa bật bộ lọc trong code", nhưng code đã có từ `73f92a6` (lọc lúc duyệt)
và ADR-056/q13-sense-filter-r1 (2026-10-02, gập thay vì xoá). Lỗ hổng thật còn lại: `AnalysisView` chỉ tính
nhóm gập **một lần** lúc mở màn (`syncDraftsIfNeeded`), trong khi ADR-053 cho đổi đích ngay trên màn duyệt
(`CollectionDestinationPicker`) và Q-09 so khớp "đã thuộc" theo collection — đổi đích mà không tính lại thì
từ đã thuộc ở bộ mới lọt danh sách chính (có thể đang chọn sẵn → lưu trùng), từ đã thuộc ở bộ cũ bị gập oan.

## Spec
- FR / journey: FR-10 GWT 1–4 (`prd.md:470`), Q-09, ADR-053, J1 bước 4 + J2 bước 4 (`journeys.md`).
- Nguyên lý: #3 Capture — "Chống lại: bộ ôn chứa thứ người dùng đã biết". NG: không đụng.
- In-scope: tính lại nhóm gập khi đổi đích; sửa docs lỗi thời về 3.8.
- Out-of-scope: schema, transaction #4, ngưỡng Q-08, UI Settings cho `known_stability`, tính lại khi sửa tay
  term/pos (chỉ tính lại theo đích), đánh giá độ phủ so khớp trên dữ liệu thật (→ gộp 3.13).
- Q mở: không.

## Tầng 1 — HLD
- **ReadoKit** (thuần): `ReviewDraftBuilder.regroup(visible:matureHidden:matureSenses:) -> ReviewDraftResult`
  (`ReviewDraft.swift`). Nhận draft **hiện tại** (giữ sửa tay + lựa chọn); khoá tính trên term/pos của draft;
  rời nhóm gập → `visible`, giữ `isSelected`; vào nhóm gập → bỏ chọn (ADR-056), `knownMeanings` theo
  `matureSenses` mới; `visible` sort lại unverified/suspect lên đầu.
- **Reado**: `AnalysisView.onChange(of: model.capture.analysisTargetCollectionID)` → `regroupMatureIfNeeded()`
  gọi `regroup` với `model.matureSensesForCapture()`.
- Protocol / transaction: không đổi. File cấm: `project.pbxproj`, schema/migration, `Prompt*.swift`.

## Tầng 2 — Tasks

### T1 — regroup khi đổi đích + khép 3.8 — XONG 2026-10-02
- Files: `ReviewDraft.swift` (+`regroup`, `MatureHiddenDraft.init` public), `ReviewDraftBuilderTests.swift`
  (+9 test), `AnalysisView.swift` (`onChange` + `regroupMatureIfNeeded`). Docs: `ROADMAP.md` 3.8 → ✅,
  `prd.md` FR-10 bỏ câu "chưa bật bộ lọc", `journeys.md` J1 bước 4.
- Test: visible→hidden (bỏ chọn), hidden→visible (giữ chọn), khoá theo term/pos đã sửa, field sửa tay sống
  sót qua đổi nhóm, `knownMeanings` làm mới theo bộ mới, `matureSenses` rỗng → tất cả về visible, idempotent,
  giữ sort unverified-first. Tất cả xanh (kit 21/21 riêng file).
- DoD: `scripts/test.sh kit` xanh → full xanh (424/426, 2 skip cũ) → ảnh `analysis-fixture-mature`
  light/dark đúng MASTER → fen xem tay đổi đích thật trên simulator (2026-10-02) — pass, hết nợ.
