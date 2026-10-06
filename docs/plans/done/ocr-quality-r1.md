# Plan: ocr-quality-r1 — đọc đúng từ đầu thay vì sửa sau

> **Trạng thái:** open (2026-10-05) - T0–T4 + T7 xong (ADR-064/065, engine `liveText`); T6 chờ D3 (OW-12)

> Trạng thái: **DRAFT 2026-10-05**, chờ fen chốt các mục "Fen cần chốt". ADR dự kiến: **ADR-064**
> (ADR-063 đã thuộc về `apple-ai-r1`).

## Context

Nhánh `apple-ai-r1` thêm bước sửa OCR bằng Apple Intelligence (`CorrectingTextRecognizer` + `FoundationModelsOCRCorrector` + `OCRFixApplier`), mặc định BẬT và sửa im lặng. Review ngày 2026-10-05 thấy bốn vấn đề:

- **Nhắm sai loại lỗi.** Sau ADR-042, lỗi còn sót chủ yếu là nhiễu 1 ký tự và dấu câu (`docs/investigations/ocr-line-drop/README.md:122`: `did I` → `did |`, mất dấu chấm, em-dash). Prompt sửa OCR lại dặn "do not change punctuation".
- **Chưa có số đo nào cho thấy có lợi.** Kết quả định lượng duy nhất của spike là WER xấu đi (0.131 → 0.134).
- **"Đề xuất rồi lọc" không chặn được lỗi ra từ thật.** `"cat"` → `"car"` qua hết mọi luật, và `OCRFixApplier` áp cho MỌI chỗ khớp trên trang.
- **Prompt viết cứng cho "printed English book".** Đầu vào thật đa dạng hơn: PDF chữ, PDF scan, ảnh chụp sách, chụp màn hình, chụp label.

**Nguyên tắc của plan:** nguồn có sẵn chữ thì lấy chữ, chỉ có hình mới OCR. Khi OCR thì dùng engine tốt nhất và ảnh tốt nhất; sửa sau là phương án cuối. Live Text (VisionKit `ImageAnalyzer`) chính là thứ fen dùng làm groundtruth, nhưng chưa bao giờ được probe như một engine. `OCRProbeTests` hiện mới so `legacy` với `documents`.

## Fen cần chốt (trước T0)

- **D1 — số phận `apple-ai-r1`:**
  - (a) Merge cả nhánh, đổi OCR-fix sang mặc định TẮT. *(Khuyến nghị)*
  - (b) Tách riêng phần agent Apple ra merge, phần OCR-fix để sau.
  - (c) Giữ nguyên như nhánh hiện tại.
- **D2 — EPUB:** giữ NG-07, tức để ngoài phạm vi plan này (*khuyến nghị*), hay mở một plan riêng để đảo NG-07.
- **D3 — gợi ý loại nguồn cho prompt (T6):** tự nhận chụp màn hình qua metadata Photos, để người dùng tự chọn "Trang sách / Màn hình / Label", hay để R2.

## Spec

- **FR liên quan:**
  - FR-01: chụp, crop, nén ảnh.
  - FR-02: `segments[]` chia đúng đoạn; `example` khớp `source_en`.
  - FR-04: không đọc được thì báo, không bịa dữ liệu.
  - FR-23: PDF chữ dùng lớp chữ; PDF scan vẽ thành ảnh rồi OCR.
- **Ma trận đầu vào:**

| Đầu vào | Đường hiện tại | Plan này |
|---|---|---|
| PDF chữ | `PDFPageText.extract` → `.text` → `analyzeText` | Không đổi |
| PDF scan | `.needsOCR` → `renderPageAsImage` (2800px) → OCR | Hưởng engine tốt hơn (T3) |
| Ảnh chụp sách | Camera/thư viện → crop → OCR | Engine tốt hơn (T3) + kiểm chất lượng ảnh (T5) |
| Chụp màn hình | Như ảnh chụp | Engine tốt hơn (T3), bỏ qua kiểm chất lượng, gợi ý prompt (T6) |
| Chụp label | Như ảnh chụp | Engine tốt hơn (T3) + nhãn "kiểm tra lại" (T4) + gợi ý prompt (T6) |
| EPUB | Bị cấm (NG-07) | Ngoài phạm vi (D2) |

- **In-scope:**
  - Bộ đo groundtruth gồm nhiều loại đầu vào.
  - Probe `ImageAnalyzer`.
  - Đổi engine OCR nếu số đo ủng hộ.
  - Nhãn "kiểm tra lại" trên từ vựng.
  - Cảnh báo ảnh mờ hoặc loá.
  - Đổi mặc định OCR-fix theo D1.
- **Out-of-scope:**
  - EPUB.
  - Gửi ảnh lên cloud: ADR-034 cấm, ảnh không được rời máy.
  - Sửa OCR bằng LLM theo kiểu mới: chỉ làm nếu T2 thất bại (xem T3b, T7).
  - Đổi UI crop.
- **Không đụng:**
  - Schema DB (không migration).
  - FSRS, `cards`, `review_logs`.
  - `PDFPageText`.
  - `Prompt.version`: giữ **v6**, trừ khi fen chốt làm T6.

## Tầng 1 — HLD

- **ReadoKit, `Analysis/PageOCR.swift`:**
  - Chuỗi engine thành `liveText` (nếu T2 thắng) → `documents` (iOS 26+, ADR-042) → `legacy`. Engine trước lỗi hoặc ra rỗng thì rơi xuống engine sau, như cách `recognizeDetailed` đang làm.
  - Protocol `PageTextRecognizer` giữ nguyên chữ ký, nên `OpenAICompatClient`, `AppleIntelligenceAnalyzer`, `MockAnalyzer` và các fake trong test không phải sửa.
  - Thêm giá trị `engine = "liveText"` vào `OCRResult.engine` và `DebugTrace`.
- **VisionKit `ImageAnalyzer`** có từ iOS 16, nên target iOS 17 là đủ. Gói trong `#if canImport(VisionKit)`, và kiểm tra build cả hai nền vì lane `kit` chạy trên macOS.
- **Không được đổi hợp đồng `\n\n` = ranh giới đoạn** của prompt v6. Nếu `transcript` không tách đoạn rõ thì dựng lại đoạn bằng hình học như legacy, hoặc lấy ranh giới đoạn từ `documents`. T2 sẽ trả lời câu này.
- **Nhãn "kiểm tra lại" (T4):** hàm thuần trong ReadoKit, tính *lúc hiển thị* từ `term`, không lưu DB.
- **Kiểm chất lượng ảnh (T5):** hàm thuần trong `Capture/`, dùng CoreImage hoặc vImage, chạy trước khi submit. Chỉ cảnh báo, không chặn.
- **File cấm:** không edit tay `project.pbxproj`. Thêm file test qua `scripts/pbxproj_tool.py add`.

## Tầng 2 — Tasks

Thứ tự bắt buộc: **T0 → T1 → [đọc số đo] → T2 → [đọc số đo] → T3a hoặc T3b → T4 → T5 → (T6) → T7**.

### T0 — chốt `apple-ai-r1` (theo D1)

- Với D1 (a):
  - Trong `AppModel+Capture.swift`, đổi `?? true` thành `?? false` cho `AppleIntelligence.ocrFixDefaultsKey`.
  - Sửa ADR-063 mục 3: "Mặc định BẬT" thành "Mặc định TẮT, chờ ocr-quality-r1", kèm lý do.
  - Sửa GWT FR-02 trong `prd.md` cho khớp.
- **Test:** `AnalyzerFactoryTests` có case "mặc định thì không bọc `CorrectingTextRecognizer`". Chạy full `scripts/test.sh`.
- **DoD:** test xanh • ADR-063 cập nhật • merge nhánh.

### T1 — bộ đo groundtruth + phân loại lỗi (không đổi code app)

- Gom **ít nhất 12 trang**, mỗi loại ít nhất 3: ảnh chụp sách, PDF scan (trang vẽ thành ảnh), chụp màn hình, chụp label. Kéo về bằng `scripts/pull_diagnostics.sh`.
- **Groundtruth gõ tay từ bản gốc**, không dùng Live Text, cho ít nhất 1 trang mỗi loại. Mục đích là tránh đo vòng tròn: T2 sẽ so Live Text với groundtruth, nên groundtruth không được chính là Live Text. Các trang còn lại có thể dùng Live Text, nhưng ghi rõ trong file.
- **Phân loại lỗi** của engine hiện tại (`documents`) trên từng trang, đếm theo 4 loại:
  - (1) mất hoặc gộp hàng, sai đoạn;
  - (2) chữ không có trong từ điển, như `tbe`, `rnay`;
  - (3) lỗi ra từ thật, như `cat` → `car`;
  - (4) dấu câu hoặc ký tự đơn, như `I` → `|`.
- **DoD:** bảng phân loại trong `docs/journal/<ngày>.md`. **Dừng, báo fen.** Bảng này quyết định T3b và T7 có cần làm hay không.

### T2 — probe `ImageAnalyzer` (công cụ đo, không đổi hành vi release)

- Trong `app/ReadoTests/OCRProbeTests.swift`, thêm cấu hình `liveText` bên cạnh `legacy` và `documents`. Mỗi cấu hình ghi số hàng, số đoạn, WER, CER so với groundtruth, và thời gian chạy (ms).
- Trả lời bằng số bốn câu:
  - (a) `liveText` có WER/CER thấp hơn `documents` trên từng loại đầu vào không?
  - (b) `transcript` có giữ ranh giới đoạn không, hay phải dựng lại?
  - (c) Độ trễ có chấp nhận được không, so với `documents`?
  - (d) Có chạy được trên Simulator không, hay chỉ trên máy thật? Điểm này chưa chắc.
- **Test:** `TEST_RUNNER_READO_OCR_PROBE_DIR=... scripts/test.sh test -only-testing:ReadoTests/OCRProbeTests`
- **DoD:** bảng probe trong journal. **Dừng, báo fen, chọn T3a hay T3b.**

### T3a — đổi engine sang `liveText` (chỉ làm nếu T2(a) thắng rõ)

- Trong `PageOCR.swift`, thêm `recognizeLiveText(imageData:)` và đặt ở đầu chuỗi fallback.
- Nếu `transcript` không có đoạn: Tách hàm thuần dựng đoạn từ dòng và vị trí (tái dùng `linesWithBreaks`), hoặc lấy chữ từ `liveText` và ranh giới đoạn từ `documents`.
- `DebugTrace` và `scripts/diag_summary.py` in ra `engine=liveText`.
- Viết ADR-064: đổi engine OCR mặc định, kèm số đo T2; `documents` và `legacy` lùi xuống làm fallback.
- **Test:** `PageOCRTests` thêm case cho hàm dựng đoạn thuần. Probe chạy lại phải cho WER của `liveText` không cao hơn `documents` trên mọi loại. Chạy full `scripts/test.sh`.
- **DoD:** test xanh • ADR-064 • fen chụp lại 1 trang mỗi loại trên máy thật, `diag_summary` ra `engine=liveText`.

### T3b — đồng thuận hai engine (chỉ làm nếu T2 thất bại và T1 cho thấy lỗi loại 2 hoặc 4 nhiều)

- Chạy cả `documents` và `legacy`, rồi căn hai kết quả theo từng từ.
  - Chỗ hai bên giống nhau: giữ nguyên.
  - Chỗ khác nhau: ưu tiên bên là từ có trong từ điển; nếu cả hai đều là từ thật thì giữ bên `documents`.
- Sửa theo **vị trí token**, không thay toàn bộ text. Lưu `rawText` để debug.
- **Test:** hàm căn và chọn là hàm thuần, test bằng chuỗi dựng tay.
- **DoD:** WER giảm trên bộ T1, và **không có chữ đúng nào bị sửa sai**.

### T4 — nhãn "kiểm tra lại" trên từ vựng (làm dù T3 đi nhánh nào)

- Trong ReadoKit, thêm hàm thuần `VocabSuspicion.check(term:) -> Bool`: từ nào `UITextChecker` (`en_US`) không nhận ra thì coi là nghi ngờ.
  - Bỏ qua: chữ viết hoa đầu, chữ có số, cụm nhiều từ mà từng từ đều hợp lệ.
- Ở màn Duyệt & lưu, từ bị nghi ngờ có nhãn nhỏ "kiểm tra lại". **Không tự sửa**, người dùng vẫn lưu được bình thường.
- **Test:** `VocabSuspicionTests` có `tbe` (nghi ngờ), `Nescafé` (bỏ qua vì viết hoa), `B12` (bỏ qua vì có số), `serendipity` (hợp lệ).
- **DoD:** test xanh • xem tay ảnh màn Duyệt có nhãn.

### T5 — cảnh báo ảnh mờ hoặc loá (chỉ ảnh chụp, không áp cho chụp màn hình và PDF)

- Trong `Capture/`, thêm hàm thuần `ImageQuality.assess(_:) -> [Issue]`:
  - mờ: đo bằng variance of Laplacian;
  - loá: tỉ lệ điểm ảnh gần trắng tụ thành vùng.
- **Ngưỡng lấy từ ảnh trong bộ T1**, không đoán.
- Ở UI capture, khi có vấn đề thì hiện "Ảnh hơi mờ / có vệt loá — chụp lại?", kèm hai nút "Chụp lại" và "Vẫn phân tích".
- **Test:** `ImageQualityTests` với ảnh fixture nét, mờ và loá.
- **DoD:** test xanh • không báo nhầm trên ảnh tốt của bộ T1.

### T6 — gợi ý loại nguồn cho prompt (chỉ làm nếu D3 chốt làm)

- Thêm `sourceKind` (`'page'` / `'screenshot'` / `'label'`) vào prompt ảnh, mỗi loại một câu dặn ngắn.
- Đổi `Prompt.version` từ 6 sang 7, và chạy eval baseline A-02 bằng `scripts/prompt_eval.py` trước và sau khi đổi.
- **DoD:** eval không xấu đi trên trang sách, và tốt hơn trên label và chụp màn hình.

### T7 — dọn OCR-fix bằng LLM (cuối cùng, theo kết quả T1-T3)

- Nếu T3a hoặc T3b đủ tốt: gỡ `CorrectingTextRecognizer`, `FoundationModelsOCRCorrector`, `OCRFixApplier` và toggle trong Settings, rồi cập nhật ADR-063.
- Nếu vẫn cần sửa OCR: làm lại theo hướng chỉ đánh dấu chữ không có trong từ điển, rồi cho model chọn trong danh sách ứng viên (`@Guide(.anyOf(candidates))`). Sửa theo vị trí, gạch chân chữ đã sửa, cho người dùng hoàn tác. Viết plan riêng cho phần này.

## Verification

| Task | Tự động | Tay (fen) |
|---|---|---|
| T0 | `scripts/test.sh` full xanh | — |
| T1 | — | Gom ảnh, gõ groundtruth, làm bảng phân loại lỗi |
| T2 | `OCRProbeTests` in bảng 3 engine × 4 loại đầu vào | Đọc số, chọn T3a hay T3b |
| T3a/b | Probe: WER mới không cao hơn cũ trên mọi loại; full test xanh | Chụp lại 1 trang mỗi loại, chạy `diag_summary` |
| T4 | `VocabSuspicionTests` | Ảnh màn Duyệt có nhãn |
| T5 | `ImageQualityTests` | Chụp thử 1 ảnh mờ và 1 ảnh loá |
| T6 | `prompt_eval.py` trước và sau | — |

Mỗi task đóng bằng `/rhandoff`, chạy full `scripts/test.sh` trước khi đóng.

## Rủi ro và điều chưa chắc

- `ImageAnalyzer` có thể không chạy trên Simulator. Khi đó probe phải chạy trên máy thật, nên mỗi vòng thử sẽ chậm hơn.
- `transcript` có thể không có ranh giới đoạn, làm T3a phức tạp hơn dự tính.
- Live Text và `RecognizeDocumentsRequest` có thể dùng chung model bên dưới, nên khoảng cách giữa hai engine có thể nhỏ. Đó là lý do T1 cần groundtruth gõ tay.
- Ngưỡng ở T5 dễ báo nhầm. Vì vậy T5 chỉ cảnh báo, không chặn, để báo nhầm không gây hại.
