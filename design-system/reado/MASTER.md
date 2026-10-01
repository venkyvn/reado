# Reado — Look & luật UI native

> **FROZEN 2026-09-14 (quyết định look):** glass trên chrome nổi, nội dung đọc đặc.
> Quyết định này không đổi nếu fen chưa đồng ý. Phần chữ bên dưới được sửa cho khớp code (ADR-051).
> Đối chiếu code lần cuối: `fe571bf`.

Mỗi luật kiểm được bằng diff hoặc ảnh chụp. Dòng `→` là lý do.
Ngoại lệ đã có chủ ý: `CaptureView` tự vẽ toàn màn (ADR-036), `FloatShutter` (glass tô accent, `.interactive()`),
lưới heatmap `StreakCalendarView` và skeleton trong `AnalysisComponents` (bo góc/khe/frame số riêng, không `.continuous`, có comment tại chỗ).

## Nguồn token
- `app/Reado/Shared/DesignSystem.swift`: `Spacing`, `Radius`, `Typo`, `Pill`, `IconTile`, `VocabSummary`, `cardShadow()`.
- `app/Reado/App/ReadoApp.swift`: `Theme`, `AppTheme`, `Motion`, `Haptics`, `card()`, `chromeGlass(in:)`.
- Giá trị nằm trong code. File này chỉ ghi tên và khi nào dùng, không chép con số.
  → Chép số thì sẽ lệch: bản cũ ghi tint và font cứng, trong khi code đã đổi.

## Màu
- Màu nhấn = `Color.accentColor` (thừa hưởng `.tint` ở `ReadoApp`). Không dùng `Color.blue`.
  → Fen chọn accent trong `AppTheme` (Xanh rừng mặc định · Chàm · Nâu giấy · Hệ thống). Ghi cứng một màu là bỏ qua lựa chọn đó.
- Không dùng `.tint(...)` để đổi màu nhãn, chữ hay icon — màu chữ đi qua `.foregroundStyle`. `.tint` chỉ hợp lệ khi tô nền control hệ thống bằng token, ví dụ swipe action `.tint(Color.accentColor)` / `.tint(Theme.danger)` / `Color(.systemGray)` cho trạng thái tắt (`SettingsView`, `KhoTabView`, `AnalysisView`).
  → Swipe action không có cách tô nào khác. Dùng `.tint` cho chữ thì màu chỉ ăn ở một số control, chỗ khác vẫn là accent.
- Hex chỉ được xuất hiện trong `AppTheme.accent`.
  → Mỗi accent cần hai sắc độ light/dark, đặt một chỗ thì mới chỉnh được.
- Màu trạng thái chỉ đi qua `Theme.due` / `Theme.ok` / `Theme.warn` / `Theme.danger` / `Theme.level`. Không dùng `.orange`/`.red` trần trong view.
  → Hue mang nghĩa (đến hạn, lỗi, CEFR). Đổi nghĩa thì đổi đúng một chỗ.
- Nền phụ (pill, ô nhập, card) dùng `Theme.surface` / `Theme.surfaceStrong`, không dùng `.secondary.opacity(...)`.
  → Alpha cố định gần như tàng hình trên nền tối. System fill thì tự đổi theo dark mode.
- Chữ trên nền tint nhạt luôn là `.primary`, giống `Pill`.
  → Chữ cam/xanh trên nền cùng hue nhạt không đạt contrast 4.5:1.

## Vật liệu (FROZEN)
- Glass chỉ đặt trên chrome nổi (tab bar, nút nổi), qua `chromeGlass(in:)`. View không gọi `.glassEffect` / `.ultraThinMaterial` / `.regularMaterial` trực tiếp.
  → Một hàm giữ đúng look iOS 26 và tự rơi về material cũ ở iOS < 26.
- Khối nội dung đọc dùng `card()`: nền `Theme.surface`, đặc, không bóng.
  → Chữ để đọc lâu cần nền đặc. Glass sau chữ làm giảm contrast.
- `cardShadow()` chỉ dùng cho card Ôn (thẻ nổi, kéo được). Card khác không có bóng.
  → Bóng đánh dấu thứ cầm kéo được. Rải khắp nơi thì mất nghĩa đó.

## Chữ
- Font chỉ lấy từ `Typo.*` hoặc text style hệ thống (`.body`, `.headline`…). Không font custom, không `.font(.system(size:))` ngoài `Typo.heroSymbol`.
  → Text style giữ Dynamic Type. Cỡ cố định sẽ vỡ ở cỡ accessibility.
- Chữ đọc phụ dùng `Typo.meta` + `.secondary`. `.caption` chỉ dùng cho pill và nhãn nhỏ.
  → `.caption` quá nhỏ cho chữ người dùng phải đọc.

## Icon
- Chỉ dùng SF Symbols, không emoji làm icon.
  → Symbol theo được Dynamic Type, đổi được màu theo tint và đọc được bằng VoiceOver. Emoji thì không.
- Toolbar và điều hướng dùng symbol outline (`gearshape`, `plus`, `xmark`…).
  → Đồng nhất một tầng. Filled cạnh outline trông như đang bật.
- Trạng thái đã chọn/đã xong và CTA chính dùng `.fill` (`checkmark.circle.fill`, `camera.fill`). Tab bar dùng outline, chuyển sang `.fill` khi đang chọn.
  → Filled = "đang bật / làm việc này", nhìn ra ngay không cần đọc chữ.
- Icon đầu row dùng `IconTile`.
  → Cùng cỡ thì mép trái các row thẳng hàng.

## Bố cục
- Khoảng cách dùng `Spacing.*`, bo góc dùng `Radius.*` kèm `style: .continuous`. Không viết số lẻ. Ngoại lệ đã liệt kê ở đầu file.
  → Một thang duy nhất thì các màn khớp nhau mà không cần đo.
- Nhãn nhỏ (due, CEFR, POS, trạng thái) dùng `Pill`. Khối một từ dùng `VocabSummary`.
  → Kho và màn duyệt từ giữ cùng thứ tự dòng, không có capsule copy tay.
- Nội dung cuộn trong shell phải chừa chỗ: `.safeAreaPadding(.bottom, ShellTabBar.reservedHeight)` hoặc đặt trong view đã có sẵn khoảng chừa này.
  → Tab bar nổi đè lên nội dung. Nút Quên/Khó/Được/Dễ từng bị che.
- Hiện/ẩn nội dung đi qua `Motion.run(reduceMotion:)` + `revealTransition()`. Haptic đi qua `Haptics.*`. Sheet/tab/push để hệ thống tự animate.
  → Một nhịp motion duy nhất, tôn trọng Reduce Motion, không làm hiệu ứng ăn mừng.
- Vùng chạm ≥ 44×44pt.
  → Chuẩn HIG. Nút nhỏ hơn thì bấm trượt.

## Không làm (chiếu `docs/specs/vision.md`)
- NL1: màn/kho "bài đọc mẫu" do app soạn. → Nguồn học là văn bản thật người dùng tự chọn.
- NL2: ẩn bản dịch sau quiz, hoặc bắt đoán nghĩa mới cho xem. → Nghĩa không bao giờ bị chặn.
- NL3: chọn sẵn mọi từ trong trang, hoặc lưu không qua bước duyệt. → AI đề xuất, người đọc duyệt cuối.
- NL4: mặt sau thẻ thiếu câu gốc hoặc collection. → Ngữ cảnh là chỗ bám của trí nhớ.
- NL5: kết quả phân tích dạng bong bóng chat. → Dữ liệu có cấu trúc, không phải chat dùng một lần.
- NL6: tóm tắt hiện trước trang. Điểm/XP, huy hiệu không gắn với việc đã làm. Bảng xếp hạng. → Chống tiến bộ ảo, chỉ hiện số đo có thật.

## Checklist trước khi báo xong
- [ ] Chụp cả light và dark: `scripts/sim_screens.sh shot <tên>`, đọc PNG.
- [ ] Thử ≥ 2 accent: Xanh rừng và Nâu giấy (Settings → Chủ đề).
- [ ] Dynamic Type `accessibility-extra-large` (`scripts/sim_screens.sh size accessibility-extra-large`): không cắt chữ, không chồng lấn.
- [ ] Không có gì bị `ShellTabBar` che ở cuối màn cuộn.
- [ ] Diff không thêm hex, số lẻ hay màu trần mới. Mọi giá trị đi qua token ở trên.
