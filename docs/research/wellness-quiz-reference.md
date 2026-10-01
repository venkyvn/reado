# Wellness Quiz Prompt — Tham chiếu cho Reado

> **Lỗi thời một phần (2026-10-01, ADR-051):** hex tint, rgba glass và font Inter trích từ MASTER cũ dưới đây không còn đúng. Luật hiện hành: [design-system/reado/MASTER.md](../../design-system/reado/MASTER.md).
>
> **Mục đích:** Ghi lại những gì học được từ prompt wellness quiz của fen để tham chiếu khi thiết kế UI Reado. Không phải yêu cầu sản phẩm mới, không thêm FR/journey, không code ở phase này.
> **Nguồn prompt:** Yêu cầu build màn hình quiz wellness trong phone frame mockup — React 18 + Tailwind CSS 3 + Lucide React + Vite + TypeScript.

---

## 1. Bối cảnh

### Prompt wellness quiz là gì

Một spec web chi tiết cho màn hình mobile wellness quiz đặt trong phone frame giả lập (mockup), bao gồm:

- **Phone Frame:** 375×780, bo góc 52px, nền `#8a9aaa`, box-shadow nhiều lớp mô phỏng viền, Dynamic Island 120×32 ở top center.
- **Background:** ảnh full-bleed từ URL `images.higgs.ai` với `blur(12px) + scale(1.1)`, overlay `#8a9aaa` 30% opacity.
- **Font:** "Helvetica Now Var" + fallback `'Helvetica Neue', Helvetica, Arial, sans-serif`.
- **Layout:** flex column, padding 56px top / 24px sides / 24px bottom. Gồm: header badge (liquid glass pill + Timer icon + "Vitaforge Daily"), title ("Choose all that apply" + heading), grid 2 cột 4 cards (Sleep quality / Stress / Weight / Skin, 100px height, rounded-[32px], label 01–04, pre-selected Stress+Skin), nút voice 64px liquid glass + waveform SVG + glow vàng, slide-to-confirm 56px track + thumb 44px + "Done" + chevrons.
- **Liquid Glass CSS:** `.liquid-glass` (`rgba(255,255,255,0.01)`, luminosity blend, `backdrop-filter: blur(4px)`, pseudo-element gradient border 1.4px với mask-composite exclude) và `.liquid-glass-selected` (`rgba(0.12)`, blur 8px, viền sáng hơn).
- **Animation:** staggered fade-up `opacity:0 → 1, translateY(16px) → 0`, duration 0.5s, easing `cubic-bezier(0.22, 1, 0.36, 1)`, delay 0.1s–0.85s.

### Vì sao không áp dụng thẳng vào Reado

| Điểm khác | Wellness prompt | Reado v2 |
|---|---|---|
| Platform | Web (React + Tailwind + Vite) | **iOS native SwiftUI** (xem `docs/specs/prd.md` v0.8, `docs/research/tech-stack.md`) |
| Khung màn hình | Phone frame giả lập 375×780 + Dynamic Island CSS | Chạy thật trên iPhone — không cần mockup frame |
| Style system | CSS liquid glass + backdrop-filter + mask-composite | Design system Reado: `design-system/reado/MASTER.md` — `--glass rgba(255,255,255,0.55)`, `--tint #007AFF`, Inter, SwiftUI `Material` |
| Navigation | Trang đơn trong page trắng | Journeys J1–J6 + Settings J-R1-S/P/D (`docs/specs/journeys.md`) — không có slide-to-confirm |

Kết luận: **không copy code/CSS**. Chỉ trích pattern UX/visual để áp vào SwiftUI khi phù hợp.

---

## 2. Chuyển được ngay (áp vào Reado)

Những pattern đã có FR/journey tương ứng — ghi rõ ánh xạ để khi code SwiftUI không tự bịa flow mới.

| # | Pattern từ wellness quiz | Ánh xạ vào Reado | Ghi chú SwiftUI |
|---|---|---|---|
| 1 | **Multi-select grid 2 cột (12px gap, card 100px, rounded-[32px])** — 4 cards, chọn nhiều | **J3 "Học mới"** (chọn items để lưu), **J5 "Trộn collection"** (FR-18 chọn vài collection), **FR-03 Review & Correct Before Save** (chọn/bỏ vocab items) | `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12)` + state `Set<ID>` + overlay checkmark. Card height ~100pt, cornerRadius 32 |
| 2 | **Pre-selected mặc định (Stress+Skin đã chọn sẵn)** | **FR-03 + FR-09** — *"mặc định chọn tất cả, user bỏ cái đã biết"*. Cùng triết lý: giảm thao tác khi AI đã lọc tốt | Initial state `selected = allIDs` (verified items). Unverified (FR-02 example không khớp `segments[]`) thì **không** chọn sẵn — đúng criterion FR-02 |
| 3 | **Liquid glass material** (glass + blur + gradient border) | **Đã có trong MASTER.md:** `Glass rgba(255,255,255,0.55)`, `Hairline rgba(255,255,255,0.45)`, FROZEN 2026-09-14 "look liquid-glass. Apple material: glass trên nav/controls, nội dung đọc đặc" | SwiftUI: `.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))` + `.overlay(RoundedRectangle(cornerRadius: 32).stroke(...))`. **Không** dùng CSS pseudo-element / mask-composite |
| 4 | **Header badge (pill + icon 12px + label 12px medium)** | Pattern label ngắn cho màn hình capture/review — ví dụ badge trạng thái collection hoặc CEFR level trên card (FR-08 hiển thị `cefr`, `pos`) | Pill: `Capsule` + `.ultraThinMaterial` + `Label` (Lucide → SF Symbols / custom SVG). Padding 10 vertical / 12 horizontal tham chiếu |
| 5 | **Radial glow sau button** (`radial-gradient` vàng nhạt) | Micro-interaction cho **FAB capture (J1)** hoặc nút Học/Ôn trên Home (FR-14) | SwiftUI: `RadialGradient` overlay phía sau button, opacity thấp (0.5 → transparent). Chỉ dùng khi cần nhấn mạnh CTA chính |
| 6 | **Numbered label 01/02/03/04 (white/50, 11px medium)** trên card | **Queue position indicator** cho **Review Queue (FR-11)** hoặc thứ tự trong lưới chọn collection | Text nhỏ `11pt medium, opacity 0.5` ở góc card. Hữu ích khi queue dài |

> Tất cả các pattern trên **không** tạo journey mới. Chúng chỉ là chi tiết hiển thị — chọn cách đơn giản nhất khi implement (theo `docs/specs/vision.md` + `CLAUDE.md`).

---

## 3. Giữ làm material cho sau (chưa có FR, không cam kết)

Ghi lại để sau này cân nhắc, tránh quên ý hay nhưng cũng tránh scope creep.

| Pattern | Nguồn trong prompt | Khi nào cân nhắc |
|---|---|---|
| **Slide-to-confirm** (track 56px + thumb 44px + drag 85% threshold, snap back/end) | Wellness quiz — bottom action | Chưa có journey Reado nào cần. Material nếu sau này cần confirm destructive (ví dụ xoá collection FR-17). Hiện tại **không** implement |
| **Staggered fade-up** (0.5s, `cubic-bezier(0.22, 1, 0.36, 1)`, delay 0.1/0.25/0.4/0.48/0.56/0.64/0.7/0.85s) | Animation toàn màn hình | Tham chiếu easing cho transition giữa các màn Reado. SwiftUI dùng `.transition` + `.animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5))`. Đối chiếu với MASTER motion: `power1.out` 300–400ms, y offset 8–16px. Không áp nguyên delay 8 bước nếu không cần |
| **Voice button waveform (5 bars, strokeWidth 2, strokeLinecap round)** | Nút voice giữa màn hình | NG-01 loại trừ pronunciation/speech ở R1 — không làm. Giữ như material nếu sau này cân nhắc input voice |
| **Full-bleed blurred background + overlay 30%** | Background wellness (blur 12px + scale 1.1) | Reado reading view (FR-05) ưu tiên **nội dung đọc đặc** (MASTER: "glass trên nav/controls, nội dung đọc đặc"). Không dùng background blur toàn màn hình cho màn đọc |

---

## 4. Không chuyển (tránh lạc hướng)

Ghi rõ để không ai copy nhầm.

| Phần wellness quiz | Lý do không chuyển |
|---|---|
| Phone frame mockup (375×780, 52px radius, box-shadow bezel, Dynamic Island 120×32) | Reado chạy thật trên iPhone — không giả lập frame trong app |
| CSS `backdrop-filter`, `mask-composite: exclude`, `::before` gradient border 1.4px | Kỹ thuật web — SwiftUI có `Material` + `Shape.stroke` native, không cần trick CSS |
| React component + Tailwind utility + Vite build | Stack web — Reado là SwiftUI + Xcode project viết tay (objectVersion 60), local package `XCSwiftPackageProductDependency` |
| GSAP / `cubic-bezier` CSS / `backdrop-filter` JS | Reado animation là SwiftUI `.transition` / `matchedGeometryEffect` / `withAnimation` |
| Helvetica Now Var + fallback Helvetica stack | Reado typography là **Inter** (MASTER.md) + SF Pro fallback — không đổi font |
| Ảnh nền `images.higgs.ai` URL cứng | Không liên quan JTBD-01/JTBD-02; Reado không dùng ảnh nền trang trí cho màn đọc |

---

## 5. Cách dùng file này

1. Khi prompt UI cho một màn Reado (theo `docs/specs/journeys.md`), mở file này trước để xem pattern nào đã map sẵn.
2. Pattern ở mục 2 thì áp thẳng vào SwiftUI (kèm FR/journey đã ghi). Pattern ở mục 3 chỉ tham chiếu khi owner duyệt scope mới — không tự động thành FR.
3. Mọi chi tiết hiển thị chưa rõ → chọn cách đơn giản nhất, ghi lại lựa chọn (theo `CLAUDE.md` §6).

---

*Cập nhật 2026-09-19 — trích từ prompt wellness quiz React/Tailwind của fen. Không thêm dependency, không sửa PRD/journeys/design-system.*
