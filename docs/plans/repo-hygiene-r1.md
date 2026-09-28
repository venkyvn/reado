# Plan: repo-hygiene-r1 — dọn repo, pbxproj đồng bộ thư mục, tách code UI, lane test nhanh

> Lưu thành `docs/plans/repo-hygiene-r1.md` ở bước đầu A1 (fen đã OK plan).
> Người implement: Sonnet, **mỗi task 1 session**, mở bằng `/rstart`, đóng bằng `/rhandoff`.
> CI: để sau, không nằm trong plan này.

## Context

Fen hỏi cấu trúc repo đang ở mức nào và cải thiện gì. Kết luận review 2026-09-28: quy trình agent + docs mạnh (top ~5%), nhưng kéo xuống bởi:
1. **Rủi ro thật:** ảnh trang sách (bản quyền) `ref/sample/*.png|jpeg` đang track trong git, mâu thuẫn với việc đã xoá `captures/*/page.jpg` vì bản quyền. `.env.example` chứa key Gemini thật (chưa từng commit, nhưng tên sai vai).
2. **pbxproj viết tay:** mỗi file Swift phải có đủ 4 dấu vết, thiếu 1 là Xcode bỏ qua ngầm → cần `pbxproj_tool.py` + gate `check`. Xcode 27 trên máy hỗ trợ *synchronized folders* (objectVersion 77), thứ bỏ hẳn bài toán này.
3. **Code UI:** `app/Reado/` gần phẳng; 4 file quá lớn (`Screens/ReviewQueueView.swift` 824, `AppModel.swift` 765, `AnalysisView.swift` 683, `RootView.swift` 661). Test gần như hết nằm trong `ReadoTests` (cần simulator), `ReadoKit/Tests` chỉ 1 file. `ReadoKit` khai báo `.macOS(.v13)` nhưng `Capture/ImageCompressor.swift` `import UIKit` trần → không build được trên macOS.
4. **Docs:** 5 file kiểu mục lục (`README`, `PROJECT.md`, `AGENTS.md` stub, `CLAUDE.md`, `agent-rulebook`); `docs/archive/*-pwa-gen.md` ~2.000 dòng làm nhiễu grep; thư mục gốc lặt vặt (`idea.md`, `qr/`, `ui-lab/`, `design-system/`, `ref/`); `scripts/verify/` còn script Node thời PWA.

Fen đã chốt: **xoá archive, pointer thay bằng hash**; **ref/sample gỡ khỏi git, giữ file local** (không viết lại lịch sử).

## Ràng buộc song song — ĐỌC TRƯỚC MỖI TASK

Một session khác đang chạy `visual-polish-r1` (`docs/plans/visual-polish-r1.md`), đụng **mọi file view trong `app/Reado`**, `AppModel.swift`, `project.pbxproj` (thêm `DesignSystem.swift`), `ROADMAP.md`, `docs/session-brief.md`, `docs/decisions-log.md`.

- **Phase A** (A1–A5): làm được ngay, song song. **Cấm** sửa: `app/Reado/**`, `app/ReadoTests/**`, `project.pbxproj`, `ROADMAP.md`, `docs/plans/**`, `docs/sample.md`, `scripts/fixtures/`. `docs/session-brief.md` + `docs/decisions-log.md` chỉ **thêm** mục mới ở cuối, không sửa đoạn có sẵn.
- **Phase B** (B1–B5): chỉ bắt đầu khi `visual-polish-r1` đã khép + commit **và** `git status` sạch ở `app/`. Không đủ điều kiện → dừng, báo fen.
- Commit: luôn `git add <đường dẫn cụ thể>`, không `git add -A`/`.`. Xem `git diff --cached` trước commit, chỉ giữ hunk của task (memory: `git add -p`, pipe `y`/`n`).
- ADR: dùng số **kế tiếp tại thời điểm viết** (session kia sẽ lấy ADR-043), grep `^## ADR-` trong `docs/decisions-log.md`.
- `docs/sample.md` (untracked, không rõ chủ) — không đụng, ghi vào mục "Chờ owner".

## Spec

- Không đổi hành vi app, không đổi schema/FR/transaction/prompt. Phase B là refactor thuần (di chuyển + tách file), test phải giữ nguyên tổng số pass.
- Không thêm dependency.
- In-scope: 4 nhóm trên. Out-of-scope: CI, deploy proxy, đổi nội dung spec/research (chỉ thêm tóm tắt), viết lại git history.

---

## Phase A — làm ngay

### A1 — Bí mật + bản quyền

- **`.env`:** nếu `.env` đã tồn tại → so nội dung với `.env.example`, gộp key thật vào `.env` (hỏi fen nếu hai file khác giá trị). Nếu chưa → `mv .env.example .env`.
- Tạo `.env.example` mới **chỉ placeholder**, lấy tên biến từ `grep -rn 'getenv\|environ' proxy/` (`GEMINI_API_KEY`, …) + comment 1 dòng mỗi biến. Track nó.
- **`.gitignore`:** xoá khối "`.env.example` đang chứa key Gemini thật…" (dòng `.env.example` cuối file), giữ `.env`, `.env.*`, `!.env.example`. Thêm:
  ```
  # Ảnh trang sách thật (bản quyền) — chỉ giữ local
  ref/sample/*.png
  ref/sample/*.jpg
  ref/sample/*.jpeg
  ref/sample/page-37
  ```
  (`page-37` kiểm trước: nếu là thư mục/ảnh → ignore; nếu là text do fen viết → giữ track.)
- `git rm --cached` các ảnh trên. `ref/sample/*.txt` (OCR/output tay) giữ track.
- Kiểm: `git ls-files ref/sample` không còn ảnh; `git check-ignore -v ref/sample/page-42.png` ra đúng dòng; `git check-ignore .env.example` → không ignore; `grep -E 'AIza|sk-' .env.example` rỗng.
- **Báo fen** trong handoff: remote `github.com:venkyvn/reado` — nếu repo **public**, ảnh vẫn còn trong lịch sử cũ → cần quyết lại (filter-repo). Nếu key Gemini từng dán ở nơi khác → rotate.

### A2 — Dọn thư mục gốc + scripts cũ

| Hiện tại | Đích | Cập nhật pointer |
|---|---|---|
| `idea.md` | `docs/idea.md` | `docs/specs/prd.md:13`, `docs/agent/prompt-spec.md:18,99`, `README.md` |
| `ui-lab/` | `ref/ui-lab/` | grep `ui-lab` (comment Swift **không sửa** ở Phase A — ghi lại, sửa ở B2) |
| `qr/restore.py` | đọc file trước; nếu là tool giải gói transport (như `qr/v2/restore.py` đã xoá 09-18) → `git rm -r qr/` + bỏ dòng `.build-qr/`, `.xcode-packages-qr/` trong `.gitignore` | ROADMAP (để B5) |
| `scripts/verify/verify.mjs`, `ab-compress.mjs`, `samples/` | xoá (Node, thời PWA) | `scripts/verify/README.md` viết lại chỉ còn `check-doc-links.mjs` |
| `.keep.json` | đọc; không rõ mục đích → giữ, ghi "Chờ owner" | — |

- `design-system/` **không** di chuyển ở Phase A (session kia đang dùng path này) → B2.
- `git mv` để giữ lịch sử. Kiểm: `grep -rn 'idea\.md\|ui-lab\|qr/' --include=*.md --include=*.py --include=*.sh . | grep -v 'docs/journal\|docs/archive'` chỉ còn pointer đúng.

### A3 — Gộp file mục lục

- **Xoá `AGENTS.md`.** Sửa ref: `docs/research/tech-stack.md:9,42,463-466` (bảng lịch sử: đổi thành "`AGENTS.md` (đã gộp vào `CLAUDE.md` §7, ADR-035)"), `.claude/commands/raudit.md:10`.
- **Xoá `PROJECT.md`** sau khi chuyển phần không trùng:
  - Bảng "file & vì sao" → gộp vào `CLAUDE.md` §3 chỉ những dòng chưa có (design-system, ref/pvo "không đọc cho R1", journal, investigations). `CLAUDE.md` giữ ≤ ~120 dòng.
  - Mô tả sản phẩm tiếng Anh → bỏ (README tiếng Việt đã có).
  - README: bỏ dòng trỏ PROJECT.md, trỏ `CLAUDE.md` §3.
- `docs/agent/agent-rulebook.md`: giữ (index "đụng X → grep Y" có vai riêng), chỉ sửa link gãy.
- Kiểm: `node scripts/verify/check-doc-links.mjs` sạch (hoặc `/raudit`).

### A4 — Xoá `docs/archive/`, thay pointer bằng ADR + hash

1. `H=$(git log -1 --format=%h)` **trước** khi xoá (commit cuối còn archive).
2. Thêm ADR mới "Xoá docs/archive PWA-gen": liệt 6 file + lệnh khôi phục `git show $H:docs/archive/<file>`.
3. `git rm -r docs/archive/`.
4. Thay pointer ở docs **sống** (không sửa `docs/journal/*`, không sửa dòng log lịch sử trong ROADMAP): mẫu
   `archive/mvp-plan-pwa-gen mục 5` → `mvp-plan-pwa-gen mục 5 (đã xoá, ADR-0xx)`; link markdown → bỏ link, giữ tên + `(ADR-0xx)`.
   File: `docs/specs/journeys.md` (~10 chỗ, dòng 564–917), `docs/specs/solution-design.md:10`, `docs/agent/prompt-spec.md:239`, `docs/agent/coding-conventions.md:5`, `docs/agent/agent-rulebook.md:3`, `docs/research/review.md:922,932,1047,1060`, `docs/research/vocabulary.md:1504,1515`.
   `ROADMAP.md:5,15,88,241` → **để B5** (file đang bị session kia sửa).
5. `CLAUDE.md` §7 "Đọc file": bỏ `docs/archive/*`.
6. **Research gọn:** đầu `docs/research/vocabulary.md` và `docs/research/review.md` thêm mục `## TL;DR — đã chốt` (≤ 30 dòng mỗi file): chỉ liệt quyết định còn hiệu lực + trỏ mục chi tiết (grep bảng "Đã chốt"/"Quyết định" trong file, đối chiếu `CLAUDE.md` §5). Không xoá phần khảo sát. `CLAUDE.md` §7: "research đọc TL;DR trước".
- Kiểm: `grep -rn 'docs/archive\|archive/' --include=*.md . | grep -v 'docs/journal\|ROADMAP'` chỉ còn dạng "(đã xoá, ADR-0xx)"; check-doc-links sạch.

### A5 — Lane test nhanh ReadoKit trên macOS

- `ReadoKit/Sources/ReadoKit/Capture/ImageCompressor.swift`: bọc toàn file trong `#if canImport(UIKit)` … `#endif`. Không đổi logic. Grep lại `UIImage|UIGraphics|UIKit` trong `ReadoKit/Sources`; thêm chỗ nào thì bọc tương tự. **Nếu phải đổi logic hay chỗ bọc > 3 file → dừng, báo fen.**
- `scripts/test.sh`: thêm action `kit`:
  ```bash
  scripts/test.sh kit            # build + test ReadoKit trên macOS, không simulator
  ```
  Chạy từ `app/ReadoKit`, `xcodebuild -scheme <scheme> -destination 'platform=macOS' test` cùng 3 cờ cache (`-derivedDataPath "$ROOT/DerivedData"`, `-clonedSourcePackagesDirPath "$ROOT/.xcode-packages"`, `TMPDIR`) + `-resultBundlePath "$ROOT/.tmp/results/kit.xcresult"`, log `/tmp/build-kit.log`, cùng bộ lọc grep + tóm tắt xcresult. Tên scheme: xem `xcodebuild -list` (guard cho phép `-list`) — thường `ReadoKit` hoặc `ReadoKit-Package`. Bỏ qua `pbxproj_tool check` + boot simulator cho action này.
  Mặc định `scripts/test.sh` (không tham số) **chưa** đổi ở A5.
- `.claude/hooks/guard.py`: không cần sửa (lệnh đi qua `scripts/test.sh`). Kiểm lại bằng cách chạy thật.
- `CLAUDE.md` §2: thêm dòng `scripts/test.sh kit`. Sửa comment `Package.swift` (`swift test` → `scripts/test.sh kit`).
- Kiểm: `scripts/test.sh kit` → `PrimitivesTests` xanh; `scripts/test.sh` full vẫn 256/258 (2 skip).

---

## Phase B — sau khi visual-polish-r1 khép

### B1 — pbxproj sang synchronized folders (objectVersion 77)

- **Bước fen làm tay trong Xcode (~5 phút)** — Sonnet hướng dẫn, không tự sửa pbxproj:
  1. Mở `app/Reado.xcodeproj`. Chuột phải group `Reado` → **Convert to Folder**. Lặp với `ReadoTests`.
  2. Project → File inspector → Project Format = **Xcode 16.0** (hoặc mới nhất). Đóng Xcode.
- Sonnet sau đó:
  - Kiểm pbxproj: `grep -c 'PBXFileSystemSynchronizedRootGroup'` = 2; `grep -c '\.swift \*/ = {isa = PBXFileReference'` = 0; `objectVersion = 77`; `XCSwiftPackageProductDependency`/local package ReadoKit + TOCropViewController vẫn còn.
  - `scripts/pbxproj_tool.py`: xoá `add`/`remove` và các hàm chỉ chúng dùng; viết lại `check` = kiểm 2 group `Reado`, `ReadoTests` là `PBXFileSystemSynchronizedRootGroup` và không còn `PBXFileReference` `.swift` rời (dấu hiệu ai đó thêm file kiểu cũ). Giữ `list` nếu còn ích. `scripts/test.sh` giữ gọi `check`.
  - `guard.py`: giữ chặn edit tay pbxproj, sửa message (bỏ gợi ý `add|remove`, thay "thêm file = tạo file trong thư mục, Xcode tự nhận").
  - Docs: `CLAUDE.md` §7 mục pbxproj (viết lại 3–4 dòng), bẫy build "objectVersion 60" → 77; `.claude/agents/reado-dev.md:18`; `docs/agent/coding-conventions.md:93,138`; `docs/agent/plan-template.md` nếu có bước `pbxproj_tool add`. ADR mới.
- Kiểm: tạo thử `app/ReadoTests/ZzSyncProbeTests.swift` (1 test `XCTAssertTrue(true)`), `scripts/test.sh test -only-testing:ReadoTests/ZzSyncProbeTests` chạy được 1 test → xoá file. Full `scripts/test.sh` = cùng tổng số như trước B1.

### B2 — Tổ chức `app/Reado/` theo feature (chỉ `git mv`)

```
app/Reado/
  App/       ReadoApp, RootView, ShellTabBar, AppModel(+ các file B4), NotificationScheduler
  Home/      OnboardingChecklistSection, StreakCalendarView, HomePinToggle
  Capture/   CaptureView, CameraController
  Analysis/  AnalysisView
  Review/    ReviewQueueView, SessionDoneView
  Library/   CollectionDetailView, ReadingSessionView, ImportView, ExportView
  Settings/  SettingsView
  Shared/    DesignSystem (từ visual-polish), Pronunciation
```
- Xoá `Screens/`. File mới do visual-polish thêm mà bảng trên chưa có → xếp theo màn dùng nó, ghi vào handoff.
- Cùng task: `git mv design-system docs/design-system`; sửa ref (`app/Reado/.../ReadoApp.swift` comment, `docs/plans/visual-polish-r1.md`, `docs/research/wellness-quiz-reference.md`, `docs/ux/visual-redesign-plan.md`, chính `MASTER.md`/`pages/*.md` nếu có path tuyệt đối, `CLAUDE.md` §3). Sửa comment Swift nhắc `ui-lab` → `ref/ui-lab`.
- `repo_map.py` / `CLAUDE.md` §7: kiểm vẫn chạy với cấu trúc mới.
- Kiểm: `scripts/test.sh` full cùng tổng số; `git log --follow` một file vẫn ra lịch sử.

### B3 — Tách 3 file view lớn (di chuyển thuần, ≤ ~400 dòng/file)

- `App/RootView.swift` → tách `HomeTabView` + `MasteryRing` → `Home/HomeTabView.swift`; `KhoTabView` → `Library/KhoTabView.swift`; `FloatShutter` + `ShutterPressStyle` → `App/FloatShutter.swift`. Giữ `AppTab`, `ShellRoute`, `RootView` ở chỗ cũ.
- `Analysis/AnalysisView.swift` → `ReviewCardRow` → `Analysis/ReviewCardRow.swift`; `SegmentBlock`, `VerificationBadge`, `AnalysisSkeleton` → `Analysis/AnalysisComponents.swift`.
- `Review/ReviewQueueView.swift` → `ScopePickerSheet` → `Review/ScopePickerSheet.swift`; `SwipeMotion`, `extension ReadoRating`, `private extension View` → `Review/ReviewQueueSupport.swift`. Nếu thân `ReviewQueueView` còn > 500 dòng: tách các `// MARK:` (Empty/Done, Card, Grade buttons) thành `extension ReviewQueueView` ở `ReviewQueueView+Card.swift`, `+Grade.swift`.
- Quy tắc: `private struct` → bỏ `private` (internal) khi sang file khác; `@State`/`private var` bị extension khác file cần → đổi thành internal, **không** đổi kiểu hay logic. Không đổi tên type.
- Kiểm: build + full test; `grep -c` số dòng mỗi file; so screenshot không cần (không đổi UI).

### B4 — Tách `AppModel` theo extension (không đổi API)

- Giữ `App/AppModel.swift`: khai báo class, **toàn bộ stored property**, `init`, `reloadOverview`, `CollectionOverview`, `ReviewError`, `GradeResult`, seed DEBUG.
- Di chuyển method theo `// MARK:` sẵn có sang `extension AppModel` (Swift cho phép extension khác file, chỉ không có stored property):
  - `App/AppModel+Analysis.swift` — FR-01 Capture, FR-02 Analysis, chốt phiên duyệt (`handleCapturedImage` … `prepareRecapture`)
  - `App/AppModel+Review.swift` — FR-11/12 ôn, `grade`, `undoReview`, `intervalLabels`, `learnMore`, `loadStreakHeatmap`, Ôn nhanh (`toggleReviewPriority`, `setReviewAll`)
  - `App/AppModel+Library.swift` — Overview, FR-08, FR-17 collection + Home pin, FR-20 CSV import
  - `App/AppModel+Settings.swift` — FR-15, `addAgent`, `syncReminderSchedule`, `matureKeysForCapture`
- `private` method/property bị file khác gọi → `internal` (ghi danh sách vào handoff). Không tạo sub-model `@Observable` mới (đổi injection = hợp đồng, để plan sau nếu cần).
- Kiểm: `AppModel.swift` ≤ ~250 dòng; build + full test cùng tổng số.

### B5 — Chuyển test logic thuần sang `ReadoKitTests` + khép

- Chọn test file chỉ `import XCTest` + `@testable import ReadoKit` (+ Foundation), không `UIKit`/`Vision`/`ImageIO`, không dùng `AppModel` hay type của target app. Loại sẵn: `CaptureFailureTests`, `LiveAIBoxTests`, `OCRProbeTests`, `ImageCompressorTests`, `PageOCRTests`. Kiểm từng file bằng grep.
- `TestSupport.swift`: helper nào các file chuyển đi cần → chép sang `app/ReadoKit/Tests/ReadoKitTests/TestSupport.swift` (bản ReadoTests giữ lại phần app còn dùng).
- `git mv` từng file. Nhờ B1 không cần đụng pbxproj; package test target tự nhận.
- `scripts/test.sh` mặc định (không tham số) = chạy `kit` rồi lane simulator, cộng tổng; exit ≠ 0 nếu lane nào đỏ. Giữ `test -only-testing:...` như cũ.
- **Tổng pass kit + simulator phải = tổng trước B5** (ghi hai con số trong handoff). Test nào hỏng trên macOS vì khác nền tảng → trả về `ReadoTests`, không sửa logic.
- Khép: `ROADMAP.md` pointer archive (dòng 5,15,88,241 → dạng ADR) + dòng tiến độ; `docs/session-brief.md` §1 (tooling: `kit` lane, synchronized folders, cấu trúc feature); `CLAUDE.md` §2/§7; chạy `/raudit`; đánh dấu plan khép.

---

## File then chốt

- Tooling: `scripts/test.sh`, `scripts/pbxproj_tool.py`, `.claude/hooks/guard.py`, `.gitignore`, `.env.example`
- Code: `app/ReadoKit/Sources/ReadoKit/Capture/ImageCompressor.swift`, `app/ReadoKit/Package.swift` (comment), `app/Reado/**` (B2–B4), `app/ReadoTests/**` → `app/ReadoKit/Tests/ReadoKitTests/` (B5)
- Docs: `CLAUDE.md`, `README.md`, `docs/decisions-log.md`, `docs/specs/journeys.md`, `docs/agent/{coding-conventions,agent-rulebook,prompt-spec}.md`, `docs/research/{tech-stack,review,vocabulary}.md`, `.claude/agents/reado-dev.md`, `.claude/commands/raudit.md`, `ROADMAP.md` (B5)

## Verification (mọi task)

1. `git status` đầu task: đúng Phase A/B điều kiện ở trên.
2. Task đụng code/tooling: `scripts/test.sh` full → ghi số pass/total/skip; phải bằng mốc trước (hiện 256/258, 2 skip; visual-polish có thể đổi mốc — lấy số trong `docs/session-brief.md` §1 lúc bắt đầu task). Từ A5: thêm `scripts/test.sh kit`.
3. Task đụng docs: `node scripts/verify/check-doc-links.mjs` sạch.
4. B1: probe file test tự nhận (xem B1). B2/B3/B4: không đổi hành vi → mở app simulator 1 lượt qua 3 tab + Ôn + Analysis (fen xem tay, ghi "UI chưa xem tay" nếu chưa).
5. Không chạy được simulator → không ghi "xong" (CLAUDE.md §7).
