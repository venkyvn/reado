# Plan — prompt-v6: dịch hay, cặp cụm EN↔VI, chọn sẵn top 5

> **Trạng thái:** open (2026-09-30) - dịch hay + cặp cụm EN↔VI + chọn sẵn top 5; fen go, chưa code

> 3 task, T1 làm chen lúc nào cũng được; T3 sau `reencounter-r1` T2.

## Spec
- FR / journey: FR-02 (output schema), FR-05 (hiển thị cặp cụm), **FR-09 criterion 1 "mặc định tất cả" → "chọn sẵn top 5"** (sửa PRD). J1, J2.
- Nguyên lý: #2 (bản dịch là thứ để học văn phong, chống word by word), #3 (AI đề xuất, người duyệt cuối). Không đụng NG.
- In-scope: prompt v6, `segments[].phrases`, xếp hạng vocabulary + preselect 5, UI chạm-sáng, script đánh giá.
- Out-of-scope: `proxy/prompt.py` (còn v1 ảnh, proxy chưa deploy — ghi nợ), lưu cặp cụm vào kho từ.
- Q mở: không. Fen chốt 2026-09-30: **N = 5, AI xếp hạng**; bộ đánh giá = **replay Diagnostics**.
- Docs lệch đã thấy: prompt baseline ĐÃ có ở `prompt-spec.md` §2 (09-08) — session-brief §2 ghi "trống" là sai (đã sửa).

## Tầng 1 — HLD
- Schema output thêm (tuỳ chọn, không phá output cũ): `segments[].phrases: [{"en": "...", "vi": "..."}]`, `maxItems 6`. `en` phải là substring của `source_en`, `vi` của `translation_vi` — sai thì bỏ im lặng (đồ hiển thị, không phải vocab; luật "không tự loại" của FR-02 chỉ áp cho vocabulary).
- `vocabulary[]` trả về theo thứ tự giá trị học giảm dần. `ReviewDraft.drafts` chọn sẵn tối đa 5 item đầu trong số verified + đúng CEFR; phần còn lại hiện, không chọn sẵn.
- `SegmentDTO` thêm `phrases` optional → JSON phiên đọc cũ vẫn decode; cặp cụm theo phiên đọc (tối đa 10 phiên), không vào `vocab_items`.
- `Prompt.version` 5 → 6.
- prompt-spec §7 dòng "Nên đưa từ nào vào bộ ôn tập" → sửa: AI chỉ **xếp thứ tự đề xuất**, người dùng vẫn duyệt (FR-03/FR-09).
- File: `Analysis/Prompt.swift`, `AnalysisResponseDecoder.swift`, `AnalysisResponseNormalizer.swift`, `PageAnalysis.swift`, `ReviewDraft.swift`, `Session/ReadingSession.swift`; Reado `AnalysisView`/`SegmentBlock`, `ReadingSessionView`.

## Tầng 2 — Tasks

### T1 — công cụ đánh giá
- `scripts/prompt_eval.py` (stdlib/urllib, không dependency): đọc OCR của ≤30 lần phân tích trong thư mục `scripts/pull_diagnostics.sh`, chạy prompt v5 và v6 (key từ `.env`), xuất bảng so song song Markdown ra `.tmp/prompt-eval/`.
- DoD: chạy được trên 1 thư mục diagnostics thật; không ghi text trang vào repo (bản quyền).

### T2 — prompt v6 + decoder
- Prompt: dịch theo văn phong, cụm/nhịp câu tự nhiên; `phrases`; xếp hạng vocabulary.
- Decoder/normalizer: `phrases` optional + kiểm substring; preselect top 5.
- Test: decode có/không `phrases`, bỏ cặp sai, JSON phiên cũ, preselect 5.
- Docs: prompt-spec §3/§4/§7, PRD FR-09, ADR-049.
- DoD: full xanh **và** fen chấm bảng T1: v6 không tệ hơn v5.

### T3 — UI chạm-sáng
- Chạm cụm EN → cụm VI tương ứng sáng (AnalysisView + ReadingSessionView). Kiểu hiển thị khác gạch chân từ kho của `reencounter-r1`.
- DoD: full xanh + fen xem tay.
