# Plan: apple-ai-r1 — Apple Intelligence: sửa lỗi OCR + agent phân tích mặc định

> Trạng thái: **T1–T7 xong** (2026-10-05). ADR: **ADR-063** (kế hoạch ban đầu ghi
> ADR-061 — đã trùng với ADR-061 của pdf-nav-r1, đổi số khi viết docs ở T2).
> **Cập nhật 2026-10-05 (cùng ngày, ocr-quality-r1):** phần "soát lại OCR" (mục 1
> dưới, `CorrectingTextRecognizer`/`FoundationModelsOCRCorrector`/`OCRFixApplier`)
> đã **GỠ HẲN** — ADR-064 đổi engine OCR sang `liveText`, ADR-065 gỡ nhánh LLM sau
> khi fen xác nhận `liveText` đủ tốt. Phần "agent phân tích mặc định" (mục 2) vẫn
> còn nguyên, không đổi. Xem `docs/decisions-log.md` ADR-064/065,
> `docs/journal/2026-10-05.md`.

## Context

Fen muốn dùng Apple Intelligence (`FoundationModels`, iOS/macOS 26+) cho hai việc:
1. Soát lại OCR trên máy trước khi gửi agent phân tích (Vision đọc sai do nhoè/font lạ).
2. Thêm Apple Intelligence làm một agent phân tích, **mặc định** khi máy hỗ trợ và
   đã bật — không thay thế BYOK, chỉ là lựa chọn không cần key.

Quyết định trước khi code (2026-10-04): đo thật bằng spike (T1) rồi mới chọn model/
kiến trúc, vì các giới hạn runtime (context size, guardrail, entitlement) không
đoán được từ tài liệu Apple. Sửa OCR phải **im lặng**, ưu tiên giữ nguyên câu
("ưu tiên nguyên vẹn nhất câu chứ không phải rephrase").

## T1 — Spike (xong 2026-10-05)

Chạy thật trên máy fen (macOS 27.0, model "AFM 3 Core"), 4 trang diagnostics thật.
File: `app/ReadoTests/AppleIntelligenceSpikeTests.swift` (mặc định `XCTSkip`, chạy
bằng `TEST_RUNNER_READO_AI_SPIKE=1 ... scripts/test.sh test
-only-testing:ReadoTests/AppleIntelligenceSpikeTests`).

**Phát hiện quan trọng (quyết định toàn bộ kiến trúc T6):**
- Lane `kit` (ReadoKitTests, SwiftPM CLI trên macOS) **không gọi được**
  FoundationModels — xctest trần qua `xcodebuild test -destination platform=macOS`
  không phải app đã ký/sandbox đúng cách, Model Manager từ chối ("Operation not
  permitted", `ModelManagerError 1046`). Phải chuyển spike sang `ReadoTests` (chạy
  lồng trong `Reado.app` trên Simulator — môi trường giống hệt lúc feature chạy
  thật).
- **Guided generation luôn vỡ context.** Schema FR-02 đầy đủ (segments lồng
  phrases + vocabulary + summary) tự ăn ~2500 token dù `includeSchemaInPrompt`
  mặc định `true` — 8/8 lượt `onDevice-G` lỗi "exceeds context size 4096" dù
  prompt gốc chỉ ~1450–1565 token.
- **String + `.permissiveContentTransformations` cũng vỡ 2/4 trang** — một lượt
  DUY NHẤT cho cả trang không đủ chỗ dù không guided.
- **Chia nhỏ (dịch từng đoạn) chạy được 4/4 trang**, 17–34s/trang — ngang tầm
  BYOK cloud (~45s đo được ở diagnostics cũ).
- **PCC crash cứng**: `PrivateCloudComputeLanguageModel()` ném
  `Fatal error: Missing entitlement com.apple.developer.private-cloud-compute`
  ngay khi construct — cần fen bật capability trong Xcode (Apple cấp quyền
  riêng), chưa làm được phiên này.
- **Prompt sửa OCR bản đầu bị model đọc nhầm ví dụ thành lỗi thật** — liệt kê
  "rn/m, cl/d, l/I/1…" trong instructions khiến model lặp lại CHÍNH các cặp đó
  trên mọi trang test. Viết lại instructions bỏ ví dụ dạng cặp ký tự.
- `OCRFixApplier` chặn được gần hết đề xuất bậy, nhưng **một fix vẫn lọt và làm
  WER xấu đi** (0.131→0.134) — rủi ro "sửa im lặng" là thật, không chỉ lý thuyết.

**Quyết định của fen sau khi đọc report** (AskUserQuestion, 2026-10-05):
(a) Chia nhỏ là **mặc định**, không phải fallback sau khi thử một lượt.
(b) Model: **on-device only** cho R1 (PCC để R2 khi fen bật entitlement).
(c) Sửa OCR: **text-only** (ảnh+text chậm ~3x, không tốt hơn).
(d) OCR-fix giữ mặc định **BẬT**, nhưng viết lại prompt + luật áp trước khi code.

## Spec (GWT, ADR) — xem chi tiết

- `docs/decisions-log.md` ADR-063 — bối cảnh đầy đủ, số đo, quyết định, đã cân nhắc.
- `docs/specs/prd.md` FR-02 + FR-21 — GWT mới (v0.14).
- `docs/specs/db.md` A.1/A.2 — CHECK mới + hàng builtin.
- `CLAUDE.md` §1/§5.

## Tầng 1 — HLD (như đã build)

```
AnalyzerFactory.active(db:, ocrFixEnabled:, onProgress:)
  → textRecognizer(ocrFixEnabled:, status:) → PageOCR.live hoặc
    CorrectingTextRecognizer(base: PageOCR.live, corrector: FoundationModelsOCRCorrector)
  → analyzer(for: kind, ..., ocr:)
      "openai_compat"      → OpenAICompatClient
      "reado_proxy"        → NoAgentAnalyzer (placeholder "chưa chọn agent")
      "apple_intelligence" → AppleIntelligence.makeAnalyzer(ocr:onProgress:)
                                → AppleIntelligenceAnalyzer(model: OnDeviceAnalysisModel())

AppleIntelligenceAnalyzer.run():
  checkStatus() → OCR (ảnh) hoặc pageText (PDF) → chunkedPipeline():
    tách đoạn (\n\n) → model.translateParagraph() mỗi đoạn (String + permissive)
    → model.extractVocabulary() MỘT lượt cả trang (guided, schema phẳng,
      includeSchemaInPrompt: false, tự retry 1 lần với text cắt ngắn nếu vỡ context)
    → model.summarize() MỘT lượt (String + permissive)
    → ráp {segments, vocabulary, summary_vi} → AnalysisResponseNormalizer/Decoder
      (CHUNG với BYOK — không viết lại luật lọc/verify)
```

- **ReadoKit** (`Analysis/AppleIntelligence/`): `OCRFix`/`OCRFixApplier`,
  `OCRCorrector`/`FoundationModelsOCRCorrector`, `CorrectingTextRecognizer`/
  `TimeoutRunner`, `AppleIntelligenceStatus`/`AppleIntelligence` (cổng không
  mang `@available`), `AppleAnalysisModel`/`OnDeviceAnalysisModel`,
  `AppleIntelligenceErrorMapper`, `AppleIntelligenceAnalyzer`.
- **Reado**: `AppModel` (`ocrFixAvailable`, `appleAgentStatus`, `applyDefault`
  gọi mỗi `reloadOverview`, `activeAgentReady` tính riêng cho hàng Apple),
  `SettingsView` (toggle OCR-fix, hàng Apple không swipe/mờ khi không sẵn sàng).

## Tầng 2 — Tasks (trạng thái thật)

| Task | Trạng thái | Việc chính | Test |
|---|---|---|---|
| T1 | ✅ | Spike thật trên Simulator (không phải `kit` — xem phát hiện ở trên) | report.md thật, không commit |
| T2 | ✅ | ADR-063 + GWT prd.md + db.md + CLAUDE.md + ROADMAP.md | `/raudit` chưa chạy lại |
| T3 | ✅ | `OCRFix`/`OCRFixApplier`/`OCRCorrector`/`FoundationModelsOCRCorrector`/`CorrectingTextRecognizer`/`TimeoutRunner`/`AppleIntelligenceStatus` | 30 test mới, weak-link xác nhận `otool -L` |
| T4 | ✅ | `AnalyzerFactory.textRecognizer`, toggle Settings, `diag_summary.py` | 4 test mới |
| T5 | ✅ | Migration v6, `AnalysisAgentStore.applyDefault`/`builtinAgent` | ~15 test mới (`AppleAgentStoreTests`) |
| T6 | ✅ | `AppleIntelligenceAnalyzer` + `OnDeviceAnalysisModel` + error mapper | `AppleIntelligenceAnalyzerTests` + `AppleIntelligenceErrorMapperTests` |
| T7 | ✅ | `AnalyzerFactory`/`AppModel`/`SettingsView` nối agent thật, `READO_DEV_APPLE_AI` | 2 test mới, xem tay qua ảnh (1/2 trạng thái) |

**Khác với plan gốc (do số đo T1, không phải tự ý đổi):**
- Không có `PCCAnalysisModel`/`FallbackAnalysisModel`/nhánh "auto" — R1 chỉ
  on-device (PCC crash cứng, thiếu entitlement).
- Không có nhánh ảnh+text cho sửa OCR — đo thấy chậm hơn, không tốt hơn.
- `AppleIntelligenceAnalyzer` KHÔNG thử một lượt rồi fallback chia nhỏ — chia
  nhỏ là đường DUY NHẤT (một lượt đơn không đáng tin trên trang sách thật).
- `phrases` rỗng ở agent Apple R1 (dịch theo đoạn độc lập, chưa có cách lấy cặp
  cụm EN↔VI gắn với bản dịch đoạn tương ứng mà không thêm một lượt gọi nữa).

## Verification

| Task | Tự động | Tay (fen) |
|---|---|---|
| T1–T6 | `scripts/test.sh kit` 517/517 | — |
| T7 | `scripts/test.sh` (full) 536/539 (3 skip = spike + 2 cũ) | ảnh Settings: trạng thái "off" đã chụp đúng (hàng Apple mờ + lý do + checkmark giữ nguyên khi đang active); trạng thái "available" cần cuộn (`DebugLaunch` không giả lập cuộn) — chưa chụp |

**Nợ xem tay (cần fen, máy thật có Apple Intelligence):**
1. Cài mới / xoá agent BYOK đang dùng → mở lại app → Apple tự thành active.
2. Chụp 1 trang qua Apple, so cảm quan với BYOK.
3. Đổi qua lại BYOK ⇄ Apple trong Settings.
4. Tắt Apple Intelligence trong Cài đặt iOS → mở lại Reado → hàng Apple mờ + lý
   do, chụp báo lỗi rõ.
5. Một trang PDF qua Apple (`analyzeText`, không OCR).
6. Đối chiếu vài lần sửa OCR thật với `page.jpg` — xác nhận không câu nào bị
   viết lại (`scripts/pull_diagnostics.sh` + `scripts/diag_summary.py`, giờ in
   thêm dòng "OCR fix: N áp / M loại / X ms").

**Nợ kỹ thuật (để R2 hoặc khi fen cần):**
- PCC: fen bật capability `com.apple.developer.private-cloud-compute` trong
  Xcode (Signing & Capabilities) rồi báo — có thể thêm `PCCAnalysisModel` +
  `modelChoice` mà không cần migration mới (cột `model` đã có sẵn giá trị
  `'on_device'`, thêm `'pcc'`/`'auto'` là đủ).
- `phrases` cho agent Apple (cần một lượt gọi thêm mỗi đoạn, hoặc gộp vào
  `translateParagraph`).
- **Tốc độ response (/ridea 2026-10-05):** `chunkedPipeline` dịch từng đoạn
  TUẦN TỰ (`AppleIntelligenceAnalyzer.swift:136-162`), mỗi lượt tạo
  `LanguageModelSession` mới, không prewarm — 17–34s/trang. Hai hướng chưa đo:
  (B) chạy song song các lượt dịch đoạn độc lập bằng `TaskGroup` — CHƯA BIẾT
  model on-device có thật sự xử lý song song hay xếp hàng ngầm, cần spike đo
  trước khi code thật; (C) prewarm session sớm hơn (song song lúc OCR chạy) —
  rủi ro thấp, chỉ giảm độ trễ cảm nhận chứ không giảm thời gian xử lý thực.
  Khuyến nghị: spike B riêng trước (đo thời gian, không phải code chính thức);
  C làm luôn không cần đo. Chưa ai làm, không chặn gì — làm khi fen cần.
