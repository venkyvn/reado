# Plan: vision-refresh-r1

> **Trạng thái:** closed (2026-09-30) - gọn nguyên lý 5, làm rõ #6, nối vision vào /rplan (docs-only)

> Fen confirm 2026-09-30. Docs-only, **1 session, 2 task** (T1 → T2), đóng bằng `/rhandoff`.
> Người thực hiện: Sonnet. Làm đúng các thay đổi dưới đây, không mở rộng scope.
> Working tree đang có `docs/plans/shell-chrome-r1.md` untracked — **không** stage file đó.

## Spec
- **Bối cảnh:** `docs/specs/vision.md` chưa sửa từ khi track (commit `88eeee1`). Từ đó có 3 chỗ lệch/thiếu:
  1. Conclusion ghi "Trang sách thì trôi đi" — sai từ Q-10 / ADR-029 (lưu 10 phiên đọc/collection có tên).
  2. Nguyên lý 5 bị vá chồng (đoạn "đã thu hẹp" → "đến 2026-09-18 mở lại" → khối "Cập nhật") — người đọc phải tự ghép.
  3. Vision không nói gì về ghi nhận tiến bộ → #6 từng bị diễn giải thành "chống gamification" (ADR-038 đã sửa ở tầng UX, vision chưa). Mục Retention không nhắc Cram (ADR-043).
  4. Vision chỉ được đọc khi mơ hồ (CLAUDE.md §6), không nằm trong luồng `/rplan` → feature được đề xuất trước khi đối chiếu nguyên lý.
- **In-scope:** `docs/specs/vision.md`, `.claude/commands/rplan.md`, `docs/agent/plan-template.md`, 1 ô trong bảng `CLAUDE.md` §3.
- **Out-of-scope / không đụng:**
  - **Không đổi 6 nguyên lý, không đổi tiêu đề `##` nào** — anchor đang được link từ `prd.md` (`#1-authentic-input-over-graded-readers`, `#4-context-is-the-memory-anchor`, `#5-durable-data-not-disposable-chat`, `#retention-is-a-solved-problem--use-the-solution`) và `prompt-spec.md`.
  - Không sửa Introduction, nguyên lý 1–4, mục "Philosophy" của bất kỳ nguyên lý nào.
  - Không đổi style link (repo dùng đường dẫn tính từ root, ví dụ `docs/specs/prd.md` — giữ nguyên).
  - Không ADR mới (đây là làm rõ, không phải quyết định mới — trỏ về ADR-029/038/043 có sẵn).
  - Không code, không `scripts/test.sh`.
- **Q mở:** không.

## Tầng 1 — HLD
- Chỉ docs + 1 slash command. Không Reado/ReadoKit, không transaction.
- File cấm: mọi thứ ngoài 4 file in-scope + journal/session-brief do `/rhandoff` đụng.

## Tầng 2 — Tasks

### T1 — vision-text
**File:** `docs/specs/vision.md`. Văn phong: tiếng Việt, giọng như phần còn lại của file; được chuốt câu nhẹ nhưng giữ đủ ý và các mã tham chiếu (Q-10, ADR-xxx, NFR-04, NG-04).

**(a) Nguyên lý 5 — viết lại phần phạm vi.**
Giữ nguyên: khối `> **Philosophy:**`, đoạn `**Với Reado:**` (đoạn đầu), đoạn `**Chống lại:**`.
Thay **toàn bộ** phần từ `**Phạm vi của nguyên lý này đã thu hẹp, và cần nói thẳng.**` đến hết khối `> **Cập nhật 2026-09-18 (Q-10 chốt, ADR-029):** …` (gồm 3 đoạn + 1 blockquote) bằng:

```markdown
**Phạm vi của nguyên lý này hẹp hơn bản đầu, và cần nói thẳng.** Thứ được giữ vĩnh
viễn là **từ vựng**. Artefact đọc — text trang, bản dịch song ngữ, tóm tắt — chỉ được
giữ trong phạm vi hẹp: **10 phiên đọc gần nhất của mỗi collection có tên**, đủ để mở
lại vài trang vừa đọc (Q-10, ADR-029). Phiên thứ 11 trôi đi; kho tạm không lưu phiên;
ảnh gốc không bao giờ được lưu (NFR-04).

Hai lý do cho giới hạn này: toàn văn trang sách là bề mặt bản quyền lớn hơn hẳn một
câu trích, và nhu cầu đọc lại có thật nhưng chỉ với vài trang gần nhất, không phải cả
cuốn. Lịch sử đảo chiều (bản đầu hứa lưu cả `segment` lẫn `summary`, bản sau cho mọi
thứ trôi, rồi chốt ở giữa) nằm ở ADR-029.
```

**(b) Nguyên lý 6 — thêm đoạn làm rõ SAU đoạn `**Chống lại:**` hiện có** (không sửa đoạn cũ):

```markdown
Nguyên lý này **không** cấm ghi nhận tiến bộ. Cho người dùng thấy số đo có thật — số
thẻ vừa ôn, từ vừa chạm ngưỡng "đã thuộc", chuỗi ngày ôn — là phản chiếu hành trình,
không phải thay thế nó. Thứ bị chặn là tiến bộ ảo: điểm/XP, huy hiệu không gắn với việc
đã làm, bảng xếp hạng (ADR-038, NG-04).
```

**(c) Mục "Retention Is A Solved Problem" — thêm 1 đoạn cuối mục** (sau đoạn "Reado không sáng tạo gì ở tầng này…"):

```markdown
Ôn thêm ngoài lịch (Cram, ADR-043) không phải ngoại lệ: lượt cram chỉ ghi log, không
đổi lịch mà scheduler đã tính.
```

**(d) Conclusion — sửa câu cuối.** Thay:
```
Reado chỉ đảm bảo rằng
mọi **từ** họ học được trên đường đi đều ở lại với họ. Trang sách thì trôi đi —
đó là đánh đổi có chủ ý ở nguyên lý 5.
```
bằng ý: mọi **từ** ở lại; trang sách phần lớn trôi đi, chỉ vài phiên gần nhất được giữ để đọc lại — đánh đổi có chủ ý ở nguyên lý 5. Giữ nguyên `> **Đọc sách thật. Không mất gì.**`.

**DoD T1:**
- `grep -n '^## ' docs/specs/vision.md` ra đúng 10 tiêu đề như trước (Introduction, 1–6, Retention…, Conclusion — so với `git show HEAD:docs/specs/vision.md | grep '^## '`).
- `grep -n 'trôi đi —' docs/specs/vision.md` không còn câu "Trang sách thì trôi đi — đó là…" nguyên dạng cũ.
- `grep -n 'Cập nhật 2026-09-18' docs/specs/vision.md` → rỗng.
- `git diff docs/specs/vision.md` chỉ đụng 4 chỗ (a)–(d).

### T2 — rplan-wiring
**Files:**
1. `.claude/commands/rplan.md` — bước 1 (**Spec**), nối thêm vào cuối câu đầu:
   `Đọc đủ \`docs/specs/vision.md\` (file ngắn, đọc nguyên) + non-goals \`grep -n 'NG-0' docs/specs/prd.md\` — feature phải chỉ ra phục vụ nguyên lý nào.`
   Không đổi các bước khác, không đổi frontmatter.
2. `docs/agent/plan-template.md` — trong khối `## Spec` của template, thêm một dòng ngay sau dòng `- FR / journey: …`:
   `- Nguyên lý: phục vụ #N (vision.md) · đụng mục "Chống lại" / NG nào (không → ghi "không")`
3. `CLAUDE.md` §3 — ô "Đọc khi nào" của hàng `docs/specs/vision.md`: `6 nguyên lý — resolver mọi chỗ mơ hồ` → `6 nguyên lý — đọc ở mỗi \`/rplan\` + resolver mọi chỗ mơ hồ`. Không sửa chỗ khác trong CLAUDE.md.

**DoD T2:** `git diff` 3 file trên, mỗi file đúng 1 hunk nhỏ như mô tả.

## Đóng session
- `/rhandoff`. Bước test: docs-only → **không** chạy `scripts/test.sh`, ghi rõ "docs-only, không build" (không ghi số test mới).
- Nếu có lệnh `/raudit`: chạy phần link/anchor cho `docs/specs/vision.md` để chắc anchor từ `prd.md`/`prompt-spec.md` còn sống.
- Khép plan: đánh dấu T1/T2 ✅ trong file này.
- Commit một commit: `docs(vision): vision-refresh-r1 — gọn nguyên lý 5, làm rõ #6 ghi nhận tiến bộ, nối vision vào /rplan`. Stage đích danh: `docs/specs/vision.md .claude/commands/rplan.md docs/agent/plan-template.md CLAUDE.md docs/plans/vision-refresh-r1.md` + file journal/session-brief mà `/rhandoff` sửa. **Không** `git add -A`, không stage `docs/plans/shell-chrome-r1.md`.
