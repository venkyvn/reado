# Plan template — Reado (`docs/plans/<task-id>.md`)

Chỉ lưu sau khi fen confirm (in ra chat trước). Không viết PRD mới — trích spec có sẵn.

```markdown
# Plan: <task-id>

## Vấn đề & bằng chứng
- Vấn đề gốc (không phải giải pháp) + bằng chứng: (diagnostics, số đo, `file:line`)
- Đã qua `/ridea`? → tóm 1 dòng kết luận; chưa → ≥ 2 phương án, có "không làm gì"
- Tiêu chí thành công + tiêu chí dừng, đặt TRƯỚC spike/code:
- Investigation / ADR liên quan đã đọc:

## Spec
- FR / journey: (grep prd.md + journeys.md — GWT giữ nguyên, không viết lại)
- Nguyên lý: phục vụ #N (vision.md) · đụng mục "Chống lại" / NG nào (không → ghi "không")
- In-scope:
- Out-of-scope / không đụng:
- Q mở / chỗ thiếu hợp đồng: (nếu có → dừng, hỏi fen)

## Tầng 1 — HLD
- Module: Reado vs ReadoKit
- Protocol / transaction đụng tới
- File cấm

## Tầng 2 — Tasks
1 task = 1 session. Chỉ implement task fen vừa OK.

### T1 — <slug>
- Files:
- Test:
- DoD:
```
