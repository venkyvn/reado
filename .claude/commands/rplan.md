---
description: Spec → hỏi nếu mơ hồ → HLD → task breakdown. Không code. Lưu docs/plans/ chỉ khi fen OK.
argument-hint: "[FR hoặc task-id]"
---

Lập plan Reado theo CLAUDE.md §7 (spec-driven, hai tầng). **Đừng `write` code.** Template: `docs/agent/plan-template.md`.

1. **Spec** — grep FR/GWT trong `docs/specs/prd.md` và journey trong `docs/specs/journeys.md` (cấm read nguyên file lớn). Ghi in-scope / out-of-scope / không đụng. Không viết PRD mới.
2. **Thiếu hợp đồng** (schema mới, FR chưa có, Q mở ở `CLAUDE.md` §5, docs lệch code) → hỏi fen **một lượt**, dừng. Không reasonable default.
3. **Tầng 1 HLD** — Reado vs ReadoKit, protocol, transaction, file cấm. Skeleton tĩnh: conventions §2 + solution-design §3; hiện trạng: `python3 scripts/repo_map.py` chỉ khi Turn 1 chưa chạy map.
4. **Tầng 2** — task nhỏ: files, test, DoD. 1 task = 1 session. Nêu task nào nên làm trước.
5. In plan ra chat. **Không** ghi `docs/plans/<task-id>.md` trừ khi fen bảo save / ok / go.
6. Skip hợp lệ (nói 1 câu, không cần HLD đầy đủ): bug UI / copy / test khi FR+journey đã chốt — trừ khi fen bắt plan.

Sau confirm: chỉ implement **một** task tầng 2; đóng bằng `/rhandoff`.
