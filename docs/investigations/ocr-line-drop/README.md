# Điều tra: OCR rơi hàng / chia sai đoạn (ocr-line-drop)

Bundle bàn giao cho agent debug tiếp. Mọi dữ liệu thật đều nằm trong `captures/`. Ghi ngày **2026-09-26**.

## 1. Vấn đề (owner báo)

Kết quả phân tích trang bị **chia sai đoạn** và **thiếu từ vựng** so với ảnh gốc. Chạy Live Text của Apple trên **cùng ảnh** thì nhận đúng hoàn toàn, cả ký tự lẫn chia đoạn.

Owner nghi ba chỗ: (1) nén ảnh, (2) tầng OCR ngắt dòng/layout, (3) model LLM (DeepSeek) bóc tách kém.

## 2. Kết luận hiện tại

| Nghi vấn | Kết luận | Bằng chứng |
|---|---|---|
| Nén ảnh | **Không phải.** Vision nhận ảnh ~4800px; hạ về 1600px thì số hàng/câu mất **không đổi** | `probe.json`: `fullRes_*` == `scaled1600_*` trên cả 3 capture |
| Lọc confidence (`minConfidence = 0.25`) | **Không phải.** `droppedLowConfidence = 0` ở mọi capture | `ocr.json` capture 3 + `probe.json` |
| DeepSeek | **Không phải.** Model chỉ nhận text OCR; text đó đã thiếu/sai từ trước | `page_ocr.txt` so với `groundtruth.txt` |
| **Tầng OCR của app** | **ĐÚNG — gốc lỗi.** Có hai cơ chế, xem §3 | §3, §4 |

Thiếu từ và sai đoạn **cùng một gốc**: hàng bị mất/gộp tạo khoảng trống dọc hoặc hàng dài bất thường, và heuristic ngắt đoạn hình học (ADR-037) đọc nhầm những chỗ đó thành ranh giới đoạn.

## 3. Hai cơ chế lỗi trong đường OCR cũ (`VNRecognizeTextRequest` + `PageOCR.detailedReadingOrder`)

### 3a. Gộp nhầm hai hàng in thành một hàng (`clusterLines` / `sameLine`)
- `PageOCR.sameLine` (`app/ReadoKit/Sources/ReadoKit/Analysis/PageOCR.swift`) dùng ngưỡng `max(0.018, meanHeight * 0.65)` theo toạ độ chuẩn hoá 0…1.
- Khi chữ chiếm phần nhỏ của khung (ảnh **không crop**, như capture 3), khoảng cách giữa hai hàng in (~0.013–0.015) **nhỏ hơn sàn 0.018**, nên hai hàng liền nhau bị gộp.
- Gộp xong, text trong hàng được **sort theo `minX`** rồi nối lại, nên thứ tự bị đảo. Ví dụ capture 3, `page_ocr.txt` dòng 8: `"If you are rich and tall… also be among brothers are more correlated…"` = hàng in 3 + hàng in 2.
- Capture 3: `raw=59` observation nhưng chỉ ra `lines=22`, legacy lệch 11–12 câu so với groundtruth.

### 3b. Vision trên **máy thật** không trả observation cho vài hàng
- Capture 2 (đã crop, chữ to): trong app trên iPhone, `observationCount = 26` và `page_ocr.txt` thiếu hẳn 4 hàng in (hàng đầu "Economist Bhashkar Mazumder…", "status. But find me…", "too messy, too complex…", "It's possible to statistically…").
- Chạy lại **đúng file `page.jpg` đó** trong simulator (`OCRProbeTests`, cùng cấu hình request) thì ra `raw = 30`.
- → **Chưa giải thích được**, là câu hỏi mở #1 (§6). Giả thuyết: model Vision trên thiết bị (ANE) khác simulator (CPU), hoặc đường decode ảnh khác nhau (`CGImageSourceCreateImageAtIndex` trong app so với `UIImage(data:).cgImage` trong probe; xử lý EXIF orientation).
- Build app lúc chụp capture 2 **chưa** ghi `rawObservationCount`, nên không rõ Vision không thấy hay có bước nào khác làm rơi. Capture 3 đã có log mới (`raw=66 kept=66 dropped=0`).

## 4. Số đo probe (`OCRProbeTests`, simulator iPhone 18 Pro)

`missing` = số câu trong `groundtruth.txt` (tách theo `. ` và xuống dòng, bỏ câu < 20 ký tự) **không** xuất hiện liền mạch trong text OCR sau khi chuẩn hoá khoảng trắng + lowercase.

| Capture | Ảnh | legacy full | legacy 1600 | documents full | documents 1600 |
|---|---|---|---|---|---|
| `12-00-44Z_653fcbdb` (trang khác, không có groundtruth) | 4800×4311, đã crop | raw 29 | raw 29 | 9 đoạn | 9 đoạn |
| `15-44-57Z_e7711d75` (Bhashkar, **đã crop**) | 3879×4800 | missing **3** | missing 3 | missing **2** | missing 2 |
| `16-20-39Z_1175cf3d` (Bhashkar, **không crop**, có tab trình duyệt + bàn phím) | 3603×4800 | missing **12** | missing 11 | missing **2** | missing 2 |

- `documents` = `RecognizeDocumentsRequest` (Vision Swift API, **iOS 26+ trên SDK máy này**; compiler báo vậy, tài liệu cộng đồng ghi iOS 18 là sai với SDK hiện tại). Engine này trả sẵn `document.paragraphs[].transcript`.
- `raw` của documents = **số đoạn**, không phải số hàng, nên không so trực tiếp với `raw` của legacy.
- **Documents API vượt trội rõ ở ảnh không crop (2 so với 12)** và nhỉnh hơn ở ảnh đã crop (2 so với 3).
- Hai câu "missing" còn lại của documents có thể là **nhiễu của chính probe**: `normalize` chưa gập `—`/`-` và `’`/`'`, và cách tách câu bằng `". "` khá thô. Cần kiểm lại bằng mắt `probe.json`/text trước khi coi là mất thật.

## 5. Code đã đổi trong session này

| File | Thay đổi |
|---|---|
| `app/ReadoKit/Sources/ReadoKit/Analysis/PageOCR.swift` | `Observation.confidence` (mặc định 1.0); `OCRResult.rawObservationCount` + `droppedLowConfidence`; hàm thuần `partitionByConfidence` (testable) |
| `app/ReadoKit/Sources/ReadoKit/Analysis/OpenAICompatClient.swift` | `ocr.json` ghi thêm `rawObservationCount`, `droppedLowConfidence[{text, confidence, yTop}]` |
| `scripts/diag_summary.py` | In `raw / kept / droppedLowConfidence / unseen` |
| `app/ReadoTests/PageOCRTests.swift` | Test `testPartitionByConfidenceKeepsHighDropsLow` |
| `app/ReadoTests/OCRProbeTests.swift` (mới) | Probe opt-in, 4 cấu hình (legacy/documents × full/1600), ghi `probe.json`, so `groundtruth.txt` |
| `scripts/pull_diagnostics.sh`, `scripts/sim_aibox.sh` | Bundle id mặc định `com.readoluca.app` (ghi đè được bằng `READO_BUNDLE_ID`) |

Full suite `scripts/test.sh` sau các thay đổi này: **250/252 passed, 2 skipped** (`LiveAIBoxTests` và `OCRProbeTests`, cả hai opt-in theo env), `** TEST SUCCEEDED **`, iPhone 18 Pro simulator, 2026-09-26.

## 6. Câu hỏi mở cho agent tiếp theo

1. **Device và simulator ra khác nhau (26 so với 30 observation) trên cùng `page.jpg`.** Build DEBUG mới lên máy, chụp lại trang đã crop, đọc `rawObservationCount` trong `ocr.json`. Thử thêm đường decode ảnh có áp EXIF orientation.
2. **Đổi engine sang `RecognizeDocumentsRequest`** (plan T3): `if #available(iOS 26, *)` dùng documents, fallback legacy cho iOS 17–25. Hợp đồng với prompt giữ nguyên: `\n` giữa hàng, `\n\n` giữa đoạn, `Prompt.version` giữ 5. Cần ADR mới (ADR-041 đã bị `ux-polish-r1` dùng, nên lấy số tiếp theo trống trong `docs/decisions-log.md`).
3. Nếu giữ legacy làm fallback: sửa `sameLine` để sàn 0.018 không lớn hơn khoảng cách hàng thật (ví dụ ngưỡng theo median pitch của cột), và không sort-by-minX trong một hàng đã gộp hai hàng in.
4. Sửa `normalize` của probe (gập dash/quote) để `missing` của documents về đúng 0 nếu thật sự đủ.
5. **Bug phụ FR-01:** `ImageCompressor.resizeIfNeeded` dùng `UIGraphicsImageRenderer` với scale mặc định @3x, nên "1600px" thực ra ra ~4800px (3–5MB). Probe cho thấy 1600px **không** làm rơi thêm hàng, nên sửa `format.scale = 1` an toàn (plan T4).

## 7. Tái hiện

```bash
# Probe trên bundle này (ghi đè probe.json trong captures/*):
TEST_RUNNER_READO_OCR_PROBE_DIR="$PWD/docs/investigations/ocr-line-drop/captures" \
  scripts/test.sh test -only-testing:ReadoTests/OCRProbeTests
# Kết quả in trong /tmp/build.log (khối "OCRProbeTests summary").
# Bẫy: sau khi test xong, xcodebuild có thể treo ở bước `simctl diagnose`.
# Test đã pass thì kill tiến trình xcodebuild/simctl diagnose.

# Log thật từ iPhone (build Debug qua Xcode Run):
scripts/pull_diagnostics.sh device <udid>      # xcrun devicectl list devices
python3 scripts/diag_summary.py .tmp/diagnostics/<ts>
```

Muốn thêm ground truth cho capture mới: mở ảnh trên iPhone, dùng Live Text copy toàn văn, lưu thành `captures/<id>/groundtruth.txt` (mỗi đoạn một dòng).

## 8. Bố cục `captures/<ts>_<id>/`

| File | Nội dung |
|---|---|
| `page.jpg` | Đúng ảnh Vision nhận trong app (sau crop, sau `ImageCompressor`) |
| `page_ocr.txt` | Text OCR app gửi cho agent (có `\n\n` ngắt đoạn) |
| `ocr.json` | Từng hàng: `minX/maxX/yTop/height/breakReason`; capture 3 có thêm `rawObservationCount`, `droppedLowConfidence` |
| `meta.json` | model, baseURL, cefr, httpStatus, ocrMs, totalMs |
| `response_raw.txt` / `analysis.json` | Output DeepSeek (thô / đã decode) |
| `groundtruth.txt` | Live Text owner dán tay (**expected**). Có ở capture 2 và 3 (cùng một trang sách) |
| `probe.json` | Kết quả `OCRProbeTests` cho 4 cấu hình |

## 9. Tài liệu liên quan

- Plan: [`docs/investigations/ocr-line-drop/plan.md`](plan.md) (T1 bundle id → T2 probe → T3 documents OCR → T4 compressor scale)
- ADR-037 trong `docs/decisions-log.md` (DebugTrace + ngắt đoạn hình học + prompt v5)
- FR-01, FR-02 trong `docs/specs/prd.md`; J1 bước 3 trong `docs/specs/journeys.md`
- Code: `PageOCR.swift`, `OpenAICompatClient.swift`, `ImageCompressor.swift`, `DebugTrace.swift`

## 10. Lưu ý

- Ảnh chụp **màn hình máy tính** hiển thị PDF (không phải sách in), nên có moiré, loá và UI trình duyệt nếu không crop. Live Text vẫn đọc đúng trên chính ảnh này, nên đây vẫn là phép so công bằng.
- Ảnh là trang sách có bản quyền ("The Psychology of Money"). NFR-04 chỉ miễn cho log DEBUG trên máy. Bundle này chỉ nên nằm trong repo riêng tư; xoá `captures/*/page.jpg` khi xong điều tra.

## 11. Cập nhật 2026-09-28 — probe đo lại + fix (ADR-042)

Probe cũ có hai lỗi làm số đo lệch: `scaledTo1600` vẫn @3x (ra ~4800px, không phải 1600) và `normalize` không gập dash/quote. Đã sửa (scale = 1, gập `— – ’ “ ”`, bỏ gạch nối cuối hàng); `probe.json` giờ ghi thêm `text` + `missingSentences` từng cấu hình.

| Capture | legacy full | legacy 1600 (thật) | documents full | documents 1600 (thật) | app (`PageOCR.recognizeDetailed`) |
|---|---|---|---|---|---|
| `e7711d75` (crop) | missing 2 | 1 | 1 | 1 | `engine=documents`, missing 1 |
| `1175cf3d` (không crop) | missing 11 | 10 | 2 | 1 | `engine=documents`, missing 2 |

- Phần "missing" còn lại của documents là nhiễu 1 ký tự (`did I` → `did |`, mất dấu chấm cuối đoạn, em-dash cuối hàng). Documents ra đủ 8 đoạn khớp groundtruth.
- 1600px thật không làm rơi hàng so với full-res → `ImageCompressor` đã áp `scale = 1` (FR-01 thật).
- Fix: `PageOCR.recognizeDetailed` iOS 26+ dùng `RecognizeDocumentsRequest`, lỗi/rỗng rơi về legacy; `joinParagraphs` (thuần, có test); `ocr.json` + `diag_summary.py` ghi `engine`.
- **Còn mở:** device vs simulator (26 vs 30 obs, §6.1) chưa giải thích — cần chụp lại trên máy thật, `diag_summary` phải in `engine=documents`. `sameLine` legacy (§3a) chưa sửa (chỉ ảnh hưởng iOS 17–25).
