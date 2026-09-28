# Reado

Công cụ học tiếng Anh qua việc đọc văn bản nguyên bản — sách giấy, báo mạng, tài
liệu chuyên ngành: chụp một trang, nhận về bản song ngữ Anh–Việt theo từng đoạn
cùng từ vựng đã trích xuất, rồi ôn lại số từ đó bằng spaced repetition.

**Nền tảng:** iOS native (SwiftUI), local-first SQLite, AI qua proxy hybrid.

## Bắt đầu

> **Nếu bạn là agent được giao build project này:** đọc
> [CLAUDE.md](CLAUDE.md) trước tiên (entry point duy nhất, gồm cả cách làm việc), rồi
> [ROADMAP.md](ROADMAP.md) để biết tiến độ và checklist. CLAUDE.md có thứ tự đọc,
> danh sách quyết định **không được** tranh luận lại, và danh sách câu hỏi **phải hỏi**
> thay vì tự quyết.

## Tài liệu

| Doc | Trả lời câu hỏi |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Entry point cho agent — sơ đồ docs (§3), luật cứng, cách làm việc |
| [docs/specs/vision.md](docs/specs/vision.md) | Tại sao Reado đáng tồn tại — design principles và ranh giới sản phẩm |
| [docs/specs/prd.md](docs/specs/prd.md) | Thế nào là "xong" — functional/non-functional requirements, scope, metrics |
| [docs/agent/prompt-spec.md](docs/agent/prompt-spec.md) | Prompt gửi cho AI ở FR-02 và **structured output schema** — hợp đồng giữa AI và data model |
| [docs/research/vocabulary.md](docs/research/vocabulary.md) | **Các từ** được tổ chức thế nào — collection, card design, import, data model |
| [docs/research/review.md](docs/research/review.md) | **Khi nào** thẻ quay lại — FSRS state, review log, multi-client sync, rich-vocab cram |
| [docs/specs/db.md](docs/specs/db.md) | Schema SQLite dialect R1 — từng bảng, vì sao, bẫy |
| [docs/specs/journeys.md](docs/specs/journeys.md) | Các lối đi UI (J1–J6) và schema tham chiếu |
| [docs/specs/sync-server-ddl.md](docs/specs/sync-server-ddl.md) | Bản nháp DDL server cho sync tương lai (Postgres/Supabase, USN, RLS) — Later, chờ owner |
| [ref/pvo/pvo-2022-model.md](ref/pvo/pvo-2022-model.md) | Mô hình PVO của thầy Vũ — nguồn tham khảo cho tầng liên kết từ vựng, thuộc R2 |
| [docs/idea.md](docs/idea.md) | Ý tưởng gốc, giữ lại làm provenance |

## Tiến độ & nhật ký

- Tiến độ, checklist và nhật ký thay đổi nằm ở [ROADMAP.md](ROADMAP.md).
- Bàn giao session hiện tại nằm ở [docs/session-brief.md](docs/session-brief.md).
- Lịch sử quyết định (ADR) nằm ở [docs/decisions-log.md](docs/decisions-log.md).