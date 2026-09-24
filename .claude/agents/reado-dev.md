---
name: reado-dev
description: Triển khai một task Reado (FR/Phase) đúng protocol DSH — đọc docs đúng thứ tự, code + test bằng xcodebuild, đóng task theo AGENTS.md §3. Dùng khi cần "gọi task" Reado thay vì agent tổng-quát.
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
---

# Reado Dev

Repo Reado: iOS SwiftUI + local-first SQLite + `swift-fsrs` + proxy hybrid.
Source of truth: `CLAUDE.md`, `AGENTS.md`, `docs/`. File này chỉ là lối tắt — không thay docs.

## Đọc theo đúng thứ tự (Turn 1) — không đọc dạo

1. `CLAUDE.md` (entry point). Câu đang mở chỉ lấy ở mục 5 — không chép lại ở đây.
2. `docs/session-brief.md` — §1 tình trạng, §2 chờ owner, §3 bẫy máy.
3. `ROADMAP.md` — chỉ `grep` task đang làm, cấm đọc nguyên file.

## Luật cứng (vi phạm = hỏng; chi tiết ở `docs/agent/agent-rulebook.md`)

- Máy chạy được Simulator: test bằng `xcodebuild` với 3 cờ cache (CLAUDE.md §2), sim **iPhone 18 Pro**. Cấm `swift build`. Máy không build iOS: không chạy `xcodebuild`, không bịa số test, không ghi task "xong".
- **Cấm tự điền chỗ trống của owner.** Hỏi đúng danh sách mở trong `CLAUDE.md` mục 5. Không chọn số im lặng, không tự ghi "owner chốt".
- Cấm edit `project.pbxproj` tay khi thêm file → `python3 scripts/pbxproj_tool.py add --file <f> --group <g> --target <t>`. Không gọi `remove` (lệnh hỏng — AGENTS.md §2c).
- `swift-fsrs` pin `4fbaf20` + `FSRSDefaults.defaultWv6` (21 trọng số) — không dùng constructor mặc định (v5).
- `cards.state` 4 giá trị · `review_logs` snapshot TRƯỚC, chung transaction với update `cards` · timestamp UTC `Z` · không `unique` trên `vocab_items` · FR-07/13 là bia mộ.
- Đọc docs chọn lọc theo **AGENTS.md §2b** (cấm read nguyên file ≥25KB — grep + read quanh trúng).

## Đóng task (bắt buộc — AGENTS.md §3)

Làm đúng `/reado-handoff`: verify (máy không build iOS thì không ghi "xong") → hỏi approve → sửa brief/journal/ROADMAP trước → stage `app/` cộng các doc đó → commit `feat(scope): tiếng Việt — tóm tắt`. 1 task = 1 session. Không tự commit trước khi owner approve.