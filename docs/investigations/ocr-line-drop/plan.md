# Plan: ocr-line-drop

## Context

Fen báo: bản phân tích chia sai đoạn và thiếu từ so với ảnh gốc, trong khi Live Text đọc đúng hết.
Đã chẩn đoán bằng log DEBUG thật (`.tmp/diagnostics/20260926T155409Z/`, trang "Economist Bhashkar Mazumder…"):

- OCR trong app **mất trọn 4 hàng in** (hàng đầu trang + 3 hàng giữa đoạn). Live Text có đủ.
- Mỗi hàng mất để lại một khoảng trống dọc, và `PageOCR.linesWithBreaks` coi khoảng trống đó là **ranh giới đoạn** (`gap`), nên chèn `\n\n` giữa câu. **Thiếu từ và sai đoạn là cùng một gốc.**
- DeepSeek không có lỗi: nó chỉ nhận lại text đã thiếu sẵn.
- Nén ảnh không phải nguyên nhân: Vision nhận ảnh 4800px (`OpenAICompatClient.swift:56-65`, `page.jpg` = đầu vào OCR).
- **Chưa biết:** Vision không thấy 4 hàng đó, hay thấy rồi bị `minConfidence = 0.25` lọc (`PageOCR.swift:146`). `observationCount` trong `ocr.json` được đếm *sau* bước lọc (`OpenAICompatClient.swift:122`).
- Bug phụ: `ImageCompressor` dùng `UIGraphicsImageRenderer` với scale mặc định @3x, nên "1600px" thực ra là 4800px (3–5MB) và FR-01 chưa từng được áp.
- Bundle id: fen phải đổi sang `com.readoluca.app` vì `com.reado.app` bị trùng khi ký máy thật. Repo vẫn ghi id cũ.

## Spec

- **FR-01** (prd.md:263): crop/xoay trước khi submit. Phần nén ≤1600px nằm ở comment `ImageCompressor` + SD mục 8.
- **FR-02** (prd.md:278): `segments[]` chia theo đoạn đúng thứ tự trên trang. `example` phải khớp `source_en` ghép lại, nên hàng rơi khiến `example` bị đánh dấu chưa xác minh hoặc mất từ.
- **J1 bước 3** (journeys.md:120): OCR trên máy, một lần gọi agent.
- **ADR-037**: DebugTrace + ngắt đoạn hình học + prompt v5 (tin `\n\n` của OCR).
- **In-scope:** bundle id, log OCR thô, probe so sánh engine OCR, đổi engine OCR nếu số đo ủng hộ, sửa scale nén theo số đo.
- **Out-of-scope / không đụng:** prompt (`Prompt.version` giữ **5**, vì hợp đồng `\n\n` = ranh giới đoạn không đổi), `ReadoProxyClient` (vẫn gửi ảnh multipart), schema/DB, FSRS, UI capture/crop.
- **Đã chốt với fen (2026-09-26):** T4 chờ số đo từ probe ở T2 rồi mới chọn hướng.

## Tầng 1 — HLD

- **ReadoKit** chứa hết logic: `Analysis/PageOCR.swift`, `Analysis/OpenAICompatClient.swift` (ghi trace), `Diagnostics/DebugTrace.swift`, `Capture/ImageCompressor.swift`.
- **Reado (app):** không đổi code. Bundle id đổi trong target settings.
- **Protocol `PageTextRecognizer`** (`PageOCR.swift:8`) giữ nguyên chữ ký. Engine mới cắm vào sau `PageOCR.live`, nên `OpenAICompatClient`, test fake và `MockAnalyzer` không phải sửa.
- **Deployment target iOS 17** (pbxproj + `Package.swift .iOS(.v17)`). `RecognizeDocumentsRequest` (Vision Swift API) chỉ có từ **iOS 26**, nên phải dùng `if #available(iOS 26, *)` và giữ `VNRecognizeTextRequest` + ngắt đoạn hình học làm fallback.
- Không có transaction DB nào bị đụng.
- **File cấm:** không edit tay `project.pbxproj`. Bundle id đổi qua Xcode UI (xem T1). Thêm file test qua `scripts/pbxproj_tool.py add`.

## Tầng 2 — Tasks (thứ tự bắt buộc: T1 → T2 → [đọc số đo] → T3 → T4)

### T1 — bundle-id (nhỏ, làm trước để mọi build sau cài đúng app trên máy)
- **Fen làm tay trong Xcode** (hook cấm sửa pbxproj bằng tay): target *Reado* → Build Settings → Product Bundle Identifier = `com.readoluca.app` (Debug + Release). Target *ReadoTests* = `com.readoluca.app.tests`.
- Sonnet: `grep -n PRODUCT_BUNDLE_IDENTIFIER app/Reado.xcodeproj/project.pbxproj` phải ra đủ 4 dòng `readoluca`. Trong pbxproj chỉ giữ hunk bundle id (memory: xcodebuild re-sort, flush churn trước commit).
- Sửa `scripts/sim_aibox.sh:17` → `BUNDLE_ID="${READO_BUNDLE_ID:-com.readoluca.app}"`, cùng kiểu với `scripts/pull_diagnostics.sh:14` (đã sửa ở session này, chưa commit).
- `grep -rn "com\.reado\.app" --exclude-dir=.tmp .` phải về 0 (trừ comment giải thích).
- Lưu ý: trên simulator, bundle id mới = app mới, nên DB/Keychain dev bị trống. Chạy lại `scripts/sim_aibox.sh` để seed.
- **Test:** `scripts/test.sh` toàn bộ (kỳ vọng 227/228, 1 skip).
- **DoD:** 4 dòng pbxproj đúng · 2 script đúng · `** TEST SUCCEEDED **` · `scripts/pull_diagnostics.sh device <udid>` kéo được mà không cần biến môi trường.

### T2 — ocr-probe (công cụ đo, không đổi hành vi release)
Mục tiêu: trả lời bằng số 3 câu hỏi: (a) hàng rơi do Vision hay do lọc confidence; (b) `RecognizeDocumentsRequest` có nhận đủ hàng + đoạn đúng không; (c) OCR ở 1600px có rơi thêm hàng so với full-res không.

1. **Log thô trong DebugTrace** (chỉ bản DEBUG):
   - `PageOCR.Observation` thêm `confidence: Float` (init có default `1.0` để test cũ không phải sửa).
   - `recognizeDetailedSync` giữ lại cả observation bị lọc, trả thêm `rawObservationCount` và `droppedLowConfidence: [Observation]` trong `OCRResult` (thêm field có default, không phá chữ ký).
   - `OpenAICompatClient.swift:~122` ghi vào `ocr.json`: `rawObservationCount`, `droppedLowConfidence[{text, confidence, yTop}]`, và `confidence` của từng line.
   - `scripts/diag_summary.py` in thêm dòng `raw=N kept=M dropped=K` + các text bị drop.
2. **Probe test opt-in** `app/ReadoTests/OCRProbeTests.swift` (thêm bằng `pbxproj_tool.py add --group ReadoTests --target ReadoTests`):
   - Làm giống `LiveAIBoxTests`: đọc `READO_OCR_PROBE_DIR` (truyền bằng `TEST_RUNNER_READO_OCR_PROBE_DIR=…`), thiếu thì `XCTSkip`.
   - Với mỗi `*/page.jpg` trong thư mục: chạy **4 cấu hình**: {legacy `VNRecognizeTextRequest` như hiện tại, `RecognizeDocumentsRequest`} × {full-res, 1600px scale=1}. Ghi cho mỗi cấu hình: số hàng, số đoạn, text ghép.
   - Ghi kết quả ra `<dir>/<analysis>/probe.json` + in bảng tóm tắt ra log test. Simulator đọc được thẳng đường dẫn host, **không cần fen chụp lại**.
   - Có thể thêm cột `groundtruth.txt` (fen dán Live Text) để probe tự tính số hàng mất. Đã có sẵn ground truth cho `2026-09-26T15-44-57Z_e7711d75`, lấy từ tin nhắn fen trong session này.
- **Test:** `PageOCRTests` thêm case: observation có `confidence < 0.25` vào `droppedLowConfidence` chứ không vào `lines` (dùng hàm lọc tách thành static, testable). Chạy `TEST_RUNNER_READO_OCR_PROBE_DIR=$PWD/.tmp/diagnostics/20260926T155409Z/analyses scripts/test.sh test -only-testing:ReadoTests/OCRProbeTests`.
- **DoD:** test xanh + bảng probe cho cả 2 ảnh đã kéo về được dán vào `docs/journal/2026-09-2x.md`, trả lời rõ (a)(b)(c). **Dừng, báo fen số đo trước khi làm T3/T4.**

### T3 — document-ocr (chỉ làm nếu T2(b) cho thấy Documents API nhận đủ hàng/đoạn)
- `PageOCR.swift`: `recognizeDetailedSync` → `if #available(iOS 26, *)` dùng `RecognizeDocumentsRequest`: lấy `document.paragraphs` theo thứ tự, trong đoạn nối hàng bằng `\n`, giữa các đoạn nối bằng `\n\n`. Mỗi `Line` có `breakReason = "document"`. Có sẵn đoạn rồi nên **bỏ qua** `splitColumns`/`linesWithBreaks`.
- Fallback iOS < 26: giữ nguyên đường legacy hiện tại. Nếu T2(a) cho thấy hàng bị lọc do confidence thì hạ `minConfidence` theo số đo.
- Tách hàm thuần `joinParagraphs(_ paragraphs: [[String]]) -> OCRResult` để test không cần Vision.
- `DebugTrace` ghi thêm `engine: "documents" | "legacy"` vào `meta.json`/`ocr.json`.
- ADR-040 trong `docs/decisions-log.md`: đổi engine OCR, lý do (hàng rơi + số đo T2). Ngắt đoạn hình học của ADR-037 lùi về làm fallback. Prompt v5 giữ nguyên.
- **Test:** `PageOCRTests` thêm case cho `joinParagraphs` (1 đoạn, nhiều đoạn, đoạn rỗng bị bỏ). Chạy lại `OCRProbeTests`: engine documents phải khớp groundtruth ≥ legacy. Chạy full `scripts/test.sh`.
- **DoD:** probe trên 2 ảnh thật không mất hàng · test xanh · ADR-040 · fen chụp lại một trang trên máy, `diag_summary` cho thấy `engine=documents` và đủ hàng.

### T4 — compressor-scale (hướng quyết định theo T2(c))
- Nếu **1600px không rơi thêm hàng**: `ImageCompressor.resizeIfNeeded` dùng `UIGraphicsImageRendererFormat` với `format.scale = 1` → FR-01 được áp thật.
- Nếu **có rơi thêm**: dừng lại, trình fen phương án "OCR dùng ảnh cạnh dài ~3000px, chỉ nén 1600 cho upload proxy" (đổi hợp đồng `CapturedImage`, cần ADR). Chưa code.
- **Test:** thêm `ImageCompressorTests` (hoặc case trong file test có sẵn): ảnh 4000×3000 → output JPEG có cạnh dài pixel = 1600 (đọc bằng `CGImageSource`, không dùng `UIImage.size`).
- **DoD:** test xanh · ghi kích thước/bytes trước-sau vào journal.

## Gợi ý crop (trả lời fen, không phải task)

Crop sát vùng chữ là **nên**, có mấy lý do: `minimumTextHeight = 0.015` tính theo chiều cao ảnh nên chữ chiếm khung lớn thì dễ nhận hơn; bỏ được viền màn hình, con trỏ chuột và chữ của trang bên cạnh (thuật toán tách cột có thể nhầm những thứ đó là cột thứ hai). Cách làm đúng:
1. **Chừa lề khoảng 1 hàng chữ** quanh khối văn bản. Không cắt sát mép chữ, và tuyệt đối không cắt ngang một hàng (hàng bị cắt nửa thường rơi hẳn).
2. **Giữ nguyên chiều rộng cột:** lề phải bị cắt lệch sẽ làm hỏng heuristic `shortEnding` (hàng ngắn = cuối đoạn).
3. **Chỉ lấy đoạn trọn vẹn:** đoạn đầu/cuối trang bị cắt dở thì model vẫn dịch nhưng `example` dễ lệch.
4. **Xoay thẳng hàng** trước khi crop (crop view có xoay). Chụp **song song mặt giấy/màn hình**, tránh vệt loá. Ảnh vừa rồi có một đốm sáng ở góc trên, và hàng đầu trang bị mất nằm ngay gần đó.
5. **Chụp màn hình máy tính** (như ảnh này) dễ bị moiré. Nếu có thể thì chụp màn hình hoặc xuất text luôn, hoặc lùi xa một chút rồi zoom thay vì chụp sát.
6. Ưu tiên **chụp đầy khung ngay từ đầu** hơn là chụp rộng rồi crop mạnh: crop mạnh làm mất điểm ảnh. Sau khi T4 áp 1600px thật thì điều này càng quan trọng.

## Verification (end-to-end)
1. T1: `scripts/test.sh` xanh; build Xcode Run lên iPhone Air cài đúng `com.readoluca.app`; `scripts/pull_diagnostics.sh device <udid>` chạy không cần env.
2. T2: `TEST_RUNNER_READO_OCR_PROBE_DIR=… scripts/test.sh test -only-testing:ReadoTests/OCRProbeTests` in bảng 4 cấu hình; `python3 scripts/diag_summary.py <dir>` in `raw/kept/dropped`.
3. T3: probe engine documents khớp groundtruth; chụp lại trang "Economist Bhashkar Mazumder" trên máy → `diag_summary` đủ 30 hàng, 6 đoạn (đếm trên ảnh), không có `gap` giả.
4. Mỗi task đóng bằng `/rhandoff` (full `scripts/test.sh` trước).
