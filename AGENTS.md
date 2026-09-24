# AGENTS.md — Reado v2 (DSH protocol)

Luật dự án: đọc `CLAUDE.md` (rồi `docs/agent/agent-rulebook.md` khi task chạm điều khoản).
DSH là tool chính. File này KHÔNG nhân đôi CLAUDE.md — chỉ chứa protocol riêng cho DSH.

## 1. Session protocol

- **Turn 1 — session mới:** Đọc `CLAUDE.md`, rồi `docs/session-brief.md` mục 1–3. Câu đang mở chỉ ở `CLAUDE.md` mục 5.
- **Từ Turn 2:** CẤM đọc lại `session-brief.md` hay bất kỳ file đã có trong ngữ cảnh.
- **Không tự đọc lại file vừa sửa:** Nội dung vừa ghi đã nằm sẵn trong context. Cấm `read` để xác nhận lại.
- **Lệnh code cụ thể:** Viết code ngay bằng `write`/`edit`. Không đọc tài liệu dạo đầu.
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
- **CẤM read nguyên** các file ≥25KB sau (chỉ grep + read quanh trúng): `ROADMAP.md` · `docs/archive/mvp-plan-pwa-gen.md` (~128K) · `docs/research/vocabulary.md` (~100K) · `docs/agent/agent-rulebook.md` (~100K) · `docs/research/review.md` (~76K) · `docs/specs/prd.md` · `docs/specs/journeys.md` (~60K) · `docs/archive/*-pwa-gen.md` (tombs) · `docs/decisions-log.md` · `docs/research/tech-stack.md` · `docs/agent/prompt-spec.md` · `docs/specs/sync-server-ddl.md` · `docs/specs/db.md` · `docs/specs/solution-design.md`.
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

### 2d. smart_glob — CẤM glob trần (tool bắt buộc)

Khi cần danh sách file/dir — cấm `glob **/*.md` trần (session3: 123 kết quả → ~15k token chỉ để đọc danh sách). Dùng `scripts/smart_glob.py`:

```bash
# Liệt kê md (thu hẹp trước khi đọc)
python3 scripts/smart_glob.py --ext .md --limit 15

# Swift trong app/, loại cache
python3 scripts/smart_glob.py --ext .swift --root app --limit 15

# Grep luôn thay thế — không cần glob rồi read
grep -rn "FR-16" docs/specs/prd.md | head -n 20
```

## 3. Session hygiene — chống phình context

### 3a. Flow chốt task (bắt buộc)

Task lớn xong → flow bắt buộc:

1. **Hỏi owner approve** — hỏi 1 câu duy nhất, ví dụ: *"Task X xong rồi, approve để commit + handoff không?"*.
2. **Owner approve** → agent **chủ động làm tất cả**, doc trước commit:
   a. Thay khối hiện tại của `docs/session-brief.md` §1 (không nối bullet task cũ). HEAD trong brief lấy từ `git log -1 --oneline` sau commit; chưa commit thì ghi "HEAD xem git".
   b. Append 3–5 dòng vào `docs/journal/YYYY-MM-DD.md` (gì xong / gì còn / bẫy nào).
   c. Nếu task thay đổi trạng thái ROADMAP/PROJECT — cập nhật luôn.
   d. Stage `app/` cộng các doc vừa sửa, rồi `git commit` đúng format `feat(scope): tiếng Việt — tóm tắt` theo conventions mục 7b.
3. **Không chờ owner nhắc lại** — commit + handoff là một bước, không tách rời.
4. Kết thúc phiên — không dồn việc vào session đang phình.

### 3b. Giới hạn chống phình (bắt buộc)

- **1 task = 1 session.** Cấm gộp `2.4 + 2.5` vào cùng session. Xong task → chốt session → task tiếp ở session mới.
- **Tối đa 12–15 steps/turn.** Vượt ngưỡng → dừng, tóm tắt đã làm, hỏi owner `commit + handoff` hay tiếp tục.
- **Input >60k/step là tín hiệu handoff.** Context đã phình — mỗi step sau tốn gấp đôi, rẻ hơn nhiều nếu `commit` + mở session mới (Turn 1 đọc `CLAUDE.md` rồi brief mục 1–3).
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