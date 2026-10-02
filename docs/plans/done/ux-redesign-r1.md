# Plan: ux-redesign-r1 — Phase 0 (Audit) + Phase 1 (IA) + Phase 2 (Plan) cho Sonnet implement

> **Trạng thái:** ✅ KHÉP (2026-10-02) - T0–T11 xong. T0–T10 code + xem tay (fen xác nhận 3 luồng J1 trên máy thật, 3
> bug che/chồng/sai màu UI đã sửa). **T11 (docs)** xong: `docs/specs/journeys.md` Phần 1 viết lại theo IA 2 tab/phiên
> ôn/banner/5 pin, mọi dòng Journey drift xử lý (xem bảng dưới, cột cuối), bảng vỡ J-R1-S sửa, Phần 2 (DB schema PWA
> cũ) **bỏ theo fen duyệt 2026-10-02** — trỏ `docs/specs/db.md`. ADR-052/053/054 đã ghi vào `docs/decisions-log.md`.

## Context
`task.md`: fen muốn redesign UX/UI Reado cho chuyên nghiệp (không chỉ tô lại), mở khoá cấu trúc tab, shutter,
điểm vào Settings/Dữ liệu, Capture→Analysis, điều hướng sau Lưu. Fen giao Opus làm tự chủ Phase 0→2 (fen không
dừng ở Phase 1 để chọn hướng — Opus chọn hướng khuyến nghị, fen vẫn có thể đảo trước khi giao Sonnet), rồi
đem plan lên Claude cloud cho Sonnet implement từng task. Ghi chú bổ sung của fen: **code là nguồn sự thật cho
hiện trạng UI**, journeys.md chỉ dùng cho ý định (JTBD/FR/empty-error); prd.md + decisions-log.md thắng journeys.md;
cần bảng "Journey drift"; task cuối viết lại Phần 1 journeys.md.

**Giới hạn của audit này:** viết lúc ở plan mode nên không chạy simulator. Bằng chứng = đọc code (file:line) + 2 ảnh có
sẵn ở `.tmp/screens/` (`after2-home-forest-light.png`, `verify-alert-sheet-light.png`). Mọi màn khác = "chưa xem
tay" → T0 chụp baseline (trên Mac).

## Đã áp review (2026-10-01, `review.md`)
Đã đối chiếu từng góp ý với code trước khi áp:
- Áp nguyên: hero chỉ hiện onboarding khi `!hasFirstPage` (T2) · tách T1→T1a/T1b, T5→T5a/T5b · nhãn [cloud]/[mac] + commit
  ảnh then chốt (`.tmp/` bị ignore, ReadoKit link Vision nên không build trên Linux) · Hub bỏ nút chụp riêng (T6) · picker
  đích dùng `Menu` (T5a) · số chạm J4 từ Thư viện = 2 · T7 dùng cờ pending, không present 2 cover · `save()` bỏ `dismiss()`
  (T8) · banner không tự ẩn khi bật VoiceOver (T2) · thêm Q-e về badge.
- Thêm so với review: dòng cảnh báo `agentWarning` trên hero khi người dùng cũ có agent hỏng (T2/T3) — để lỗi agent không chỉ
  lộ ra lúc bấm chụp.
- Không áp: review đề nghị chỉ xin quyền thông báo khi toggle chuyển false→true. Không cần: `NotificationScheduler.apply`
  đã chỉ xin quyền khi `enabled`, và iOS chỉ hiện hộp thoại một lần (T8 ghi lại điều này).

## ⚠️ Rủi ro lớn nhất: Claude cloud không build được iOS
Claude Code trên cloud chạy sandbox Linux — không có Xcode/simulator → không chạy được `scripts/test.sh` (kể cả lane
`kit`) hay `sim_screens.sh`. Theo CLAUDE.md §7 "không chạy được simulator → không bịa số test, không ghi xong".
Quy trình bắt buộc cho mỗi task: Sonnet (cloud) code trên branch `ux-redesign-r1/Tn` → mở PR, mô tả ghi rõ "chưa build,
chưa xem tay" → fen kéo về Mac chạy `scripts/test.sh build` + `scripts/test.sh kit` + `sim_screens.sh` (hoặc mở một
session local) → sửa lỗi build → `/rhandoff` + merge. Không gộp 2 task chưa verify vào nhau.

Hai giới hạn nữa (đã kiểm):
- `.tmp/` nằm trong `.gitignore` (dòng 8) → ảnh ở `.tmp/screens/` không lên origin, cloud không thấy. Ảnh then chốt
  (Home, Analysis, Hub, Ôn mặt trước/sau, trước và sau redesign) copy sang `docs/investigations/ux-redesign-r1/screens/` rồi commit.
- `app/ReadoKit/Package.swift` link `Vision`/`ImageIO`/`CoreGraphics` → ReadoKit không build trên Linux. Cloud không có
  lane verify nào, kể cả task chỉ đụng ReadoKit.

Nhãn mỗi task: **[cloud]** = Sonnet code được, fen verify trên Mac sau · **[mac]** = cần simulator/đo ảnh ngay trong lúc làm, không giao cloud.

| Task | Nhãn |
|---|---|
| T0, T1b, T10 | [mac] |
| T1a, T2, T3, T4, T5a, T5b, T6, T7, T8, T9, T11 | [cloud] |

Thứ tự: T0 → T1a → T2 → T1b → T3 → T4 → T5a → T5b → T6 → T7 → T8 → T9 → T10 → T11.
T1a/T2/T5a/T5b/T6/T7/T8/T9 dùng được cho cả hướng A lẫn B.

## Sau khi fen review xong (chưa làm)
1. ~~Chốt Q-b~~ — đã chốt hướng B (2026-10-01). Q-a/c/d/e có mặc định, không chặn.
2. Khép diff accent đang treo (FloatShutter/ShellTabBar/MASTER/reado-ui skill): `scripts/test.sh build` → commit
   `fix(ui): accent trong glass đọc theo AppTheme`. Phải xong trước T1b vì T1b viết lại hai file này.
3. Tách Phase 0/1 sang `docs/investigations/ux-redesign-r1/{audit,ia-options}.md` — bắt buộc: mỗi session Sonnet chỉ cần
   Phase 2 + bảng vấn đề, đọc cả file là phí context. File này giữ link.
4. Đổi trạng thái sang `open`. Ghi ADR-052/053/054 vào `docs/decisions-log.md` (bản nháp ở cuối file). Thêm 1 dòng vào
   `docs/session-brief.md` §1.
5. Commit ảnh then chốt (T0) + push `main` lên origin.

---

# PHASE 0 — Audit

## Đếm chạm hiện trạng (từ code điều hướng `RootView.swift`)
| Journey | Đường đi hiện tại | Chạm |
|---|---|---|
| J1 chụp → lưu (kho tạm) | Shutter nổi → Chụp → Crop xong → (tự phân tích) → Lưu (n) → alert "Đã lưu" OK → **bị đẩy sang tab Home + push Hub kho tạm** | 5 |
| J2 đọc tiếp một bộ | Pin "Đang đọc" → Hub → shutter → Chụp → Crop → Lưu → OK | 6 |
| J4 ôn đến hạn | Tab Ôn → thẻ. Xong: "Về Home" (nghi không làm gì, xem P0-2) | 1 |
| J5 phạm vi | Tab Ôn → icon phạm vi → chọn → Áp dụng | 4 |
| J6 dọn kho tạm | Tab Kho → Kho tạm → Sắp xếp → chọn → Chuyển → chọn bộ | 5+ |
| Settings / Dữ liệu / Streak | Icon trên toolbar Home / icon trên toolbar Home / row streak | 1 / 1 / 1 |
| Người mới → lần chụp đầu | Checklist: Đúng (CEFR) → Thêm (agent) → điền form → Chụp | 4+form |

## Bảng vấn đề
| # | Vấn đề | Màn | Journey | Mức | Bằng chứng |
|---|---|---|---|---|---|
| 1 | FloatShutter đè lên nội dung list (che chữ row streak) — overlay không chừa chỗ ở cuối list | Home/Kho/Hub | J1 | P0 | `after2-home-forest-light.png`; `RootView.swift:107-125` |
| 2 | Tab Ôn: nút "Về Home" của SessionDone gọi `dismiss()` — trong tab không có gì để dismiss → **nút chết** (nghi, cần tap thử) | Ôn | J4 | P0 | `ReviewQueueView.swift:98-109`, `SessionDoneView.swift:45` |
| 3 | Đổi tab rồi quay lại Ôn → `onAppear` nạp lại hàng đợi, reset `tally`/con trỏ — mất màn tổng kết giữa phiên | Ôn | J4 | P1 | `ReviewQueueView.swift:153-169, 307-338` |
| 4 | Sau Lưu: alert chặn + ép đổi sang tab Home + push Hub, kể cả khi người dùng chụp từ tab Kho → mất định hướng | Analysis→Home | J1 | P1 | `AnalysisView.swift:184-197`, `RootView.swift:146-156` |
| 5 | Màn duyệt ghi "Đổi bộ ở màn chụp" nhưng không quay về được màn chụp → ngõ cụt khi chọn nhầm đích | Analysis | J1/J2 | P1 | `AnalysisView.swift:323-334`, ảnh `verify-alert-sheet-light.png` |
| 6 | CTA chính "Lưu (n)" là nút chữ nhỏ trên toolbar; nội dung đầu màn là "Đoạn gốc" dài → việc chính (duyệt từ) bị đẩy xuống dưới | Analysis | J1 | P1 | ảnh `verify-alert-sheet-light.png`; `AnalysisView.swift:321-402` |
| 7 | Bản dịch đoạn ẩn tới khi chạm "Dịch" từng đoạn — lệch ADR-030 (mặc định hiện + 1 nút ẩn/hiện toàn bộ) và NL2 | Analysis | J2 | P1 | `AnalysisView.swift:16-17, 336-347` so với `ReadingSessionView.swift:5-13` |
| 8 | Row từ trong Analysis: 5 dòng chữ (từ, pill, nghĩa, IPA, câu ví dụ) + pill + chevron bóp cột nghĩa → vượt "≤3 cấp mỗi row" | Analysis | J1 | P2 | ảnh `verify-alert-sheet-light.png`; `ReviewCardRow.swift` |
| 9 | Checklist onboarding: bước 3 tick xanh nhưng phụ đề "Cần kết nối agent trước" (phụ đề đọc `isEnabled`, không đọc `isDone`) | Home | Onboarding | P1 | `OnboardingChecklistSection.swift:97-112`; ảnh Home |
| 10 | Home có 4–6 khối ngang hàng (checklist, Ôn, Kho tạm, Streak, Gặp lại, Đang đọc) — không có 1 CTA chính nhận ra trong 1 giây; "Kho tạm" nằm trong "Hôm nay" sai nhóm | Home | J3/J4 | P1 | `HomeTabView.swift:52-65, 154-176` |
| 11 | Hai khái niệm "yêu thích" trùng nhau: Ghim (Home, ≤5) và Ưu tiên ôn (≤3, vuốt trong Kho) + nút "Ôn nhanh" ở đầu Kho đổi phạm vi của tab khác | Kho/Ôn | J5 | P1 | `KhoTabView.swift:17-38, 141-170` |
| 12 | Phạm vi ôn chỉnh ở 2 nơi, khác nhau: "Ôn nhanh" (lưu bền, ở Kho) vs picker trong Ôn (chỉ cho phiên) | Kho/Ôn | J5 | P1 | `KhoTabView.swift:18-38`, `ReviewQueueView.swift:128-142` |
| 13 | Ôn mở bằng 3 cách khác nhau: tab (Ôn), sheet (Hub "Ôn bộ này", Lịch streak) → chrome khác nhau (có/không nút Đóng, có/không thanh tab) | Ôn | J4/J5 | P1 | `RootView.swift:80-90`, `CollectionDetailView.swift:136-140`, `StreakCalendarView.swift:38` |
| 14 | Hub: header nặng (thanh 4 màu + legend + 3 ô số có chữ phụ) rồi tới Section riêng chỉ chứa toggle "Hiện trên Home" — CTA chính chìm giữa | Hub | J2 | P2 | `CollectionStatsHeader.swift`, `CollectionDetailView.swift:37-60` |
| 15 | Shutter nổi trên Hub ngầm chọn đích = bộ đang mở, không có gì trên UI nói điều đó | Hub | J2 | P2 | `RootView.swift:190-196`, `CollectionDetailView.swift:86-95` |
| 16 | Camera: nút "+" tạo bộ đứng riêng cạnh chip đích — 2 control cho 1 việc | Capture | J2 | P2 | `CaptureView.swift:196-228` |
| 17 | Settings trộn 2 kiểu lưu: Chủ đề áp ngay, các mục khác phải bấm "Lưu" (Nielsen #4 consistency) | Settings | J-R1-S | P2 | `SettingsView.swift:52-58, 266-276` |
| 18 | Không có trạng thái "vocab rỗng sau FR-10" trong Analysis (J1 yêu cầu nói rõ + CTA chụp lại) | Analysis | J1 | P1 | `AnalysisView.swift:351` (section ẩn im lặng) |
| 19 | Chưa có agent mà bấm shutter → chụp xong mới báo lỗi (phòng lỗi trước, Nielsen #5) | Capture | J1 | P2 | `RootView.swift:191-196` (không kiểm `activeAgentReady`) |
| 20 | Màn ôn rỗng hoàn toàn không có CTA sang chụp (J3: "Hết new và backlog = 0 → CTA sang J1/J2") | Ôn | J3 | P2 | `ReviewQueueView.swift:198-209` |
| 21 | Tên tab "Kho" lẫn với "Kho tạm" | Shell | — | P2 | `RootView.swift:13-19` |

Đã xem tay (2026-10-02, T0+T10): Hôm nay, Thư viện, Hub, Analysis, Settings, Streak, AX-XL (Hôm nay + Hub), theme
sepia (Hôm nay), 3 luồng J1 + banner "Xem" trên máy thật. Chưa xem tay: Ôn mặt sau (cần lật thẻ bằng tay), SessionDone,
Data, Capture, Reduce Motion, thứ tự VoiceOver thật (máy agent không có Simulator GUI để bật).

## Journey drift (journeys.md ↔ code) — ✅ xử lý xong ở T11 (2026-10-02)
| journeys.md | Code thực tế | Giữ ý định? | Kết quả T11 |
|---|---|---|---|
| §3 "Home tối đa **hai** named collection" (l.110) | `HomePinService.maxPins = 5` | Bỏ số 2 (code đúng); giữ "có giới hạn + chooser thay thế" | ✅ Sửa thành "năm", ghi `HomePinService.maxPins` |
| J-R1-S b.5 "Mục Đang đọc trên Home" trong Settings (l.350) | `SettingsView.swift:33-38` không có mục này; ghim ở Hub (`HomePinToggle`) + vuốt ở Kho | Bỏ | ✅ Bỏ bước, ghi "quản lý pin dời sang menu ⋯ Hub" |
| J1 b.6 "Toast / về Home" (l.131) | push Hub sau khi lưu (`RootView.swift:146-156`) | Giữ ý định "không bắt ở lại" → IA mới: banner, giữ nguyên chỗ đang đứng | ✅ Viết lại theo ADR-053 (`ShellBanner` "Xem") |
| J1 b.1 "Home hoặc FAB" | `FloatShutter` overlay | Viết lại: nút chụp trong thanh tab | ✅ Viết lại theo ADR-052 |
| Không mô tả cấu trúc tab | 3 tab Home/Ôn/Kho (`RootView.swift:8-36`), không có ADR | Viết lại theo ADR-052 | ✅ Thêm đoạn "Khung app (ADR-052)" đầu Phần 1 + ADR ghi vào decisions-log |
| J4 b.1 "Home → Ôn" | tab Ôn | Giữ ý định → Home hero mở phiên ôn | ✅ J3/J4 viết lại: hero/Hub/Lịch streak → `startReview` |
| J5 b.1 "Từ Home hoặc màn ôn mở scope picker" | Chỉ trong màn ôn + "Ôn nhanh" ở Kho | Giữ: picker trong phiên ôn + mục mặc định | ✅ J5 viết lại: picker trong phiên + section "Mặc định khi bấm Ôn" |
| J2 b.7 song ngữ "hiện sẵn + nút ẩn/hiện toàn bộ" (ADR-030) | ReadingSession đúng; **Analysis lệch** (chạm từng đoạn) | Giữ ý định → sửa code Analysis (T5b) | ✅ Code đã sửa ở T5b; journeys.md J2 b.7 ghi rõ Duyệt&lưu dùng chung cơ chế |
| J2 b.7 "control Hiện trên Home" trong session detail | `ReadingSessionView` không có | Bỏ (ghim ở Hub) | ✅ Bỏ khỏi J2 b.7 |
| J2 b.7 "Từ session này collect thêm" | Chưa làm (brief §2.3 chờ fen) | Giữ là mục mở, ngoài redesign | ✅ Giữ, ghi rõ "Mở — chưa làm" + trỏ brief §2 mục 3 |
| J2 b.1 "Collection picker" như màn riêng trước Hub | Không có; chọn đích ở chip camera | Bỏ màn riêng; giữ ý định chọn đích lúc chụp | ✅ Bỏ bước "Collection picker"; vào Hub từ Thư viện/pin |
| J-R1-D cửa Dữ liệu trên Home (`HomeTabView.swift:42-48`) | đúng code (trước redesign) | Đổi: menu ⋯ của Thư viện (ADR-052); giữ ý định "không đặt ở Settings" | ✅ J-R1-D viết lại: cửa vào = menu ⋯ Thư viện |
| J1 "Vocab rỗng sau FR-10 → nói rõ" | Analysis ẩn im lặng (trước T9) | Giữ → T9 | ✅ Code đã sửa ở T9; journeys.md khớp copy thật ("Không còn từ đáng học trên trang này") |
| FR-15/J-R1-S `cefr_level` **một** mức | Settings chip **nhiều** mức (`SettingsView.swift:100` "CEFR đa level") | **HỎI fen** (Q-a) | ⚠️ **BÁO LẠI, không tự sửa prd.md** (CLAUDE.md §6 bước 2) — journeys.md đã đổi theo code (nhiều mức, khớp `db.md` migration v3); `prd.md` FR-15 vẫn ghi số ít, owner cần xác nhận có sửa `prd.md` không |
| Phần 2 DB trỏ `syncDb.ts`/`migrate.ts`/`seed.ts` (l.611, 866, 873) | Code Swift; trùng `docs/specs/db.md` | Đề xuất bỏ Phần 2, trỏ db.md (fen duyệt trước khi xoá) | ✅ Fen duyệt 2026-10-02 (AskUserQuestion) — Phần 2 đã bỏ, trỏ `db.md`; luật `due_at` (bia mộ) chuyển vào `db.md` A.2.2 |

## Câu hỏi cho fen (không chặn T0–T2; trả lời trước task ghi trong ngoặc)
- ~~**Q-a** CEFR một hay nhiều mức?~~ **T11 áp mặc định (giữ code, sửa docs)** — nhưng đây là báo lại, không phải
  chốt: `prd.md` FR-15 vẫn ghi một mức, owner cần xác nhận có sửa `prd.md` theo code không (xem Journey drift dòng cuối-2).
- ~~**Q-b** Đồng ý bỏ tab Ôn (hướng B)?~~ **Chốt 2026-10-01: có, làm hướng B** (T1b bỏ tab Ôn và màn "Bắt đầu ôn" tạm của T1a).
- **Q-c** Settings tự lưu, bỏ nút "Lưu"? Mặc định: có (T8).
- **Q-d** Analysis mở mặc định tab "Từ vựng" (không phải "Trang")? Mặc định: Từ vựng (T5b).
- **Q-e** Badge trên tab Hôm nay: số / chấm / không có? Số đỏ tạo áp lực, lệch Retention "không cần học hết".
  Mặc định: chấm khi có thẻ đến hạn, không ghi số (T3).

---

# PHASE 1 — IA & Flow

Màn **Ôn mặt trước/sau** và **Capture** giống nhau ở cả 3 hướng (gesture ADR-025/033 giữ nguyên):
```
Ôn — mặt trước                Ôn — mặt sau
┌────────────────────────┐    ┌────────────────────────┐
│ ✕   Ôn tập 3/10   ⏷    │    │ ✕   Ôn tập 3/10   ⏷    │
│ ▓▓▓▓░░░░░░  [Hoàn tác] │    │ ┌────────────────────┐ │
│ ┌────────────────────┐ │    │ │ resilient          │ │
│ │                    │ │    │ │ kiên cường         │ │
│ │     resilient      │ │    │ │ /rɪˈzɪl.jənt/ 🔊   │ │
│ │      [adj] 🔊      │ │    │ │ "A resilient mind…"│ │
│ │                    │ │    │ │ ── Atomic Habits   │ │
│ └────────────────────┘ │    │ └────────────────────┘ │
│ Chạm để lật · ← Quên · Được → │ [Quên][Khó][Được][Dễ]│
└────────────────────────┘    └────────────────────────┘
```

## Hướng A — Giữ 3 tab, sắp lại (chi phí S)
```
Home                              Kho                         Hub bộ
┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│ ⚙                Reado│ │ Kho          ⋯   +   │ │ ‹  Atomic Habits  ⋯  │
│ ┌ Hôm nay ─────────┐ │ │ 📥 Kho tạm · 12 từ   │ │ Đã nhớ 40/120 ▓▓▓░░ │
│ │ 10 thẻ đến hạn   │ │ │ ── Bộ ──             │ │ [ Ôn bộ này · 6 ]   │
│ │ [  Ôn ngay  ]    │ │ │ Atomic Habits  ◔ 6   │ │ Phiên đọc (3/10)    │
│ └──────────────────┘ │ │ Sapiens        ◔     │ │ Từ vựng · 120       │
│ 🔥 5 ngày · 👁 3 từ  │ │                      │ │                      │
│ Đang đọc · 2/5       │ │                      │ │                      │
│ [Home][Ôn][Kho]  (📷)│ │ [Home][Ôn][Kho]  (📷)│ │ [Home][Ôn][Kho]  (📷)│
└──────────────────────┘ └──────────────────────┘ └──────────────────────┘
```
Sửa P0/P1 nhưng vẫn giữ tab Ôn ⇒ vẫn còn #2, #3, #13 (cần vá riêng), Home + tab Ôn cùng là cửa vào ôn.
Phục vụ NL6 vừa đủ. Rủi ro thấp. J1 5→4, J4 1→1.

## Hướng B — 2 tab "Hôm nay · Thư viện" + nút chụp trong thanh, Ôn là phiên toàn màn (chi phí M) ★ khuyến nghị
```
Hôm nay                           Thư viện                       Hub bộ
┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│ Hôm nay            ⚙ │ │ Thư viện      ⋯   +  │ │ ‹  Atomic Habits  ⋯  │
│ ┌──────────────────┐ │ │ ┌──────────────────┐ │ │ Đã nhớ 40/120        │
│ │ 10 thẻ đến hạn   │ │ │ │📥 Kho tạm        │ │ │ ▓▓▓▓▒▒░░░  ●●●●     │
│ │ ~6 phút · Tất cả⏷│ │ │ │12 từ chưa xếp  › │ │ │ Đến hạn 6 · +14 từ/7n│
│ │ [   Ôn ngay   ]  │ │ │ └──────────────────┘ │ │ [  Ôn bộ này · 6  ] │
│ └──────────────────┘ │ │ Bộ                   │ │                      │
│ 🔥 5 ngày   👁 3 từ › │ │ 📌Atomic Habits ◔ 6 │ │ Phiên đọc · 3/10     │
│ Đang đọc · 2/5       │ │   Sapiens       ◔    │ │  1/10 14:02 · Ý chính…│
│ 📌 Atomic Habits ◔ 6 │ │   Công việc ⚡  ◔    │ │ Từ vựng · 120        │
│ 📌 Sapiens       ◔   │ │                      │ │  resilient adj B2    │
│ ╭───────────────╮ ╭─╮│ │ ╭───────────────╮ ╭─╮│ │ ╭───────────────╮ ╭─╮│
│ │ Hôm nay│Thư viện│ │📷││ │ │ Hôm nay│Thư viện│ │📷││ │ │ Hôm nay│Thư viện│ │📷││
│ ╰───────────────╯ ╰─╯│ │ ╰───────────────╯ ╰─╯│ │ ╰───────────────╯ ╰─╯│
└──────────────────────┘ └──────────────────────┘ └──────────────────────┘
Hero theo trạng thái: chưa xác nhận CEFR → "Trình độ đọc: B2 [Đúng][Đổi]" · chưa có agent → "[Kết nối agent]"
· chưa có trang → "[Chụp trang đầu tiên]" · có đến hạn → "[Ôn ngay]" · hết hạn, còn ôn thêm → "[Ôn thêm 20 thẻ]"
· xong → "Xong phần hôm nay ✓" + link "Chụp trang mới".

Duyệt & lưu (sheet)                          Sau Lưu (đang đứng chỗ cũ)
┌──────────────────────────────┐            ┌──────────────────────┐
│ ✕     Duyệt trang             │            │ … màn trước đó …     │
│ Lưu vào: Kho tạm          ⏷  │            │ ┌──────────────────┐ │
│ [ Từ vựng · 12 |  Trang  ]   │            │ │✓ Đã lưu 8 từ vào │ │
│ Chọn tất cả      Đã chọn 8/12│            │ │ Kho tạm     Xem ›│ │
│ ☑ setback  noun B2  ✓        │            │ └──────────────────┘ │
│   sự vấp ngã, trở ngại     ⌄ │            │ ╭─────────────╮ ╭─╮  │
│ ☐ keystone noun C1  ⚠        │            └──────────────────────┘
│ ┌──────────────────────────┐ │
│ │   Lưu 8 từ vào Kho tạm   │ │  ← nút prominent ghim đáy
│ └──────────────────────────┘ │
└──────────────────────────────┘
Tab "Trang": EN + VI hiện sẵn từng đoạn, nút đáy "Ẩn bản dịch" (ADR-030), gạch chân từ đã có (FR-22), "Ý chính" thu gọn dưới cùng.
```
- **Vòng lặp đọc→khựng→giữ→ôn→nhận ra:** Hub gom đủ một vòng (chụp vào bộ · phiên đọc · ôn bộ này · thanh "Đã thấm");
  Home chỉ trả lời "hôm nay làm gì". Ôn thành phiên tập trung (giống Anki iOS: chọn bộ → học toàn màn).
- **Phục vụ:** NL3 (đích lưu đổi được trước khi lưu, duyệt từ là việc chính của sheet), NL2 (bản dịch hiện sẵn), NL6
  (hero chỉ số thật, không thêm gamification), Retention ("mỗi ngày vài từ": một CTA, không bảng tồn).
- **Đánh đổi:** mất cửa Ôn luôn hiện ở đáy màn hình (bù bằng hero + badge số đến hạn trên tab Hôm nay); Dữ liệu sâu thêm 1 chạm.
- **Rủi ro:** viết lại shell (RootView/ShellTabBar) — hằng số đo shutter phải đo lại bằng ảnh; `pendingReviewMode`/
  `pendingHubNavigationID` đổi cơ chế.
- **Chạm:** J1 5→**4** (bỏ alert OK, không bị đẩy tab) · J2 6→**5** · J4 1→**1** từ Hôm nay / **2** từ Thư viện (hiện
  tại 1 từ mọi tab; app mở mặc định ở Hôm nay nên ca phổ biến vẫn 1) · J5 4→4 · Dữ liệu 1→3.
- Hub chỉ có 1 CTA chính (Ôn). Chụp vào bộ = nút chụp trên thanh khi đang mở Hub; chip đích ở camera ghi tên bộ (giải #15 ở camera).

## Hướng C — "Bộ sách" làm trục: 1 màn gốc Thư viện + Hub dày (chi phí L)
```
Gốc (không tab)                    Hub bộ = màn làm việc chính
┌──────────────────────┐          ┌──────────────────────┐
│ Reado            ⚙ ⋯ │          │ ‹ Atomic Habits      │
│ ┌ Hôm nay: Ôn 10 ┐   │          │ [Đọc][Ôn 6][Từ 120]  │  ← segmented trong Hub
│ └────────────────┘   │          │ … nội dung theo tab… │
│ Đang đọc             │          │                      │
│ ▣ Atomic   ▣ Sapiens │ (lưới)   │              ( 📷 )  │
│ Kho tạm · 12 từ      │          └──────────────────────┘
│              ( 📷 )  │
└──────────────────────┘
```
Vòng lặp hiện rõ nhất trong từng bộ, nhưng J1 (chụp nhanh không chọn bộ) và ôn toàn kho thành công dân hạng hai;
bỏ tab bar = viết lại gần hết điều hướng + Hub; rủi ro cao. J4 1→1, J1 5→4.

## Trả lời 7 câu hỏi (theo hướng B)
1. **Vòng lặp có hiện ra không?** Hiện tại bị chia vụn: chụp (nút nổi) · đọc lại (Hub) · ôn (tab) · nhận ra (dòng
   Home không bấm được). B gom vào Hub; "Gặp lại N từ" trên Home bấm được, mở danh sách từ đã thấm (T3).
2. **Home vs Kho trùng vai trò?** Có: "Đang đọc" và Kho tạm nằm ở cả hai. B: Home chỉ giữ pin (lối tắt), Kho tạm chỉ ở Thư viện.
3. **Settings + Dữ liệu trên toolbar Home?** Settings giữ (⚙ góc phải, quy ước iOS). Dữ liệu là việc của thư viện → menu ⋯ Thư viện.
4. **Sau Lưu nhảy vào Hub có hiểu không?** Không — bị đổi tab ngầm. B: ở nguyên chỗ + banner "Xem ›".
5. **Chọn đích lúc chụp rõ chưa?** Chip đủ rõ, không cản chụp, nhưng không sửa được sau khi chụp. B: chip giữ, gộp nút "+" vào
   picker, cho đổi đích ở đầu màn duyệt.
6. **Gộp điểm vào Ôn?** Có: một phiên ôn toàn màn duy nhất (`ReviewSession`), mở từ hero Home, Hub, Lịch streak; phạm vi chọn trong phiên.
7. **Người mới tới lần chụp đầu:** hiện 4 chạm + form, nhưng 3 bước dàn ngang. B: vẫn 4 chạm, mỗi lúc chỉ 1 CTA trong hero; bấm
   shutter khi chưa có agent → mở thẳng form agent thay vì chụp rồi báo lỗi.

**Không đề xuất đổi** look FROZEN (glass vẫn chỉ ở chrome nổi: capsule tab + nút chụp) và gesture vuốt.

---

# PHASE 2 — Plan `ux-redesign-r1` (khung plan-template)

## Spec
- FR / journey: FR-01..05/09/12/14/17/18/21/22 · J1–J6, J-R1-S/D/P — GWT giữ nguyên, chỉ đổi vị trí/điều hướng.
- Nguyên lý: #2 (bản dịch hiện sẵn ở Analysis), #3 (đổi đích + duyệt từ là việc chính), #6 (hero số thật). Không đụng mục "Chống lại".
- In-scope: shell 2 tab + nút chụp trong thanh, phiên ôn toàn màn, Home hero, Thư viện, Hub, luồng Capture→Analysis→Lưu, Settings tự lưu, empty/error.
- Out-of-scope: ReadoKit logic nghiệp vụ/DB/prompt/FSRS/transaction, gesture, look FROZEN, dependency mới, "Từ session này collect thêm".
- Q mở: Q-a..Q-d ở trên (có mặc định, không chặn).

## Tầng 1 — HLD
- Reado (app): hầu hết thay đổi. ReadoKit chỉ thêm logic thuần có test: `HomeHero` (chọn trạng thái hero),
  và case mới trong `Shell/DebugLaunch.swift` (+ test parse).
- Không đổi protocol/transaction. `saveSelection`, `grade`, `undoReview`, `ReviewScopeService`, `HomePinService` gọi như cũ.
- File cấm: `project.pbxproj` (thêm file = tạo trong `app/Reado/**`), `docs/specs/db.md`, mọi file `ReadoKit/**` ngoài 2 chỗ trên.
- Mỗi task: đọc skill `reado-ui` + `docs/agent/coding-conventions.md` trước; sheet/cover mới gắn `.appErrorAlert()` ở gốc.

## Tầng 2 — Tasks (1 task = 1 session = 1 PR; nhãn [cloud]/[mac] như mục ⚠️)

Mọi task: DoD có `[ ] scripts/test.sh build xanh` (fen chạy trên Mac nếu [cloud]) và `[ ] PR ghi rõ màn nào "chưa xem tay"`;
"Không làm" liệt kê phần thuộc task khác để Sonnet không lấn sang.

### T0 — Baseline ảnh (không sửa code) [mac]
- Chạy mỗi màn `DebugLaunch.Screen` (`home, kho, review, review-extra, collection:<id>, settings, streak, data, capture,
  analysis-fixture, encounter-sheet`) với `--seed demo-reviewed --fresh`, `shot` light/dark, `size accessibility-extra-large`
  + shot, home + review thêm `--theme sepia`; empty: `open home --seed empty --fresh`. Ảnh → `.tmp/screens/ux-before/`.
- Copy ảnh then chốt (Home, Analysis, Hub, Ôn mặt trước/sau, Home empty) sang `docs/investigations/ux-redesign-r1/screens/before-*.png` và commit.
- Xác nhận/bác P0-1, P0-2, P1-3 (tap tay trên simulator nếu cần); cập nhật cột "Bằng chứng" trong bảng vấn đề ở Phase 0.
  **Đã xác nhận (2026-10-02):** P0-1 (FloatShutter đè nội dung) hết hẳn — nút chụp giờ trong thanh, không còn overlay
  nổi (ảnh before/after-home). P0-2 (nút "Về Home" chết) và P1-3 (mất tổng kết khi đổi tab) hết theo kiến trúc mới —
  tab Ôn không còn tồn tại, phiên ôn là `fullScreenCover` che cả thanh tab nên không đổi tab giữa phiên được nữa.
- Không làm: sửa code.
- DoD: [x] bảng vấn đề không còn "chưa xem tay" ngoài màn cần AI thật [x] ảnh then chốt đã commit.

### T1a — Phiên ôn toàn màn (giữ 3 tab) [cloud]
- Files: mới `App/ReviewLauncher.swift`, `App/RootView.swift`, `App/AppState.swift`, `Review/ReviewQueueView.swift`,
  `Review/SessionDoneView.swift`, `Library/CollectionDetailView.swift`, `Home/StreakCalendarView.swift`, `Home/HomeTabView.swift`.
- Trước → sau:
  - `ReviewRequest { scope: Set<String>?, mode: ReviewMode }` (Identifiable); RootView giữ `@State reviewRequest` +
    `.fullScreenCover(item:)` → `NavigationStack { ReviewQueueView(initialScope:, initialMode:) }` + `.appErrorAlert()`.
    Expose `EnvironmentValues.startReview: (ReviewRequest) -> Void`. Hub (`CollectionDetailView.swift:136-140`), Lịch streak,
    Home (row "Ôn tập hôm nay" / "Ôn thêm") dùng env này, bỏ sheet riêng. Home mở với `scope = model.reviewScopeDefault.scopeSet`.
  - Tab Ôn tạm thời: root là màn "Bắt đầu ôn" (số thẻ đến hạn, phạm vi mặc định, nút prominent gọi `startReview`).
    Bỏ ở T1b nếu Q-b = B; giữ làm màn tổng quan nếu Q-b = A.
  - Bỏ `ShellSignals.pendingReviewMode`, nhánh `showsCloseButton == false` trong ReviewQueueView (luôn có nút ✕),
    `.safeAreaPadding(reservedHeight)` của tab Ôn.
  - SessionDone: "Về Home" → "Xong" (dismiss cover). onDismiss cover → `model.reloadOverview()`; Hub refresh qua `dataRevision` (kiểm có bump).
  - DebugLaunch: `review`/`review-extra` mở cover (sửa nhánh trong `RootView.applyDebugScreenIfNeeded`, không đổi ReadoKit).
- Sửa: #2, #3, #13 — có giá trị ở cả hướng A và B.
- Không làm: đổi `AppTab`, đụng ShellTabBar/FloatShutter (T1b).
- DoD: [ ] build xanh [ ] `open review|review-extra|collection:<id>` mở cover [ ] ✕ về đúng tab cũ [ ] chấm hết → "Xong" đóng được
  [ ] cover che thanh tab nên không đổi tab giữa phiên, tally không mất.

### T1b — Shell 2 tab + nút chụp trong thanh [mac]
- Files: `App/RootView.swift`, `App/ShellTabBar.swift`, `App/FloatShutter.swift` (xoá hoặc thu thành `ShellCaptureButton`),
  `App/AppState.swift`, `Home/HomeTabView.swift` (toolbar), `ReadoKit/Shell/DebugLaunch.swift`.
- Trước → sau:
  - `AppTab` 3 case → 2: `.today` ("Hôm nay", `sun.max`/`.fill`), `.library` ("Thư viện", `books.vertical`/`.fill`). Bỏ tab Ôn + màn "Bắt đầu ôn" của T1a.
  - Thanh: capsule 2 tab + nút chụp tròn glass **cùng hàng** bên phải (kiểu nút Search tách của iOS 26), cao bằng capsule.
    Bỏ overlay `FloatShutter` + `shutterGap`. Nút chụp ẩn khi vào route sâu (streak/settings/data/phiên đọc) — giữ
    `isCaptureSurface` + `suppressFloatShutter`.
  - **Đo lại `reservedHeight` bằng ảnh** (vì vậy [mac]).
  - Route `.data` sang stack Thư viện; Home toolbar chỉ còn ⚙ (góc phải); `pendingSettingsNavigation` → tab `.today`.
  - DebugLaunch: `kho` giữ làm alias cho `.library` (không phá script cũ) + test parse.
- Không làm: nội dung Home/Thư viện (T3/T4).
- DoD: [ ] build xanh [ ] `open home|kho|collection:<id>` light/dark + AX-XL [ ] nút chụp không đè nội dung (đọc PNG)
  [ ] cuộn ẩn/hiện chrome vẫn chạy.

### T2 — Component dùng chung + logic hero [cloud]
- Files: mới `ReadoKit/Home/HomeHero.swift` (+ `ReadoKitTests/HomeHeroTests.swift`), mới `Shared/HeroCard.swift`,
  mới `Shared/ShellBanner.swift`, `ReadoKit/Shell/DebugLaunch.swift`.
- `HomeHero.resolve(cefrConfirmed:, agentReady:, hasFirstPage:, dueToday:, extraAvailable:, backlog:) -> State` với
  `.confirmCefr / .connectAgent / .firstCapture / .review(n) / .extra(n) / .done`.
- **Luật ưu tiên:** trạng thái onboarding (`confirmCefr/connectAgent/firstCapture`) **chỉ** khi `!hasFirstPage`. Đã có trang
  → luôn `review/extra/done`, kể cả khi agent hỏng (key hết hạn). Lý do: bỏ tab Ôn thì hero là cửa ôn chính — agent hỏng không
  được giấu thẻ đến hạn (code hiện tại hiện lại checklist trong ca này, `OnboardingChecklist.swift:45-47`). Agent hỏng thể
  hiện bằng `agentWarning: Bool` đi kèm state (dòng phụ, không phải CTA) + chặn lúc bấm chụp (T9).
  CEFR dùng lại `OnboardingChecklist.isDone(.cefr)` (`= cefrConfirmed || hasFirstPage`).
- Test bắt buộc trong `HomeHeroTests` (≥7 ca): người mới từng bước (3 ca) · có trang + agent hỏng + due>0 → `.review` +
  `agentWarning` · có trang + agent hỏng + due=0 + extra>0 → `.extra` · có trang + due>0 → `.review` · hết sạch → `.done`.
- Cờ `reado.onboarding.dismissed` thành vô dụng (hero tự hết onboarding khi có trang) → để nguyên key, không đọc nữa.
- `HeroCard`: title (`Typo.rowTitle`/`.title3`), subtitle (`Typo.meta`), 1 nút `.borderedProminent .controlSize(.large)`,
  link phụ tuỳ chọn, dòng cảnh báo tuỳ chọn (`Theme.warn`); nền `card()`.
- `ShellBanner`: banner không chặn ở đáy (trên thanh tab), icon + 1 dòng + nút "Xem" + nút ✕, `Motion.run` + `revealTransition()`,
  `AccessibilityNotification.Announcement`. Tự ẩn sau 4s; **khi `UIAccessibility.isVoiceOverRunning` thì không tự ẩn**
  (đóng bằng ✕) — WCAG 2.2.1. Không thư viện toast.
- DebugLaunch thêm `-ReadoScreen save-banner` (hiện banner mẫu) + test parse.
- Không làm: gắn hero/banner vào màn thật (T3/T5a).
- DoD: [ ] fen chạy `scripts/test.sh kit` xanh (HomeHeroTests ≥7 ca) [ ] `open save-banner` light/dark.

### T3 — Màn Hôm nay [cloud]
- Files: `Home/HomeTabView.swift`, `Home/OnboardingChecklistSection.swift` (xoá, logic vào hero), `App/RootView.swift` (badge), `App/AppModel*.swift` (chỉ đọc state sẵn có).
- Sau: title "Hôm nay"; `HeroCard` theo `HomeHero` (bước CEFR có 2 nút Đúng/Đổi; agent mở `AgentFormSheet`; review/extra mở
  `startReview`; `agentWarning` → dòng "Agent chưa chạy được — chụp sẽ không phân tích được · Sửa" mở Settings).
  Dòng phụ hero "Phạm vi: Tất cả ⏷" mở `ScopePickerSheet` mặc định. Hàng chỉ số gọn: 🔥 streak (→ Lịch) · 👁 Gặp lại N (ẩn khi 0).
  Section "Đang đọc · k/5" giữ. Bỏ row Kho tạm, bỏ section checklist. Badge tab Hôm nay theo Q-e (mặc định: chấm khi
  `dueToday > 0`, không số). Sửa luôn lỗi phụ đề bước chụp (#9) nhờ hero.
- Không làm: Thư viện (T4), phiên ôn (T7).
- DoD: [ ] build xanh [ ] `open home` với `--seed empty` (hero CEFR→agent), `demo` (Ôn ngay), `demo-reviewed`; light/dark/AX-XL/sepia.

### T4 — Thư viện [cloud]
- Files: `Library/KhoTabView.swift` (đổi tên `LibraryTabView.swift` bằng `git mv`), `Review/ScopePickerSheet.swift`.
- Sau: title "Thư viện"; card Kho tạm đầu màn ("N từ chưa xếp ›" → Hub kho tạm); Section "Bộ"; vuốt Ghim/Ưu tiên giữ nguyên.
  Toolbar: `+` Tạo bộ, `⋯` Menu {Nhập CSV, Xuất dữ liệu} → push `.data`. **Bỏ** section "Ôn nhanh"; chuyển nút bật
  "Tất cả kho / N/3 bộ ưu tiên" (`setReviewAll`) vào `ScopePickerSheet` thành section "Mặc định khi bấm Ôn" (footer: "Vuốt một bộ trong Thư viện để ưu tiên").
  Empty: chỉ có kho tạm → section Bộ hiện gợi ý "Tạo bộ theo tên sách" + nút.
- Không làm: Hub (T6), màn Dữ liệu (T8).
- DoD: [ ] build xanh [ ] `open kho` demo/empty [ ] mở picker trong phiên ôn thấy section mặc định.

### T5a — Đích lưu + Lưu không chặn [cloud]
- Files: `Analysis/AnalysisView.swift`, `Capture/CaptureView.swift`, `Capture/CaptureView+Destination.swift` → tách
  `Shared/CollectionDestinationPicker.swift`, `App/AppModel+Capture.swift`, `App/AppState.swift`, `App/RootView.swift`,
  `Shared/ShellBanner.swift` (dùng, không viết mới).
- Sau:
  - Picker đích dùng chung là **`Menu`** (không sheet): Kho tạm · các bộ · Divider · "Tạo bộ mới…". Analysis đã là sheet →
    sheet picker + alert tạo bộ = 3 tầng modal, vượt luật ≤2. "Tạo bộ mới…" mở alert có TextField (1 tầng). Camera bỏ nút "+" riêng.
  - Analysis: dòng "Lưu vào: X ⏷" → Menu đổi `analysisTargetCollectionID`; bỏ footer "Đổi bộ ở màn chụp".
  - Nút đáy `safeAreaInset` prominent "Lưu N từ vào X" (disabled khi 0); bỏ nút Lưu trên toolbar.
  - Lưu thành công: bỏ alert; `Haptics.success()`; set `shell.saveConfirmation = SaveConfirmation(count, collectionID, name)`; dismiss.
    RootView onDismiss: **không** đổi tab/push; hiện `ShellBanner` "Đã lưu N từ vào X · Xem" → push `.hub(id)` trên stack tab
    hiện tại (đang ở đúng Hub → chỉ refresh). Bỏ `pendingHubNavigationID`. **Giữ** `pendingRecapture` + `pendingSettingsNavigation`.
    Lỗi lưu giữ alert.
- Không làm: segmented / song ngữ / row từ (T5b).
- DoD: [ ] build xanh [ ] `open analysis-fixture` đổi đích được [ ] lưu → banner, không nhảy tab [ ] J1 = 4 chạm.

### T5b — Bố cục màn duyệt [cloud]
- Files: `Analysis/AnalysisView.swift`, `Analysis/ReviewCardRow.swift`, `Analysis/AnalysisComponents.swift`, `ReadoKit/Shell/DebugLaunch.swift`.
- Sau: segmented `Từ vựng · N | Trang` (mặc định theo Q-d). Tab Trang: EN+VI hiện sẵn, nút đáy "Ẩn/Hiện bản dịch" + chạm
  đoạn lật riêng (chép cơ chế `ReadingSessionView.swift:5-13`), "Ý chính" thu gọn cuối. Row từ: ≤3 tầng chữ khi đóng
  (từ+pill · nghĩa · 1 dòng meta); IPA/câu ví dụ chỉ hiện khi mở. DebugLaunch thêm `analysis-fixture-page` + test parse.
- Không làm: đích lưu / banner (T5a), empty vocab (T9).
- DoD: [ ] build xanh [ ] `open analysis-fixture-page` thấy VI hiện sẵn [ ] AX-XL row không vỡ.

### T6 — Hub bộ [cloud]
- Files: `Library/CollectionDetailView.swift`, `Library/CollectionStatsHeader.swift`, `Home/HomePinToggle.swift`.
- Sau: header = "Đã nhớ X/Y" + thanh 4 màu + legend, một dòng meta "Đến hạn N · +M từ/7 ngày · Lần ôn tiếp …" (bỏ 3 ô).
  CTA chính theo ngữ cảnh (giữ logic hiện tại). **Không** thêm nút "Chụp trang vào bộ này" → Hub chỉ 1 CTA chính; nút chụp
  trên thanh đã ngầm chọn đích = bộ đang mở và chip ở camera ghi tên bộ (#15 giải ở camera); chụp vào bộ khác thì đổi ở chip
  hoặc ở màn duyệt (T5a). Toggle "Hiện trên Home" → menu ⋯ ("Ghim lên Hôm nay"/"Bỏ ghim", giữ chooser thay thế khi đủ 5 của
  `HomePinToggle`). Ôn qua `startReview`.
- Không làm: phiên đọc (`ReadingSessionView`), phiên ôn (T7).
- DoD: [ ] build xanh [ ] `open collection:<id>` (bộ có tên + kho tạm), AX-XL [ ] menu ghim khi đủ 5 (`--alert pin-limit`).

### T7 — Phiên ôn hoàn thiện [cloud]
- Files: `Review/ReviewQueueView*.swift`, `Review/SessionDoneView.swift`, `App/AppState.swift`, `App/RootView.swift`.
- Sau: chrome cover thống nhất (✕ trái, tiêu đề + phạm vi ⏷ phải); doneView "Đóng". Empty "Không có gì cần ôn" khi kho rỗng
  thêm CTA "Chụp trang": set `shell.pendingCaptureAfterReview = true` → dismiss cover → RootView `onDismiss` của cover đọc cờ
  rồi mới `showCapture = true` (không present 2 cover cùng lúc, cùng kiểu `pendingRecapture`).
- Không làm: gesture, nút chấm, nhãn nhịp ôn.
- DoD: [ ] build xanh [ ] `open review`, `review-extra` với demo / demo-reviewed / empty [ ] chấm hết [ ] Reduce Motion
  [ ] empty → "Chụp trang" mở camera sau khi cover đóng hẳn.

### T8 — Settings, Dữ liệu, Lịch streak [cloud]
- Files: `Settings/SettingsView.swift`, `Library/ExportView.swift`, `Home/StreakCalendarView.swift`.
- Sau: Settings tự lưu (Q-c): Picker/Toggle/chip CEFR gọi `save()` ngay khi đổi; ô "Thẻ mới mỗi ngày" khi submit/mất focus
  (vẫn `clampNewLimit`). `save()` **bỏ `dismiss()`** (`SettingsView.swift:348`) — đang ở màn thì phải ở lại. Bỏ nút "Lưu".
  Lỗi lưu: dòng đỏ inline dưới section vừa đổi, giá trị UI giữ nguyên để sửa lại. CEFR bỏ hết chip → không lưu, hiện
  "Chọn ít nhất 1 mức". Quyền thông báo: không cần logic mới — `NotificationScheduler.apply` chỉ xin quyền khi `enabled`
  (`NotificationScheduler.swift:15-21`) và iOS chỉ hiện hộp thoại một lần.
  Thứ tự section: Agent phân tích (lên đầu khi chưa có agent) → Học tập → Nhắc ôn → Giao diện. Lịch streak: CTA ôn dùng `startReview`.
- Không làm: form agent (`AgentFormSheet`), nội dung Xuất/Nhập.
- DoD: [ ] build xanh [ ] `open settings`, `data`, `streak` [ ] đổi giá trị → rời màn → mở lại còn giữ [ ] đổi giá trị không pop màn.

### T9 — Empty / error còn thiếu [cloud]
- Analysis: vocab rỗng sau FR-10 → "Không còn từ đáng học trên trang này" + [Chụp lại] [Đóng] (vẫn cho đọc tab Trang).
- Bấm nút chụp khi `!model.activeAgentReady` → sheet `AgentFormSheet` (hoặc alert "Cần kết nối agent" + [Thêm agent]) thay vì mở camera.
- Rà mọi màn: loading/empty/error/success có thiết kế (cập nhật bảng trong audit).
- Không làm: copy/bố cục ngoài các state trên.
- DoD: [ ] build xanh [ ] `open home --seed empty --fresh` → bấm chụp ra form agent [ ] fixture rỗng (thêm `scripts/fixtures/analysis-empty.json` nếu cần).

### T10 — Motion / haptic / a11y + vòng ảnh cuối [mac] ✅ (2026-10-02)
- Rà `Haptics.*`/`Motion.*`, thứ tự VoiceOver (hero → chỉ số → list), vùng chạm ≥44pt, AX-XL, 2 accent, light/dark mọi màn.
- Cập nhật `design-system/reado/MASTER.md`: ngoại lệ `FloatShutter` → nút chụp trong thanh; luật banner; checklist.
- So `.tmp/screens/ux-before/` với `ux-after/`; ảnh then chốt sau redesign → `docs/investigations/ux-redesign-r1/screens/after-*.png`, commit.
- Không làm: tính năng mới.
- DoD: [x] checklist MASTER đủ cho mọi màn [x] ảnh after đã commit.
- **Kết quả:** AX-XL + 2 accent (forest/sepia) xem bằng ảnh — layout không vỡ. VoiceOver order + Reduce Motion chỉ
  kiểm được qua code (máy agent không có Simulator GUI để bật thật) — fen xác nhận bằng máy thật: 3 luồng J1 (Hôm
  nay/Thư viện/Hub) + banner "Xem" đều đúng; 3 bug che/chồng/sai màu UI (List cuối màn, CTA Lịch streak, accent
  `ShellTabBar`/`ShellCaptureButton` không đổi theo theme) đã sửa và fen xác nhận hết lỗi trên máy thật. Bug accent
  sửa bằng cách đọc thẳng `AppTheme` từ `@AppStorage("appTheme")` thay vì `Color.accentColor`/`.tint` (không đáng
  tin cho view tự vẽ) — ghi lại pattern ở MASTER.md mục Màu.

### T11 — Docs (cuối) [cloud] ✅ (2026-10-02)
- Viết lại Phần 1 `docs/specs/journeys.md` theo IA mới (2 tab, phiên ôn, banner sau lưu, đổi đích ở màn duyệt, 5 pin), xử lý
  từng dòng bảng Journey drift, sửa bảng vỡ J-R1-S (l.355-372), cập nhật metadata đầu file; FR-07/FR-13 bia mộ giữ nguyên.
- Đề xuất bỏ Phần 2 (DB, trùng `db.md`, trỏ code TypeScript cũ) — **hỏi fen trước khi xoá**.
- `docs/session-brief.md`, `ROADMAP.md` (grep dòng liên quan), khép plan.
- Không làm: sửa code.
- DoD: [x] mọi dòng Journey drift đã xử lý hoặc ghi lý do giữ [x] fen duyệt việc bỏ Phần 2.
- **Kết quả:** fen chốt qua `AskUserQuestion` (2026-10-02) — bỏ hẳn Phần 2 (trỏ `db.md`, luật `due_at` chuyển vào
  `db.md` A.2.2), ghi ADR-052/053/054 ngay trong T11 (không để session riêng). Journey drift: 14/15 dòng viết lại
  thẳng vào journeys.md; 1 dòng (CEFR một/nhiều mức) là **báo lại cho owner**, không tự sửa `prd.md` — xem bảng
  dưới cột "Kết quả T11". Thêm mục "8. Drift đã xử lý" cuối Phần 1 tóm tắt cho session sau không phải đọc lại
  bảng này trong plan đã đóng.

## ADR — ✅ đã ghi vào `docs/decisions-log.md` (T11, 2026-10-02)
- **ADR-052** — Shell 2 tab "Hôm nay · Thư viện", nút chụp trong thanh, Ôn là phiên toàn màn. Lý do: #1, #2, #3,
  #10, #13 trong audit. Làm ở T1a (phiên ôn dạng cover) + T1b (2 tab + nút chụp).
- **ADR-053** — Lưu từ không chặn: banner thay alert, giữ nguyên chỗ đứng; đổi đích được ở màn duyệt; bản dịch
  Analysis hiện sẵn theo ADR-030. Làm ở T5a (đích + banner) + T5b (bản dịch, bố cục).
- **ADR-054** — Onboarding gộp vào hero Home (sửa ADR-041). Làm ở T2 + T3.

Nội dung đầy đủ (Bối cảnh/Quyết định/Hệ quả) nằm ở `decisions-log.md`, không lặp ở đây nữa.

## Verification (toàn plan)
- Mỗi task (task [cloud] thì fen chạy trên Mac sau khi Sonnet mở PR): `scripts/test.sh build` xanh + `scripts/test.sh kit` xanh (task chạm ReadoKit) → `sim_screens.sh open` màn đã sửa
  (light/dark, forest + sepia, AX-XL, không bị thanh tab che) → đọc PNG, đối chiếu checklist MASTER. Chưa xem được → ghi
  "chưa xem tay", không báo xong.
- Cuối plan: đếm lại chạm J1 ≤4, J4 ≤1 từ Hôm nay (≤2 từ Thư viện); full `scripts/test.sh` trước `/rhandoff` cuối.
