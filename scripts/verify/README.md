# scripts/verify — kiểm tra docs

Chỉ còn `check-doc-links.mjs`. Các script Phase 0 thời PWA (`verify.mjs`, `ab-compress.mjs`)
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

