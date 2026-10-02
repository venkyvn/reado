# Plan — prompt-v6: dịch hay, cặp cụm EN↔VI, chọn sẵn top 5

> **Trạng thái:** open (cập nhật 2026-10-02) — **T1 ✅ + T2a ✅ + T2b ✅ (code+build, chờ fen chấm
> bảng eval) + T3 ✅ (code+test+ảnh, chờ fen xem tay `ReadingSessionView`)**.
> Hợp đồng gốc 09-30 vẫn đúng; sửa vài chỗ đã cũ sau remove-proxy (ADR-049) và ux-redesign-r1.

## Chỗ cập nhật so với bản 09-30
1. ADR cho prompt v6 → **ADR-055** (ADR-049 đã là "bỏ proxy").
2. Out-of-scope cũ ghi nợ `proxy/prompt.py` — proxy đã xoá hẳn (ADR-049), bỏ.
3. "T3 sau reencounter-r1 T2" — T2 đã xong, T3 hết chặn.
4. File UI đúng vị trí hiện tại: `SegmentBlock` ở `app/Reado/Analysis/AnalysisComponents.swift`;
   `ReadingSessionView` ở `app/Reado/Library/ReadingSessionView.swift`.
5. Bẫy: `AnalysisResponseNormalizer.normalize` dựng lại segment chỉ giữ `source_en`/`translation_vi`
   → sẽ làm rơi `phrases` nếu không sửa. T2 phải vá chỗ này.
6. Preselect hiện tại (`ReviewDraftBuilder.drafts`) giữ verified theo **thứ tự xuất hiện trên trang**,
   unverified/suspect lên đầu. v6 đổi: verified giữ **thứ tự AI xếp hạng giá trị học**, preselect top 5 đầu.

## Spec
- FR / journey: FR-02 (output schema), FR-05 (hiển thị cặp cụm), **FR-09 criterion 1 "mặc định tất cả"
  → "chọn sẵn top 5"** (sửa PRD). J1, J2.
- Nguyên lý: #2 (bản dịch là thứ để học văn phong, chống word by word), #3 (AI đề xuất, người duyệt
  cuối). Không đụng NG.
- In-scope: prompt v6, `segments[].phrases`, xếp hạng vocabulary + preselect 5, UI chạm-sáng, script
  đánh giá.
- Out-of-scope: lưu cặp cụm vào kho từ; đổi transport/client.
- Q mở: không. Fen chốt 2026-09-30: **N = 5, AI xếp hạng**; bộ đánh giá = **replay Diagnostics**.

## Tầng 1 — HLD
- Schema output thêm (tuỳ chọn, không phá output cũ): `segments[].phrases: [{"en": "...", "vi": "..."}]`,
  `maxItems 6`. `en` phải là substring của `source_en`, `vi` của `translation_vi` — sai thì bỏ im lặng
  (đồ hiển thị, không phải vocab; luật "không tự loại" của FR-02 chỉ áp cho vocabulary).
- `vocabulary[]` trả về theo thứ tự giá trị học giảm dần. `ReviewDraft.drafts` chọn sẵn tối đa 5 item
  đầu trong số verified + đúng CEFR; phần còn lại hiện, không chọn sẵn.
- `PageAnalysis.Segment` + `SegmentDTO` (ReadingSession) thêm `phrases` optional → JSON phiên đọc cũ
  vẫn decode; cặp cụm theo phiên đọc (tối đa 10 phiên), không vào `vocab_items`. Không đổi DDL SQLite.
- `Prompt.version` 5 → 6.
- prompt-spec §7 dòng "Nên đưa từ nào vào bộ ôn tập" → sửa: AI chỉ **xếp thứ tự đề xuất**, người dùng
  vẫn duyệt (FR-03/FR-09).
- File: `Analysis/Prompt.swift`, `AnalysisResponseDecoder.swift`, `AnalysisResponseNormalizer.swift`,
  `PageAnalysis.swift`, `ReviewDraft.swift`, `Session/ReadingSession.swift`; Reado
  `Analysis/AnalysisComponents.swift` (SegmentBlock), `Library/ReadingSessionView.swift`.

## Tầng 2 — Tasks

### T1 — công cụ đánh giá (làm trước) (✅ xong 2026-10-02)
- `scripts/prompt_eval.py` (stdlib/urllib, không dependency): đọc OCR của ≤30 lần phân tích trong
  thư mục `scripts/pull_diagnostics.sh` (`.tmp/diagnostics/<ts>/…/analyses/*/` có `page_ocr.txt`,
  `meta.json` [model, baseURL, cefr], `response_raw.txt`).
- Prompt lấy từ file template `scripts/prompts/v5.txt` (chép nguyên `Prompt.text` hiện tại, placeholder
  `{CEFR}`/`{PAGE_OCR}`); gọi cùng model/baseURL của từng lần phân tích gốc, body giống
  `OpenAICompatClient.body` (`response_format: json_object`).
- Key: đọc `.env` lúc chạy (tái dùng logic `pick_key` của `scripts/sim_aibox.sh`), không in key ra bất
  cứ đâu.
- Xuất bảng so song song Markdown (EN · VI-vA · VI-vB · vocab rank) vào `.tmp/prompt-eval/` — không
  ghi text trang vào repo (bản quyền).
- DoD: chạy được trên 1 thư mục diagnostics thật với `--prompt v5.txt --prompt v5.txt` (sanity, so
  một prompt với chính nó trước khi có v6).
- **Kết quả:** chạy thật trên `.tmp/diagnostics/20260928T112557Z/` (4 lần phân tích) — gọi đúng API,
  nhưng `deepseek-v4.1-flash` trả 503 model_not_found cả 4 lần (model đã đổi tên/ngừng ở provider —
  đáng chú ý cho T2, không phải lỗi script). Output đúng chỗ, không lộ key/text trang. Chi tiết:
  `docs/journal/2026-10-02.md`.

### T2 — chi tiết hoá 2026-10-02: tách T2a/T2b (gộp quá nhiều cho 1 session + DoD cần model sống)

#### T2a — đường ống `phrases` trong ReadoKit (thuần, không mạng) (✅ xong 2026-10-02)
- `PageAnalysis.Segment` thêm `phrases: [Phrase]` (`Phrase { en, vi }`), mặc định `[]` → 4 chỗ gọi hiện
  có không phải sửa.
- `AnalysisResponseNormalizer` giữ `phrases` khi dựng lại segment (hiện đang làm rơi): chỉ cặp `en`/`vi`
  không rỗng, `en` ⊂ `source_en`, `vi` ⊂ `translation_vi` (so khớp **qua `VerifyEngine.normalize`** —
  case/dấu câu cong/whitespace, tái dùng util đối chiếu `example` sẵn có), tối đa 6 — cặp sai bỏ im
  lặng. Decoder: `RawSegment.phrases` optional, thiếu = `[]`.
- `SegmentDTO` (ReadingSession) thêm `phrases: [PhraseDTO]?`, encode `nil` khi rỗng; JSON phiên cũ (không
  key) vẫn decode ra `[]`.
- Files: `Analysis/PageAnalysis.swift`, `Analysis/AnalysisResponseNormalizer.swift`,
  `Analysis/AnalysisResponseDecoder.swift`, `Session/ReadingSession.swift`.
- Test (`AnalysisDecoderTests`, `ReadingSessionTests`): có phrases hợp lệ giữ đúng thứ tự; cặp không ⊂
  nguồn/rỗng bị bỏ; >6 cắt còn 6; không có `phrases` → `[]`; round-trip encode/decode; JSON phiên cũ.
- Docs: prompt-spec §4 (schema `phrases` optional, maxItems 6, luật substring); ROADMAP FR-02/FR-05.
- DoD: `scripts/test.sh` full xanh. Không đổi `Prompt.version` (prompt v5 chưa xin `phrases`).
- **Kết quả:** +6 test (`AnalysisDecoderTests` ×4, `ReadingSessionTests` ×2). Full test **390/392
  xanh** (2 skip opt-in cũ), `** TEST SUCCEEDED **`. Chi tiết: `docs/journal/2026-10-02.md`.

#### T2b — prompt v6 + xếp hạng + preselect top 5 (✅ code+build xong 2026-10-02, chờ fen chấm)
- Model eval: **`qwen3.8-flash`** (fen chốt 2026-10-02 — `deepseek-v4.1-flash` cũ đã 503 model_not_found).
- `prompt_eval.py` thêm `--model`/`--base-url` ghi đè meta; `load_prompt_template` nhận cả `.swift`
  (rút literal multi-line string trong `Prompt.text`) → so trực tiếp với bản đang sửa, không cần
  `v6.txt` riêng (tránh lệch template). Thêm bảng song song Markdown theo chỉ số segment
  (EN · VI mỗi prompt · phrases mỗi prompt) + list vocab theo thứ tự AI, đánh dấu 5 item sẽ preselect.
- `Prompt.swift` v6 (`version = 6`): dịch theo cụm/nhịp câu tự nhiên (vision #2), xin `phrases` 2–6 cặp/
  đoạn, `vocabulary` xếp theo giá trị học giảm dần.
- `ReviewDraftBuilder.drafts`: verified giữ thứ tự AI (không còn thứ tự trang); preselect tối đa
  `preselectLimit` (5) đầu trong số verified + đúng CEFR (đếm sau `excludingMature`). Unverified/suspect
  vẫn lên đầu, không chọn sẵn, không chiếm suất.
- Test (`ReviewDraftBuilderTests`, +6): 8 verified → đúng 5 đầu; 3 verified → cả 3; CEFR lọc trước rồi
  mới đếm 5 (item ngoài level không chiếm suất); unverified không chiếm suất dù đứng trước; mature-
  excluded không chiếm suất. Sửa comment `testDraftBuilderNilLevelsSelectsAllVerified` theo luật mới.
- Docs: PRD FR-09 criterion 1; journeys.md (J1 bước 4, bảng mục 1); prompt-spec §3 (trỏ v6) + §7 dòng
  "Nên đưa từ nào vào bộ ôn tập" → "AI chỉ xếp thứ tự đề xuất"; ADR-055; ROADMAP nhật ký.
- **Kết quả:** full suite **395/397 xanh** (2 skip cũ), kit **376/376**, `** TEST SUCCEEDED **`. Chạy
  thật `qwen3.8-flash` trên 4 trang `.tmp/diagnostics/20260928T112557Z/`
  (`python3 scripts/prompt_eval.py --diagnostics .tmp/diagnostics/20260928T112557Z --model qwen3.8-flash
  --prompt scripts/prompts/v5.txt --prompt app/ReadoKit/Sources/ReadoKit/Analysis/Prompt.swift`):
  cả 4 trang hai bản đều ra JSON hợp lệ, v6 có phrases hợp lệ (11–16/trang, v5 luôn 0 vì chưa hỏi),
  vocab 2 bản tương đương về chất lượng. Bảng: `.tmp/prompt-eval/20261002T041512Z.md` (gitignore,
  **không** commit — có text trang bản quyền).
- **DoD còn treo:** full xanh ✅ **và** fen chấm bảng v5 vs v6 — bảng đã có, **fen chưa xác nhận**.
  Coi T2b là "code xong, build xanh", chưa coi là "prompt v6 đã kiểm chứng chất lượng" cho tới khi
  fen đọc `.tmp/prompt-eval/20261002T041512Z.md` và nói v6 không tệ hơn.

### T3 — UI chạm-sáng (✅ code+test+ảnh xong 2026-10-02, chờ fen xem tay `ReadingSessionView`)
- `Analysis/PhraseLocator.swift` (ReadoKit, mới): định vị `segment.phrases[].en`/`.vi` thành
  `Range<String.Index>` trên chuỗi gốc — dựng bảng (ký tự gập 1-1 ↔ index gốc) theo đúng luật
  `VerifyEngine.normalize`, tìm khớp có biên từ (EN) hoặc không (VI, dấu câu tiếng Việt không đều),
  bỏ qua lần khớp sai biên và thử lần kế tiếp (`cue` không khớp giữa `rescue`), chồng chữ thì cụm sau
  bị bỏ. Cụm không định vị được bỏ im lặng — đồ hiển thị (FR-05), không phải vocabulary.
- Hiển thị: cụm EN gạch chân liền mảnh (`Color.secondary`, không chồng với gạch chấm accent của
  FR-22). Chạm cụm EN → cụm đó VÀ cụm VI tương ứng cùng tô nền `accent.opacity(0.18)`, chữ giữ
  `.primary`; tự hiện bản dịch đoạn nếu đang ẩn. Tối đa MỘT cụm sáng trên cả màn. Ẩn bản dịch của
  đoạn đang sáng (nút đoạn hoặc nút đáy) → tắt luôn highlight. `accent` đọc qua
  `@AppStorage("appTheme")` (pattern `ShellTabBar`, MASTER §Màu ngoại lệ ux-redesign-r1 T10), không
  `Color.accentColor` trần.
- `EncounterText.swift`: thêm tham số có default (`phrases`, `activePhraseIndex`, `accent`,
  `onPhraseTap`) — link cụm (`reado-phrase://`) gán TRƯỚC, link từ gặp lại FR-22
  (`reado-term://`) gán SAU nên đè ở phần chữ chồng (chạm đúng chữ chồng mở popover từ cũ, không
  sáng cụm — ưu tiên có chủ ý). `PhraseHighlightText.swift` (mới, `Shared/`): bản VI, không
  tappable, chỉ phản chiếu cụm đang sáng.
- `SegmentBlock` (`AnalysisComponents.swift`) + `ReadingSessionView`: nối `PhraseLocator.spans`,
  state `activePhrase` (segment+phrase index), `togglePhrase`/`revealIfNeeded`; `accessibilityActions`
  một action mỗi cụm (VoiceOver không chạm được link lồng trong `Text` theo span).
- Debug: `DebugLaunch.Screen.phraseHighlight` (`-ReadoScreen phrase-highlight`) — mở tab Trang, sáng
  sẵn cụm đầu tiên định vị được, không cần chạm tay. Cờ `AppState.debugActivateFirstPhrase`.
- Fixture `scripts/fixtures/analysis-demo.json` thêm `phrases` cho cả 3 đoạn (2–3 cặp/đoạn); một cặp
  chứa `keystone` để chụp được ca chồng với từ gặp lại FR-22 (`demo-vocab.csv`).
- Test (`PhraseLocatorTests`, ReadoKit, +10): khớp đúng nguyên văn, khác hoa/thường, nháy cong,
  khoảng trắng kép/xuống dòng, giữ dấu tiếng Việt (`ban` ≠ `bán`), biên từ EN (`in` không khớp
  `within`), bỏ qua lần khớp sai biên thử lần kế (`cue` trong `rescue`), không tìm thấy, chồng nhau,
  rỗng, giữ đúng `phraseIndex` gốc. `DebugLaunchTests` +1 (`phrase-highlight`).
- **Kết quả:** kit 387/387 (+11), full **406/408** (+11, 2 skip cũ), `** BUILD SUCCEEDED **` /
  `** TEST SUCCEEDED **`. Ảnh `analysis-fixture-page` (gạch chân cụm, chồng với `keystone`) và
  `phrase-highlight` (trạng thái đã chạm) — light/dark + theme sepia — đúng MASTER, không bị
  `ShellTabBar` che. **Chưa xem tay** `ReadingSessionView` thật (phiên đọc đã lưu — chưa có launch
  argument mở thẳng màn đó); DoD còn treo phần này, ghi ở session-brief §2.7.
