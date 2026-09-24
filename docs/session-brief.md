# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc `CLAUDE.md` trước, rồi file này (Turn 1, mục 1–3). Từ Turn 2 cấm đọc lại.
> Câu đang mở chỉ ở `CLAUDE.md` mục 5. Kho luật: `docs/agent/agent-rulebook.md` — chỉ mở khi task chạm điều khoản.
> Chi tiết task đã xong nằm ở `docs/journal/` và `ROADMAP.md`. Mục 1 dưới đây là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (cập nhật 2026-09-24)

- **Git:** `git log -1 --oneline` là HEAD thật. Lần ghi gần nhất: `88eeee1`. Hash trong journal từ T2 trở về có thể không resolve sau reword — đừng checkout hash cũ.
- **Analysis:** vẫn `MockAnalyzer` trong `AppModel` cho tới proxy 0.7.
- **IA hiện tại:** 3 tab (Home / Ôn / Kho), pin Home tối đa 5, CEFR nhiều level, migration v3.
- **Test gần nhất đã ghi:** 182/182 trên iPhone 18 Pro tại `9c1becc`. Máy không build iOS thì không chạy lại, và không ghi "xong" khi thiếu `** TEST SUCCEEDED **`.
- **Cổng chưa code:** 3.8 FR-10 (Q đã chốt, chờ dữ liệu thật) · 3.11 FR-21 (proxy 0.7 + adapter 1.5) · 3.13 đo NFR · cram FR-18 (R2) · "Từ session collect thêm" (chưa chọn: thêm `session_id` / để R2 / bỏ bước).
- **Leech:** owner chốt 2026-09-24 = 6 lần Again. Không gộp với Q-08.

## 2. Chờ owner (không tự bắt đầu)

1. Dán prompt baseline thủ công cho A-02 (`docs/agent/agent-rulebook.md` mục 8) — vẫn trống, chặn A-02/0.8.
2. Ngưỡng leech FR-19 đã chốt = 6 (2026-09-24). Không hỏi lại.
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4).

## 3. Bẫy máy này

- Không dùng `swift build` — luôn `xcodebuild` với 3 cờ cache vào workspace: `TMPDIR="$PWD/.tmp"` + `-derivedDataPath "$PWD/DerivedData"` + `-clonedSourcePackagesDirPath "$PWD/.xcode-packages"`; sandbox chặn `~/Library` → cần `danger-full-access` khi chạy simulator.
- `Reado.xcodeproj` viết tay objectVersion 60; local package dùng `XCSwiftPackageProductDependency`.
- `ISO8601FormatStyle()` trần không parse nổi — phải compose đủ field (xem `ISOTimestamp.swift`).
- `swift-fsrs` pin `4fbaf20`, `FSRSDefaults.defaultWv6` (21 trọng số).
- SQLite `COLLATE NOCASE` chỉ gập ASCII — gập tiếng Việt là việc tầng app.
- TOCropViewController lần build đầu cần mạng (SPM từ xa).
- iPhone simulator trên máy này là **iPhone 18 Pro** (không phải iPhone 16).
- `scripts/pbxproj_tool.py` lệnh `remove` **bị hỏng** (hàm `remove_file` high-level ở cuối file shadow bản low-level → TypeError). Thêm file: dùng `add`; cần gỡ: sửa tay 1 dòng pbxproj + grep-verify, hoặc sửa tool trước.
- File test Swift PHẢI có đủ 4 dòng trong pbxproj (PBXBuildFile + PBXFileReference + group child + sources phase). Thiếu PBXFileReference → file bị skip **ngầm** (không lỗi build), test "thừa xanh". Nghi ngờ thì kiểm `nm -gU ReadoTests.xctest`.
- `xcodebuild test` đôi khi treo **sau khi** test đã xong ("Failure collecting diagnostics from simulator: Timed out after 600s") — kết quả test đã in xong. Chạy background + Monitor `/tmp/build.log` bắt dòng `Executed N tests`/`TEST SUCCEEDED`, đừng ngồi chờ `BUILD SUCCEEDED` tới cùng.

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
