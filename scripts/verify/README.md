# scripts/verify — kiểm tra docs

Gồm `check-doc-links.mjs`, `audit.sh` (gom mọi kiểm tra docs/workflow máy kiểm được — `/raudit` chỉ chạy script này; `.claude/hooks/guard.py` chạy nó trước mỗi `git commit`, exit 1 thì commit bị chặn) và `test_guard.py` (bảng case của guard). Khép plan: `scripts/close_plan.sh <id> "<tóm tắt>"`. Các script Phase 0 thời PWA (`verify.mjs`, `ab-compress.mjs`)
đã xoá — xem `docs/decisions-log.md` (ADR xoá script Phase 0) và `git log -- scripts/verify`.

## Kiểm tra link docs (`check-doc-links.mjs`)

```bash
node scripts/verify/check-doc-links.mjs    # exit 1 nếu có link nội bộ/anchor hỏng
```

Quét **file sống** (root `*.md` + `docs/` trừ `journal/`): link nội bộ
theo quy ước gốc-repo `docs/...` (resolve gốc-repo trước, fallback file-relative),
anchor theo slug GitHub (giữ `_`, mỗi space → `-`, heading trùng lặp tự `-1`),
tệp mồ côi, và liệt kê link ngoài (không verify mạng). Reference-style link chỉ
cảnh báo, không làm exit 1. Chạy sau mỗi đợt sửa docs để chặn link chết.

