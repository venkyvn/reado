# PROJECT.md — Reado
> **AI Agent Index — mục lục nội dung repo.**
> Entry point duy nhất là [CLAUDE.md](CLAUDE.md) — agent mới đọc nó trước tiên,
> rồi [AGENTS.md](AGENTS.md) cho protocol DSH. File này giúp tìm file nhanh, không
> phải nguồn chỉ đạo làm việc.

---

## 1. What is this repo?

Reado is a tool for someone who already learns English by reading authentic text
(paper books, web articles, work docs). Capture a page photo, get a bilingual
segment view plus extracted vocabulary, then review those words with FSRS.

Owner = fen. R1 is a single-user MVP. Persona is the owner. Success is M-07:
the manual Gemini-chat workflow is abandoned.

---

## 2. Tech Stack

**Chốt (2026-09-17)** — [docs/research/tech-stack.md](docs/research/tech-stack.md) mục 11.
Q-03 *proxy-only* **đã đảo**; bia mộ tech-stack mục 2.3.

- Platform: **native iOS**, SwiftUI (PRD Q-01). R1 không Android, không PWA
- Data: **local-first**, SQLite on device (PRD Q-02). Dashboard sản phẩm = Later
- API key: **hybrid** (PRD Q-03 v0.9) — proxy Gemini mặc định, key `.env` server;
  user BYOK OpenAI-compat ở Keychain (FR-21). NFR-07: key sản phẩm không trên client
- FSRS: **`swift-fsrs`** với `defaultWv6` (không constructor mặc định = v5)
- Learning steps in-day: **off** (PRD Q-12)
- Capture at R1: camera / picker hệ thống, not a custom viewfinder
- Example verification: **cùng lần gọi FR-02** — trên proxy nếu active = Reado, trên máy nếu BYOK (tech-stack 10.4)
- Proxy must be hosted (not laptop-local); HTTPS required
- Proxy language: **Python + `google-genai`** (đã chốt 2026-09-18 — ROADMAP task 0.5)
- Dialect SQLite: uuid `TEXT`, timestamp ISO-8601 UTC `Z`, `fsrs_params` `TEXT` JSON

**Cố ý chưa chốt:** hosting vendor, model Gemini.

---

## 3. Key File Locations

| Path | What |
|---|---|
| [AGENTS.md](AGENTS.md) | How to work with the docs: read order, settled tables, questions you must ask |
| [ROADMAP.md](ROADMAP.md) | Tracker tiến độ hiện hành (v2): phases, checklist theo FR, quy ước "xong" có bằng chứng |
| [docs/specs/vision.md](docs/specs/vision.md) | Six principles — the resolver for ambiguity |
| [docs/specs/prd.md](docs/specs/prd.md) | FR-01..FR-21 (FR-07 and FR-13 are tombs), NFRs, R1/R2 scope |
| [docs/specs/journeys.md](docs/specs/journeys.md) | Flow spec before UI: J1–J6, Học/Ôn/Trộn + DDL tham chiếu |
| [docs/agent/prompt-spec.md](docs/agent/prompt-spec.md) | FR-02 prompt + structured output contract; owner baseline prompt still missing |
| [docs/research/vocabulary.md](docs/research/vocabulary.md) | Five tables, collections, scoped review (gộp 3 nguồn) |
| [docs/research/review.md](docs/research/review.md) | FSRS state, review log, sync & cram (gộp 3 nguồn) |
| [docs/research/tech-stack.md](docs/research/tech-stack.md) | Stack R1: iOS + SQLite + proxy mặc định + BYOK; mục 12 is the sync list |
| [docs/specs/db.md](docs/specs/db.md) | Dialect SQLite R1 (tầng A) + ghi chú sync Later (tầng B) |
| [design-system/reado/MASTER.md](design-system/reado/MASTER.md) | Tokens for the prototype |
| [app/](app/) | R1 iOS app (SwiftUI) — nền móng 1.1–1.4 ⚡ 2026-09-18. Analysis là **MockAnalyzer** cho tới khi có proxy |
| [ref/pvo/](ref/pvo/) | PVO reference — **do not read to build R1** |

**Đã có:** [solution-design v2](docs/specs/solution-design.md) — proxy API + ranh giới transaction; owner duyệt 6/6 đề xuất 2026-09-18 (ROADMAP task 0.6).
iOS walking skeleton sống ở [app/](app/). DDL SQLite R1 đã có ở [docs/specs/db.md](docs/specs/db.md) mục A.

---

## 4. How to Run & Test

iOS app (walking skeleton, analysis **mock**):

```bash
open app/Reado.xcodeproj
```

Chọn scheme **Reado**, Simulator iPhone, Run. Test: Product → Test, hoặc:

```bash
cd app
TMPDIR="$PWD/../.tmp" xcodebuild -project Reado.xcodeproj -scheme Reado \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath "$PWD/../DerivedData" -clonedSourcePackagesDirPath "$PWD/../.xcode-packages" test
```

FR Given/When/Then trong PRD vẫn là test case sản phẩm. `app/ReadoTests` đang cover
migration/seed, queue hai nhánh, grade + undo, snapshot log, primitives, export,
leech, capture failure (91 test xanh, 2026-09-24). `app/ReadoKit/Tests` là smoke cho
`swift test` macOS.

---

## 5. Constraints (do not violate)

- Read [AGENTS.md](AGENTS.md) before any other work. Do not fill owner-owned
  blanks with a "reasonable default".
- Do not implement FR-07 or FR-13 (tombs). Do not delete tomb entries.
- Do not add a `unique` constraint on `vocab_items`. Dedup is FR-10 at extract time.
- `cards.state` has **four** values (`new`, `learning`, `review`, `relearning`).
- `review_logs` stores the card snapshot **before** the grade, not after.
- NG-07: one input path — page photo. No PDF/ebook import.
- NG-09: do not write an SRS algorithm. Use an existing FSRS library.
- NG-05: R1 is one user. Do not prompt UI for J7–J9 (login / account).
- Walking skeleton first: capture → analyze → review & edit → save → review
  (FR-01, FR-02, FR-03, FR-09, FR-11, FR-12) plus the default collection (`is_default` of FR-17).
- Q-06, Q-08, Q-09, Q-10, Q-11 are owner decisions. Ask. Do not pick silently.
  Do not re-open Q-01–Q-02 or Q-12. Q-03 = hybrid (v0.9); đừng đảo về proxy-only
  im lặng.
- Owner's manual Gemini prompt is not in the repo. Do not treat the reconstructed
  prompt in [docs/agent/prompt-spec.md](docs/agent/prompt-spec.md) as proof of A-02.
