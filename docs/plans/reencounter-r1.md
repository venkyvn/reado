# Plan — reencounter-r1: gặp lại từ cũ khi đọc + mức "Đã thấm"

> **Trạng thái 2026-10-01:** fen OK (go) cả schema `encounters` và FR-22 mới. 3 task: **T1 ✅ T2 ✅ T3 ✅(tạm)** — T1/T2 fen xác nhận test xanh + xem tay UI; T3 fen chốt "tạm xem như xong" 2026-10-01 (xem ghi chú ở T3).

## Spec
- FR / journey: **FR-22 mới "Gặp lại từ cũ khi đọc"** (thêm vào PRD ở T1); lấp criterion 3 của FR-05 (chạm vocab trong đoạn → nghĩa + IPA — chưa làm ở `ReadingSessionView`). Thước đo trực tiếp **M-06**. J2.
- Nguyên lý: #4 (ngữ cảnh), #6 (thang Mới · Đang học · Đã nhớ · Đã thấm), Retention ("lần nhận ra khi đọc cũng chỉ ghi lại, không đổi lịch"), Conclusion (vòng lặp). Không đụng NG.
- In-scope: bảng `encounters`, matcher xuyên collection, gạch chân + popover ở màn phân tích và màn đọc, nút "Nhận ra", thang 4 mức, dòng "Gặp lại N từ tuần này" trên Home.
- Out-of-scope: đổi FSRS/`review_logs`, lemmatize (Q-06 giữ), sửa Q-09 (Q-09 chỉ cho FR-10; FR-22 ghi rõ so khớp xuyên collection), import lại `encounters` từ backup.
- Q mở: không. Fen chốt 2026-09-30: gộp "Đang nhớ" vào "Đang học" → đúng 4 mức vision.

## Tầng 1 — HLD

### Schema v4 (migration v3 → v4)
```sql
CREATE TABLE encounters (
  id            TEXT NOT NULL PRIMARY KEY,
  vocab_item_id TEXT NOT NULL REFERENCES vocab_items(id) ON DELETE CASCADE,
  kind          TEXT NOT NULL CHECK (kind IN ('seen', 'recognized')),
  created_at    TEXT NOT NULL
);
CREATE INDEX idx_encounters_item ON encounters (vocab_item_id, kind);
```
- Không dùng `review_logs` (CHECK `mode`, bắt buộc `rating` + snapshot) — FSRS không bị động.
- `seen`: tự ghi khi lưu một trang có từ đã có trong kho, **cùng transaction** lưu vocab + phiên đọc; mỗi vocab một dòng mỗi lần lưu.
- `recognized`: fen chạm "Nhận ra"; tối đa 1 dòng / vocab / ngày học (giờ chuyển ngày FR-11).
- Chuyển collection giữ nguyên (khoá theo `vocab_item_id`); xoá vocab → cascade.

### Luật mức (tính lúc đọc, không cột)
| Mức | Điều kiện |
|---|---|
| Mới | mọi thẻ `new` |
| Đang học | còn lại, chưa đạt Q-08 |
| Đã nhớ | Q-08 (`state='review'` và `stability >= Mastery.stabilityThreshold`) |
| Đã thấm | Đã nhớ **và** ≥1 `recognized` — tụt Q-08 thì tự về Đang học |

### Matcher (ReadoKit, hàm thuần)
`EncounterMatcher`: nguyên từ + cụm nhiều chữ, không phân biệt hoa/thường, biên từ, cụm dài thắng khi chồng nhau, không lemmatize. Lexicon = vocab chưa suspend; một term nhiều dòng → popover liệt kê đủ nghĩa.

### Module
- ReadoKit: `Database/Migration.swift` (v4), `Encounter/EncounterRepository.swift`, `Encounter/EncounterMatcher.swift`, `Review/Mastery.swift` (`level`), `Vocab/VocabRepository.swift` (`CollectionSummary.absorbedCount`), `Export/ExportService.swift`.
- Reado: `Analysis/AnalysisView.swift` (+ `SegmentBlock`), `Library/ReadingSessionView.swift`, popover mới trong `Shared/`, `Library/CollectionStatsHeader.swift`, `Shared/MasteryRing.swift`, `Home/HomeTabView.swift`, `App/AppModel.swift`.
- Bẫy: link trong `Text` bị `Button` của đoạn nuốt chạm → lật dịch đoạn chuyển sang `onTapGesture`, link xử lý qua `openURL`.

## Tầng 2 — Tasks

### T1 — dữ liệu ✅ xong 2026-10-01
- **Xong 2026-10-01** (fen xác nhận `scripts/test.sh` + `kit` xanh, không kèm số; commit `42c949f`). Chi tiết: `EncounterRepository.insertSeen` **không** tự mở transaction (T2 gọi trong transaction lưu trang); `recordRecognized` tự mở một transaction; matcher thêm luật `'s` là ranh giới; export giữ `version: 1`, thêm khoá `encounters`. Docs đã cập nhật: `db.md` A.2, `solution-design.md` §5/§6, PRD v0.10 + FR-22, ADR-048, ROADMAP 3.16.
- Migration v4, `EncounterRepository` (insert seen/recognized idempotent theo ngày, đếm tuần), `EncounterMatcher`, export thêm `encounters`.
- Test: migration từ v3, matcher (cụm, biên từ, hoa/thường, chồng nhau), cascade, recognized 1 lần/ngày.
- Docs: `db.md`, DDL `solution-design.md`, PRD FR-22, ADR-048.
- DoD: `scripts/test.sh kit` + full xanh.

### T2 — màn đọc ✅ xong 2026-10-01
- **Xong 2026-10-01** (commit `ec091ef`; fen xác nhận test xanh + đã xem tay UI: gạch chân, popover, "Nhận ra", lưu trang, export). `VocabRepository.saveCapture` ghi `seen` cùng transaction (matcher dựng TRƯỚC khi chèn item mới; ghi cả khi đích là kho tạm; không có đoạn gốc thì không ghi; từ có thẻ leech bị loại). UI: `Shared/EncounterText.swift` (`EncounterText` gạch chân chấm + link qua `openURL`; `EncounterSheet` popover nghĩa/IPA/"Đã gặp ở ‹collection›"/"Nhận ra ✓" mỗi dòng vocab); `AppModel+Encounter.swift`; `SegmentBlock` và `ReadingSessionView` đổi `Button` → `onTapGesture` (Button nuốt chạm link). Popover làm bằng sheet `.medium/.large` (trên iPhone `.popover` cũng tự thành sheet).
- Gạch chân + popover (nghĩa, IPA, "đã gặp ở ‹collection›", nút "Nhận ra ✓") ở `AnalysisView` và `ReadingSessionView`; ghi `seen` khi lưu trang.
- Test: `seen` ghi đúng transaction lưu; UI test/preview tối thiểu.
- DoD: full xanh + fen xem tay trên simulator.

### T3 — thang tiến độ ✅(tạm) 2026-10-01
- **Chốt tạm 2026-10-01:** fen build được bản T3 và xem Home nhưng **chưa thấy** dòng "Gặp lại N từ tuần này" — code đọc lại không thấy lỗi, nhiều khả năng N = 0 (hàng cố ý ẩn khi 0; `seen` chỉ ghi khi LƯU trang mới có từ cũ, `recognized` chỉ khi bấm "Nhận ra"). Test T3 đã xanh (fen chạy full 306/308 ở `597c8d9`). **Chưa xác minh UI:** dòng Home với dữ liệu thật, thanh 4 màu/`MasteryRing` đã thấm. Nếu sau này vẫn không hiện khi `SELECT … FROM encounters` có dòng trong 7 ngày → bug thật, mở lại.
- **Code (viết ở cloud):** `Mastery.Level` + `Mastery.level(state:stability:recognizedCount:)` (hàm thuần — nguồn luật; SQL đối chiếu trong test); `CollectionSummary.absorbedCount` (thêm cột 12 + một bind ngưỡng, `masteredCount` giữ nghĩa Q-08 gồm cả Đã thấm); `ReviewQueue.newCardIDs` khoá (2) = số dòng cùng term **+ `seen`** (`recognized` không cộng điểm); `AppModel.reencounteredThisWeek` (7 ngày gần nhất, nạp trong `reloadOverview`), `recognizeWord` gọi `reloadOverview` khi vừa ghi; UI: thanh 4 nhóm Đã thấm › Đã nhớ › Đang học › Mới ở `CollectionStatsHeader`, `MasteryRing(absorbed:)` cung thứ hai (Home + Kho), nhãn "Đã thuộc" → "Đã nhớ" (toast "Thuộc rồi!" ADR-038 giữ nguyên), hàng "Gặp lại N từ tuần này" ở Home (ẩn khi 0). Docs: PRD FR-11 criterion thứ tự thẻ mới nhắc `seen`. Test: `MasteryLevelTests` (kit), `VocabularyListTests` (+2, đối chiếu SQL ↔ `Mastery.level`), `ReviewQueueAndServiceTests` (+3).
- `Mastery.level`, `absorbedCount`, thanh 4 màu đổi nhãn Mới · Đang học · Đã nhớ · Đã thấm, `MasteryRing`, Home "Gặp lại N từ tuần này"; `newCardIDs` cộng số `seen` vào key ưu tiên.
- DoD: full xanh.
