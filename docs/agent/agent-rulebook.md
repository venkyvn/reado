# Agent rulebook — index luật (không phải kho 100KB)

Bản PWA đầy đủ đã archive: `docs/archive/agents-pwa-gen.md` — **đừng dùng làm luật hiện hành**.

Luật cứng sống ở `CLAUDE.md` §4–5. Protocol session / cache / đọc file sống ở `AGENTS.md`. File này chỉ **định tuyến**: đụng chủ đề nào thì grep file đó, không `read` nguyên file lớn.

## Khi đụng X → grep Y

| Đụng | File | Ghi chú |
|---|---|---|
| Luật cứng, Q mở | `CLAUDE.md` §4–5 | Một nguồn Q; command không chép số Q |
| Session, cache prefix, glob, handoff | `AGENTS.md` | Không nhân đôi CLAUDE.md |
| Schema / DDL / dialect SQLite | `docs/specs/db.md` | Grep cột / bảng; cấm read nguyên |
| Lịch ôn, FSRS, cram, sync Later | `docs/research/review.md` | Grep mục cần |
| Tổ chức collection / thẻ / import | `docs/research/vocabulary.md` | Grep; đây **không** phải rulebook |
| Capture AI, output schema, verify example | `docs/agent/prompt-spec.md` | FR-02 |
| Module iOS, proxy, transaction, wiring skeleton | `docs/specs/solution-design.md` | §3 kiến trúc; §10 walking skeleton |
| Slice + tiến độ FR | `ROADMAP.md` Phase 2–3 | Chỉ grep task; không read nguyên |
| Journey UI | `docs/specs/journeys.md` | J1–J6 + J-R1-* |
| Nguyên lý mơ hồ | `docs/specs/vision.md` | Có mục "Chống lại" |
| Swift layout / commit message | `docs/agent/coding-conventions.md` | §2 skeleton tĩnh |
| ADR | `docs/decisions-log.md` | Grep số ADR |
| Tình trạng máy / HEAD / test | `docs/session-brief.md` | Turn 1 §1–3 thôi |

## Walking skeleton (trỏ, không nhắc lại FR)

Vòng mỏng R1: chụp → phân tích → duyệt & sửa → lưu → ôn (`FR-01` → `FR-02` → `FR-03`/`FR-09` → `FR-11`/`FR-12` + `is_default` của FR-17). Chi tiết wiring: `docs/specs/solution-design.md` §10. Tracker: `ROADMAP.md` Phase 2.

## Bảng "Đã chốt"

Không copy bảng. Nguồn: `CLAUDE.md` §5 + bảng "Đã chốt" cuối từng spec (prd / vocabulary / review). Thấy dòng chốt có vẻ sai → **báo fen**, không sửa im lặng.
