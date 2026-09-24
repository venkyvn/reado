# Tham khảo ngoài — "UI UX Pro Max" (trích chọn cho Reado)

> **Tình trạng: chỉ là THAM KHẢO — không dòng nào ở đây là quyết định của Reado.**
> Dùng gì trong file này đều phải chiếu qua sáu nguyên lý của
> [`docs/vision.md`](../docs/vision.md), non-goals (PRD mục 3) và các bảng "Đã chốt"
> của research docs. Ba bài toán tương tác ở AGENTS mục 7 **do owner quyết** — nguồn
> này chỉ bổ sung chi tiết hiển thị, không trả lời thay.

| Field | Value |
|---|---|
| Nguồn | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — skill "UI UX Pro Max" v2.13.0, MIT |
| Trích ngày | 2026-09-08, từ clone local `/Users/vuong/Documents/00_workspace/05_ai_project/tool/ui-ux-pro-max-skill` (nằm ngoài repo này; nếu mất thì clone lại URL trên) |
| Trích gì | 6 dòng product + 3 dòng reasoning + 24 dòng UX guideline + 4 palette + tóm tắt 2 file stack (`react`, `html-tailwind`) |
| Không trích | 34 mẫu landing page, 25 loại chart, catalog icon/font, các stack khác, máy sinh design system |

---

## 1. Nguồn này là gì và cách tra thêm

Kho tri thức thiết kế dạng CSV + máy tìm BM25 (`search.py`, Python 3) để AI coding
agent tra cứu khi dựng UI. **Không phải thư viện component** — không có code tái dùng
được. DSH không nằm trong danh sách platform của nó, nhưng không cần cài: gọi thẳng
script sau khi clone:

```bash
python3 <clone>/src/ui-ux-pro-max/scripts/search.py "chip wrap" --domain ux
python3 <clone>/src/ui-ux-pro-max/scripts/search.py "touch target" --domain web   # app-interface.csv
python3 <clone>/src/ui-ux-pro-max/scripts/search.py "memo" --stack react
```

Các domain: `product`, `style`, `typography`, `color`, `landing`, `ux`, `web`,
`react`, `google-fonts`, ... (đủ danh sách trong CLAUDE.md của repo nguồn). License
MIT nên trích dẫn thoải mái, ghi nguồn là đủ.

---

## 2. Reado nằm ở đâu trong phân loại của nguồn

Nguồn phân 192 loại sản phẩm. Reado rơi vào **giao điểm của bốn** loại sau:

`products.csv` — Primary Style Recommendation, Color Palette Focus, Key Considerations:

| # | Product Type | Primary Style | Color Palette Focus | Key Considerations (cắt gọn) |
|---|---|---|---|---|
| 78 | Language Learning App | Claymorphism + Vibrant & Block-based | Playful colors + progress indicators | Progress tracking. Gamification. Achievement badges |
| 103 | Flashcard & Study Tool | Claymorphism + Micro-interactions | Playful primary + correct green + incorrect red + progress blue | 3D card flip. **Spaced repetition algorithm.** Session progress bar. Streak tracking |
| 135 | Book & Reading Tracker | Swiss Modernism 2.0 + Minimalism & Swiss Style | Warm paper white + ink brown + reading progress green | Progress percentage. Notes and quotes. Genre stats |
| 114 | Bookmark & Read-Later | Minimalism & Swiss Style + Flat Design | Paper warm white + ink neutral + tag colors | Distraction-free view. **Tags and collections.** Offline sync |
| 43 | Online Course/E-learning | Claymorphism + Vibrant & Block-based | Vibrant learning colors + progress green | Course catalog. Progress tracking. Gamification |
| 9 | Educational App | Claymorphism + Micro-interactions | Playful colors + clear hierarchy | Engagement & ease of use |

`ui-reasoning.csv` — 3 dòng tương ứng (decision rules viết gọn):

| # | Style Priority | Color Mood | Typography Mood | Key Effects | Rules nổi bật | Anti-Pattern |
|---|---|---|---|---|---|---|
| 78 | Claymorphism + Vibrant & Block-based | Playful + progress | Friendly + Clear | Progress animations, achievement unlocks | must_have: progress-tracking, gamification | Boring design + No motivation |
| 103 | Claymorphism + Micro-interactions | Playful primary + green/red/blue | Playful, rounded, friendly | Multi-layer shadows, spring bounce, soft press 200ms | **if_ux_focused → prioritize clarity; if_mobile → optimize touch targets** | Inconsistent styling + poor contrast |
| 135 | Swiss Modernism 2.0 + Minimalism | Warm paper white + ink brown + progress green | Professional + clean hierarchy | Subtle hover, smooth transitions | anchor: excess decoration bị cấm | Excessive decoration |

⚠️ **Cảnh báo trước khi dùng:** style của nguồn cho mảng học tập thiên
**gamification + playful** (Claymorphism, badge, streak). Reado ưu tiên ngược lại:
ít ma sát, bình tĩnh, không gamification ở R1 — nên xu hướng tone 135/114 (giấy/ink)
hợp vision hơn 78/103. Dòng `if_mobile → optimize touch targets` và "poor contrast
= anti-pattern" thì luôn đúng với Reado.

---

## 3. UX guidelines trích chọn (24/119 dòng) — nguyên văn Do/Don't

### 3.1 Content & compact label (chip, badge, chữ dài) — nhóm đắc dụng nhất

| Issue | Platform | Do | Don't | Sev |
|---|---|---|---|---|
| Chip Collection Reflow | All | Wrap cả nhóm chip, hoặc nút `+n` mở được để xem phần tràn | Ép toàn bộ chip vào một hàng bị cắt, hoặc giấu giá trị tràn | High |
| Compact Label Overflow | All | Chỉ giới hạn giá trị không đoán trước; nowrap + nhãn co lại được; lộ được toàn văn cho keyboard/pointer/touch | Để một nhãn gọn tràn xuống dòng hai, hoặc tooltip chỉ hiện khi hover | High |
| Compact Label Semantics | All | Chọn markup static/tương tác theo **nghĩa** của nhãn; badge = trạng thái, chip/tag = giá trị hay hành động | Biến mọi pill thành nút bấm được, hoặc mã hoá trạng thái chỉ bằng màu | High |
| Compact Control Semantics | Web | Dùng `button` thật, lộ trạng thái pressed/selected khớp với nhãn hiển thị | `div` clickable, hoặc chỉ lộ hành động khi hover | Critical |
| Contextual Live Badge Updates | Web | Một thông điệp trạng thái nguyên câu, ví dụ "3 mục trong kho" | Phát ra một con số trần, hoặc biến mọi badge thành live region tranh nhau | High |
| Content Jumping | Web | Chừa sẵn không gian / giữ layout ổn định khi trạng thái async thay đổi | Nhét text/media bổ sung vào mà không có chiến lược layout | High |
| Long Token Wrapping | Web | `overflow-wrap: anywhere`, để text trong flex/grid co lại được | `word-break: break-all` cho mọi đoạn văn | High |
| Essential Text Truncation | All | Wrap/resize, hoặc cho đường xem đầy đủ | Cắt nghĩa hiển thị chỉ để các card đồng đều nhau | Critical |
| Truncation | All | Ellipsis + cách mở rộng để xem hết | Tràn hoặc vỡ layout | Medium |
| Overflow Hidden | Web | Test nội dung thực sự nằm gọn trong container | `overflow: hidden` bừa bãi | Medium |

### 3.2 Accessibility nền

| Issue | Platform | Do | Don't | Sev |
|---|---|---|---|---|
| Text Reflow and Spacing | Web | Kích thước fluid, chiều cao theo nội dung, `line-height` không đơn vị | Cắt chữ trong box cố định chiều rộng/cao | Critical |
| Color Contrast | All | Tối thiểu 4.5:1 cho text thường | Chữ tương phản thấp | High |
| Contrast Readability | All | Chữ tối trên nền sáng | Chữ xám trên nền xám | High |
| Focus Appearance | Web | Indicator rõ (AAA: viền ≥ 2px, contrast 3:1) — đừng tuyên cái này là AA | Viền mảnh, tương phản thấp | Medium |
| Reduced Motion | All | Kiểm `prefers-reduced-motion` | Bỏ qua tuỳ chọn giảm hiệu ứng của người dùng | High |

### 3.3 Touch & responsive (PWA thể thao chính)

| Issue | Platform | Do | Don't | Sev |
|---|---|---|---|---|
| Touch Target Size | Mobile | iOS 44pt / Android 48dp; **web theo WCAG 2.5.8 (24×24px)** — tính riêng | Gộp chung một con số cho mọi nền tảng | High |
| Touch Spacing | Mobile | Tối thiểu 8px giữa hai target bấm được | Các phần tử bấm dính sát nhau | Medium |
| Tap Delay | Mobile | `touch-action: manipulation` | Để mặc định gây trễ tap | Medium |
| Mobile First | Web | Viết mobile trước rồi thêm breakpoint | Desktop-first sinh lỗi mobile | Medium |
| Readable Font Size | All | Body tối thiểu 16px trên mobile | Chữ tí hon trên mobile | High |
| Breakpoint Testing | Web | Test 320 / 375 / 414 / 768 / 1024 / 1440 | Chỉ test trên máy mình | Medium |
| Disabled States | All | Giảm opacity + con trỏ phù hợp | Khiến trạng thái disabled không phân biệt được | Medium |

---

## 4. Ánh xạ guideline nguồn → màn hình Reado

Không phải spec — chỉ là bản đồ "làm màn hình nào thì mở nhóm nào ra":

| Màn hình / phần | Guideline nguồn đối ứng |
|---|---|
| **Duyệt & sửa từ** (FR-03 + FR-09 — bài toán UI-2) | Content Jumping (thêm/xoá field không nhảy layout), Compact Label Overflow, Chip Collection Reflow, Essential Text Truncation + Truncation (path đầy đủ), Compact Control Semantics (checkbox/chip thật, không div), Focus Appearance, Long Token Wrapping (`meaning_vi`, `ipa` dài) |
| **Kho tạm + di chuyển lô** (FR-17) | Contextual Live Badge Updates (số kho đổi → "N mục trong kho"), Compact Label Semantics (chip = collection, badge = trạng thái) |
| **Số nợ** (FR-18 — bài toán UI-3) | Contextual Live Badge Updates (phát nguyên câu, không phát số trần) — cách trình bày mạnh/nhẹ vẫn là **quyết định UI-3 của owner** |
| **Bản song ngữ** (UI-1 đã chốt: xen kẽ theo đoạn) | Text Reflow and Spacing (Critical), Readable Font Size ≥ 16px, Contrast Readability |
| **Thẻ ôn** (FR-12) | Reduced Motion (lật thẻ phải tôn trọng user), Touch Target Size, Color Contrast 4.5:1 |
| **Capture** (FR-01 — NFR-08 ≤ 3 thao tác) | Touch Target Size + Spacing, Tap Delay, Mobile First — nút to, ngón cái, ít bước |
| **Toàn app** | Color Contrast, Focus Appearance, Breakpoint Testing (5 mốc trên), Disabled States |

---

## 5. Kiến thức mobile (app-interface.csv, 32 dòng) → chuyển sang PWA

File này của nguồn viết cho iOS/Android/React Native. Chuyển đổi sang PWA như sau —
ý giữ nguyên, câu chữ đổi:

| Ý trong nguồn (RN) | Tương đương cho PWA Reado |
|---|---|
| Touch target 44pt iOS / 48dp Android, web tính riêng theo WCAG 2.5.8 | Dùng luật web: 24×24px chuẩn, nhắm ~44×44px cho ngón cái |
| Safe Area insets (notch, gesture bar) | `env(safe-area-inset-*)` + `viewport-fit=cover`, chú ý `display: standalone` khi Add to Home Screen |
| Tôn trọng reduce-motion của OS | `@media (prefers-reduced-motion: reduce)` |
| Feedback loading > 300ms (skeleton/indicator) | **Bắt buộc** ở bước AI phân tích (FR-02) — lần gọi kéo dài vài giây, không để màn hình đơ |
| Virtualize danh sách > ~50 phần tử | Virtualize màn danh sách collection / số đến hạn; màn duyệt ~8 từ mỗi trang không bắt buộc |
| Debounce scroll/search | Debounce ô tìm kiếm khi có FR-08 |
| Back button đoán được, giữ state màn hình | PWA: giữ vị trí cuộn khi quay lại, đừng reset form duyệt từ |
| Dynamic Type / fontScale của OS | Text reflow theo WCAG (mục 3.2), **không tắt zoom**, line-height không đơn vị |
| Keyboard type theo field | `inputmode`/`enterkeyhint` (6 field đều là text tiếng Anh) |
| Micro-interaction 150–300ms, ease-out | Transition mở/collapse màn duyệt từ, lật thẻ |

---

## 6. Stack đã chốt của Reado có trong nguồn

Stack chốt thế hệ PWA (tracker cũ, mục 1): **Vite + React + TS**. Nguồn có:

- `stacks/react.csv` — **61 guideline React 19.x** chia 18 nhóm: State, Effects,
  Rendering, Components, Props, Events, Forms, Hooks, Context, Performance,
  ErrorHandling, Testing, Accessibility, TypeScript, Patterns, Tooling, Concurrency,
  Security.
- `stacks/html-tailwind.csv` — **59 guideline Tailwind** chia 16 nhóm: Animation,
  Z-Index, Layout, Images, Typography, Colors, Spacing, Forms, Responsive, Buttons,
  Cards, Accessibility, Performance, Plugins, Interactivity, Customization.
- `react-performance.csv` — 44 mục performance riêng.

Tra nhanh: `search.py "<query>" --stack react`. Lưu ý: dùng làm chuẩn **tham chiếu**,
không thay `docs/coding-conventions.md` (task 1.4) — convention của repo luôn thắng.

---

## 7. Bảng màu gợi ý (colors.csv — chỉ là hạt giống, không chốt)

| Nguồn | Primary | Secondary | Accent | Background | Foreground | Notes |
|---|---|---|---|---|---|---|
| 103 Flashcard | `#7C3AED` | `#8B5CF6` | `#059669` | `#FAF5FF` | `#0F172A` | Study purple + correct green |
| 78 Language | `#4F46E5` | `#818CF8` | `#16A34A` | `#EEF2FF` | `#312E81` | Learning indigo + progress green |
| 135 Book Tracker | `#78716C` | `#92400E` | `#D97706` | `#FFFBEB` | `#0F172A` | **Book brown + page amber** — hợp tone đọc sách |
| 114 Read-Later | `#D97706` | `#F59E0B` | `#2563EB` | `#FFFBEB` | `#0F172A` | Warm amber + link blue |

⚠️ Tone tím `#7C3AED`/indigo kiểu app học tập đại trà; tone giấy/ink của 135/114
nghiêng về vision Reado hơn. Font trong nguồn (74 cặp) **chưa trích** — dùng cặp nào
phải kiểm tra **subset tiếng Việt** trước, không phải cặp Google Fonts nào cũng đủ
dấu.

---

## 8. Cái gì KHÔNG lấy từ nguồn này

- **34 mẫu landing page + 192 quy tắc reasoning sinh landing** — Reado R1 không có
  landing page; đa phần nội dung nguồn phục vụ marketing sites.
- **25 loại chart** — không có dashboard ở R1 (thống kê thời gian → Later/R2).
- **GSAP skeletons** — không thêm dependency GSAP.
- **Máy sinh design system end-to-end** — cần chạy đủ 192 rules; Reado chỉ cần tập
  con ở trên. Đừng coi output của nó là spec của Reado.

---

## 9. Tóm tắt một dòng

Nguồn này trả lời được câu hỏi *"chi tiết hiển thị nên thế nào"* (chip có wrap
không, contrast bao nhiêu, nút to cỡ nào, badge đọc gì) — **không** trả lời được
*bố trí sản phẩm thế nào* (UI-2, UI-3), những cái đó vẫn là quyết định của owner.