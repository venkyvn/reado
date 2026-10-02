# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc ở Turn 1 session mới (`/rstart`), mục 1–2. Luật + cách làm việc: `CLAUDE.md`. Câu đang mở: `CLAUDE.md` §5.
> Chi tiết task đã xong: `docs/journal/` và `ROADMAP.md`. Mục 1 là mục lục, không phải nhật ký.

---

## 1. Tình trạng hiện tại (mục lục — chi tiết ở journal/plan, không lặp lại ở đây)

> Số test chính thức: hook `session-context.sh` tự nạp `.tmp/results/{last,kit}-summary.txt` — không ghi tay. **Chưa xem tay UI** nhiều màn: §2.7 mở được bằng `scripts/sim_screens.sh open <màn>`, còn chạy từng mục + đọc ảnh (verify-nav-r1 T3).

**Đang mở / hàng đợi**
- ux-redesign-r1 (draft 2026-10-01) — audit + IA hướng B (bỏ tab Ôn, Q-b chốt) + 14 task, chưa code; Q-a/c/d/e có mặc định. → `docs/plans/ux-redesign-r1.md`
- verify-nav-r1 (T1 ✅ T2 ✅, T3 chưa làm) — launch argument DEBUG + `sim_screens.sh open` mở thẳng một màn. → `docs/plans/verify-nav-r1.md`
- fsrs-queue-fix-r1 (T1 ✅ T2 ✅, **T3 hết chặn — chưa làm**). → `docs/plans/fsrs-queue-fix-r1.md`
- reencounter-r1 (T1 ✅ T2 ✅ T3 ✅-tạm, ADR-048) — FR-22 gặp lại từ cũ khi đọc. → `docs/plans/reencounter-r1.md`
- prompt-v6 (fen đã go, chưa bắt đầu) — dịch hay, `phrases` chạm-sáng, chọn sẵn top 5. → `docs/plans/prompt-v6.md`

**Đã khép gần đây** (một dòng mỗi task; chi tiết ở journal ngày tương ứng)
- 2026-10-01 → `docs/journal/2026-10-01.md`: fix-alert-sheet-dismiss-r1 (`AlertHostStack`) · master-rewrite-r1 (ADR-051) · extra-review-r1 "Ôn thêm 20" (ADR-050) · remove-proxy-r1 BYOK-only (ADR-049) · refactor-r2/r3/r4 · audit nhỏ sau refactor-r4.
- 2026-09-30 → `docs/journal/2026-09-30.md`: new-order-r1 (ADR-047) · vision-refresh-r2 · shell-chrome-r1.
- 2026-09-28 → `docs/journal/2026-09-28.md`: repo-hygiene-r1 (ADR-044/046) · cram-collection-r1 (ADR-043) · OCR `RecognizeDocumentsRequest` (ADR-042).

## 2. Chờ owner (không tự bắt đầu)

> Số mục giữ cố định — plan khác trỏ `§2.3`/`§2.4`/`§2.7`. Mục đã xong để lại một dòng gạch.

1. A-02: prompt baseline đã có ở `docs/agent/prompt-spec.md` §2. Còn thiếu: fen chấm output baseline vs app — `prompt-v6` T1 (replay Diagnostics) dựng bảng so.
2. ~~Ngưỡng leech FR-19~~ — đã chốt = 6 (`CLAUDE.md` §5).
3. Chốt hướng "Từ session này collect thêm" (J2 bước 7 — schema không có `session_id` trên `vocab_items`, `ROADMAP.md` §4): (a) thêm FK, (b) để R2, (c) bỏ bước khỏi J2.
4. Camera (ADR-036) permission-denied: fen test khi tiện — từ chối quyền camera có bật đúng nút "Mở Cài đặt" không. Không chặn.
5. ~~D-3~~ — đã trả lời (ADR-050): "Ôn thêm" ghi lịch FSRS thật; fsrs-queue-fix-r1 T3 hết chặn.
6. repo-hygiene-r1: repo `venkyvn/reado` public hay private? (ảnh `ref/sample` còn trong history cũ → public thì cần `git filter-repo`); key Gemini từng nằm trong `.env.example` (chưa commit) — rotate nếu dán ở nơi khác; `docs/sample.md` (untracked) và `.keep.json` (`{}`) — giữ hay xoá.
7. Xem tay UI còn treo (máy agent không có Simulator GUI) — gộp theo màn:
   - **Ôn thêm** (extra-review-r1): trộn đúng cũ+mới, Quên → due mai, lượt 2 không ra thẻ cũ, CTA Home mở đúng `.extra`, heatmap đổi màu rõ khi ôn nhiều.
   - **Alert lỗi** (refactor-r3): tạo/đổi tên bộ trùng, xoá/chuyển, ghim >5 — đã xem `-ReadoAlert dup-name|pin-limit` lúc không có sheet; `dup-name` trong sheet đã xem sau fix-alert-sheet-dismiss-r1.
   - **Reencounter** (reencounter-r1 T2/T3): gạch chân + "Nhận ra", hàng Home "Gặp lại N từ" (nghi N=0 — kiểm `SELECT kind, created_at FROM encounters`), thanh 4 màu/`MasteryRing`.
   - **Capture** (refactor-r4 T1): chip "Lưu vào", sheet chọn/tạo bộ.
   - **Settings** (remove-proxy-r1): ẩn agent builtin, lỗi "chưa có agent" khi chụp lúc chưa thêm key.
   - **Accent lệch** (master-rewrite-r1): `FloatShutter`/tab đang chọn ra xanh iOS dù theme Xanh rừng, trong khi `IconTile`/nút "Thêm" đúng — cả hai gọi `Color.accentColor`; chưa rõ nguyên nhân (`.tint` chưa áp? `glassEffect` không đọc `.tint` môi trường?).
   - (c) migration v3→v4 trên DB thật (cài đè bản cũ) — chưa làm.

## 3. Bẫy máy này

Bẫy cố định đã chuyển vào `CLAUDE.md` §7. Mục này chỉ ghi bẫy **mới** phát hiện ở session gần nhất, chưa kịp đưa vào CLAUDE.md.

- ReadoKit build tools 6.0 (strict concurrency) chặn `static var` thường ở top-level: "not concurrency-safe because it is nonisolated global shared mutable state". Test-only override (`DebugTrace.documentsDirectoryOverride`) phải khai `nonisolated(unsafe) static var` — chấp nhận được khi biết chắc không ghi đồng thời từ nhiều thread (test set 1 lần ở `setUp`/`tearDown`).

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
