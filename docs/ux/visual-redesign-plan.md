# Kế hoạch redesign visual Reado — bố trí · icon · vị trí · settings

> Phạm vi: **chỉ tầng View (SwiftUI)**. ReadoKit, logic, FSRS, DDL, FR — **giữ nguyên hoàn toàn**.
> Neo triết lý: 6 nguyên lý `docs/specs/vision.md` (đặc biệt "Journey Over Summary" — chống gamification) + `pro-rules.md` (native checklist, trong skill `ui-ux-pro-max`) + `swiftui.csv` (luật SwiftUI).

## 0. Nền tảng — `Theme.swift` (làm TRƯỚC, mọi mục dưới phụ thuộc)

Hiện chưa có `AccentColor`, chưa có `.tint()`, mọi view hardcode màu. Tạo một file token duy nhất với **bộ tên cố định** (mọi chỗ tham chiếu `Theme.*` trong §6 đều trỏ về đây):

| Token | Nghĩa | Gợi ý giá trị |
|---|---|---|
| `Theme.accent` | brand — 1 màu duy nhất, "đọc sách/giấy" | deep green `#2F6B4F` (tùy chọn indigo-ink `#3B4A6B`) |
| `Theme.surface` | nền phụ / pill / ô editor | `Color.secondary.opacity(0.08)` |
| `Theme.surfaceStrong` | pill nhãn (vd "Mặc định") | `Color.secondary.opacity(0.12)` |
| `Theme.separator` | đường phân cách | system separator |
| `Theme.status.due` | đến hạn / streak / tồn đọng | orange |
| `Theme.status.ok` | xong / đã kiểm / đã lưu | green |
| `Theme.status.warn` | cần xem / trùng / nghi ngờ | amber |
| `Theme.status.danger` | lỗi / "Quên" (again) | red |
| `Theme.status.level` | CEFR (cấp độ) — hue riêng k0 đụng trạng thái | indigo/teal |

- Set `.tint(Theme.accent)` **đúng một lần** trong `ReadoApp` (hiện chưa có — accent đang là xanh hệ thống).
- Helper: `extension Color` + `ViewModifier` `card()` và `badge(_ tone:)` — swiftui.csv #19 (custom ViewModifier thay chuỗi modifier lặp).

## 1. Icon system (SF Symbols — cấm emoji, pro-rules §Icons)

Tất cả icon hiện đã là SF Symbols (tốt — không có emoji). Vấn đề là **filled lẫn outline trong cùng một tầng** (vd `gearshape` cạnh `camera.fill` trên toolbar RootView). Quy tắc 3 dòng:

1. **Icon toolbar / điều hướng = outline** (`gearshape`, `camera`, `plus`, `ellipsis.circle`, `line.3.horizontal.decrease.circle`). Không `.fill`.
2. **Icon "đã chọn / đã xong / kết quả" = filled** + tone (`checkmark.circle.fill` accent, `exclamationmark.triangle.fill` danger).
3. **Icon CTA chính (nút nổi, có nhãn chữ) = filled** (`camera.fill` trong `.borderedProminent`).

- `trophy.fill` (streak dài nhất) dùng `.yellow` — **contrast thấp** trên nền sáng (pro-rules §Contrast) → đổi `crown.fill` hoặc `rosette` tone amber.

## 2. Bố trí & vị trí (nguyên tắc)

### `RootView` — màn rối nhất: 6 action chen trên toolbar, CTA chính "Chụp trang" bị chôn

Tái tầng (giữ nguyên 6 chức năng, chỉ đổi chỗ):

1. **toolbar topBarLeading** = `Cài đặt` (`gearshape`).
2. **toolbar topBarTrailing** = `Dữ liệu` (`archivebox`) + `Tạo collection` (`folder.badge.plus`).
3. **Bottom `safeAreaInset`** = **"Chụp trang" `.borderedProminent` full-width** (`camera.fill` + chữ) — CTA chính, thay icon 28pt.
4. **Ôn tập** rời toolbar → **card hero** đầu list khi `dueToday > 0` (nâng cấp `dailyProgressRows` hiện có).

### Các màn còn lại
- `ReviewQueueView`: card flip đang `rotation3DEffect` + **opacity crossfade** (janky) → flip 3D thuần, tôn `accessibilityReduceMotion` (swiftui.csv #35).
- `.ultraThinMaterial` đang dùng **bừa** (Streak, ReadingSession CTA) còn màn khác thì không → **chọn một** pattern bottom-bar, dùng đều (đề xuất bỏ material, dùng `background(.background)`).

## 3. Màu trạng thái (chống gamification — "Journey Over Summary")

- **Nút grade `Again/Hard/Good/Easy`** (`buttonBackground` rải `red/orange/blue/green`): → hierarchy trung tính — chỉ **Easy = `Theme.accent` filled**; `Hard/Good` = xám tăng dần; **`Again` = soft red** duy nhất (nghĩa "sai", không phải tone game). Reversible — ghi lại quyết định.
- **Badge unify** thành `StatusBadge`: due pill → `Theme.status.due`; CEFR → `Theme.status.level`; "Mặc định" → `surfaceStrong`.

## 4. Settings (`SettingsView`)

Màn đã gọn (List + Section + Picker/Stepper/Toggle) — ít hỏng nhất. Chỉ cần:

1. **Icon đầu mỗi section header**: Học tập `book.closed`, Nhắc ôn tập `bell`, Đang đọc trên Home `pin`, Thuật toán ôn tập `function`.
2. Stepper "Giờ chuyển ngày": thêm icon `bed.double`.
3. FSRS chỉ-đọc: thêm `lock` vào footer (báo "chưa mở" trực quan).
4. Picker giờ nhắc `.wheel` = chuẩn iOS cho time → giữ.
5. Feedback lưu: giữ mẫu `saved` footer + `saveError` Section; đổi màu lỗi `\.red` raw → `Theme.status.danger`.

## 5. Thứ tự implement + Definition of Done

1. `Theme.swift` + `.tint()` trong `ReadoApp` (nền tảng — commit riêng).
2. `StatusBadge` + `card()` ViewModifier, thay các badge / `.secondary.opacity` rải rác.
3. Icon system §1 — đồng bộ filled/outline theo 3 dòng.
4. `RootView` layout (mục 2) — CTA chính nổi bật.
5. Grade buttons + flip card (`ReviewQueueView`).
6. Settings polish.

**DoD (theo `pro-rules.md` Pre-Delivery Checklist):**
- [ ] Touch target mọi control ≥ 44×44pt
- [ ] Không emoji làm icon; một họ icon nhất quán
- [ ] Text contrast ≥ 4.5:1 ở **cả light lẫn dark** (test riêng từng theme)
- [ ] Dynamic Type + reduced-motion không vỡ layout
- [ ] Safe area (notch / home indicator) không che nội dung
- [ ] Không màu hardcode theo màn — chỉ qua token
- [ ] Test trên iPhone nhỏ (375pt) + landscape

---

## 6. Mapping chi tiết từng màn (icon × vị trí × màu)

Legend: **[icon]** = SF Symbol; `token` = `Theme.*` (§0). Cột "Vấn đề" = lý do, mapping với pro-rules / vision.

### 6.1 `ReadoApp.swift`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| App root | không `.tint()` | accent = xanh hệ thống | `.tint(Theme.accent)` cho `RootView()` |

### 6.2 `RootView` — toolbar
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| topBarLeading | Ôn tập `brain.head.profile` | CTA bị chôn làm icon nhỏ | rời toolbar → **card hero** đầu list |
| topBarTrailing [1] | Cài đặt `gearshape` | outline (ổn) | giữ `gearshape` |
| topBarTrailing [2] | Chụp trang `camera.fill` | CTA chính icon 28pt; filled lẫn outline | rời toolbar → **`.borderedProminent` full-width dưới đáy** |
| bottomBar [1] | Tạo collection `plus` | mơ hồ | `folder.badge.plus` |
| bottomBar [2] | Dữ liệu `doc.on.doc` | copy metaphor | `archivebox` |

### 6.2b `RootView` — list
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| Hero ôn tập | `brain.head.profile` + `Color.accentColor` bg | màu accent thô | icon + bg qua `Theme.accent` |
| Tồn đọng (backlog) | `checkmark.circle` | trông như "xong" | `hourglass` (gợi "chờ"), tone `Theme.status.due` |
| Streak | `flame.fill` `.orange` | — | giữ, tone `Theme.status.due` |
| Pin shortcut | `pin.fill` accent | filled trong hàng inline | `pin` (outline, đồng bộ hierarchy) |
| Due pill (×2) | `orange.opacity(0.18)` | hardcode | `Theme.status.due` |
| "Mặc định" pill | `accent.opacity(0.15)` | nhãn ≠ trạng thái màu | `surfaceStrong` + text secondary |

### 6.3 `ReviewQueueView`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| topBarTrailing "Phạm vi" | `line.3.horizontal.decrease.circle` | outline (đúng) | giữ |
| Card flip | `rotation3DEffect` + opacity crossfade | janky (hai mặt cắt nhau) | flip 3D thuần; tôn reduced-motion |
| pos pill mặt trước | `Color(.systemGray5)` | hardcode | `Theme.surface` |
| Nút grade | `red/orange/blue/green` | gamification | Easy=`accent`; Good/Hard=xám; Again=soft `danger` |
| Done | `checkmark.circle` 64pt `.green` | — | `checkmark.circle.fill` tone `Theme.status.ok` |
| Banner nợ | `exclamationmark.triangle` `.orange` + `orange.opacity(0.08)` | hardcode | `Theme.status.due` |
| Scope chọn | `checkmark` accent | — | giữ |
| "Tất cả collection" | `square.stack.3d.up` | — | giữ |

### 6.4 `AnalysisView` + `ReviewCardRow`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| checkbox | `circle`/`checkmark.circle.fill` | chưa chọn = `Color.secondary` | giữ; chọn → `Theme.accent` |
| pos pill | `secondary.opacity(0.12)` | hardcode | `Theme.surface` |
| `VerificationBadge` | green/orange/red | 3 sắc rời | `Theme.status.ok / warn / danger` |
| editorField bg | `secondary.opacity(0.08)` | — | `Theme.surface` |

### 6.5 `CaptureView`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| "Chụp ảnh" CTA | `camera.fill` + `Color.accentColor` bg | tự xây button, màu thô | `.buttonStyle(.borderedProminent)` + `Theme.accent` |
| "Chọn từ thư viện" | `photo.on.rectangle` + `secondary.opacity(0.1)` | tự xây button | `.buttonStyle(.bordered)` |

### 6.6 `CollectionDetailView`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| toolbar menu | `ellipsis.circle` | — | giữ |
| Ôn bộ này | `brain.head.profile` | — | giữ |
| Chụp vào bộ này | `camera.fill` | filled trong hàng action inline | `camera` (outline) |
| CEFR pill | `blue.opacity(0.12)` | hardcode, lệch hệ màu | `Theme.status.level` |
| checkbox select | `circle`/`checkmark.circle.fill` | — | giữ |

### 6.7 `StreakCalendarView`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| Chuỗi hiện tại | `flame.fill` orange | — | token `Theme.status.due` |
| Dài nhất | `trophy.fill` `.yellow` | contrast thấp | `crown.fill` tone amber `Theme.status.warn` |
| Heatmap | orange 0.25→1.0 | — | giữ (đã ổn) |
| CTA | borderedProminent + `.ultraThinMaterial` | glass không đồng bộ | bỏ material, `background(.background)` |

### 6.8 `ReadingSessionView`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| toggle dịch | `eye`/`eye.slash` + `.ultraThinMaterial` | glass không đồng bộ | bỏ material, `background(.background)`; icon giữ |
| chevron summary | `chevron.up/down` | — | giữ |

### 6.9 `SettingsView`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| section headers | không icon | màn dài khó scan | `Label` header: `book.closed` / `bell` / `pin` / `function` |
| lỗi lưu | `exclamationmark.triangle.fill` `.red` | hardcode | `Theme.status.danger` |
| Giờ chuyển ngày | (không icon) | khó liên hệ "đêm" | thêm `bed.double` |
| FSRS chỉ-đọc | (không icon) | chưa gợi "khoá" | thêm `lock` vào footer |

### 6.10 `ExportView` + `ImportView`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| checkmark chọn | `checkmark.circle.fill` `.blue` | hardcode xanh ≠ accent | `Theme.accent` |
| Xuất CSV / JSON / Nhập | `doc.text` / `doc.badge.gearshape` / `square.and.arrow.down` | — | giữ |
| lỗi xuất | `exclamationmark.triangle.fill` `.red` | — | `Theme.status.danger` |
| state rỗng Import | `doc.badge.plus` | — | giữ |

### 6.11 `HomeShortcutToggle`
| Vị trí | Hiện tại | Vấn đề | Đề xuất |
|---|---|---|---|
| toggle | `Toggle` thường | — | giữ (đã chuẩn native) |
## 7. Liquid Glass (iOS 26) — ux-polish-r1 T4

Deployment target vẫn 17.0 (`app/Reado.xcodeproj` + `Package.swift`) — mọi API
Liquid Glass bọc `if #available(iOS 26, *)`, fallback giữ `.regularMaterial`
cũ (không đổi hành vi iOS 17–25).

- `View.chromeGlass(in:)` (`ReadoApp.swift`) — helper duy nhất cho chrome nổi:
  `.glassEffect(.regular, in: shape)` khi có iOS 26, material+overlay+shadow
  cũ khi không. Dùng ở `ShellTabBar` (capsule).
- `FloatShutter` (`RootView.swift`): nhánh iOS 26 dùng
  `.glassEffect(.regular.tint(Color.accentColor).interactive(), in: Circle())`
  — glass tự phản hồi khi nhấn, bỏ `ShutterPressStyle` cho nhánh này (nhánh
  cũ vẫn giữ `ShutterPressStyle` cho iOS < 26).
- **Không** gộp `ShellTabBar` + `FloatShutter` vào một `GlassEffectContainer`/
  `glassEffectID` để morph — hai view nằm ở hai lớp khác nhau (`overlay` vs
  `safeAreaInset`, xem comment `RootView.swift` dòng ~93-102, đo bằng
  screenshot); gộp container sẽ phá cách đặt vị trí đã đo.
- Số đổi mượt: `.contentTransition(.numericText())` cho đếm thẻ ôn
  (`ReviewQueueView`), "N thẻ sẽ ôn" và streak (Home). Icon `flame.fill` +
  checkmark `SessionDoneView` dùng `.symbolEffect(.bounce, value:)`, tắt khi
  Reduce Motion (giá trị truyền vào không đổi).
- `SessionDoneView`: nền `MeshGradient` nhẹ (iOS 18+, fallback
  `LinearGradient`) + 3 ô số đo hiện lần lượt (`Motion.reveal.delay`). Vẫn chỉ
  số thật (ADR-038) — không confetti/particle, không đổi màu nút grade.
- **Không đụng:** `Haptics` (giữ imperative, đổi sang `.sensoryFeedback` là
  churn không cần thiết), glass trên nội dung đọc (card ôn, list, editor —
  MASTER.md: nội dung đọc phải đặc), màn Capture (đã tự vẽ, ADR-036).

## 8. Token Spacing / Radius / Typo (visual-polish-r1, ADR-045)

Định nghĩa ở `app/Reado/DesignSystem.swift`. View không viết số lẻ — đi qua token.

| Đang có | Thay bằng |
|---|---|
| spacing 2, 3 trong VStack chữ | `Spacing.tight` (2) |
| 4, 6 trong VStack chữ | `Spacing.xs` (4) |
| 6, 8 giữa icon ↔ label | `Spacing.sm` (8) |
| 10, 12, 14 khe row / nút | `Spacing.row` (12) |
| 16, `.padding()` mặc định | `Spacing.md` (16, ghi rõ số) |
| 20, 24 giữa khối | `Spacing.lg` (24) |
| 28, 32, 36 | `Spacing.xl` (32) |
| radius 8 / 10 | `Radius.sm` (8) |
| radius 12 | `Radius.md` (12) — mặc định `card()` |
| radius 16 (card lớn) | `Radius.lg` (20) |
| `.caption` + `.secondary` cho chữ đọc | `Typo.meta` + `.secondary` |
| capsule copy tay | `Pill(text:systemImage:tone:)` |

Vai trò chữ: `rowTitle` (headline), `rowSubtitle` (subheadline, kèm `.secondary`), `meta`
(footnote), `pill` (caption semibold), `cardTerm`/`cardAnswer` (card Ôn), `metric`
(số đo), `heroSymbol` (symbol trang trí lớn). Component: `Pill` (chữ luôn `.primary`,
nền tint 0.15 — đạt contrast cả 2 mode), `IconTile` (32pt, symbol đổi màu theo
appearance vì accent dark là bản nhạt), `VocabSummary` (term+POS+CEFR → nghĩa → IPA →
ví dụ; dùng chung row Kho và row duyệt Analysis).
