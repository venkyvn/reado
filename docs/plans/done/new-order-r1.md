# Plan — new-order-r1: thứ tự thẻ mới ưu tiên bộ đang đọc

> **Trạng thái:** closed (2026-09-30) - thẻ mới ưu tiên bộ đang đọc (LIFO), 271/273 xanh, ADR-047

## Spec
- FR / journey: FR-11 (thêm 1 criterion "thứ tự chọn thẻ mới trong hạn mức"), FR-14 criterion 3 (tồn "nếu hiện" → bỏ khỏi Home hợp lệ, không sửa PRD). J3 (Học từ mới), J4.
- Nguyên lý: Retention — scheduler lo *khi nào*, không lo *bao nhiêu*; "ưu tiên từ của thứ đang đọc, từ gặp lại nhiều lần". Không đụng "Chống lại" / NG.
- In-scope: `ReviewQueue.newCardIDs` đổi `ORDER BY`; Home bỏ con số tồn.
- Out-of-scope: hạn mức (`daily_new_limit`, "Học thêm 10 từ"), nhánh thẻ đến hạn, thứ tự trình bày (`hydrate` vẫn `due_at`), schema.
- Q mở: không. Fen chốt 2026-09-30: **bộ vừa thêm từ gần nhất trước (kể cả kho tạm) → trong bộ, từ gặp ≥2 lần trước → thứ tự trang**.

## Hiện trạng
`newCardIDs` `ORDER BY c.due_at, c.id`; thẻ mới `due_at` = lúc tạo (FR-09) → từ cũ nhất ra trước, từ sách bỏ dở chiếm hạn mức của sách đang đọc.

## Tầng 1 — HLD
- Module: ReadoKit (`ReviewQueue.swift`) + Reado (`HomeTabView.swift`).
- Luật:
  ```sql
  ORDER BY (SELECT MAX(v2.created_at) FROM vocab_items v2 WHERE v2.collection_id = v.collection_id) DESC,
           (SELECT COUNT(*) FROM vocab_items v3 WHERE v3.term_normalized = v.term_normalized) DESC,
           v.created_at, c.id
  ```
  Index sẵn: `idx_vocab_inbox_time (collection_id, created_at)`, `idx_vocab_term`.
- `DailyProgressService` gọi cùng `newCardIDs` → số Home khớp hàng đợi, không sửa.
- Hạn mức vẫn áp toàn cục trước lọc phạm vi: quota tính trước, `scope` chỉ lọc.
- Không transaction mới, không protocol mới.

## Tầng 2 — Tasks

### T1 — thứ tự thẻ mới + bỏ số tồn Home
- Files: `app/ReadoKit/Sources/ReadoKit/Review/ReviewQueue.swift`, `app/Reado/Home/HomeTabView.swift`, test `ReadoKitTests`.
- Test: bộ mới hơn chọn trước; từ gặp lại (term_normalized ≥2 dòng) lên trước trong bộ; trong bộ theo `created_at`; quota cắt đúng theo thứ tự mới; scope vẫn lọc sau quota.
- Docs: FR-11 criterion mới, ADR-047, journeys J3.
- DoD: `scripts/test.sh kit` xanh + full `scripts/test.sh` xanh; Home hết hạn mức hiện "Xong phần hôm nay", không con số.

## Nối tiếp
`reencounter-r1` T3 cộng thêm số lần `seen` (bảng `encounters`) vào key thứ 2.
