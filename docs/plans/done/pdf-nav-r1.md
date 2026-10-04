# Plan: pdf-nav-r1 — điều hướng trang dễ hơn trong PDF reader

> **Trạng thái:** closed (2026-10-04) - N0/N1/N2 xong, code+test xanh (kit
> 462/462, full 481/483). Fen xem tay trực tiếp trên simulator 3 vòng trong lúc
> implement → ADR-060 (bỏ thanh kéo trang + nút ◀ ▶, gõ trang + Mục lục đã đủ;
> thêm chạm-vào-trang ẩn/hiện nav bar + thanh đáy; thêm tông nền đọc) → ADR-061
> (nhiều tông giấy + Slider độ đậm; cố định màu viền `PDFView` không theo Dark
> Mode) → ADR-062 (dọn control tông nền từ Menu trên toolbar reader sang Section
> "Đọc PDF" ở `SettingsView`). Phần "Hàng 1" ở N2 bước 2 dưới đây (slider/◀▶)
> **không còn áp dụng** — xem ADR-060/061/062 ở `docs/decisions-log.md` cho đặc tả
> cuối cùng. Nợ xem tay (chạm-ẩn-chrome, vuốt lật trang, chọn tông + kéo Slider ở
> Cài đặt bằng tay thật): `session-brief.md` §2.

## Context

pdf-reader-r1 T0–T4 đã chạy được trên máy fen (branch `pdf-reader-r1`). Fen thử với sách
thật 254 trang và thấy **khó chọn trang, khó đổi trang**: reader hiện chỉ có vuốt ngang
từng trang (`PDFView` + `usePageViewController`). Không có cách nhảy nhanh, không có mục
lục, thanh tab chiếm chỗ đọc.

**Fen đã chốt (2026-10-04, không hỏi lại):**
1. Thêm **thanh kéo trang + nút ◀ ▶ + chạm "Tr. N / M" để gõ số trang**.
2. Thêm **Mục lục** từ outline có sẵn trong PDF. Việc này **đảo dòng "mục lục" ngoài phạm
   vi** của FR-23/J2b → ghi ADR-059.
3. **Ẩn thanh tab** (Hôm nay / Thư viện) khi đang ở màn đọc PDF.
4. **Không làm:** đổi sang cuộn dọc liên tục, lưới ảnh thu nhỏ. Giữ lật ngang từng trang.

**PDF mẫu của fen** (chỉ dùng trên máy, KHÔNG BAO GIỜ commit):
`reado_v2/The-Courage-to-be-Disliked-…-z-lib.org_.epub_.pdf`. 254 trang, khổ Letter
612×792, có `/Outlines` (~68 mục). `.gitignore` đã có sẵn dòng `/*.pdf` (sửa trên đĩa,
**chưa commit**) → commit ở N0.
- Không dán nội dung sách vào docs, journal, commit message hay test. Ảnh chụp màn
  hình sách thật chỉ để trong `.tmp/screens/` (đã gitignore).
- File này cũng dùng được cho pdf-reader-r1 T5 sau này, nhưng T5 không thuộc plan này.

## Spec

- **FR / journey:** FR-23 (`docs/specs/prd.md`) + J2b (`docs/specs/journeys.md`).
  Thêm 1 GWT vào FR-23:
  > Given đang đọc một PDF nhiều trang, when kéo thanh trang, bấm ◀/▶, gõ số trang, hoặc
  > chọn một mục trong Mục lục, then reader nhảy tới đúng trang đó và trang đó được nhớ
  > như khi lật tay.
- **Nguyên lý:** #2 "Meaning must never be blocked" (ma sát điều hướng làm đứt mạch đọc)
  + #3 (tới trang cần phân tích nhanh hơn). Không đụng "Chống lại" nào. Mục lục chỉ là
  điều hướng, không phải tóm tắt (#6 không vi phạm).
- **In-scope:** điều hướng (slider, ◀▶, gõ trang, Mục lục), ẩn tab bar trong reader,
  sửa icon hàng PDF ở Hub sang `IconTile` (lệch MASTER từ T3), sửa
  `startAccessingSecurityScopedResource` false → không nên chặn mở file (xem N2 bước 8),
  debug hook để agent chụp màn với PDF thật.
- **Out-of-scope:** cuộn dọc, thumbnail, tìm kiếm chữ trong PDF, highlight/ghi chú,
  bookmark nhiều chỗ, T5 eval, EPUB.
- **Không đụng:** schema (`pdf_sources` giữ nguyên, trang nhảy tới vẫn lưu qua
  `PDFSourceRepository.updatePage`), prompt, `PDFPageText`, luồng phân tích T4.

## Tầng 1 — HLD

### ReadoKit — `PDF/PDFNavigation.swift` (mới, logic thuần, test bằng lane `kit`)

`import PDFKit` (đã dùng trong `PDFPageText.swift`, chạy được trên macOS).

```swift
public enum PDFNavigation {
    /// pageCount <= 0 → 0. Kẹp vào 0...pageCount-1.
    public static func clamp(_ index: Int, pageCount: Int) -> Int
    /// Người dùng gõ số trang 1-based. Trim khoảng trắng; "42" → 41.
    /// Rỗng / không phải số / 0 / âm / > pageCount → nil.
    public static func pageIndex(fromInput text: String, pageCount: Int) -> Int?

    public struct OutlineEntry: Equatable, Sendable, Identifiable {
        public let id: Int           // thứ tự trong danh sách đã duỗi phẳng
        public let label: String     // đã trim
        public let depth: Int        // 0 = mục cấp 1 (con trực tiếp của outlineRoot)
        public let pageIndex: Int?   // nil = mục không trỏ tới trang nào (không bấm được)
    }
    /// Duyệt sâu theo thứ tự tài liệu, bỏ outlineRoot. Không có outline → [].
    /// Trang đích: `outline.destination?.page`, NẾU nil thì
    /// `(outline.action as? PDFActionGoTo)?.destination.page` — PDF chuyển từ epub
    /// thường dùng /A GoTo thay vì /Dest. Nhãn rỗng sau trim → bỏ nút đó nhưng VẪN
    /// duyệt con của nó ở cùng depth.
    public static func outlineEntries(in document: PDFDocument) -> [OutlineEntry]
    /// Mục "đang đọc": mục có pageIndex lớn nhất ≤ trang hiện tại; hoà nhau → mục
    /// đứng SAU trong danh sách (cụ thể hơn). Trang hiện tại trước mục đầu → nil.
    public static func currentEntryID(in entries: [OutlineEntry], pageIndex: Int) -> Int?
}
```

### Reado (UI)

- **`PDF/PDFReaderNavigator.swift` (mới):** `@MainActor final class` giữ
  `weak var pdfView: PDFView?`. Hàm `go(to index: Int)`: kẹp bằng
  `PDFNavigation.clamp`, lấy `document.page(at:)`, gọi `pdfView.go(to:)`. Là `@State`
  của `PDFReaderView`, truyền vào `PDFPageView`, gán `navigator.pdfView = view` trong
  `makeUIView`. Dùng object điều khiển thay vì binding "trang yêu cầu" để tránh vòng lặp
  `.PDFViewPageChanged` → state → `go(to:)`.
- **`PDF/PDFReaderView.swift`:**
  - Thanh đáy 2 hàng (chi tiết ở N2).
  - Alert "Đi tới trang".
  - Nút Mục lục trên toolbar.
  - Bỏ `.safeAreaPadding(.bottom, ShellTabBar.reservedHeight)` vì tab bar đã ẩn.
- **`PDF/PDFOutlineSheet.swift` (mới):** sheet danh sách mục lục.
- **`App/RootView.swift`:** `ShellTabBar(isHidden: chrome.isHidden || isReadingPDF, …)`.
- **`App/AppModel+PDF.swift`:** `openPDFDocument` không fail khi
  `startAccessingSecurityScopedResource()` trả `false`. Trả thêm `didStartAccess`.
- **`Library/CollectionDetailView.swift`:** hàng PDF dùng `IconTile`.
- **Debug (DEBUG-only):**
  - env `READO_DEV_PDF_FIXTURE` (đường dẫn PDF thật) + `READO_DEV_PDF_PAGE` (trang mở
    sẵn, 1-based);
  - màn `pdf-reader-toc`, `pdf-reader-goto`;
  - `sim_screens.sh --pdf / --pdf-page`.

**File cấm / luật:** không sửa tay `project.pbxproj` (file mới trong `app/Reado/PDF/`,
`app/ReadoKit/...` tự nhận). Không thêm dependency. Token qua `Spacing`/`Typo`/`IconTile`,
không hex/số lẻ (MASTER). Vùng chạm ≥ 44×44. Haptic qua `Haptics.*`. Alert/sheet gắn
`.appErrorAlert()` ở gốc sheet (gotcha `reado-ui`).

## Tầng 2 — Tasks

Thứ tự: **N0 → N1 → N2**. N0 nhỏ, làm chung session với N1 được. N2 là UI: **load skill
`reado-ui` trước khi sửa view** và đọc `design-system/reado/MASTER.md`.

### N0 — docs + gitignore

1. Chép plan này vào `docs/plans/pdf-nav-r1.md`.
2. `docs/decisions-log.md` thêm **ADR-059** "Điều hướng trang + Mục lục trong PDF reader
   — đảo dòng 'mục lục' ngoài phạm vi của FR-23", gồm:
   - Bối cảnh: fen thử sách 254 trang, chỉ vuốt từng trang thì khó.
   - Quyết định: 1–4 ở Context.
   - Hệ quả: không đổi schema; Mục lục đọc outline có sẵn trong file, không tự sinh;
     tab bar ẩn trong reader.
   - Không sửa ADR-058.
3. `docs/specs/prd.md`:
   - FR-23 thêm GWT điều hướng (ở Spec);
   - câu "Không thuộc phạm vi R1: … highlight/ghi chú/mục lục trong PDF …" bỏ chữ "mục
     lục", ghi chú "(mục lục: ADR-059)";
   - bảng changelog thêm dòng.
4. `docs/specs/journeys.md` J2b:
   - Happy path "Hằng ngày" bước 2 thêm: thanh đáy có thanh kéo + ◀ ▶ + chạm số trang để
     gõ, nút Mục lục góc trên (chỉ hiện khi PDF có outline), thanh tab ẩn trong reader.
   - Dòng "Không có ở R1" bỏ "mục lục".
   - Bảng Empty/error thêm: "PDF không có outline → không hiện nút Mục lục";
     "Gõ số trang ngoài khoảng → rung báo lỗi, không nhảy".
5. `ROADMAP.md` 3.17 thêm ghi chú "pdf-nav-r1: điều hướng + Mục lục (ADR-059)".
6. Commit gồm cả `.gitignore` (dòng `/*.pdf` đã có trên đĩa). Kiểm `git status`: file
   PDF sách KHÔNG được staged.

### N1 — kit: `PDFNavigation` + test

- Files:
  - `app/ReadoKit/Sources/ReadoKit/PDF/PDFNavigation.swift`;
  - `app/ReadoKit/Tests/ReadoKitTests/PDFNavigationTests.swift` (mới);
  - `app/ReadoKit/Tests/ReadoKitTests/PDFTestSupport.swift` (mới): chuyển
    `makeTestPDF` đang là `private static` trong `PDFPageTextTests.swift` ra helper
    dùng chung, hỗ trợ N trang (`[[(String, CGPoint)]]`). `PDFPageTextTests` đổi sang
    dùng helper, hành vi test giữ nguyên.
- Test (`PDFNavigationTests`):
  - `clamp`: -1→0, 0→0, 5 (count 5)→4, pageCount 0→0.
  - `pageIndex(fromInput:)`: "1"→0, " 42 "→41 (count 254), "254"→253, "255"/"0"/"-3"/
    ""/"abc"/"4.5"→nil.
  - `outlineEntries`: PDF 5 trang dựng bằng helper, outline dựng tay:
    root → Ch1 (trang 0) [con: 1.1 (trang 1)], mục nhãn rỗng (trang 2) [con: 2.x (trang
    2)], Ch3 (không destination, không action), Ch4 dùng `PDFActionGoTo` (trang 3).
    Kỳ vọng thứ tự/label/depth/pageIndex: Ch1(0,0), 1.1(1,1), 2.x(0,2) (con của mục rỗng
    lên cùng depth với mục rỗng), Ch3(0,nil), Ch4(0,3). PDF không outline → `[]`.
  - Cách dựng: `let root = PDFOutline(); let o = PDFOutline(); o.label = "…";
    o.destination = PDFDestination(page: page, at: .zero); root.insertChild(o, at:
    root.numberOfChildren); doc.outlineRoot = root`.
  - **Nếu PDFKit trên macOS không giữ outline dựng tay trong bộ nhớ:** dừng, ghi rõ
    trong journal, chuyển sang test bằng PDF ghi ra đĩa rồi đọc lại. Không bỏ test.
  - `currentEntryID`: trang 0→Ch1, 1→1.1, 2→2.x, 3→Ch4, 4→Ch4; outline bắt đầu ở
    trang 2 mà trang hiện tại là 0 → nil.
- Lệnh: `scripts/test.sh kit`, rồi full `scripts/test.sh` trước commit.
- DoD: kit + full xanh.

### N2 — UI điều hướng + ẩn tab bar + debug hook

1. **Navigator** — `PDFReaderNavigator` như HLD. Sau khi gọi `navigator.go(to: i)`,
   `PDFReaderView` cũng tự gán `currentPageIndex = i` + `scheduleSavePage(i)` (idempotent
   với notification — không dựa hoàn toàn vào `.PDFViewPageChanged` có bắn khi
   `go(to:)` dưới `usePageViewController` hay không).
2. **Thanh đáy** (`VStack(spacing: Spacing.xs)`, padding `Spacing.md`/`Spacing.sm`,
   `.background(.bar, ignoresSafeAreaEdges: .bottom)`):
   - **Hàng 1** (ẩn khi `pageCount <= 1`): `[◀] Slider [▶]`.
     - ◀/▶: `Image(systemName: "chevron.left"/"chevron.right")`, khung ≥ 44×44,
       `accessibilityLabel("Trang trước"/"Trang sau")`, disable ở hai đầu,
       `Haptics.selection()`.
     - Slider `in: 0...Double(pageCount - 1), step: 1`. Kéo thì nhãn số trang đổi theo
       (`@State isScrubbing`, `@State sliderValue`). Chỉ `go(to:)` khi THẢ tay
       (`onEditingChanged == false`), không gọi liên tục lúc kéo. Ngoài lúc kéo,
       `sliderValue` bám `currentPageIndex` (`.onChange`).
     - Màu: control hệ thống tự ăn accent từ `.tint` ở `ReadoApp` — không tô thêm.
   - **Hàng 2:** `Button("Tr. N / M")` (Typo.meta, `.secondary`, cao ≥ 44,
     `accessibilityHint("Chạm để gõ số trang")`) mở alert. `Spacer`. CTA "Phân tích trang
     này" giữ nguyên như T4.
   - Dynamic Type accessibility: bọc hàng 2 bằng `ViewThatFits(in: .horizontal)`,
     fallback `VStack` (nhãn trên, CTA full width dưới).
3. **Alert "Đi tới trang":** `TextField` placeholder `"1–\(pageCount)"`,
   `.keyboardType(.numberPad)`, nút "Đi" + "Huỷ" (cancel), message "Sách có M trang."
   Dùng `PDFNavigation.pageIndex(fromInput:)`; nil → `Haptics.error()`, không nhảy.
   Mở alert thì xoá text cũ.
4. **Mục lục:**
   - Tính `outlineEntries` MỘT lần lúc mở document (`@State`).
   - Toolbar `.topBarTrailing`: `Button { … } label: { Label("Mục lục", systemImage:
     "list.bullet") }`, chỉ hiện khi entries không rỗng (symbol outline theo MASTER).
   - `PDFOutlineSheet(entries:currentPageIndex:onSelect:)`: `NavigationStack { List }`,
     title "Mục lục", nút "Xong", `.presentationDetents([.medium, .large])`,
     `.appErrorAlert()` ở gốc.
   - Mỗi dòng là `Button`: label + thụt đầu dòng `CGFloat(min(depth, 3)) * Spacing.md`,
     cuối dòng "tr. N" (Typo.meta, `.secondary`).
   - Mục `currentEntryID` đánh dấu `checkmark` + `.accessibilityAddTraits(.isSelected)`.
     `ScrollViewReader` cuộn tới mục đó khi mở.
   - Mục `pageIndex == nil` → `.disabled(true)`.
   - Chọn mục → đóng sheet → `navigator.go(to:)` (+ cập nhật state như bước 1).
5. **Ẩn tab bar:**
   - `RootView`: `private var isReadingPDF: Bool` lấy path của `selectedTab`
     (`todayPath`/`libraryPath`) — `if case .pdfReader = path.last { true }`. Truyền
     `isHidden: chrome.isHidden || isReadingPDF`.
   - `ShellTabBar` đã có cơ chế ẩn (offset + opacity + `allowsHitTesting(false)` +
     `accessibilityHidden`, safe area đứng yên — D3) → KHÔNG sửa `ShellTabBar`.
   - `PDFReaderView` bỏ `.safeAreaPadding(.bottom, ShellTabBar.reservedHeight)`, sửa
     comment gotcha tương ứng.
   - Chụp ảnh xác nhận: thanh đáy nằm ngay trên home indicator, không còn khoảng trống
     ~80pt.
6. **Hàng PDF ở Hub:** thay `Image(systemName: "doc.text")` bằng
   `IconTile(systemImage: "doc.text")` (MASTER: icon đầu row dùng `IconTile`).
7. **Debug hook (DEBUG-only):**
   - `RootView.openDebugPDFReader`:
     - env `READO_DEV_PDF_FIXTURE` có và file tồn tại → dùng
       `URL(fileURLWithPath:)` đó thay `DebugPDFFixture`;
     - env `READO_DEV_PDF_PAGE` (1-based) có → sau attach gọi
       `model.savePDFPage(collectionID:pageIndex:)` (qua `PDFNavigation.pageIndex`)
       trước khi push reader.
   - `DebugLaunch.Screen` thêm `pdfReaderTOC` ("pdf-reader-toc") và `pdfReaderGoTo`
     ("pdf-reader-goto"); thêm vào bảng `DebugLaunchTests.testEachScreenParses`.
   - `ShellSignals` (`#if DEBUG`) thêm `debugShowPDFOutline`, `debugShowPDFGoTo`. RootView
     set cờ rồi gọi `openDebugPDFReader()`. `PDFReaderView` đọc cờ ở `.task` sau khi
     document mở xong (sleep 0.6s như các cờ debug khác), mở sheet/alert, dọn cờ.
   - `scripts/sim_screens.sh open`:
     - `--pdf <file>` → `SIMCTL_CHILD_READO_DEV_PDF_FIXTURE` (đổi sang đường dẫn tuyệt
       đối như `ANALYSIS_FIXTURE`);
     - `--pdf-page <N>` → `SIMCTL_CHILD_READO_DEV_PDF_PAGE`;
     - comment đầu file bổ sung tên màn `pdf-reader`, `pdf-reader-toc`,
       `pdf-reader-goto`.
8. **Sửa `openPDFDocument`** (`AppModel+PDF.swift`):
   - Hiện tại `guard url.startAccessingSecurityScopedResource() else { return
     .failure(.accessDenied) }`. Theo Apple, hàm này trả `false` với URL không
     security-scoped nhưng file vẫn đọc được (vd file trong container app, file host
     của simulator).
   - Đổi thành `let didStart = url.start…()`, vẫn thử `PDFDocument(url:)`. Chỉ trả
     `.accessDenied` khi `!didStart && document == nil`; còn lại theo nhánh cũ.
   - Tuple success thêm `didStartAccess: Bool`. `PDFReaderView` chỉ gọi
     `stopAccessingSecurityScopedResource()` khi `didStartAccess` (lưu
     `activeURL = didStart ? url : nil`).
   - Các nhánh fail sau khi đã start vẫn stop như cũ.
9. **Docs:** thêm gotcha vào `.claude/skills/reado-ui/SKILL.md`: "Ảnh đầu tiên sau
   `sim_screens.sh open` hay trắng (app chưa vẽ xong) — chụp lại lần 2 trước khi kết
   luận." Cập nhật `docs/session-brief.md` §1 + §2.10 (nợ xem tay).

- **Test:** `scripts/test.sh kit` (DebugLaunch), full `scripts/test.sh`.
- **Xem tay bằng ảnh (agent tự làm, light + dark, đọc PNG):**
  - `scripts/sim_screens.sh open pdf-reader --seed demo --pdf "<đường dẫn PDF mẫu>"`
    → trang 1, thanh đáy 2 hàng, tab bar ẩn, nút Mục lục trên toolbar.
  - `… --pdf-page 120` → mở đúng trang 120, slider ở giữa, "Tr. 120 / 254".
  - `open pdf-reader-toc --pdf …` → sheet Mục lục, mục đang đọc có dấu ✓.
  - `open pdf-reader-goto --pdf …` → alert "Đi tới trang".
  - `open pdf-reader` (fixture 2 trang, không outline) → KHÔNG có nút Mục lục.
  - `scripts/sim_screens.sh size accessibility-extra-large` rồi chụp lại reader → không
    cắt chữ/chồng lấn. Thử accent Nâu giấy (MASTER checklist).
  - `open collection:"Demo Habits"` → hàng PDF dùng `IconTile`.
- **Ghi rõ "chưa xem tay" (DebugLaunch không giả lập chạm — fen làm):**
  - kéo slider/◀▶ thật;
  - vuốt ngang lật trang có bị cử chỉ "vuốt mép trái để back" giành không;
  - chọn mục lục rồi phân tích trang đó;
  - banner "Đã lưu…" (ADR-053, nằm cố định ~80pt trên đáy) có che thanh đáy reader
    trong 4s không — nếu che, ghi vào brief để fen quyết, KHÔNG tự sửa vị trí banner.
- **DoD:** test xanh; toàn bộ ảnh ở trên đúng; ROADMAP/brief cập nhật; commit
  `feat(pdf-nav-r1): …` không chứa file PDF sách.

## Verification (toàn plan)
- `scripts/test.sh kit` + full `scripts/test.sh` sau N1 và N2 (hiện 464/466, 2 skip
  cũ). Không chạy được simulator thì không ghi "xong".
- Ảnh như N2. Mọi PNG đọc cả light/dark trước khi báo.
- `git status` trước mỗi commit: không có `*.pdf` sách, không có ảnh sách ngoài `.tmp/`.

## Ghi chú cho người implement (Sonnet)
- Đọc `CLAUDE.md`, plan này, `docs/plans/pdf-reader-r1.md` (bối cảnh T3/T4). Code hiện
  tại: `app/Reado/PDF/PDFReaderView.swift`, `app/Reado/App/AppModel+PDF.swift`,
  `app/Reado/App/RootView.swift`.
- Mọi quyết định ở trên đã chốt — không tự đổi (vd không tự chuyển sang cuộn dọc).
  Gặp chỗ plan không nói → dừng, hỏi fen.
- Bẫy đã biết:
  - `UIViewRepresentable` trong `VStack` có thể nuốt hết chiều cao của sibling — giữ
    `PDFPageView` với `.frame(maxWidth: .infinity, maxHeight: .infinity)` và XÁC NHẬN
    bằng ảnh thanh đáy hiện đủ 2 hàng. Không thấy thì tạm tô `.background(Color.red)`
    để định vị rồi bỏ (đã ghi trong skill `reado-ui`).
  - `PDFPage`/`PDFDocument` không `Sendable` → mọi thao tác PDFKit ở MainActor, không
    tách `Task.detached`.
