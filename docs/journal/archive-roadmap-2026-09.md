# Archive — ROADMAP §1 "Quyết định đã chốt — thế hệ v2" (ảnh chụp 2026-09)

> Dời nguyên văn từ `ROADMAP.md` ngày 2026-10-06 (workflow-docs-r1 T7). **Không phải quyết định hiện hành** —
> nhiều dòng đã bị đảo (Q-03 "Hybrid" → ADR-049, Q-09 "Theo collection" → ADR-066…). Quyết định hiện hành:
> `CLAUDE.md` §5 + index `docs/decisions-log.md`. Agent không đọc file này mặc định.

## 1. Quyết định đã chốt — thế hệ v2

| # | Vấn đề | Quyết định (2026-09-17 trừ khi ghi khác) | Hệ quả trực tiếp |
|---|---|---|---|
| Q-01 | Platform | 📌 **Native iOS (SwiftUI)**. Không Android, không PWA sản phẩm. `web/` chỉ là prototype journeys | Code đi vào `app/` (Xcode). PWA hiện có trong `app/` sẽ được dọn đi ở task 1.1 |
| Q-02 | Dữ liệu | 📌 **Local-first, SQLite trên máy**. Dashboard sản phẩm = Later | Offline review miễn phí (NFR-03). DDL theo [docs/db.md](docs/specs/db.md) tầng A |
| Q-03 | API key | 📌 **Hybrid:** proxy Reado (key `.env` server) = mặc định; user thêm agent OpenAI-compat + key **Keychain**, chọn active cho FR-02 (FR-21) | Key sản phẩm không nằm trên client; key user không plaintext, không lên server. Proxy phải **hosted HTTPS** |
| Q-12 | Learning steps trong ngày | 📌 **Tắt** (2026-09-08, giữ) | Interval tính theo ngày; `state='learning'` không xuất hiện ở R1 |
| — | FSRS | 📌 **`swift-fsrs`** với **`FSRSDefaults.defaultWv6`** (21 trọng số). `FSRS()` không tham số = FSRS-5 — silent breakage (NG-09: không tự viết SRS) | Weight v6 + `fsrs_version` ghi vào DB |
| — | Capture | 📌 **Camera / picker hệ thống**, không custom viewfinder; NFR-08 ≤ 3 thao tác từ mở app tới chụp | FR-01 làm theo thế |
| — | Data type | 📌 uuid `TEXT` chữ thường có gạch nối · timestamp `TEXT` ISO-8601 **UTC hậu tố `Z`** · `fsrs_params` `TEXT` JSON + cột `fsrs_version` | Mapping đầy đủ: tech-stack mục 7.2 |
| — | Schema | 📌 `cards.state` có **bốn** giá trị; `review_logs` lưu snapshot **TRƯỚC** khi chấm, cùng transaction với update `cards`; **KHÔNG** có `unique` trên `vocab_items` | Chống trùng ở FR-10 lúc trích xuất |
| — | Slice build đầu | 📌 **Walking skeleton** = FR-01, FR-02, FR-03, FR-09, FR-11, FR-12 + `is_default` của FR-17 (kho luật mục 6). FR-21 **sau** skeleton | Phase 2 của file này |
| — | Tombstones | 📌 FR-07 và FR-13 đã bỏ (không implement, không xoá dòng); NG-07 EPUB/ebook + chép file vào app (PDF đọc tại chỗ đã đảo sang FR-23, ADR-058 2026-10-04); NG-08 không hỏi ngữ pháp | Dính tới là dừng |
| — | Reminder | 📌 Không Web Push (tech-stack mục 8.3). R1 nhắc ôn = **local notification** trên máy (owner chốt 2026-09-18); APNs khi Later cần nhắc lúc app không mở | Task 3.12 |
| — | Gập hoa thường tiếng Việt (FR-20) | 📌 **Hạ chữ thường Unicode, GIỮ dấu** (owner chốt 2026-09-24): `"SÁCH"≈"sách"`, `"Đá"≈"đá"`, nhưng `"Đá" ≠ "Đã"` — dùng chung `normalizedTerm` lúc trim/insert (SQLite NOCASE chỉ gập ASCII) | Khớp collection FR-20 + cảnh báo trùng term |
| — | Proxy framework | 📌 **Python + `google-genai`** — owner duyệt đề xuất 6.2 ngày 2026-09-18 (framework cụ thể kiểu FastAPI chốt trong SD 0.6) | Task 0.7 |
| Q-10 | Buffer cuộn + session collection | 📌 **10 phiên đọc gần nhất PER NAMED COLLECTION** vào bảng `reading_sessions` (text + dịch + summary), để đọc lại trang cuối — chốt 2026-09-18 ([ADR-029](docs/decisions-log.md#adr-029--q-10-10-phiên-đọc-bền-per-collection-có-tên-đảo-v03-buffer-trôi), đảo v0.3 buffer-trôi). **Kho tạm KHÔNG lưu phiên**; phiên thứ 11 trôi (trim trong transaction) | Task 3.4 (FR-05/06) |
| Q-06 | Lemmatize ở FR-10 | 📌 **Không lemmatize** — mỗi word form một dòng (`running` ≠ `run`, `took` ≠ `take`). Chốt 2026-09-22 (ADR-032) | `term_normalized` giữ nguyên form, khớp FR-20 |
| Q-08 | Ngưỡng "đã thuộc" (FR-10) | 📌 **FSRS `stability ≥ 21 ngày`** = Anki "mature" (interval ≥ 21 ngày). Chốt 2026-09-22 (ADR-032), không đo bằng số lần | Bộ lọc FR-10: `state='review'` + `stability >= 21` |
| Q-09 | Phạm vi so khớp "đã thuộc" | 📌 **Theo collection**, không toàn cục — nghĩa mới của từ cũ vẫn thêm khi sang sách khác. Chốt 2026-09-22 (ADR-032) | Truy vấn FR-10 scope theo collection đang chụp |

**Chốt product-behavior cho UI ôn tập** (đối chiếu lại khi SD, không mù quáng):
UI-1 song ngữ **xen kẽ theo đoạn** (ADR-007) · card duyệt **rút gọn mở inline** (ADR-008) ·
📌 vuốt TRÁI = **Again(1)** · PHẢI = **Good(3)**, Hard/Easy là nút, chạm lật, undo nổi 1 bước, đủ 4 mức (ADR-025 — chốt 2026-09-18 theo journeys mục 4, **thay** ADR-009) ·
rich vocab **4 tags / 3 synonyms / 3 antonyms** cột JSON (ADR-010, RV-1) ·
export/import là phao cứu sinh nên làm sớm trong R1 (tinh thần cũ, scope v2 ở PRD mục 10).
Các ADR thuần PWA-tech (016 shadcn · 017 zustand · 018 i18n · 021 lazy · 022 a11y web) **không** chuyển sang SwiftUI — quyết định lại lúc SD, không chép tự động.

**CHƯA CHỐT — không tự quyết, không lấp:**
Q-11 stability jitter hai chế độ R2 (chốt trước Phase 4) ·
ngưỡng leech FR-19 = 6 (owner chốt 2026-09-24, không gộp Q-08) ·
hosting vendor proxy (chốt lúc deploy — HTTPS + không cold-start 30s) · model Gemini (chốt ở 0.8, bước A-01/A-02).
`settings.timezone` đã có trên schema (seed từ device, task 1.3) — không còn thiếu.
(Đã đóng 09-17/09-18: Q-01/02/03 pivot · local-vs-APNs = local cho R1 · framework proxy = Python · encrypted.txt = xoá · chỗ đặt code PWA cũ.
Đã đóng 2026-09-22: Q-06 không lemmatize · Q-08 stability ≥ 21 · Q-09 theo collection.)

---
