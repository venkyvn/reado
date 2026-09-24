# Spec vá IA — implement trên máy nhà

Base: nested repo `implementation/reado`, commit `97f6a4d` (`refactor: dọn dead code + rename HomeShortcut → HomePin`). Đừng áp lên `13888d5` và đừng copy file từ `app/` (GRDB).

Commit `97f6a4d` đã xóa `HomeShortcuts.swift` và đổi tên sang `HomePin`. Đừng làm lại việc đó.

## Không đụng

- Không GRDB. Không đổi pin `swift-fsrs` `4fbaf20184d62f82a9f44f343337c61a2c5483e9` trong [ReadoKit/Package.swift](implementation/reado/app/ReadoKit/Package.swift).
- Kho tạm không tạo `reading_sessions`. Giữ nhánh `isNamed` trong [VocabRepository.saveCapture](implementation/reado/app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift).
- CEFR giữ A2, B1, B2, C1 trong [LearningSettings.swift](implementation/reado/app/ReadoKit/Sources/ReadoKit/Settings/LearningSettings.swift).
- `MockAnalyzer()` trong [AppModel.analyzeCurrentImage](implementation/reado/app/Reado/AppModel.swift) giữ nguyên.
- Không tách `AppModel`, không cache, không đưa `reloadOverview` ra background.
- Không đổi 4 theme hiện có (Hệ thống / Rừng / Chàm / Nâu giấy) thành 4 chấm lab.
- Vuốt Ôn/Ghim trên Kho giữ nguyên. Không làm pill.

## 1. Home — hàng kho tạm luôn hiện

File: [RootView.swift](implementation/reado/app/Reado/RootView.swift), `HomeTabView`.

Hiện `List` chỉ có `dailyProgressRows` rồi `homePinRows`. Comment nói có kho tạm; UI không có.

Trong `List`, thứ tự:

1. Hàng ôn (giữ `dailyProgressRows` như hiện tại: chỉ khi `dueToday > 0` hoặc backlog).
2. Hàng kho tạm, luôn, kể cả khi `dailyProgress` nil.
3. Hàng streak (tách khỏi `dailyProgressRows` — xem mục 2).
4. Section `Đang đọc · k/5` (giữ).

Hàng kho tạm: `model.collections.first(where: \.isDefault)`. `NavigationLink` tới hub id đó. Title = `inbox.name`, capsule "Mặc định", subtitle `\(totalItems) từ · trang chưa phân loại`. Nếu `dueNow > 0`, badge số giống hàng pin (capsule `Theme.due`). Không nút ghim. Kho tạm không nằm trong `homePins` và không tăng `k/5`.

## 2. Shutter chỉ Home root, Kho root, Hub

Cùng file `RootView.swift`. Hiện overlay bật khi `selectedTab != .review`, và `homePath` là `NavigationPath` chỉ nhận `String`. Streak dùng `NavigationLink { StreakCalendarView() }` nên không vào path. Phiên đọc push bên trong `CollectionDetailView` cũng không vào path. Vì vậy shutter vẫn hiện trên streak và phiên đọc.

Đổi path thành enum trong file này:

```swift
private enum ShellRoute: Hashable {
    case hub(String)
    case streak
}
```

- `@State private var homePath: [ShellRoute] = []`
- `@State private var khoPath: [ShellRoute] = []`
- Cả hai `NavigationStack` bind path tương ứng.
- `.navigationDestination(for: ShellRoute.self)`: `.hub` → `CollectionDetailView`, `.streak` → `StreakCalendarView`.
- Mọi `NavigationLink(value: collection.id)` đổi thành `ShellRoute.hub(collection.id)` (Home pin và Kho list).
- Streak: `NavigationLink(value: ShellRoute.streak)`, bỏ `NavigationLink { StreakCalendarView() }`.
- Sau Lưu, `homePath.append(hubID)` đổi thành `homePath.append(.hub(hubID))`.

```swift
private var showShutter: Bool {
    if model.suppressFloatShutter { return false }
    switch selectedTab {
    case .review: return false
    case .home: return isCaptureSurface(homePath)
    case .kho: return isCaptureSurface(khoPath)
    }
}

private func isCaptureSurface(_ path: [ShellRoute]) -> Bool {
    if path.isEmpty { return true }
    if path.count == 1, case .hub = path[0] { return true }
    return false
}
```

Phiên đọc không phải `ShellRoute`, nên path vẫn là một `.hub` khi đang đọc. Thêm trên [AppModel.swift](implementation/reado/app/Reado/AppModel.swift), cạnh `shutterTargetCollectionID`:

```swift
var suppressFloatShutter = false
```

[ReadingSessionView.swift](implementation/reado/app/Reado/ReadingSessionView.swift): `@Environment(AppModel.self)`, `.onAppear { model.suppressFloatShutter = true }`, `.onDisappear { model.suppressFloatShutter = false }`.

Sheet Capture / Analysis / Settings phủ lên tab nên không cần ẩn shutter thêm.

## 3. Dest trên camera hệ thống

File: [Capture/CaptureView.swift](implementation/reado/app/Reado/Capture/CaptureView.swift).

`destBar` trên màn trước máy ảnh giữ. `CameraView` hiện không set `cameraOverlayView`.

`CameraView` nhận thêm `destName`, `isInbox`, `onPickDest`, `onCreate`, `onLibrary`. `destIsInbox`: id nil hoặc collection `isDefault` thì true.

Khi `sourceType == .camera`, gán `cameraOverlayView`. Overlay SwiftUI (`UIHostingController`) trong một `UIView` subclass: `hitTest` trả nil nếu hit chính là root, để nút chụp hệ thống vẫn ăn. Chip trên: tên bộ + dòng "Không chọn → kho tạm" hoặc "Trang này vào bộ này", nút `+` 44pt. Dưới trái: nút thư viện 44pt. `updateUIViewController` gán lại `rootView` khi tên đổi.

Sheet chọn bộ và sheet tạo bộ phải gắn **bên trong** `fullScreenCover` camera (state riêng `showDestOnCamera` / `showCreateOnCamera`). Sheet của `destBar` (trước khi mở camera) giữ `showDestPicker` / `showNewCollection`. Cả hai đường gọi cùng `destPickerSheet` / `newCollectionSheet`, và nút đóng xóa cả hai cờ.

`onLibrary`: tắt camera, bật `showPhotoLibrary` đã có. Không tự mở camera khi vào màn Chụp.

Simulator không có camera thì picker rơi `.photoLibrary` và không gắn overlay. Dest trước máy ảnh vẫn dùng được.

## 4. Chọn tất cả trên duyệt từ

File: [AnalysisView.swift](implementation/reado/app/Reado/AnalysisView.swift). `ReviewDraft.isSelected` đã là `var`.

```swift
private var allSelected: Bool {
    !drafts.isEmpty && drafts.allSatisfy(\.isSelected)
}
private func setAllSelected(_ selected: Bool) {
    for index in drafts.indices { drafts[index].isSelected = selected }
}
```

Đặt `Button(allSelected ? "Bỏ chọn" : "Chọn tất cả")` là row đầu trong `Section` từ vựng, không đặt trong header (header List nuốt tap). Header giữ "Đã chọn n/m".

## 5. Ẩn FSRS trên Settings

File: [SettingsView.swift](implementation/reado/app/Reado/SettingsView.swift).

Xóa `fsrsSection` khỏi `List`, xóa `@State fsrs`, dòng `fsrs = try? ReadoFSRS.readSettings` trong `load()`, và `retentionLabel` nếu không còn chỗ gọi. Không xóa cột DB, không đổi `request_retention` 0.9 hay `maximum_interval`.

## 6. Theme mặc định rừng

`AppTheme.forest` đã là `#2F6B4F` trong [ReadoApp.swift](implementation/reado/app/Reado/ReadoApp.swift). Default `@AppStorage("appTheme")` đang là `system` ở cả `ReadoApp` và `SettingsView`. Đổi cả hai thành `AppTheme.forest.rawValue`.

Máy đã mở app thì UserDefaults đã ghi `system`. Trong `ReadoApp`, một lần:

```swift
@AppStorage("reado.appliedForestDefault") private var appliedForestDefault = false
```

`onAppear`: nếu chưa applied và `appTheme == system` thì gán `forest`, rồi set cờ true. User đã chọn Chàm hoặc Nâu giấy thì không đụng. Sau lần này, chọn lại Hệ thống được giữ.

## 7. Pin / ôn nhanh không nuốt lỗi

[AppModel.togglePin](implementation/reado/app/Reado/AppModel.swift) và `toggleReviewPriority` đang `try?` rồi `reloadOverview`. `HomePinError` đã có `errorDescription` ("Home giữ tối đa 5…", "Kho tạm không thể ghim…").

Đổi hai hàm thành `throws`. Gọi `HomePinService.set` / `ReviewScopeService.update` bằng `try`, rồi `reloadOverview`. Swipe trong `KhoTabView` (`pinSwipe`, `reviewSwipe`): `do { try model.togglePin(...) } catch { pinError = error.localizedDescription }`. Một `.alert` trên Kho hiện chuỗi đó. Đừng thêm toast framework.

`setReviewAll` cùng kiểu nếu cũng `try?`.

## Xong khi

- Home luôn thấy kho tạm, pin 5 không tính kho tạm.
- Shutter mất trên tab Ôn, lịch streak, và phiên đọc. Còn trên Home, list Kho, và Hub.
- Mở camera thật: thấy tên bộ trên overlay, đổi bộ được, thư viện được, nút chụp hệ thống vẫn bấm được.
- Duyệt từ: Chọn tất cả rồi Bỏ chọn.
- Settings không còn "Mục tiêu nhớ" / "Khoảng cách tối đa". App mới mở màu rừng.
- Ghim quá 5 (nếu gọi được) hiện alert, không im.

Chạy test sẵn có. Không viết suite mới.

```bash
cd implementation/reado/app
TMPDIR="$PWD/../.tmp" xcodebuild -project Reado.xcodeproj -scheme Reado \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath "$PWD/../DerivedData" \
  -clonedSourcePackagesDirPath "$PWD/../.xcode-packages" test
```
