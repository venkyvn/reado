# Port UI lab → app Reado (bản readokit)

> Plan này thay thế `swiftui-lab-port.plan.md` về MẶT KỸ THUẬT. Giữ nguyên intent UI/flow/business của plan kia,
> nhưng ánh xạ về code THẬT (`app/Reado` + `app/ReadoKit`), không theo cấu trúc GRDB ảo của `qr/app`.

## 0. Quyết định chốt (2026-09-23, fen)

- UI/flow/vị trí nút: theo `ui-lab` + `qr/app` (mock để xem luồng).
- Data/DB/schema: theo **readokit** (CSQLite + swift-fsrs `defaultWv6` pin, schema `db.md`) — KHÔNG GRDB, KHÔNG `sessions.json`.
- Sessions/segments ở lại **SQLite** (đã đúng: `reading_sessions.segments` JSON).
- 4 lệch business của lab là **chốt có chủ đích** (pin 5, CEFR multi, Lưu→Hub+session, 3-tab) — phải apply lên app thật.
- Test: port hết rồi sửa test 1 lần (không vừa port vừa test).

## 1. Ánh xạ file (qr plan → app thật)

| qr plan trỏ tới (ảo) | File thật |
|---|---|
| `Navigation/AppShell.swift` | `app/Reado/RootView.swift` (đổi NavigationStack+sheet → TabView) |
| `DesignSystem/Theme.swift` | `app/Reado/ReadoApp.swift` (`Theme` + `AppTheme` — đã có) |
| `Store/AppStore.swift` | `app/Reado/AppModel.swift` (`@Observable`) |
| `Persistence/Schema.swift`/`AppDatabase`/`Records` | `app/ReadoKit/Sources/ReadoKit/Database/Migration.swift` + `Seeder.swift` + `Database.swift` |
| `Features/Home/HomeView.swift` | `app/Reado/RootView.swift` (Home = màn gốc hiện tại) |
| `Features/Collections/CollectionsView.swift` | `app/Reado/CollectionDetailView.swift` + Home list (chưa có "Kho" riêng) |
| `Features/Capture/CaptureView.swift` | `app/Reado/Capture/CaptureView.swift` |
| `Features/Vocab/VocabPickerView.swift` | `app/Reado/AnalysisView.swift` (duyệt từ đang nằm đây) |
| `Features/Review/ReviewView.swift` | `app/Reado/Screens/ReviewQueueView.swift` |
| `Features/Settings/SettingsView.swift` | `app/Reado/SettingsView.swift` |
| `Features/Session/SessionDetailView.swift` | `app/Reado/ReadingSessionView.swift` |

## 2. Đã có sẵn (đừng làm lại)

Theme accent 4 màu (`AppTheme`), `card()`, flip 3D, grade ramp, streak heatmap 18 tuần,
`reading_sessions` ≤10/collection (FR-05/06), export FR-16, pin 2 slot (`HomeShortcutService`),
`LearningSettings` (CEFR đơn + daily_new_limit + day_cutoff_hour + reminder), FR-18 `outsideDue`.
→ Phần port chỉ là **IA + 4 luật business + dest lúc chụp + thứ tự duyệt từ**, không viết lại engine.

## 3. Business delta (owner đã chốt, apply lên app thật)

| Lab | App hiện tại | Làm gì |
|---|---|---|
| Tab Home/Ôn/Kho | NavigationStack + modal sheet | `RootView` → `TabView(3)` + FloatShutter overlay |
| Shutter nổi | CTA "Chụp trang" to dưới đáy | Bỏ CTA to; `FloatShutter` nút tròn nổi (Home/Kho/Hub) |
| Lưu → Hub bộ vừa chọn | J1→Home, J2→Hub | `confirmPicker` luôn `.hub(target)` + prepend session |
| Dest trên màn chụp | Dest ẩn | overlay dest trên `CameraPicker` (tên bộ + "+") |
| CEFR nhiều | `cefr_level` đơn (A2–C1) | cột JSON `cefr_levels`; preselect item nếu `cefr` ∈ set |
| Pin Home 5 | `home_shortcut_1/2` 2 cột | cột JSON `home_pin_ids` max 5; migrate từ 2 slot |
| Ôn nhanh 1–3 bộ ở Kho | chưa có | cột JSON `review_priority_ids` + `review_all` |
| Review 4 nút VI | đã có grade ramp | giữ, chỉnh nhãn Quên/Khó/Được/Dễ nếu cần |

## 4. Schema migration v3 (ReadoKit)

Thêm vào `Migration.swift` (`currentVersion` 2 → 3, `v3Statements`):

- `settings.cefr_levels TEXT NOT NULL DEFAULT '["B2"]'` — multi; giữ `cefr_level` cũ 1 dòng (deprecate, không đụng seed hiện tại).
- `settings.home_pin_ids TEXT NOT NULL DEFAULT '[]'` — migrate dữ liệu cũ từ `home_shortcut_1/2` sang JSON trong v3 (một UPDATE sau khi thêm cột).
- `settings.review_priority_ids TEXT NOT NULL DEFAULT '[]'` + `settings.review_all INTEGER NOT NULL DEFAULT 0`.

Dịch vụ mới/extend trong ReadoKit:

- `HomePinService` (thay/mở rộng `HomeShortcutService`): `maxPins = 5`, JSON array, không nhận kho tạm, không trùng, có order.
- `ReviewScopeService`: `priorityIDs` (max 3) + `reviewAll`, đọc/ghi JSON.
- `LearningSettings` mở rộng `cefrLevels: Set<CEFRLevel>` (migrate từ `cefrLevel` đơn lúc load); `SettingsService.update` nhận Set.

## 5. Thứ tự làm (mỗi bước build simulator, KHÔNG chạy test tới bước cuối)

1. **Schema v3** + `HomePinService`/`ReviewScopeService`/CEFR multi + migrate 2 slot → 5 pin. Build.
2. **RootView → TabView** (Home/Ôn/Kho) + `FloatShutter` overlay + chuyển Dữ liệu/Cài đặt vào tab Chrome. Build.
3. **Kho** (tab archivebox): list collection + pill Ôn (max 3) + Ghim (max 5, ẩn trên kho tạm). Build.
4. **Capture dest overlay** (CameraPicker overlay + sheet tạo collection + chip đổi dest). Build.
5. **AnalysisView (duyệt từ)**: đoạn đọc/dịch trước, từ sau; preselect `verified && cefr ∈ levels`; `confirmPicker` luôn Hub+session. Build.
6. **Hub/CollectionDetail**: bỏ CTA chụp, shutter overlay, đổi session scope. Build.
7. **Review** 4 nút VI + title scope (đọc `review_priority_ids`/`review_all`); **giữ outsideDue**. Build.
8. **Settings**: CEFR multi chip (min 1), agents Keychain, gỡ pin list khỏi Settings (đã ở Kho). Build.
9. **Streak/Data restyle** + motion/haptic/44pt.
10. **Test**: sửa `app/ReadoTests/*` cho khớp pin 5 + CEFR multi + confirmPicker hub; chạy `xcodebuild test`.

## 6. Cố ý không port

Khung HTML, lưới camera Apple, `maximum_interval`/reset FSRS/21 w, `alert()` HTML, SVG→SF Symbols, analysis thật.

## Chỗ cần fen chốt (nhỏ)

- CEFR multi: giữ **A2/B1/B2/C1** (enum hiện có) hay thêm C2/A1 như lab? Mặc định em giữ A2–C1.
- `home_shortcut_1/2` cũ: sau v3 **giữ cột** (deprecate) hay **bỏ**? Mặc định giữ để không phá data cũ.