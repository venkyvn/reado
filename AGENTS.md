# AGENTS.md — Reado (protocol Claude Code)

Luật dự án: đọc `CLAUDE.md`. Khi đụng điều khoản cụ thể, mở `docs/agent/agent-rulebook.md` (index → grep đúng spec). File này **không** nhân đôi luật cứng.

## 0. Cache prefix — thứ tự bất biến

Claude Code cache theo prefix. Phá thứ tự = miss cache.

1. `CLAUDE.md` (tự load) — chỉ luật, mục lục docs, quickstart. **Cấm** nhét ROADMAP, journal, HEAD, số test, output `repo_map`.
2. File này — protocol ổn định.
3. Turn 1: `docs/session-brief.md` §1–3 (state đổi mỗi session — **sau** breakpoint, không nhét vào CLAUDE.md).

Cấm đảo thứ tự đọc Turn 1. Cấm sửa `CLAUDE.md` trừ khi luật/Q đổi. Commands (`.claude/commands/*`) chỉ load khi gọi — **không copy** bảng luật cứng.

Turn 2: cấm đọc lại file đã có trong ngữ cảnh. `repo_map.py` không chạy lại trừ khi fen bảo refresh.

## 1. Session protocol

- **Turn 1 — session mới:** `CLAUDE.md` đã ở prefix. Đọc `docs/session-brief.md` mục 1–3. Chạy `python3 scripts/repo_map.py` (stdout). Câu đang mở chỉ ở `CLAUDE.md` mục 5. Gợi `/rplan` nếu fen đã nêu task — **đừng code**. Template plan: `docs/agent/plan-template.md`.
- **Từ Turn 2:** CẤM đọc lại `session-brief.md` hay bất kỳ file đã có trong ngữ cảnh.
- **Không tự đọc lại file vừa sửa:** Nội dung vừa ghi đã nằm sẵn trong context. Cấm `read` để xác nhận lại.
- **Khi nào được `write` ngay:** (a) fen nói rõ code / sửa bug **và** (b) không đổi hợp đồng (schema, FR mới, transaction, protocol module, Q mở). Ngược lại: `/rplan` hoặc hỏi fen. Skip plan (ghi 1 câu rồi code): bug thuần UI, copy, test bổ sung khi FR/journey đã chốt — fen vẫn có thể bắt plan trước.
- **Sau khi làm xong task lớn:** Chốt session (xem mục 3).

## 2. File discovery & reading — chống đốt token

### 2a. Cấm quét cache

Khi dùng `find`, `grep`, `ls`, hoặc tool `glob`, **luôn loại trừ**:
```
DerivedData/ .tmp/ .xcode-packages/ .build/ .swiftpm/ node_modules/ .git/
```
- `glob **/*.swift` bắt buộc filter kết quả: bỏ mọi path chứa `.tmp/` / `DerivedData/` / `.xcode-packages/` trước khi `read`.
- Shell `find` chuẩn:
  ```bash
  find app -name "*.swift" -not -path "*/DerivedData/*" -not -path "*/.tmp/*" -not -path "*/.xcode-packages/*" -not -path "*/.build/*" -not -path "*/.swiftpm/*"
  ```

### 2b. Đọc có chọn lọc (Targeted Reading)

- **Cấm** `read` cả file lớn khi chỉ cần 1 FR/1 hàm: dùng `grep -n "từ_khoá" <file>` rồi `read` có `offset`/`limit` (80 dòng).
- **CẤM read nguyên** các file ≥25KB sau (chỉ grep + read quanh trúng): `ROADMAP.md` · `docs/archive/mvp-plan-pwa-gen.md` · `docs/research/vocabulary.md` · `docs/research/review.md` · `docs/specs/prd.md` · `docs/specs/journeys.md` · `docs/archive/*-pwa-gen.md` (tombs) · `docs/decisions-log.md` · `docs/research/tech-stack.md` · `docs/agent/prompt-spec.md` · `docs/specs/sync-server-ddl.md` · `docs/specs/db.md` · `docs/specs/solution-design.md`.
- Một turn không `read` quá 3 file lớn cùng lúc. Thiếu gì → `grep` tiếp, không `read` dự phòng.
- **KHÔNG `read` lại file vừa sửa** (nội dung vừa ghi đã nằm sẵn trong context). Verify bằng `grep -c "tên file" project.pbxproj` chứ không read.

### 2c. pbxproj — CẤM edit tay (tool bắt buộc)

`project.pbxproj` (~37KB) — **cấm** read nguyên + edit tay. Dùng `scripts/pbxproj_tool.py`:

```bash
# Thêm file (tự tạo PBXFileRef + PBXBuildFile + build phase + children)
python3 scripts/pbxproj_tool.py add --file app/Reado/SettingsView.swift --group Reado --target Reado

# Thêm test file
python3 scripts/pbxproj_tool.py add --file app/ReadoTests/SettingsTests.swift --group ReadoTests --target ReadoTests

# Gỡ file: KHÔNG gọi `remove`. Lệnh đó hỏng (hàm `remove_file` high-level shadow
# bản low-level → TypeError). Sửa tay đủ 4 dòng pbxproj rồi grep-verify, hoặc sửa tool trước.
# Chi tiết: docs/session-brief.md mục 3.

# Verify sau khi thêm — CHỈ grep 3 dòng, KHÔNG read lại:
grep -c "SettingsView" app/Reado.xcodeproj/project.pbxproj   # mong đợi ≥ 3
```

### 2d. repo_map — tree + interface (bắt buộc cho Swift)

Cần bản đồ code / public surface — **cấm** `glob **/*.swift` trần. Stdout only (không ghi file vào docs — bust cache):

```bash
python3 scripts/repo_map.py              # tree + signatures, mặc định --limit 80
python3 scripts/repo_map.py --root app/ReadoKit/Sources --limit 40
```

Skeleton tĩnh (ít đổi) vẫn ở `docs/agent/coding-conventions.md` §2 và `docs/specs/solution-design.md` §3.

### 2e. smart_glob — md / path không phải Swift tree

Khi cần danh sách file/dir **không** phải Swift map — cấm `glob **/*.md` trần. Dùng `scripts/smart_glob.py`:

```bash
python3 scripts/smart_glob.py --ext .md --limit 15
grep -rn "FR-16" docs/specs/prd.md | head -n 20
```

## 3. Session hygiene — chống phình context

### 3a. Flow chốt task (bắt buộc)

Task lớn xong → `/rhandoff` (AGENTS.md không lặp checklist). Một câu hỏi approve; sau approve: brief §1, journal, ROADMAP nếu cần, khép `docs/plans/<id>.md` nếu có, rồi commit.

### 3b. Giới hạn chống phình (bắt buộc)

- **1 task = 1 session.** Cấm gộp `2.4 + 2.5` vào cùng session. Xong task → chốt session → task tiếp ở session mới. Plan tầng 2 có nhiều task thì chỉ **implement task đầu** đã confirm.
- **Tối đa 12–15 steps/turn.** Vượt ngưỡng → dừng, tóm tắt đã làm, hỏi owner `commit + handoff` hay tiếp tục.
- **Input >60k/step là tín hiệu handoff.** Context đã phình — mỗi step sau tốn gấp đôi, rẻ hơn nhiều nếu `commit` + mở session mới (Turn 1: prefix + brief mục 1–3 + map).
- **Ví dụ vi phạm (session1.txt Turn 7):** 36 steps, input leo từ 59k → 137k/step, tổng 2.26M input/turn — tốn gấp 34× so với 3 turn trước. Nguyên nhân: gộp 2 task + đọc chùm 5 file lớn + không handoff.

## 4. Bẫy build máy này

- **KHÔNG `swift build` CLI** — đụng cache `~/Library`. Luôn `xcodebuild` với 3 cờ cache:
  ```
  TMPDIR="$PWD/.tmp"          # hoặc $PWD/.tmp
  -derivedDataPath "$PWD/DerivedData"
  -clonedSourcePackagesDirPath "$PWD/.xcode-packages"
  ```
- `Reado.xcodeproj` viết tay, objectVersion 60; local package dùng `XCSwiftPackageProductDependency`.
- `swift-fsrs` pin commit `4fbaf20` trong `ReadoKit/Package.swift`.
- `ISO8601FormatStyle()` trần không parse/format nổi — phải compose đủ field (xem `ISOTimestamp.swift`).
- SQLite `COLLATE NOCASE` chỉ gập ASCII — gập tiếng Việt là việc tầng app (FR-20).
- TOCropViewController kéo từ SPM từ xa — lần build đầu trong v2 cần mạng.
