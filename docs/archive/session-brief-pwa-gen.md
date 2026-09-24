> ⚰️ **BIA MỘ (2026-09-18)** — Session brief thế hệ PWA (09-10). Đã thay bằng [docs/session-brief.md](../session-brief.md) mới (post-merge v2). Lưu để truy chuỗi lịch sử.

# Session Brief — Nguồn duy nhất cho agent mỗi session mới

> Mục đích: Đọc file này SAU `AGENTS.md`. Chỉ mở thêm doc khi task cụ thể yêu cầu.

---

## 1. Tình trạng hiện tại

- **Phase:** 3 — Phần còn lại của R1
- **Phase 2 ĐÓNG:** Walking skeleton (2.1–2.8) đã chạy end-to-end pass trên máy + iPhone offline.
- **Đang chờ:** Owner test tay các màn mới (rich vocab, cram, settings, read, home, collection detail).

---

## 2. Ưu tiên tiếp theo (Candidate tasks — ưu tiên từ trên xuống)

1. **Task 3.16 — Import từ vựng:** Đã có plan (IMP-01→04). **ĐANG CHỜ OWNER ĐỌC + GO.** Khi nào owner nói "GO" hoặc "làm 3.16", mới bắt đầu.
2. **Task 3.8 — Quản lý collection:** FR-17 phần còn lại (xoá có báo số từ, chuyển từ không đụng FSRS, kho tạm chọn nguyên lô).
3. **Task 3.2 — Lỗi capture:** FR-04 (ảnh mờ, không phải tiếng Anh).
4. **Task 3.10 — Leech:** FR-19 (đếm lapses, ra khỏi queue, ngưỡng hỏi owner).

---

## 3. Best Practice / Điều cấm (Tóm tắt từ AGENTS.md + Coding Conventions)

### Phải làm

- **Verify trước khi báo xong:** Luôn chạy `lint` / `typecheck` / test related trước khi commit.
- **Snapshot trước khi chấm:** `review_logs` LUÔN ghi state TRƯỚC khi FSRS xử lý.
- **Schema validation:** Nếu parse JSON schema không pass → phải có toast + error state rõ ràng, không ẩn im lặng.
- **Log chi tiết:** Nếu debug, log state FR-11 (queue length, dailyNewCount, mode).

### Tránh làm / Tuyệt đối KHÔNG

- **KHÔNG** tự thêm `unique` index trên `vocab_items.collection_id + term_normalized`. (Mục đích: 1 từ nhiều nghĩa).
- **KHÔNG** tự viết lại SRS algorithm (NG-09). Dùng `ts-fsrs`.
- **KHÔNG** lưu ảnh trang vào SQLite (NFR-04, chỉ lưu segments JSON).
- **KHÔNG** cho user thấy ID hệ thống (`uuid`) ở bất kỳ UI nào.
- **KHÔNG** đọc API key từ DOM (input type=text hoặc .value) để gửi đi.
- **KHÔNG** chạm vào `fsrs_params`, `maximum_interval`, `enable_fuzz` ở Settings FR-15.
- **KHÔNG** thêm dependencies mới nếu không thực sự cần thiết (tránh phình bundle).
- **KHÔNG** tự chốt câu hỏi chưa có trên `AGENTS.md` (Q-08, Q-09, Q-11). Phải hỏi owner.

---

## 4. Data Model nhanh (Nhắc lại để không dùng sai)

- **4 trạng thái `cards.state`:** `new`, `learning`, `review`, `relearning` (KHÔNG chỉ có new/review).
- **Timestamp SQLite:** TEXT ISO-8601 (để giữ timezone cho chính xác, không dùng epoch số).
- **UUID SQLite:** TEXT hex, tự sinh (client offline không chờ server).

---

## 5. Enhancement Roadmap — tiến độ (owner giao 2026-09-10)

> Owner giao sau CTO review: "tạo ADR + làm hết enhancement roadmap". **Bỏ qua:** CI/CD
> (owner tự làm sau), E2E flow mới (chờ ổn định behavior), multilanguage full refactor (làm sau).
> Quyết định mới ghi ở `docs/decisions-log.md` ADR-016 → ADR-023.

### ✅ ĐÃ XONG — TOÀN BỘ ROADMAP (session 2026-09-10)

| Việc | Bằng chứng |
|---|---|
| ADR log | `docs/decisions-log.md` — ADR-001→015 (backfill) + ADR-016→023 (mới); ADR-019 điều chỉnh cách chạy (export JSON, không đọc thẳng SQLite/OPFS) |
| Prettier config | `app/.prettierrc` + `app/.prettierignore` |
| husky pre-commit | `app/.husky/pre-commit` = `npx lint-staged`; `core.hooksPath=app/.husky`; `prepare` = `husky && node scripts/setup-hooks.mjs` (sửa hooksPath cho fresh clone) |
| lint-staged config | block `lint-staged` trong `app/package.json` (ts/tsx → oxlint --fix + prettier) |
| npm scripts | `start` (= dev), `check` (lint+typecheck+test+build), `format`, `format:check`, `e2e:all`, `analytics` |
| Unified e2e runner | `app/e2e/run-all.mjs` — chạy mọi `e2e/*.mjs` (trừ seed/run-all), tổng kết, exit 1 khi fail |
| Tailwind CSS | plugin `tailwindcss()` trong vite.config + `@import "tailwindcss"` trong index.css (v4, không config file) |
| Offline indicator | banner "ngoại tuyến" trong AppRoot (`navigator.onLine` + listener online/offline) |
| Toast system | `app/src/ui/toast.ts` (hook) + `app/src/ui/ToastProvider.tsx` + CSS toast-stack — thay `console.error` ở `handleAnalyzed`/`handlePageSaved` |
| Error Boundary | `app/src/ui/ErrorBoundary.tsx` bọc toàn app trong App.tsx |
| Zustand setup | `app/src/ui/store/navigationStore.ts` — điều hướng chuyển sang store (ví dụ đầu tiên, không refactor toàn bộ) |
| React.lazy | AppRoot import 11 screens qua `lazy()` + `<Suspense>` fallback (từng màn một chunk riêng) |
| A11y baseline | ReviewScreen: bàn phím 1-4 + mũi tên chấm, Space/Enter lật, `aria-keyshortcuts` + `aria-live`; snack OK |
| Analytics script | `app/scripts/analytics.mjs` — chạy trên file export JSON FR-16 (OPFS không đọc bằng Node), `npm run analytics -- <file.json>`, output bảng + JSON |
| i18n nền tảng | `app/src/app/i18n.ts` (init sync) + `app/src/i18n/locales/vi.json` + HomeScreen làm màn ví dụ `useTranslation` |
| Verify cuối | `npm run check` XANH: oxlint 0 warn/0 err · typecheck pass · 158 test pass · build pass (27 precache entries, từng screen 1 chunk) |

### 📌 Ghi chú cho session sau

- **E2E chưa chạy lại trên Chrome** (sandbox hay đòi quyền Chrome nâng cao) — `npm run e2e:all` là runner mới, lần đầu chạy nên xem lại từng script nếu có fail do môi trường.
- **Analytics bị giới hạn:** file export JSON KHÔNG có bảng `analyses` (latency/token AI) — số đó xem trong màn Kiểm tra lưu trữ; muốn đo thì sau này cân nhắc thêm phân đoạn export.
- **Husky trên fresh clone:** `npm install` tự sửa `core.hooksPath` qua script setup-hooks; chỉ cần nhớ hooks sống ở `app/.husky`, không phải repo root.

### ⏭️ Sau khi xong enhancement

Quay lại candidate tasks mục 2: 3.16 import (chờ owner GO), 3.8 collection, 3.2 FR-04, 3.10 FR-19.
