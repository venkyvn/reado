# Plan: pdf-reader-r1 — đọc PDF trong Reado, cửa thu từ vựng thứ hai

## Context

Đọc PDF bây giờ phải đi đường vòng 5 bước: app khác → screenshot → Reado → chọn ảnh → crop.
Nguyên lý #3 lại đòi đưa từ vào bộ ôn "trong một thao tác". Fen chốt (2026-10-04): đọc PDF
**ngay trong Reado**, đọc tới trang nào thì bấm phân tích trang đó → ra màn Duyệt & lưu như
J1/J2 → về đọc tiếp. Chuyện này đảo **NG-07** ("chỉ một input path là ảnh"), nên docs sửa
trước (T0) rồi mới code.

**Fen đã chốt (không hỏi lại):**
1. Sửa vision/PRD/journeys. Đây là thêm **nguồn thu từ vựng**, không phải biến Reado thành
   app đọc sách.
2. **Không chép PDF vào app.** Mở tại chỗ bằng security-scoped bookmark, chỉ giữ bookmark +
   trang đang đọc.
3. Mỗi **bộ có tên** gắn được **1 PDF** (sách = bộ). Kho tạm không gắn được, vì kho tạm
   không có phiên.
4. Bookmark + trang lưu ở **bảng mới trong SQLite** (migration v5).
5. **Prompt riêng cho PDF** có lớp chữ tốt. Trang scan hoặc lớp chữ rác thì vẽ trang thành
   ảnh độ phân giải cao, rồi đi OCR trên máy + prompt ảnh v6 như cũ. Cả hai lối trả về
   **cùng schema** `PageAnalysis`.
6. **EPUB nằm ngoài R1** (thành nội dung mới của NG-07).

**Mặc định đã chọn cho hành vi chưa hỏi** (ghi vào ADR-058, đổi được sau):
- Phân tích lại một trang đã làm: **cho phép**, không đánh dấu trang đã phân tích (cần cột
  số trang ở session, để Later). Từ trùng thì FR-10 đã gập.
- Câu tràn qua hai trang: prompt dặn vẫn dịch nhưng không lấy làm `example`. Không ghép
  trang.
- Lối tắt "Đọc tiếp" trên Home và nút "Đọc lại bằng OCR" trong reader: **Later**.

## Spec

- **FR / journey:** thêm **FR-23 — Đọc PDF trong Reado** thuộc Epic E1 Capture, đặt ngay sau
  FR-04 (FR cao nhất hiện là FR-22). FR-01..04 giữ nguyên GWT. Journey mới **J2b** (dưới).
- **GWT FR-23** (T0 chép vào prd.md, được chỉnh câu chữ, không đổi nghĩa):
  1. Given Hub của bộ có tên, when chọn "Gắn PDF…" rồi chọn file trong Files, then bộ gắn
     với file đó **mà không chép file** vào app. Hub hiện hàng "Đọc PDF · tr. N".
  2. Given đang đọc, when lật trang, then trang được nhớ. Mở lại thì về đúng trang.
  3. Given trang hiện tại có lớp chữ dùng được, when bấm "Phân tích trang này", then text
     trang (không OCR) đi prompt PDF và ra màn Duyệt & lưu (FR-09/02/10/03). Đích mặc định
     là bộ đó, đổi được qua "Lưu vào ⏷". Lưu xong về đúng trang đang đọc.
  4. Given trang không có lớp chữ hoặc lớp chữ rác, when bấm phân tích, then trang được vẽ
     thành ảnh rồi OCR trên máy. Người dùng không phải làm gì thêm.
  5. Given file đã bị xoá, di chuyển, không truy cập được hoặc có mật khẩu, when mở reader,
     then báo lỗi cụ thể + "Chọn lại file". Vocab và session không bị ảnh hưởng.
  6. FR-04 áp nguyên (trang không có tiếng Anh thì báo, không bịa dữ liệu). Nút "Chụp lại"
     đổi thành "Về trang đọc".
- **Journey J2b — Đọc PDF trong bộ** (T0 viết vào journeys.md, ngay sau J2):
  - *Trigger:* "Tối nay đọc tiếp *Atomic Habits*", có bản PDF trên máy.
  - *Gắn lần đầu:* Hub → ⋯ → "Gắn PDF…" → trình chọn file iOS → Hub có hàng
    "📄 <tên file> · Đọc từ đầu".
  - *Hằng ngày:*
    1. Hub → hàng "Đọc PDF · tr. N" → reader mở đúng trang N.
    2. Lật ngang từng trang, pinch zoom. Đáy màn có "tr. N / M" + CTA "Phân tích trang
       này". Trang được nhớ tự động.
    3. Bấm CTA → sheet Duyệt & lưu như J1 (tiến độ, tab Từ/Trang, nhóm "Đã thuộc · N",
       "Lưu vào ⏷").
    4. Lưu → sheet đóng, về đúng trang. Banner "Đã lưu N từ vào X · Xem" (ADR-053).
    5. Back → Hub: session mới đứng đầu danh sách 10, từ trong kho của bộ.
  - *Menu ⋯ của Hub:* "Đổi PDF…" (về trang 1), "Gỡ PDF" (chỉ bỏ liên kết, không đụng file
    hay từ).
  - *Empty/error:* bảng 6 dòng — scan/rác → OCR; trang không có tiếng Anh → "Về trang đọc";
    chưa có agent → form thêm agent; file mất/iCloud chưa tải → "Chọn lại file"; có mật
    khẩu → báo mở khoá ở app khác; kho tạm → không có mục "Gắn PDF".
  - *Không có:* highlight, ghi chú, mục lục, bookmark nhiều chỗ, phân tích nhiều trang,
    chọn một từ để tra riêng.
- **Nguyên lý:**
  - Phục vụ #3 (ghi nhận tại điểm ma sát, một thao tác) và #1 (văn bản thật người dùng tự
    chọn).
  - Đụng **#5**: thêm câu "file PDF không bao giờ được chép vào app, Reado chỉ giữ chỗ trỏ
    + số trang". Text trang vẫn theo luật 10 phiên / NFR-04.
  - "Chống lại" #6 (đọc lướt qua tóm tắt): không vi phạm, vì vẫn phân tích từng trang và
    người dùng tự đọc.
- **Out-of-scope:** EPUB/ebook, highlight/ghi chú/mục lục, phân tích nhiều trang, kệ PDF
  tách khỏi bộ, sync bookmark, gắn PDF vào kho tạm, đánh dấu trang đã phân tích, lối tắt
  Home, nút "Đọc lại bằng OCR", ô nhập mật khẩu PDF.
- **Không đụng:** FSRS/scheduler, `cards`/`review_logs`, schema `reading_sessions` (một lần
  phân tích PDF = **một** session như ảnh), Q-11, prompt ảnh v6 (`Prompt.text`/`version = 6`
  giữ nguyên), `vision2.md` và `idea.md` (nháp untracked của fen).

## Tầng 1 — HLD

### ReadoKit (logic thuần, test bằng lane `kit` trên macOS)

- **`Database/Migration.swift`:** `currentVersion` 4 → 5, thêm `v5Statements` + `case 4:`
  theo đúng mẫu v4.
  ```sql
  CREATE TABLE pdf_sources (
    collection_id TEXT NOT NULL PRIMARY KEY REFERENCES collections(id) ON DELETE CASCADE,
    display_name  TEXT NOT NULL,
    bookmark      TEXT NOT NULL,   -- base64 của URL.bookmarkData (SQLValue không có BLOB)
    page_index    INTEGER NOT NULL DEFAULT 0,  -- đếm từ 0, UI hiện +1
    page_count    INTEGER NOT NULL DEFAULT 0,
    updated_at    TEXT NOT NULL    -- ISO-8601 Z
  );
  ```
  Khoá chính `collection_id` → mỗi bộ tối đa 1 PDF. Xoá bộ thì cascade
  (`VocabRepository+Collections.swift:110` không phải sửa). Kho tạm bị chặn ở tầng app,
  không CHECK SQL (db.md A.2.2). Bảng này **không export CSV, không sync** (bookmark chỉ
  dùng được trên máy tạo ra nó).
- **`PDF/PDFSourceRepository.swift` (mới):** `attach(collectionID:displayName:bookmark:pageCount:now:)`
  (UPSERT ghi đè, `page_index` về 0), `updatePage(collectionID:pageIndex:now:)`,
  `updateBookmark(...)` (bookmark stale), `detach(collectionID:)`, `source(for:) -> PDFSource?`.
  Thời gian qua `ISOTimestamp`.
- **`PDF/PDFPageText.swift` (mới, `import PDFKit` là framework hệ thống, không phải
  dependency):** `extract(page: PDFPage) -> Result`, với `Result = .text(String) | .needsOCR(Reason)`.
  1. **Lấy hàng kèm toạ độ:** `page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine()`,
     mỗi hàng giữ `string` + `bounds(for: page)`. Không dùng `page.string`, vì nó không có
     ranh giới đoạn và thứ tự có thể lộn.
  2. **Dựng text như OCR** (hàm thuần nhận mảng `(text, rect)`, test được không cần PDF):
     - Thứ tự đọc: có khe trống dọc liên tục gần giữa trang thì là 2 cột, đọc hết cột trái
       rồi cột phải. Không có thì sắp trên → dưới.
     - Ngắt đoạn: khoảng dọc > 1.5 × khoảng hàng trung vị **hoặc** hàng thụt đầu dòng
       → `\n\n`. Còn lại `\n`. Xem `PageOCR.linesWithBreaks` (ADR-037), tái dùng helper
       nếu tách được, không thì viết riêng cùng ý tưởng.
     - Chuẩn hoá ligature `ﬁ ﬂ ﬀ ﬃ ﬄ` → `fi fl ff ffi ffl`, NBSP/khoảng trắng lạ → space.
  3. **Chấm chất lượng** — hàm thuần `quality(_ text: String) -> Reason?`, trả `.needsOCR`
     khi gặp **bất kỳ** điều kiện nào:
     - dưới 40 ký tự không phải khoảng trắng;
     - chứa `(cid:` hoặc `\u{FFFD}`;
     - tỷ lệ (chữ cái + khoảng trắng + dấu câu thông dụng) dưới 85%;
     - tỷ lệ token trông như từ tiếng Anh (chỉ chữ cái, dài 1–15, có nguyên âm `aeiouy`)
       dưới 70%.

     Ngưỡng là giá trị khởi đầu, T5 chỉnh theo PDF thật. Gom thành hằng số có tên ở đầu
     file.
- **`Analysis/PageAnalyzer.swift`:** thêm vào protocol
  `analyzeText(_ pageText: String, cefr: String, sourceHash: String) async throws -> PageAnalysis`,
  cài cho đủ 3 type:
  - `MockAnalyzer` trả cùng dữ liệu mẫu;
  - `NoAgentAnalyzer` ném cùng lỗi lối ảnh;
  - `OpenAICompatClient` như mục dưới.

  Sửa doc comment "Input vẫn là ảnh (NG-07)" → "Input là ảnh (OCR trên máy) hoặc text
  trang PDF (FR-23, ADR-058)".
- **`Analysis/OpenAICompatClient.swift`:** tách phần sau OCR thành hàm chung
  `run(prompt:promptVersion:sourceHash:apiKey:trace:)`, bao gồm retry `response_format`,
  map lỗi URL và gắn meta.
  - Lối ảnh: OCR → `Prompt.text` → `run`. **Hành vi không đổi.**
  - Lối PDF: kiểm key → `Prompt.pdfText` → `run`.
  - `meta.imageHash` giữ tên field, giá trị = `sourceHash` (hash text).
  - DebugTrace lối PDF: ghi text vào `page_ocr.txt` (cùng tên file để `prompt_eval.py` đọc
    được) + meta `"source": "pdf"`. Lối ảnh thêm `"source": "image"`.
- **`Analysis/Prompt.swift`:** thêm `pdfVersion = 1` + `pdfText(cefrLevel:pageText:)`. Dựa
  trên `text()`, chỉ khác:
  - nhãn input là `PAGE_TEXT`, "lớp chữ của một trang PDF, chữ chính xác; `\n`/`\n\n` đã
    dò bằng hình học như OCR";
  - bỏ header, footer, số trang, tiêu đề chạy đầu trang;
  - từ bị gạch nối cuối hàng thì ghép lại khi dựng `source_en`. Ngoại lệ duy nhất cho luật
    "giữ nguyên chữ", phải ghi rõ trong prompt;
  - câu cụt ở đầu/cuối trang vẫn dịch nhưng không làm `example`.

  Luật `source_en`/`example` trích nguyên văn và JSON schema giữ y hệt → `VerifyEngine`,
  `PhraseLocator`, decoder, normalizer dùng lại không đổi.

### Reado (UI, iOS)

- **`App/AppState.swift` — `CaptureFlow`:**
  - `pdfText: PDFTextPage?`: struct `text`, `sourceHash`. Lối PDF chữ tốt.
  - `origin: CaptureOrigin = .camera`, enum `.camera | .pdf(collectionID: String)`. Lối PDF
    scan dùng lại `lastCapturedImage` và đặt `origin = .pdf`.
  - `var hasPendingPage: Bool { lastCapturedImage != nil || pdfText != nil }`.
- **`App/AppModel+Capture.swift`:**
  - `analyzeCurrentImage()` → `analyzeCurrentPage()`: có `pdfText` thì gọi `analyzeText`,
    không thì lối ảnh cũ.
  - `discardAnalysis`/`saveSelection` dọn thêm `pdfText` và `origin = .camera`.
  - `prepareRecapture()`: `origin == .pdf` thì chỉ `discardAnalysis()`, **không** bật
    `pendingRecapture`.
- **`App/AppModel+PDF.swift` (mới):**
  - `pdfSource(for:)`;
  - `attachPDF(url:collectionID:)`: `startAccessing…` → `bookmarkData(options: [])` →
    đếm trang → repository;
  - `detachPDF`;
  - `openPDF(collectionID:) -> Result<PDFDocument, PDFOpenError>`: resolve bookmark;
    stale thì tạo lại + `updateBookmark`; `isLocked` → `.locked`; `PDFDocument(url:) == nil`
    → `.unreadable`;
  - `savePDFPage(...)`;
  - `preparePDFAnalysis(page:collectionID:)`: chạy `PDFPageText.extract` ngoài main
    thread. `.text` thì set `pdfText`. `.needsOCR` thì render ảnh rồi set
    `lastCapturedImage`. Cả hai đều set `origin`, `analysisTargetCollectionID`, rồi bật
    `shell.pendingPDFAnalysis = true`.
- **`App/RootView.swift`:**
  - `ShellRoute.pdfReader(String)` + `navigationDestination` cho cả `todayPath` và
    `libraryPath` (Hub có ở cả hai tab).
  - `.onChange(of: model.shell.pendingPDFAnalysis)`: tắt cờ, rồi
    `guard model.activeAgentReady else { showAgentSetup = true; return }` → `showAnalysis = true`.
  - Sheet `showAnalysis` dùng lại nguyên. Đóng sheet thì path không đổi → về reader.
  - `ShellSignals` thêm `pendingPDFAnalysis`.
- **`PDF/PDFReaderView.swift` (mới, thư mục `app/Reado/PDF/`):**
  - SwiftUI view + `UIViewRepresentable` bọc `PDFView`: `displayMode = .singlePage`,
    `usePageViewController(true)`, `autoScales = true`, `displayDirection = .horizontal`.
  - `.onAppear` gọi `openPDF`, nhảy tới `page_index`. Lỗi → empty state + "Chọn lại file"
    (`.fileImporter([.pdf])`).
  - Nghe `.PDFViewPageChanged` → debounce 0.5s → `savePDFPage`. Lưu thêm một lần ở
    `onDisappear`.
  - Thanh đáy: "tr. N / M" + CTA "Phân tích trang này" (`DesignSystem` token, nút chính
    giống CTA Hub).
  - `model.shell.suppressFloatShutter = true` khi hiện, `false` khi rời, giống
    `ReadingSessionView.swift:50`.
  - `stopAccessingSecurityScopedResource()` ở `onDisappear`.
- **Vẽ trang scan** (trong `AppModel+PDF` hoặc helper `PDFPageRenderer` ở app layer):
  `page.thumbnail(of:for: .mediaBox)` với cạnh dài **2800px** → `jpegData(0.9)` →
  `CapturedImage(imageData:)`. **Không** qua `ImageCompressor`: mức 1600 được đặt ra cho thời
  ảnh còn upload, giờ chỉ text đi ra ngoài.
- **`Library/CollectionDetailView.swift` (Hub):**
  - Menu ⋯ thêm "Gắn PDF…" (chưa gắn) / "Đổi PDF…" + "Gỡ PDF" (đã gắn). Ẩn hết khi
    `isDefault`.
  - Hàng phụ "📄 <tên> · tr. N" (chưa đọc thì "Đọc từ đầu") đặt **trên** danh sách
    session. Không phải CTA chính (ADR-052).
  - Gắn file dùng `.fileImporter(allowedContentTypes: [.pdf])` giống
    [ImportView.swift:36](app/Reado/Library/ImportView.swift#L36).
- **`Analysis/AnalysisView.swift`:**
  - `.task` đổi điều kiện `lastCapturedImage != nil` → `hasPendingPage`; gọi
    `analyzeCurrentPage()`.
  - Lỗi FR-04 khi `origin == .pdf`: nút "Về trang đọc" (đóng sheet) thay "Chụp lại".
  - Đang phân tích + `origin == .pdf` + có ảnh: dòng tiến độ `.readingPage` hiện "Trang scan
    — đang nhận dạng chữ trên máy…".
- **`Shell/DebugLaunch` (ReadoKit) + RootView:** case `pdf-reader`. Bản DEBUG sinh PDF 2
  trang (text tự viết, có một đoạn 2 cột) vào thư mục tmp, gắn vào bộ có tên đầu tiên rồi
  push reader. Không commit PDF sách thật.

### Transaction / module / file cấm
- `pdf_sources`: mỗi thao tác là một câu lệnh đơn, không cần transaction. Lưu vocab +
  session vẫn qua `VocabRepository.saveCapture` (khối #4/#5), không đổi.
- Không edit tay `project.pbxproj`. File mới đặt trong `app/Reado/**`, `app/ReadoKit/**`,
  thư mục synchronized tự nhận. Không thêm package (PDFKit là framework hệ thống, cả
  `Reado` và `ReadoKit` chỉ cần `import PDFKit`). Nếu link lỗi thì **dừng, nhờ fen** thêm
  framework trong Xcode.
- Ảnh trang vẽ ra chỉ sống trong bộ nhớ (NFR-04). DebugTrace DEBUG là ngoại lệ ADR-037.
  Timestamp hậu tố `Z`.

## Tầng 2 — Tasks

1 task = 1 session, đóng bằng `/rhandoff`. Thứ tự: **T0 → T1 → T2 → T3 → T4 → T5**.
T1 và T2 độc lập nhau. `home-eevas-r1` T2–T4 còn dở và cũng đụng `CollectionDetailView`/
`RootView`, nên **làm xong home-eevas-r1 trước T3**, hoặc fen chốt thứ tự khác.

### T0 — docs-adr (chỉ docs, không code)

Mọi chỗ còn nói "PDF bị cấm" phải sửa. Lệnh kiểm cuối:
`grep -rn -E "NG-07|PDF|ebook|một input path|đúng một lối" --include='*.md' docs CLAUDE.md ROADMAP.md`.

| File | Sửa gì |
|---|---|
| `docs/decisions-log.md` | **ADR-058** "Đọc PDF trong Reado — đảo NG-07". Gồm: bối cảnh (5 bước screenshot); quyết định 1–6 ở Context; mặc định hành vi; vì sao không chép file; vì sao lớp chữ trước OCR sau + chấm chất lượng; vì sao không gửi ảnh cho vision LLM; hệ quả (2 prompt, 2 bộ eval, bảng thứ 9); Later |
| `docs/specs/vision.md` | §1 "Với Reado": thêm "file PDF đang đọc trên máy". §3: "chụp trang **hoặc** phân tích trang PDF đang mở". §5: thêm câu không chép file PDF, chỉ giữ chỗ trỏ + số trang |
| `docs/specs/prd.md` | **Dòng NG-07 (:159):** viết lại thành "Ebook (EPUB, Kindle…) và chép/lưu file vào app". Ghi chú đảo một phần 2026-10-04, ADR-058: PDF đọc tại chỗ là cửa thứ hai (FR-23). Giữ id NG-07, không xoá dòng. **Ghi chú v0.6 (:66–67) và :807–808:** sửa câu "ảnh là đúng một lối" → "hai cửa: ảnh (FR-01) và trang PDF (FR-23)". **Thêm FR-23 + GWT** sau FR-04. **NFR-04:** thêm "file PDF không chép vào app". **Mọi bảng liệt kê FR:** `grep -n "FR-22" prd.md`, bảng nào liệt kê FR theo release/scope thì thêm FR-23 vào R1. Thêm ghi chú phiên bản **v0.x** đầu file theo mẫu các ghi chú cũ |
| `docs/specs/journeys.md` | :108 (bảng "Điểm đã chốt"): "Input hai cửa: ảnh (camera/thư viện) và trang PDF đọc trong bộ — FR-23, ADR-058". **Thêm J2b** (nội dung ở Spec) sau J2. :416: bỏ câu "NG-07 vẫn cấm PDF/ebook", giữ ý FR-20 không phải cửa capture. :597: "Import PDF / ebook (NG-07)" → "EPUB/ebook (NG-07)". Khung app/mermaid đầu file có Hub thì thêm nhánh "Đọc PDF" |
| `docs/specs/db.md` | A.2 "Tám bảng" → "Chín bảng" + mục `pdf_sources` (DDL ở trên, cột, lý do base64). A.3/C: không export, không sync (bookmark gắn với máy). B: ghi "không lên server" |
| `docs/specs/solution-design.md` | §7.1 Protocol: thêm `analyzeText`. §8 Capture: thêm mục con "8b PDF (FR-23)" — reader, `PDFPageText`, chấm chất lượng, rơi về OCR. §5 DDL: trỏ db.md bảng thứ 9 |
| `docs/agent/prompt-spec.md` | Mục mới "3b. Prompt PDF (`Prompt.pdfText`, `pdfVersion`)": khác v6 ở đâu, vì sao ghép gạch nối là ngoại lệ, câu cụt đầu/cuối trang. §8: eval PDF dùng `prompt_eval.py --swift-func pdfText`. §9 Đã chốt: thêm dòng |
| `docs/research/vocabulary.md` | :852, :1340–1345, :1487 là research cũ, **không viết lại**. Chỉ thêm một dòng "> Đã đảo một phần: ADR-058 (2026-10-04) — PDF đọc tại chỗ là cửa thứ hai" ngay dưới mỗi chỗ |
| `docs/agent/agent-rulebook.md` | Thêm hàng: "PDF reader, lớp chữ, chấm chất lượng, bookmark → ADR-058 + solution-design §8b + db.md `pdf_sources`" |
| `ROADMAP.md` | :17 `FR-01..FR-22` → `FR-01..FR-23`. :57 hàng Tombstones: bỏ "NG-07 một input path là ảnh chụp" → "NG-07 EPUB/ebook". Thêm checklist FR-23 (T1–T5 của plan này). Later: đánh dấu trang đã phân tích, lối tắt Home "Đọc tiếp", "Đọc lại bằng OCR", ô mật khẩu PDF, EPUB |
| `CLAUDE.md` §5 | Thêm "**Chốt thêm 2026-10-04:** đọc PDF trong Reado (FR-23) — đảo NG-07, ADR-058; EPUB vẫn ngoài." Không thêm luật cứng §4 |
| `docs/session-brief.md` | Hàng đợi: pdf-reader-r1 (T0 xong, T1–T5 chờ) |
| `docs/plans/pdf-reader-r1.md` | Bản plan này (chép vào lúc bắt đầu T0) |

- Test: `/raudit` (link/anchor). Lệnh grep ở trên chỉ còn các dòng đã sửa nghĩa.
- DoD: fen đọc + OK ADR-058 và FR-23. Commit `docs(pdf-reader-r1): T0 — ADR-058 đảo NG-07,
  FR-23, J2b`.

### T1 — kit-pdf-schema
- Files: `Migration.swift` (v5), `PDF/PDFSourceRepository.swift` (ReadoKit), test
  `MigrationAndSeedTests` (thêm case: DB v4 có dữ liệu → v5 giữ nguyên dữ liệu; DB mới tạo
  thẳng v5 có bảng) + `PDFSourceRepositoryTests` mới:
  - attach rồi đọc lại;
  - attach lần 2 ghi đè + reset trang;
  - `updatePage`, `updateBookmark`, `detach`;
  - xoá bộ → dòng `pdf_sources` mất (cascade);
  - `updated_at` có hậu tố `Z`.
- Test: `scripts/test.sh kit` khi làm, full `scripts/test.sh` trước `/rhandoff`.
- DoD: test xanh. `ExportService` không đổi.

### T2 — kit-pdf-analyze
- Files: `PDF/PDFPageText.swift`, `Analysis/PageAnalyzer.swift`,
  `Analysis/OpenAICompatClient.swift`, `Analysis/Prompt.swift`.
- Test:
  - `PDFPageTextTests` mới. Hàm dựng text test bằng mảng `(text, rect)` dựng tay:
    - 2 đoạn cách xa → đúng một `\n\n`;
    - hàng thụt đầu dòng → `\n\n`;
    - 2 cột → hết cột trái rồi cột phải;
    - ligature chuẩn hoá.
  - Chấm chất lượng: text sạch → qua; `(cid:72)…` / `Tlie qnick brovvn fox jnmps` /
    `@@## %%` / dưới 40 ký tự → `.needsOCR`.
  - Một test end-to-end nhỏ sinh PDF bằng `CGContext` + CoreText (macOS) → `extract` ra
    `.text` chứa câu mong đợi; trang trắng → `.needsOCR`.
  - `AnalysisStreamTests`/`AnalyzerFactoryTests`: lối `analyzeText` **không gọi OCR**
    (OCR giả ném lỗi nếu bị gọi), body chứa `PAGE_TEXT`, `meta.imageHash == sourceHash`.
    Test lối ảnh cũ vẫn xanh.
- DoD: kit + full xanh.

### T3 — ui-pdf-reader (đọc + nhớ trang, chưa phân tích)
- Files: `app/Reado/PDF/PDFReaderView.swift`, `App/AppModel+PDF.swift` (attach/open/detach/
  save page), `App/RootView.swift` (route `pdfReader`), `Library/CollectionDetailView.swift`
  (menu + hàng PDF), `DebugLaunch` case `pdf-reader`.
- CTA "Phân tích trang này" **ẩn** ở task này.
- Test: full `scripts/test.sh`.
- Xem tay trên simulator iPhone Air, qua `-ReadoScreen pdf-reader` + gắn tay một file trong
  Files của sim:
  - lật trang, back, mở lại → đúng trang;
  - "Đổi PDF…" → trang 1;
  - "Gỡ PDF" → hàng biến mất;
  - kho tạm không có menu;
  - xoá file trong Files → "Chọn lại file".
  - Ảnh 2 theme + Dynamic Type lớn.
- DoD: fen xem ảnh/xem tay OK.

### T4 — ui-pdf-analyze (nối vào màn duyệt)
- Files: `App/AppState.swift` (`pdfText`, `origin`, `hasPendingPage`, `pendingPDFAnalysis`),
  `App/AppModel+Capture.swift`, `App/AppModel+PDF.swift` (`preparePDFAnalysis` + render
  scan), `App/RootView.swift` (`onChange` → agent gate → sheet),
  `Analysis/AnalysisView.swift` (điều kiện `.task`, "Về trang đọc", dòng tiến độ scan),
  `PDF/PDFReaderView.swift` (hiện CTA).
- Test: full `scripts/test.sh`.
- Xem tay:
  - trang có chữ → Duyệt & lưu → banner → vẫn ở trang đó → Hub có session mới;
  - trang 2 cột → thứ tự đoạn đúng;
  - một trang chỉ có ảnh (DEBUG PDF có trang ảnh) → đi OCR;
  - trang trắng → "Về trang đọc";
  - chưa có agent (`--seed empty`) → form agent;
  - `diag_summary.py`: `source=pdf`, không có `ocrMs`.
- DoD: vòng đọc → phân tích → lưu → đọc tiếp chạy trên simulator. Lối chụp ảnh cũ không đổi
  (chụp thử 1 lần).

### T5 — eval-pdf-prompt (cần fen + máy thật)
- Fen phân tích 3–5 trang **mỗi loại** rồi `scripts/pull_diagnostics.sh device`:
  - (a) PDF sinh từ máy, 1 cột, có header/footer + gạch nối;
  - (b) 2 cột;
  - (c) scan không chữ;
  - (d) scan có lớp chữ rác (nếu tìm được).
- `scripts/prompt_eval.py`: thêm `--swift-func` (mặc định `text`, `pdfText` cho PDF), nhận
  cả placeholder `\(pageText)`, lọc theo meta `source`.
- Kiểm:
  - thứ tự đoạn đúng;
  - (c)(d) đi OCR, (a)(b) không;
  - `example` không lấy câu cụt;
  - header/số trang không lọt vào segment.

  Chỉnh ngưỡng chấm chất lượng / prompt nếu cần (bump `pdfVersion`).
- DoD: fen chấp nhận bảng eval prompt PDF v1. Ghi vào ADR-058 + journal.

## Verification (toàn plan)
- `scripts/test.sh kit` sau T1/T2. Full `scripts/test.sh` trước mỗi `/rhandoff`. Không chạy
  được simulator thì không ghi "xong", không bịa số test.
- End-to-end simulator iPhone Air: Hub → Gắn PDF → đọc tới tr. 5 → Phân tích → lưu 3 từ →
  banner → vẫn tr. 5 → back → Hub có session mới + 3 từ → đóng app, mở lại → tr. 5.
- `python3 scripts/diag_summary.py <dir>`: lượt PDF có `source=pdf` và không có bước OCR;
  lượt scan có `source=image` + `ocrMs`.
- Sau T0: lệnh grep NG-07/PDF không còn câu nào nói PDF bị cấm.

## Ghi chú cho người implement (Sonnet)
- Đọc `CLAUDE.md` + plan này. Chỉ làm **đúng một task** được giao. Phần "Tầng 1" đã chốt hết
  các quyết định, **không tự quyết lại**. Gặp chỗ plan không nói → dừng, hỏi fen.
- Không đọc nguyên file lớn (prd, journeys, db, solution-design, ROADMAP, decisions-log):
  grep số dòng rồi Read có offset.
