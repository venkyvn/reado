# Plan — reencounter-r1: gặp lại từ cũ khi đọc + mức "Đã thấm"

> **Trạng thái 2026-09-30:** fen OK (go) cả schema `encounters` và FR-22 mới. 3 task, làm sau `new-order-r1`.

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

### T1 — dữ liệu
- Migration v4, `EncounterRepository` (insert seen/recognized idempotent theo ngày, đếm tuần), `EncounterMatcher`, export thêm `encounters`.
- Test: migration từ v3, matcher (cụm, biên từ, hoa/thường, chồng nhau), cascade, recognized 1 lần/ngày.
- Docs: `db.md`, DDL `solution-design.md`, PRD FR-22, ADR-048.
- DoD: `scripts/test.sh kit` + full xanh.

### T2 — màn đọc
- Gạch chân + popover (nghĩa, IPA, "đã gặp ở ‹collection›", nút "Nhận ra ✓") ở `AnalysisView` và `ReadingSessionView`; ghi `seen` khi lưu trang.
- Test: `seen` ghi đúng transaction lưu; UI test/preview tối thiểu.
- DoD: full xanh + fen xem tay trên simulator.

### T3 — thang tiến độ
- `Mastery.level`, `absorbedCount`, thanh 4 màu đổi nhãn Mới · Đang học · Đã nhớ · Đã thấm, `MasteryRing`, Home "Gặp lại N từ tuần này"; `newCardIDs` cộng số `seen` vào key ưu tiên.
- DoD: full xanh.
