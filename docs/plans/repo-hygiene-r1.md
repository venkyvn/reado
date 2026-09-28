# Plan: repo-hygiene-r1 — dọn repo, pbxproj đồng bộ thư mục, tách code UI, lane test nhanh

> Lưu thành `docs/plans/repo-hygiene-r1.md` ở bước đầu A1 (fen đã OK plan).
> Người implement: Sonnet, **mỗi task 1 session**, mở bằng `/rstart`, đóng bằng `/rhandoff`.
> CI: để sau, không nằm trong plan này.

## Trạng thái (cập nhật 2026-09-28)

**Phase A xong** (A1–A5, 5 commit `repo-hygiene-r1`, ADR-044). **Phase B: B1+B2+B3 đã có plan chi tiết bên dưới (điều kiện `app/` sạch đã đạt 2026-09-28: `2ffe8ee`, `03267f5`); B4/B5 hoãn.** **B1 xong 2026-09-28 (ADR-046)** — lệch plan: Xcode ghi objectVersion **70** (không phải 77), `check` chấp nhận ≥ 70; phải gỡ 2 file path nhiều cấp + reference trùng `OCRProbeTests.swift` trước khi Convert; full test 263/265 bằng mốc. **B2+B3 xong 2026-09-28** (`ea46f05` + commit tách file): `app/Reado` chia 8 thư mục feature, `RootView` 626→204, `AnalysisView` 647→400, `ReviewQueueView` 894→309 dòng; full test 263/265 bằng mốc; diff chỉ còn di chuyển + bỏ `private` (kiểm bằng so tập dòng +/-). **Phase B khép** (B4/B5 hoãn). Fen đã xem tay UI 2026-09-28 (app chạy đúng như trước).

Lệch so với plan ban đầu:
- **A1:** `.env` đã có sẵn (cùng key với `.env.example`, so bằng hash) nên không gộp; `.env.example` mới lấy biến từ `proxy/main.py` + biến dev (`READO_*`) thay vì biến Phase 0. `ref/sample/page-37` là file text → giữ track.
- **A2:** `.keep.json` (nội dung `{}`, không ai dùng) giữ nguyên — chờ owner.
- **A4:** ADR là **044** (043 dành cho visual-polish). 4 dòng link archive trong `ROADMAP.md` đã sửa luôn (stage riêng đúng 4 hunk, hunk của session kia không bị kéo vào) thay vì để B5; các dòng lịch sử khác trong ROADMAP còn nhắc archive dạng chữ thường — B5 dọn nốt.
- **A5:** ngoài `ImageCompressor` còn phải sửa `PageOCR.swift` (availability `macOS 26.0`, 2 dòng, không đổi hành vi iOS). Lane `kit` = 4/4; full iOS = 256/258 (2 skip), bằng mốc trước.
- Tiện thể: `docs/research/{vocabulary,review}.md` có mục **TL;DR** đầu file.

Chờ owner: `docs/sample.md` (untracked, không rõ chủ), `.keep.json`, repo `venkyvn/reado` public hay private (ảnh `ref/sample` vẫn nằm trong history cũ).

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

## Phase B — chi tiết (chốt 2026-09-28)

> **Phạm vi:** chỉ **B1** (Session 1) và **B2+B3** (Session 2). **B4** (tách `AppModel`) và **B5** (chuyển test sang `ReadoKitTests`) **hoãn** — làm khi thấy vướng (thêm FR mới / hai task cùng sửa `AppModel`; hoặc chờ `scripts/test.sh` thành nút thắt hằng ngày). Đo: 258 test chỉ ~8s, phần chậm là build + boot simulator.
> **Bỏ khỏi scope:** chuyển `design-system/` → `docs/design-system/` (không ai cần; còn phải sửa luật FROZEN trong `check-doc-links.mjs`).
> Mỗi session 1 lượt `/rstart` … `/rhandoff`. Fen làm bước Xcode ở S1.1.

## Điều kiện tiên quyết (cả hai session, kiểm TRƯỚC khi làm gì khác)

1. `git status --porcelain app/` không được còn thay đổi code thật. **Đã kiểm 2026-09-28:** visual-polish-r1 đã commit (`2ffe8ee`, ADR-045) và cram Phiên A đã commit (`03267f5`, ADR-043). `app/` chỉ còn `project.pbxproj` bị xcodebuild re-sort (nhiễu, không phải thay đổi thật; Xcode convert ở S1.1 sẽ ghi đè). Ngoài `app/` còn `ROADMAP.md`, `docs/plans/ux-polish-r1.md`, `docs/session-brief.md` sửa dở của session trước: **không** kéo vào commit của B1/B2/B3, dùng `git add -p` (xem memory git-add-p-split-commits) hoặc chỉ `git add` file mình sửa.
2. `docs/plans/visual-polish-r1.md`: code đã commit, plan còn "mở" chỉ vì chờ fen xem tay UI. Không chặn B1/B2/B3 (chỉ di chuyển file). Cram Phiên B (header collection) chưa làm, sẽ sửa `CollectionDetailView`; nếu làm sau B2 thì file đã ở `Library/`, git theo rename được.
3. Ghi lại mốc test: lấy số pass/total/skip trong `docs/session-brief.md` §1 (hiện là 263/265, 2 skip). Mọi bước kiểm đều so với mốc này.

---

# SESSION 1 — B1: pbxproj sang synchronized folders

## S1.0 Cập nhật plan trong repo
- **Đã xong (2026-09-28):** phần Phase B trong file này chính là bản chi tiết. Không cần làm gì thêm ở bước này.

## S1.1 Bước fen làm tay trong Xcode (~5 phút). Sonnet in hướng dẫn này ra rồi DỪNG chờ fen

Sonnet in đúng khối sau cho fen, rồi chờ fen báo "xong":

```
1. Đóng mọi Xcode đang mở. Mở app/Reado.xcodeproj.
2. Project navigator: chuột phải group "Reado" → Convert to Folder → Convert.
   - Nếu Xcode từ chối (thường do OCRProbeTests.swift bị tham chiếu 2 lần):
     mở group ReadoTests, chọn MỘT trong hai dòng OCRProbeTests.swift → Delete →
     "Remove Reference" (KHÔNG Move to Trash), rồi thử lại.
3. Lặp lại với group "ReadoTests".
4. Bấm vào project "Reado" (dòng trên cùng) → File inspector (⌥⌘1) →
   Project Format = "Xcode 16.0" (hoặc mới hơn).
5. ⌘B một lần cho chắc (không bắt buộc). Đóng Xcode.
```

Sonnet **không** mở Xcode, **không** sửa pbxproj bằng script hay sed. Hook `guard.py` sẽ chặn Edit/Write, nhưng sed/python ghi thẳng vào pbxproj cũng bị cấm.

## S1.2 Kiểm pbxproj sau khi fen convert (chỉ grep, không Read nguyên file)

```bash
P=app/Reado.xcodeproj/project.pbxproj
grep -n "objectVersion" $P                                   # ≥ 77
grep -c "isa = PBXFileSystemSynchronizedRootGroup" $P        # = 2
grep -n  "fileSystemSynchronizedGroups" $P                   # xuất hiện ở cả 2 target
grep -c "sourcecode.swift" $P                                # = 0 (không còn fileRef .swift rời)
grep -c "in Sources \*/ = {isa = PBXBuildFile" $P            # = 0
grep -c "PBXFileSystemSynchronizedBuildFileExceptionSet" $P  # = 0 (có >0 thì xem S1.3 mục exception)
grep -n "XCLocalSwiftPackageReference \"ReadoKit\"\|TOCropViewController\|XCSwiftPackageProductDependency" $P | head   # vẫn còn
grep -n "DEVELOPMENT_TEAM\|PRODUCT_BUNDLE_IDENTIFIER\|INFOPLIST_KEY_NSCamera" $P    # build settings giữ nguyên
git diff --stat $P
```
Có số nào lệch thì dừng, báo fen kèm output, không tự sửa.

## S1.3 Viết lại `scripts/pbxproj_tool.py` (bỏ add/remove, `check` kiểu mới)

Viết lại cả file cho gọn (~120 dòng). Giữ docstring tiếng Việt kiểu cũ và quy ước chạy từ gốc repo (`Path.cwd()`).

- **Giữ:** `find_pbxproj`, `read_pbxproj`, argparse với `--pbxproj`.
- **Xoá:** `add`, `remove`, toàn bộ helper chỉ chúng dùng (`next_id`, `existing_hex_ids`, `group_hex_for`, `get_group_id`, `add_to_children`, `add_build_file`, `add_file_reference`, `_file_ref_type`, `add_to_sources_build_phase`, `remove_file_from_content`, `write_pbxproj`). Nếu có ai gọi `add`/`remove` thì argparse báo lỗi choices. Thêm dòng in: "Không cần nữa: tạo file trong app/Reado hoặc app/ReadoTests là Xcode tự nhận (synchronized folders, ADR-0xx)."
- **Actions:** `check` (mặc định) và `list`.
- **`check_project(pbxproj) -> int`**, mỗi điều kiện hỏng in một dòng `LỖI: …`, trả 1 nếu có lỗi:
  1. `objectVersion = (\d+);` phải ≥ 77.
  2. Tìm mọi block `isa = PBXFileSystemSynchronizedRootGroup;` và lấy `path = X;`. Tập path phải chứa `Reado` và `ReadoTests`.
  3. Mỗi PBXNativeTarget `Reado` / `ReadoTests` có `fileSystemSynchronizedGroups = ( <id> … )`, và id đó trỏ đúng root group có path trùng tên target. Parse block target bằng regex `(\w{24}) /\* (Reado|ReadoTests) \*/ = \{\s*isa = PBXNativeTarget;(.*?)\n\t\t\};` với cờ `re.S`.
  4. Không còn dòng `lastKnownFileType = sourcecode.swift` và không còn `in Sources */ = {isa = PBXBuildFile`. Gặp thì in "file Swift thêm kiểu cũ (group thường) — xoá reference trong Xcode, để thư mục tự nhận".
  5. **Exception set:** nếu có `PBXFileSystemSynchronizedBuildFileExceptionSet`, in các file nằm trong `membershipExceptions = ( … );`, kèm cảnh báo "file này bị LOẠI khỏi target, dễ thành skip ngầm". Coi đây là lỗi (exit 1). Hiện Reado không cần exception nào.
  6. Nếu đạt hết: `OK: synchronized folders Reado + ReadoTests (objectVersion N), K file Swift đang track sẽ được Xcode tự nhận`, trong đó K = số dòng từ `git ls-files app/Reado app/ReadoTests` có đuôi `.swift`.
- **`list`:** in objectVersion, các root group đồng bộ (id, path), target nào gắn với group nào, và số exception set.
- Tự kiểm tool: `python3 scripts/pbxproj_tool.py check` phải ra OK. Kiểm thêm nhánh lỗi: `cp $P "$SCRATCH/p.pbxproj"`, dùng `sed` sửa **bản copy** (vd `objectVersion = 60`), chạy `python3 scripts/pbxproj_tool.py check --pbxproj "$SCRATCH/p.pbxproj"` → phải ra `LỖI` và exit 1. Không bao giờ sed file thật.

## S1.4 `scripts/test.sh`
- Chỉ sửa comment dòng 62–63 thành: `# Tiền kiểm: pbxproj phải là synchronized folders (objectVersion ≥77, không exception set, không fileRef .swift kiểu cũ) — CLAUDE.md §7.` Lệnh `(cd "$ROOT" && python3 scripts/pbxproj_tool.py check)` giữ nguyên.

## S1.5 `.claude/hooks/guard.py`
- Vẫn chặn Edit/Write/MultiEdit vào `project.pbxproj`. Đổi message thành:
  `"Cấm edit tay project.pbxproj. Thêm/xoá file Swift = tạo/xoá file trong app/Reado hoặc app/ReadoTests (synchronized folders, Xcode tự nhận). Đổi cấu hình project → nhờ fen làm trong Xcode (CLAUDE.md §7)."`
- Thêm một chặn Bash: lệnh có `project.pbxproj` đi kèm `sed -i`, `perl -i`, `>`/`>>` redirect, hoặc `python3 -c` có `write` thì chặn, dùng cùng message. Regex gợi ý: `re.search(r"project\.pbxproj", cmd) and re.search(r"sed\s+-i|perl\s+-[a-z]*i|>\s*\S*project\.pbxproj|\.write", cmd)`. Không chặn `grep`/`git diff`/`git add` trên pbxproj.
- Kiểm hook bằng stdin giả:
  ```bash
  echo '{"tool_name":"Edit","tool_input":{"file_path":"app/Reado.xcodeproj/project.pbxproj"}}' | python3 .claude/hooks/guard.py; echo $?   # 2
  echo '{"tool_name":"Bash","tool_input":{"command":"sed -i \"\" s/a/b/ app/Reado.xcodeproj/project.pbxproj"}}' | python3 .claude/hooks/guard.py; echo $?  # 2
  echo '{"tool_name":"Bash","tool_input":{"command":"grep -c objectVersion app/Reado.xcodeproj/project.pbxproj"}}' | python3 .claude/hooks/guard.py; echo $?  # 0
  ```

## S1.6 `.claude/settings.json`
- Xoá 2 dòng allow `pbxproj_tool.py add *` và `remove *`. Giữ `check` và `list`.

## S1.7 Probe: chứng minh Xcode tự nhận file mới
1. **Target test:** tạo `app/ReadoTests/ZzSyncProbeTests.swift`:
   ```swift
   import XCTest
   final class ZzSyncProbeTests: XCTestCase {
       func testSynchronizedFolderPicksUpNewFile() { XCTAssertTrue(true) }
   }
   ```
   Chạy `scripts/test.sh test -only-testing:ReadoTests/ZzSyncProbeTests` → phải ra `RESULT: … passed 1/1`. Nếu ra 0/0 thì file bị skip và B1 **hỏng**: dừng, báo fen.
2. **Target app (probe âm):** tạo `app/Reado/ZzSyncProbe.swift` có `let zzSyncProbe: Int = "not an int"`. Chạy `scripts/test.sh build` → **phải FAIL**, và `grep ZzSyncProbe /tmp/build.log` ra lỗi type ở đúng file đó (chứng minh file được compile). Build pass nghĩa là file không được compile: dừng, báo fen.
3. **Thư mục con:** tạo `app/Reado/Zz/ZzNested.swift` có lỗi type y như trên, `scripts/test.sh build` phải FAIL ở file đó. Bước này chứng minh B2 dùng thư mục con được.
4. Xoá cả 3 file probe (`rm`, và `rmdir app/Reado/Zz`). `git status app/` chỉ còn diff pbxproj.
5. Full `scripts/test.sh` → pass/total/skip **bằng mốc**. Ghi số vào handoff.
   - Nếu lỗi lạ kiểu "Build input file cannot be found" hoặc stale: `rm -rf DerivedData/Build DerivedData/Index.noindex` rồi chạy lại một lần. Vẫn lỗi thì báo fen.
   - Tổng số test phải **bằng** mốc. Hết trùng OCRProbeTests không làm đổi số vì XCTest đếm theo class.

## S1.8 Docs
- `CLAUDE.md` §7, mục **pbxproj**: thay 3 bullet (Thêm/Gỡ/Kiểm) bằng:
  - `project.pbxproj` dùng synchronized folders (objectVersion 77, ADR-0xx): muốn thêm/xoá/di chuyển file Swift thì chỉ cần tạo/xoá/`git mv` trong `app/Reado/**` hoặc `app/ReadoTests/**`, không đụng pbxproj.
  - Cấm edit tay pbxproj (hook chặn). Đổi target, build setting hay package thì fen làm trong Xcode.
  - `python3 scripts/pbxproj_tool.py check`: kiểm vẫn là synchronized folders, không có exception set, không có fileRef `.swift` kiểu cũ. `scripts/test.sh` tự chạy cổng này.
  - Bẫy: file nằm trong thư mục là được compile, **kể cả file chưa track git**, nên file nháp phải để ngoài `app/`.
  - Giữ dòng "Chạy xcodebuild tự re-sort pbxproj → trước commit chỉ giữ hunk thật".
- `CLAUDE.md` §7 **Bẫy build**: đổi `viết tay objectVersion 60` thành `objectVersion 77 (synchronized folders)`.
- `.claude/agents/reado-dev.md:18`: đổi thành "Thêm file Swift: tạo file trong thư mục là xong (synchronized folders, CLAUDE.md §7)".
- `docs/agent/coding-conventions.md`:
  - dòng 21: `Reado.xcodeproj — project Xcode (objectVersion 77, synchronized folders; xem bẫy mục 9)`.
  - dòng ~91–93 ("Test file mới PHẢI có đủ 4 dòng…"): viết lại thành "Test file mới chỉ cần tạo trong `app/ReadoTests/`, sau đó tin cột `Executed N tests` / `RESULT` của `scripts/test.sh`."
  - dòng 138–140 (bẫy pbxproj viết tay): đổi thành "pbxproj objectVersion 77 synchronized folders (ADR-0xx); local package vẫn là `XCSwiftPackageProductDependency`; scheme share ở `xcshareddata/xcschemes/`."
- Grep lần cuối `grep -rn "pbxproj_tool.py add\|pbxproj_tool.py remove\|4 tham chiếu\|4 dấu vết\|objectVersion 60" CLAUDE.md README.md docs/agent docs/specs .claude scripts`. Kết quả phải rỗng, trừ `docs/journal/`, `docs/plans/repo-hygiene-r1.md` và các dòng ADR lịch sử.
- **ADR mới** trong `docs/decisions-log.md` (số = `grep "^## ADR-" docs/decisions-log.md | tail -1` + 1), ≤ 12 dòng: bối cảnh (4 dấu vết, skip ngầm, OCRProbeTests bị trùng), quyết định (synchronized folders, objectVersion 77, fen convert bằng Xcode), hệ quả (`pbxproj_tool` chỉ còn `check`/`list`; cấm exception set; file trong thư mục là compile).
- `node scripts/verify/check-doc-links.mjs` phải sạch.

## S1.9 Đóng
- `/rhandoff`. Commit gồm pbxproj + `scripts/pbxproj_tool.py` + `scripts/test.sh` + `.claude/hooks/guard.py` + `.claude/settings.json` + docs. `git add` theo đường dẫn cụ thể và xem `git diff --cached --stat` trước khi commit. Message gợi ý: `chore(xcode): B1 repo-hygiene-r1 — pbxproj sang synchronized folders (ADR-0xx)`.
- Handoff ghi: số test so với mốc, output `pbxproj_tool.py check`, kết quả 3 probe.

---

# SESSION 2 — B2 + B3: chia thư mục theo feature và tách 3 view lớn

Điều kiện: B1 đã commit, `python3 scripts/pbxproj_tool.py check` ra OK, `git status --porcelain app/` rỗng.
Nguyên tắc: **refactor thuần**. Không đổi tên type, không đổi logic, không đổi UI. Chỉ di chuyển code và bỏ `private` ở chỗ nào bắt buộc. Làm hai commit: B2 (chỉ `git mv`) rồi B3 (tách file), để `git log --follow` vẫn chạy được.

## S2.1 — B2: `git mv` sang thư mục feature (commit 1)

Cấu trúc đích (thư mục `Capture/` đã có sẵn; `Screens/` sẽ bị xoá):

| Thư mục | File (`git mv` từ `app/Reado/`) |
|---|---|
| `App/` | `ReadoApp.swift`, `RootView.swift`, `ShellTabBar.swift`, `AppModel.swift`, `NotificationScheduler.swift` |
| `Home/` | `OnboardingChecklistSection.swift`, `StreakCalendarView.swift`, `HomePinToggle.swift` |
| `Capture/` | `Capture/CaptureView.swift` (giữ nguyên), `CameraController.swift` |
| `Analysis/` | `AnalysisView.swift` |
| `Review/` | `Screens/ReviewQueueView.swift`, `SessionDoneView.swift` |
| `Library/` | `CollectionDetailView.swift`, `ReadingSessionView.swift`, `ImportView.swift`, `ExportView.swift` |
| `Settings/` | `SettingsView.swift` |
| `Shared/` | `DesignSystem.swift`, `Pronunciation.swift` |

- Chạy `mkdir -p` cho các thư mục trên, rồi `git mv` từng file. Sau đó `rmdir app/Reado/Screens`.
- Nếu `ls app/Reado/*.swift` còn file nào không có trong bảng (vd file visual-polish hay cram thêm sau khi viết plan) → xếp vào thư mục của màn dùng nó (`grep -rln "<TypeName>" app/Reado`), ghi vào handoff.
- `app/ReadoTests/` giữ phẳng, không đụng.
- Kiểm:
  - `ls app/Reado/*.swift 2>/dev/null` rỗng (gốc không còn file Swift).
  - `python3 scripts/pbxproj_tool.py check` ra OK, và `git diff --stat app/Reado.xcodeproj` **rỗng** (synchronized folder không ghi path file vào pbxproj). Nếu pbxproj đổi thì dừng, báo fen.
  - `scripts/test.sh` full phải bằng mốc.
  - `git log --follow --oneline app/Reado/Review/ReviewQueueView.swift | head -3` phải ra lịch sử cũ.
- Docs cho B2:
  - `docs/agent/coding-conventions.md` §2: dưới dòng `Reado/` thêm cây con 8 thư mục, mỗi thư mục 1 dòng mô tả (App = shell + AppModel; Home; Capture; Analysis; Review; Library = Kho + collection + import/export; Settings; Shared = DesignSystem + tiện ích dùng chung).
  - Grep đường dẫn cũ trong docs **đang dùng**: `grep -rn "app/Reado/[A-Za-z]*\.swift\|Screens/ReviewQueueView\|Capture/CaptureView" CLAUDE.md README.md docs/agent docs/specs docs/session-brief.md .claude scripts`. Sửa sang path mới. **Không** sửa `docs/journal/`, không sửa ADR cũ, không sửa plan đã khép.
  - `python3 scripts/repo_map.py --root app/Reado --limit 40` phải chạy được với cấu trúc mới (script quét đệ quy, có lỗi thì sửa script).
- Commit 1: `refactor(app): B2 repo-hygiene-r1 — chia app/Reado theo feature (git mv thuần)`. Chỉ gồm các rename + docs vừa sửa. Kiểm `git diff --cached -M --stat`: mọi file Swift phải hiện là rename 100%.

## S2.2 — B3: tách 3 file lớn (commit 2)

**Quy tắc chung (Sonnet làm đúng theo thứ tự này cho mỗi file):**
1. Cắt nguyên khối code (kể cả doc comment `///` và `// MARK:` ngay trên nó) sang file mới. Không sửa nội dung bên trong.
2. File mới có đúng các `import` mà file gốc đang có (`SwiftUI`, `ReadoKit`, … chép theo đầu file gốc), và thêm một dòng comment đầu file: `// Tách từ <File gốc>.swift (repo-hygiene-r1 B3).`
3. Type top-level `private struct/enum/func` được chuyển sang file khác mà file gốc còn dùng → bỏ `private` (thành internal). Type chỉ dùng trong file mới thì **giữ `private`**.
4. Trước khi bỏ `private` của một type: `grep -rn "struct <Tên>\b\|enum <Tên>\b\|func <tên>(" app/Reado`. Chỉ được ra đúng 1 kết quả, trùng tên thì dừng, báo fen.
5. Sau mỗi file: `scripts/test.sh build`. Gặp lỗi `'X' is inaccessible due to 'private' protection level` thì bỏ `private` đúng ở khai báo `X` rồi build lại. Lỗi khác kiểu này thì dừng, báo fen.
6. Mục tiêu mỗi file ≤ ~400 dòng (`wc -l`). Không cần đạt con số tuyệt đối.

### B3a — `App/RootView.swift` (626 → ~210)
| Khối (dòng hiện tại, xác nhận lại bằng grep) | File đích | Visibility |
|---|---|---|
| `private enum ShellRoute` (40) | **ở lại** `App/RootView.swift` | bỏ `private` (Home/Kho dùng `ShellRoute.hub`, `.streak`) |
| `private struct FloatShutter` + `private struct ShutterPressStyle` (208–251) | `App/FloatShutter.swift` | `FloatShutter` internal, `ShutterPressStyle` giữ `private` nếu chỉ FloatShutter dùng |
| `private struct HomeTabView` (252–439) | `Home/HomeTabView.swift` | internal |
| `private func masteryLabel` + `private struct MasteryRing` (440–466) | `Shared/MasteryRing.swift` (Home và Kho cùng dùng) | internal cả hai |
| `private struct KhoTabView` (467–626) | `Library/KhoTabView.swift` | internal |
`AppTab`, `ShellRoute`, `RootView` ở lại `App/RootView.swift`.

### B3b — `Analysis/AnalysisView.swift` (647 → ~400)
| Khối | File đích | Visibility |
|---|---|---|
| `// MARK: - Card duyệt (ADR-008)` + `private struct ReviewCardRow` (402–563) | `Analysis/ReviewCardRow.swift` | internal |
| `private struct SegmentBlock`, `VerificationBadge`, `AnalysisSkeleton` (564–647) | `Analysis/AnalysisComponents.swift` | internal những struct `AnalysisView`/`ReviewCardRow` dùng. `VerificationBadge` có thể chỉ `ReviewCardRow` dùng, nhưng vẫn để internal vì hai file khác nhau |
`private enum SaveAlert` lồng trong `AnalysisView` thì giữ nguyên.

### B3c — `Review/ReviewQueueView.swift` (894 → ~320)
| Khối | File đích | Visibility |
|---|---|---|
| `private struct ScopePickerSheet` (754–838) | `Review/ScopePickerSheet.swift` | internal |
| `extension ReadoRating { label, buttonBackground, buttonForeground }` (865–894) | `Review/ReadoRating+Display.swift` | đã internal, không đổi |
| `// MARK: — Card` (277–556: `cardView`, `refreshIntervals`, `flipCard`, `faceStack`, `swipeGesture`, `swipeProgress`, `dragAngle`, `swipeStamp`, `stampText`, `badgeLabel`, `commitSwipe`, `snapBack`, `cardFace`, `backFaceContent`) | `Review/ReviewQueueView+Card.swift` bọc trong `extension ReviewQueueView { … }` | bỏ `private` ở member mà file khác gọi (vd `cardView` được `body` gọi). Member chỉ dùng trong file này thì giữ `private` |
| `private extension View { frontGradeActions }` (839–856) + `private enum SwipeMotion` (857–863) | cũng đưa vào `ReviewQueueView+Card.swift` (chỉ khối Card dùng) | giữ `private` (cùng file với chỗ dùng). Nếu grep thấy khối Grade cũng dùng thì bỏ `private` |
| `// MARK: — Grade buttons` (557–717: `gradeButtons`, `gradeButton`, `performGrade`, `gradeNow`, `showMasteredToast(term:)`, `performUndo`) | `Review/ReviewQueueView+Grade.swift`, `extension ReviewQueueView { … }` | như trên |
| Stored property, `init`, `body`, `// MARK: — Empty / Done` (142–276), `loadQueue` (718–753) | **ở lại** `Review/ReviewQueueView.swift` | — |

Riêng B3c: extension nằm ở file khác thì **không đọc được `@State private var`**. Mọi `@State private var` / `private var` / `private let` (vd `items`, `currentIndex`, `flipDegrees`, `dragOffset`, `isCommitting`, `didPassThreshold`, `isFlipped`, `lastLogID`, `lastSnapshot`, `undoSnapshot`, `showUndoToast`, `tally`, `showMasteredToast`, `masteredToastTerm`, `masteredToastTask`, `mode`, `intervalLabels`, `model`, `reduceMotion`, `dynamicTypeSize`, `showsCloseButton`) mà file `+Card`/`+Grade` dùng thì bỏ `private` (`@State private var x` → `@State var x`; `@Environment(...) private var model` → `@Environment(...) var model`). Không đổi kiểu, không đổi giá trị khởi tạo. Để compiler chỉ ra từng biến theo quy tắc 5, **không** bỏ `private` hàng loạt trước khi build.
- `showMasteredToast` vừa là `@State var` vừa là tên hàm `showMasteredToast(term:)`. Swift hiện đang chấp nhận vì khác chữ ký. Giữ nguyên, không đổi tên.

### Kiểm B3
- `wc -l app/Reado/*/*.swift | sort -n | tail -8`: ba file gốc ≤ ~420. Ghi bảng trước/sau vào handoff.
- `python3 scripts/pbxproj_tool.py check` ra OK, `git diff --stat app/Reado.xcodeproj` rỗng.
- `scripts/test.sh` full phải bằng mốc.
- Kiểm không đổi logic (đơn giản, đọc bằng mắt):
  1. `git diff HEAD --stat -- app/Reado` cho số dòng thêm ≈ số dòng xoá (chênh chỉ do `import`, `extension … {`/`}` và comment header `Tách từ`).
  2. Xem dòng `+` không nằm trong khối được chuyển: `git diff HEAD -U0 -- app/Reado | grep '^+' | grep -v '^+++'`. Mỗi dòng phải là 1 trong: `import`, comment `Tách từ`, `extension ReviewQueueView {`, `}` đóng extension, dòng trống, hoặc 1 dòng khai báo vừa bỏ `private`. Thấy dòng `+` nào khác (đổi logic, đổi tên) thì dừng, báo fen.
- UI: fen xem tay trên simulator một lượt (Home, Kho, Ôn có vuốt, lật thẻ, chấm, undo, đổi phạm vi, Analysis). Fen chưa xem thì handoff ghi "UI chưa xem tay". Agent **không** ghi "xong UI".
- Docs B3: `docs/agent/coding-conventions.md` §2 bổ sung 1 dòng: "View > ~400 dòng thì tách subview/extension theo `// MARK:` (ví dụ `ReviewQueueView+Card.swift`)".
- Commit 2: `refactor(app): B3 repo-hygiene-r1 — tách RootView/AnalysisView/ReviewQueueView (di chuyển thuần)`.

## S2.3 Đóng Phase B
- `docs/plans/repo-hygiene-r1.md`: ghi B1–B3 xong, B4/B5 hoãn, plan **khép** (phần còn lại của B5, tức dọn pointer archive trong ROADMAP, làm gộp luôn ở bước này: trong `ROADMAP.md` chạy `grep -n 'archive' ROADMAP.md`, chỉ sửa các dòng còn là **link/pointer sống** tới `docs/archive/` (tình trạng, bảng task 0.6/1.2) sang dạng "(đã xoá, ADR-044)"; dòng nhật ký lịch sử (bảng ngày 2026-09-18) giữ nguyên. Số dòng có thể đã lệch, không tin số cũ).
- `docs/session-brief.md` §1 mục Repo: cấu trúc feature + synchronized folders. `/raudit` nhanh, rồi `/rhandoff`.

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
