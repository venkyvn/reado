# Plan `ux-polish-r1` — cải thiện UX/UI Reado (5 task, 0 dependency)

> **Trạng thái:** closed (2026-09-26) - 5 task UX/UI: nhịp ôn trên nút, TTS, Liquid Glass, onboarding checklist (ADR-040/041)

> Plan này thay cho `/rplan`: owner đã chọn phạm vi + 2 quyết định non-goal (2026-09-26).
> Người code (Sonnet) làm **đúng 1 task / session** theo thứ tự T1→T5, mỗi task đóng bằng `/rhandoff`.
> Việc đầu tiên của session T1: chép file này thành `docs/plans/ux-polish-r1.md` (commit cùng T1).

## Trạng thái — 2026-09-26, cùng session, code xong cả 5 task

| Task | Commit | Test |
|---|---|---|
| T1 U1 khoảng ôn trên nút | `45b2bc4` | 244/245 xanh (1 skip LiveAIBoxTests) |
| T2 U3 phát âm + U9 vòng đã thuộc (ADR-040) | `f2f2a5f` | 244/245 xanh |
| T3 U7 skeleton + U8 duyệt nhanh | `5f029c1` | 244/245 xanh |
| T4 Liquid Glass iOS 26 | `07864d7` | 244/245 xanh |
| T5 Onboarding checklist (ADR-041) | `101494e` | `OnboardingChecklistTests` 5/5 xanh riêng; full suite **256/258 xanh** (2026-09-28, sau ADR-042) |

**Đã giải quyết (2026-09-28):** lúc làm T5 (09-26) `OCRProbeTests.swift` của phiên
`ocr-line-drop` lỗi biên dịch nên full suite chạy không nổi; ADR-042 (`e0cb9da`) sửa
xong, full suite xanh lại — T5 khép, không còn việc treo.

## Context

Fen muốn nâng UX/UI. Research (Anki, Duolingo, LingQ, Things/Linear, Apple Liquid Glass) → fen chọn:
U1 khoảng ôn trên nút chấm · U3 phát âm · U9 vòng "đã thuộc" · U7 skeleton lúc chờ AI · U8 duyệt nhanh · U2 onboarding · UI native iOS 26, **không thêm dependency**.

**Quyết định owner 2026-09-26 (ghi ADR khi làm task tương ứng):**
- **ADR-040 (T2):** Nút loa TTS (`AVSpeechSynthesizer`, đọc một từ, không luyện nói, không chấm, không nội dung audio) **không vi phạm** NG-01/NG-02. Ranh giới: cấm ghi âm/nhận giọng/chấm phát âm/bài nghe.
- **ADR-041 (T5):** Onboarding = **checklist 3 bước trên Home, không trang mẫu** (trang mẫu = nội dung app soạn sẵn → trái NG-03 + vision #1). Đồng thời đóng dòng J-R1-S "CEFR trống lần đầu … phải nhìn thấy được".

**Sự thật đã kiểm trong code (đừng đoán lại):**
- Deployment target **iOS 17.0** (pbxproj + `Package.swift .iOS(.v17)`) → API iOS 18/26 phải bọc `if #available`.
- `ReviewScheduler.grade(_:snapshot:now:)` (`app/ReadoKit/Sources/ReadoKit/Review/ReviewScheduler.swift:215`) là hàm thuần, không ghi DB. `AppModel.grade` (`app/Reado/AppModel.swift:348`) dựng scheduler bằng `ReadoFSRS.readSettings(on:)` mỗi lần chấm.
- `ReviewOutcome.scheduledDays` = nhịp MỚI (Int, đã round).
- `masteredCount` đã có trên `AppModel.CollectionOverview` (`AppModel.swift:119`); Kho hiện dạng chữ (`RootView.swift:574-577`), Hub có `ProgressView` (`CollectionDetailView.swift:42-51`).
- `AnalysisView` đã có nút "Chọn tất cả/Bỏ chọn" (`AnalysisView.swift:310`); card là `ReviewCardRow` (private, cùng file).
- `AgentFormSheet`, `AgentPreset`, `KeyCheck` đang `private` trong `app/Reado/SettingsView.swift` (dòng 394/407/592). `AnalysisAgentStore.add(...)` mặc định `makeActive: true`.
- Test target **không** import module app (`Reado`) — logic cần test phải nằm trong `ReadoKit`.
- File mới trong `app/ReadoKit/Sources/...` = SPM tự nhận, **không** cần pbxproj. File mới trong `app/Reado/` hoặc `app/ReadoTests/` = **bắt buộc** `python3 scripts/pbxproj_tool.py add ...`.
- Working tree đang có `M app/Reado.xcodeproj/project.pbxproj` + `?? docs/sample.md` từ trước — **không phải của plan này**; trước mỗi commit xem `git diff`, chỉ stage hunk của task (memory: xcodebuild re-sort pbxproj → flush churn).

**Luật chung mọi task:** tôn `accessibilityReduceMotion` (dùng `Motion.run`/`Motion.reveal` ở `app/Reado/ReadoApp.swift:86`), màu qua `Theme.*`/`Color.accentColor`, không đổi màu nút grade (ADR-038 §3), không hardcode hex, comment tiếng Việt ngắn cùng giọng code xung quanh. Build/test **chỉ** `scripts/test.sh`.

---

## T1 — U1: khoảng ôn kế tiếp trên nút chấm (như Anki)

**Mục tiêu:** mặt sau thẻ, dưới mỗi nút Quên/Khó/Được/Dễ hiện dòng nhỏ "1 ngày", "4 ngày", "2 tháng"…; stamp khi vuốt hiện "Quên · 1 ngày" / "Được · 4 ngày". Số lấy từ `swift-fsrs` thật qua `ReviewScheduler` (luật §4: không tự tính).

### 1a. ReadoKit — file mới `app/ReadoKit/Sources/ReadoKit/Review/IntervalPreview.swift`
```swift
import Foundation

/// U1 ux-polish-r1: xem trước nhịp ôn cho cả 4 mức chấm — gọi đúng
/// `ReviewScheduler.grade` (thuần, không ghi DB), không tự tính FSRS.
public enum IntervalPreview {
    public static func outcomes(
        scheduler: ReviewScheduler, snapshot: CardSnapshot, now: Date
    ) throws -> [ReadoRating: ReviewOutcome] {
        var result: [ReadoRating: ReviewOutcome] = [:]
        for rating in ReadoRating.allCases {
            result[rating] = try scheduler.grade(rating, snapshot: snapshot, now: now)
        }
        return result
    }

    /// Nhãn ngắn tiếng Việt từ số ngày: 0 → "<1 ngày", 1–29 → "N ngày",
    /// 30–364 → "N tháng" (days/30 làm tròn, tối thiểu 1), ≥365 → "N năm"
    /// (1 chữ số thập phân dấu phẩy, bỏ ",0": 1,5 năm / 2 năm).
    public static func label(days: Int) -> String { … }
}
```
- `ReadoRating` phải `Hashable` để làm key dict — enum `Int` raw đã Hashable, OK.
- Fuzz: dùng **cùng** settings như lúc chấm thật (không tắt fuzz). Chấp nhận lệch ±vài % do `now` khác nhau; nhãn là ước lượng thô nên không hiện sai bậc. Ghi 1 dòng comment lý do.

### 1b. AppModel — thêm hàm (cạnh `grade`, `AppModel.swift:~367`)
```swift
/// U1: nhãn nhịp ôn cho thẻ đang hiện — lỗi thì trả rỗng (nút vẫn chấm được).
func intervalLabels(for snapshot: CardSnapshot) -> [ReadoRating: String] {
    guard let database,
          let settings = try? ReadoFSRS.readSettings(on: database),
          let scheduler = try? ReviewScheduler(settings: settings),
          let outcomes = try? IntervalPreview.outcomes(
              scheduler: scheduler, snapshot: snapshot, now: SystemClock().now)
    else { return [:] }
    return outcomes.mapValues { IntervalPreview.label(days: $0.scheduledDays) }
}
```

### 1c. `app/Reado/Screens/ReviewQueueView.swift`
- Thêm `@State private var intervalLabels: [ReadoRating: String] = [:]` và helper:
  ```swift
  private func refreshIntervals() {
      intervalLabels = lastSnapshot.map { model.intervalLabels(for: $0) } ?? [:]
  }
  ```
  Gọi ở **3 chỗ** `lastSnapshot` đổi: cuối `loadQueue()` (sau khi gán `lastSnapshot`), trong `gradeNow` ngay sau `lastSnapshot = nextSnap`, và cuối `performUndo()` thành công (thẻ quay lại → `lastSnapshot` giữ snapshot cũ, nhưng vẫn gọi để chắc). **Không** tính trong `body` (drag render mỗi frame).
- `gradeButton(_:)` (dòng 509): label thành `VStack(spacing: 2) { Text(rating.label).font(.subheadline.weight(.semibold)); if let hint = intervalLabels[rating] { Text(hint).font(.caption2).monospacedDigit().opacity(0.8) } }`; `minHeight` 44 → **52**. Giữ nguyên `buttonBackground/buttonForeground`.
  `.accessibilityLabel(intervalLabels[rating].map { "\(rating.label), ôn lại sau \($0)" } ?? rating.label)`.
- `swipeStamp` (dòng 375): truyền text `"Quên · \(intervalLabels[.again] ?? "")"` — viết helper `stampText(_ rating:)` trả `rating.label` khi không có nhãn, `"\(rating.label) · \(hint)"` khi có. `badgeLabel` giữ nguyên.
- Dòng gợi ý mặt trước (dòng 300) giữ nguyên.

### 1d. Test — thêm vào `app/ReadoTests/ReviewSchedulerTests.swift` (file có sẵn → không đụng pbxproj)
1. `testIntervalPreviewMatchesGradeForNewCard` — scheduler fuzz=false, `Fixtures.cardSnapshot(due: now)`; với mỗi rating: `IntervalPreview.outcomes(...)[r]` == `scheduler.grade(r, snapshot:, now:)` (so `scheduledDays`, `stability`, `state`).
2. `testIntervalPreviewMatchesGradeForReviewCard` — snapshot state "review", stability 10, reps 3, lastReview = now − 10 ngày, due = now.
3. `testIntervalPreviewOrderedAgainToEasy` — review card: days(again) ≤ days(hard) ≤ days(good) ≤ days(easy).
4. `testIntervalLabelBuckets` — 0→"<1 ngày", 1→"1 ngày", 29→"29 ngày", 30→"1 tháng", 45→"2 tháng" (45/30=1.5 → round 2), 364→"12 tháng", 365→"1 năm", 548→"1,5 năm", 730→"2 năm".
(Không cần test "không ghi DB": `IntervalPreview` không nhận `SQLiteDatabase`.)

### 1e. Docs
- `docs/specs/journeys.md` J4: thêm 1 dòng "Nút chấm hiện nhịp ôn kế tiếp (preview FSRS, ước lượng)". Grep `## J4` rồi Edit, không đọc nguyên file.
- Không cần ADR (chỉ hiển thị, CLAUDE.md §6.4) — ghi lựa chọn fuzz vào journal/session-brief qua `/rhandoff`.

**Verify T1:** `scripts/test.sh test -only-testing:ReadoTests/ReviewSchedulerTests` → full `scripts/test.sh` (kỳ vọng 231/232, +4). Chạy simulator: ôn 1 thẻ new → lật → thấy 4 nhãn; vuốt → stamp có nhãn; bật Dynamic Type AX → nút grid 2×2 không cắt chữ.

---

## T2 — U3 phát âm (TTS) + U9 vòng "đã thuộc"

### 2a. ADR-040 trong `docs/decisions-log.md` (append cuối, theo khuôn ADR-039)
Tiêu đề: "ADR-040 — Nút loa đọc từ (TTS on-device) không thuộc NG-01/NG-02". Nội dung: bối cảnh (research U3), quyết định (chỉ `AVSpeechSynthesizer` đọc `term`, offline, không lưu audio), ranh giới cấm (ghi âm, speech recognition, chấm phát âm, shadowing, bài nghe), hệ quả. Thêm 1 dòng vào bảng "Đã chốt" của `docs/specs/prd.md` cạnh NG-01/02 (grep `NG-01`) trỏ ADR-040 — **không** sửa nội dung dòng NG.

### 2b. File mới `app/Reado/Pronunciation.swift` (+ `python3 scripts/pbxproj_tool.py add --file app/Reado/Pronunciation.swift --group Reado --target Reado`)
```swift
import AVFoundation
import SwiftUI

/// ADR-040: đọc một từ bằng giọng on-device — không luyện nói, không chấm.
@MainActor
enum Pronunciation {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ term: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        // .playback để vẫn nghe khi gạt im lặng — user chủ động bấm loa.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio, options: [.duckOthers])
        let utterance = AVSpeechUtterance(string: term)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}

/// Nút loa 44×44 dùng chung (thẻ ôn + card duyệt).
struct SpeakButton: View {
    let term: String
    var body: some View {
        Button { Pronunciation.speak(term); Haptics.selection() } label: {
            Image(systemName: "speaker.wave.2")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("Đọc từ \(term)")
    }
}
```
- Icon outline theo `visual-redesign-plan.md` §1 (nút điều hướng/hành động phụ = outline).

### 2c. Gắn nút
- `ReviewQueueView.cardFace` mặt trước (dòng 433-444): thêm `SpeakButton(term: item.term)` dưới pos badge. Button con thắng `.onTapGesture` lật thẻ của cha → không lật khi bấm loa (kiểm tay trên simulator).
- `backFaceContent` (dòng 460): `HStack { Text(ipa)…; SpeakButton(term: item.term) }` — nếu `ipa == nil` vẫn hiện nút ở hàng riêng.
- `AnalysisView.ReviewCardRow.editor` (dòng 505, field IPA): `HStack { editorField("Phiên âm (IPA)") {…}; SpeakButton(term: draft.term) }`. **Không** đặt trong `summaryLabel` (nằm trong Button mở rộng → nút lồng nút).
- `ReviewQueueView.onDisappear`: không cần dừng giọng (câu 1 từ rất ngắn).

### 2d. U9 — `MasteryRing` trong `app/Reado/RootView.swift` (private struct cuối file)
```swift
/// Ý 4 motivation-r1 dạng vòng: tỉ lệ đã thuộc (Q-08) của một bộ. Bộ rỗng → không vẽ.
private struct MasteryRing: View {
    let mastered: Int
    let total: Int
    var body: some View {
        let ratio = total > 0 ? Double(mastered) / Double(total) : 0
        ZStack {
            Circle().stroke(Theme.surfaceStrong, lineWidth: 3)
            Circle().trim(from: 0, to: ratio)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
        .accessibilityElement()
        .accessibilityLabel("Đã thuộc \(mastered) trên \(total) từ")
    }
}
```
- Kho `collectionRow` (dòng 536): chèn `if collection.totalItems > 0 { MasteryRing(mastered: collection.masteredCount, total: collection.totalItems) }` ngay **sau** `Spacer()`, trước badge ưu tiên (số thứ tự Ôn nhanh). Giữ dòng chữ `wordCountLabel` (VoiceOver + số chính xác).
- Home `homePinRows` (dòng 411-414): đổi `Text("\(collection.totalItems) từ")` thành cùng format `wordCountLabel` — chuyển `wordCountLabel` từ `KhoTabView` thành hàm `fileprivate func masteryLabel(_:)` cấp file để dùng chung; thêm `MasteryRing` sau `Spacer()`.
- Home `inboxRow`: giữ nguyên (kho tạm là chỗ chứa tạm, không phải bộ đang học).

**Verify T2:** full `scripts/test.sh` (không test mới; logic thuần không đổi). Simulator: bấm loa mặt trước → nghe, thẻ không lật; bật gạt im lặng trên máy thật vẫn nghe (fen kiểm); Kho/Home có vòng, bộ 0 từ không có vòng; VoiceOver đọc "Đã thuộc X trên Y từ".

---

## T3 — U7 skeleton lúc chờ AI + U8 duyệt nhanh (`app/Reado/AnalysisView.swift` duy nhất)

### 3a. U7 skeleton
- Thêm `private struct AnalysisSkeleton: View` cuối file: `VStack(spacing: 16)` gồm 4 hàng giả dạng `ReviewCardRow` — mỗi hàng `HStack(spacing: 12) { Circle().frame(24); VStack(alignment: .leading, spacing: 6) { RoundedRectangle(cornerRadius: 4).frame(width: 120, height: 14); RoundedRectangle(cornerRadius: 4).frame(maxWidth: .infinity).frame(height: 10) } }`, fill `Theme.surfaceStrong`.
- Nhịp: `@State private var dim = false` + `.opacity(dim ? 0.45 : 1)`; `.onAppear { guard !reduceMotion else { return }; withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true } }`. Reduce Motion → đứng yên.
- `.accessibilityHidden(true)` (đã có dòng progressTitle cho VoiceOver).
- Nhánh `model.isAnalyzing` (dòng 68-83): bọc `VStack(spacing: 24) { <khối ProgressView + progressTitle + "Thường mất…" giữ nguyên>; AnalysisSkeleton().padding(.horizontal) ; Spacer() }` + `.padding(.top, 32)`; bỏ `.frame(maxWidth:.infinity)` căn giữa dọc cũ nếu làm skeleton lệch.
- Không làm progressive render theo SSE (ngoài phạm vi, đụng decoder).

### 3b. U8 duyệt nhanh
- Thêm computed + hàm:
  ```swift
  /// U8: chỉ bật card đã kiểm (verified) — unverified/suspect giữ nguyên lựa chọn hiện tại (ADR-008).
  private var hasUnselectedVerified: Bool {
      drafts.contains { $0.verification == .verified && !$0.isSelected }
  }
  private func selectAllVerified() {
      for i in drafts.indices where drafts[i].verification == .verified { drafts[i].isSelected = true }
      Haptics.selection()
  }
  ```
- Hàng nút trong Section từ vựng (dòng 310): đổi thành
  `HStack { Button(allSelected ? "Bỏ chọn" : "Chọn tất cả") {…}; Spacer(); if hasUnselectedVerified { Button("Chọn tất cả đã kiểm", action: selectAllVerified) } }.buttonStyle(.borderless)` — **bắt buộc `.borderless`**, không thì List cho cả hàng bấm cả 2 nút.
- Vuốt: trên `ReviewCardRow(...)` trong `ForEach` thêm
  ```swift
  .swipeActions(edge: .leading, allowsFullSwipe: true) {
      Button { drafts[index].isSelected.toggle(); Haptics.selection() } label: {
          Label(drafts[index].isSelected ? "Bỏ chọn" : "Chọn",
                systemImage: drafts[index].isSelected ? "circle" : "checkmark.circle")
      }
      .tint(drafts[index].isSelected ? .gray : .accentColor)
  }
  ```
- Header "Đã chọn x/y" (dòng 323): thêm `.contentTransition(.numericText())` + `.animation(reduceMotion ? nil : Motion.reveal, value: selectedCount)`.

**Verify T3:** full `scripts/test.sh` (không đổi logic ReadoKit). Simulator với agent mock/AI-Box (`scripts/sim_aibox.sh`): lúc chờ thấy skeleton nhấp nháy; bật Reduce Motion → đứng yên; kết quả về → "Chọn tất cả đã kiểm" chỉ bật verified, không đụng "Chưa xác minh"; vuốt phải 1 card đổi trạng thái chọn; số "Đã chọn" đổi mượt.

---

## T4 — Pass UI native iOS 26 (0 dependency)

Khớp `design-system/reado/MASTER.md` (FROZEN liquid-glass: glass trên chrome, nội dung đọc đặc). Không đụng màn Capture (đã tự vẽ, ADR-036).

### 4a. Helper trong `app/Reado/ReadoApp.swift` (sau `extension View { card(...) }`)
```swift
extension View {
    /// Liquid Glass cho chrome nổi (tab bar). iOS < 26 rơi về material cũ.
    @ViewBuilder
    func chromeGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay { shape.stroke(Theme.surfaceStrong, lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}
```
(Kiểm chữ ký `glassEffect(_:in:)` trên SDK máy bằng build; nếu `Shape` generic không nhận, dùng `some Shape`/`AnyShape`.)

### 4b. `app/Reado/ShellTabBar.swift`
- Thay 3 dòng `.background(.regularMaterial, in: Capsule())`, `.overlay { Capsule().strokeBorder… }`, `.shadow(...)` (dòng 31-35) bằng `.chromeGlass(in: Capsule())`. Pill chọn (`matchedGeometryEffect`) giữ nguyên.
- Icon tab: thêm `.symbolEffect(.bounce, value: selected && !reduceMotion)` trên `Image` để nảy nhẹ khi chọn.

### 4c. `FloatShutter` (`app/Reado/RootView.swift:207`)
- iOS 26: `Image(...).frame(size).glassEffect(.regular.tint(Color.accentColor).interactive(), in: Circle())` và bỏ `ShutterPressStyle` (glass interactive tự phản hồi nhấn); `else` giữ nguyên code cũ (Circle fill + shadow + ShutterPressStyle). Viết bằng `if #available` trong `body`.
- **Không** dùng `GlassEffectContainer`/`glassEffectID` morph giữa shutter và tab bar: hai view nằm ở 2 lớp khác nhau (`overlay` vs `safeAreaInset`), gộp container sẽ phá cách đặt vị trí đã đo bằng screenshot (comment dòng 93-102).

### 4d. Số đổi mượt (`contentTransition(.numericText())`, iOS 17 OK)
- `ReviewQueueView` progress `Text("\(currentIndex + 1)/\(items.count)")` (dòng 239) — đã đổi trong `withAnimation`, chỉ thêm modifier.
- Home `Text("\(progress.dueToday) thẻ sẽ ôn")` (RootView dòng 306) + `Label("\(progress.streak) ngày ôn liên tục"…)` (dòng 370): thêm modifier + `.animation(reduceMotion ? nil : Motion.reveal, value: progress.dueToday / progress.streak)` (HomeTabView cần `@Environment(\.accessibilityReduceMotion)`).
- Icon `flame.fill` ở streakRow: `.symbolEffect(.bounce, value: reduceMotion ? 0 : progress.streak)` — tách `Label` thành `HStack { Image; Text }` nếu cần gắn effect riêng cho icon.

### 4e. `app/Reado/SessionDoneView.swift` (ADR-038: chỉ số thật)
- Nền: `.background { doneBackground.ignoresSafeArea() }` với
  ```swift
  @ViewBuilder private var doneBackground: some View {
      if #available(iOS 18, *) {
          MeshGradient(width: 2, height: 2,
              points: [[0, 0], [1, 0], [0, 1], [1, 1]],
              colors: [Color.accentColor.opacity(0.18), Theme.ok.opacity(0.10),
                       Color(.systemBackground), Color(.systemBackground)])
      } else {
          LinearGradient(colors: [Color.accentColor.opacity(0.15), Color(.systemBackground)],
                         startPoint: .top, endPoint: .center)
      }
  }
  ```
- Header checkmark: `.symbolEffect(.bounce, value: appeared && !reduceMotion)`.
- `statsGrid`: 3 ô hiện lần lượt — mỗi `stat(...)` thêm tham số `index`, `.opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10).animation(reduceMotion ? nil : Motion.reveal.delay(Double(index) * 0.08), value: appeared)`; bỏ `.opacity(appeared…)` bao cả ScrollView (dòng 45) để khỏi chồng hai nhịp — header/masteredSection tự thêm opacity riêng.
- Không confetti/particle, không đổi màu nút.

### 4f. Không làm (ghi rõ để khỏi lan)
- Không đổi `Haptics` sang `.sensoryFeedback` (đang imperative đúng chỗ — đổi = churn).
- Không đặt glass lên card ôn, list, editor (nội dung đọc phải đặc).

### 4g. Docs
- `docs/ux/visual-redesign-plan.md`: thêm mục "§7 Liquid Glass (iOS 26) — ux-polish-r1 T4": chrome dùng `chromeGlass`, fallback iOS 17–25, danh sách chỗ dùng numericText/symbolEffect, lý do không morph.

**Verify T4:** full `scripts/test.sh`. Screenshot simulator iPhone 18 Pro (iOS 26+): Home (tab bar glass + shutter glass), Ôn (đếm 1/N đổi mượt), SessionDone (mesh nền, 3 ô hiện lần lượt). Bật Reduce Motion + Reduce Transparency (Settings → Accessibility) → vẫn đọc được, không nhảy. Dark mode chụp lại 3 màn.

---

## T5 — U2 onboarding checklist (ADR-041)

### 5a. ADR-041 + docs
- `docs/decisions-log.md`: "ADR-041 — Onboarding = checklist 3 bước trên Home, không trang mẫu". Lý do: NG-03 + vision #1; proxy chưa deploy nên bước agent là chỗ rơi user thật; đóng dòng J-R1-S "CEFR trống lần đầu". Trạng thái lưu **UserDefaults** (không DB, không migration) — mất khi xoá app là chấp nhận được.
- `docs/specs/journeys.md` J-R1-S bảng Empty/error (dòng ~349): **không sửa** dòng cũ; thêm ghi chú dưới bảng "→ ADR-041: checklist Home bước 1 hiện CEFR đang chọn".

### 5b. ReadoKit — file mới `app/ReadoKit/Sources/ReadoKit/Onboarding/OnboardingChecklist.swift` (logic thuần để test được)
```swift
/// ADR-041: checklist bắt đầu trên Home. Trạng thái suy từ dữ liệu thật +
/// 2 cờ UserDefaults — không lưu DB.
public struct OnboardingChecklist: Equatable, Sendable {
    public enum Step: Int, CaseIterable, Sendable { case cefr, agent, firstPage }

    public let cefrConfirmed: Bool
    public let agentReady: Bool
    public let hasFirstPage: Bool
    public let dismissed: Bool

    public init(cefrConfirmed: Bool, agentReady: Bool, hasFirstPage: Bool, dismissed: Bool)

    /// Đã có trang đầu tiên thì coi như CEFR đã được dùng (user cũ không bị hỏi lại).
    public func isDone(_ step: Step) -> Bool {
        switch step {
        case .cefr: cefrConfirmed || hasFirstPage
        case .agent: agentReady
        case .firstPage: hasFirstPage
        }
    }
    /// Chụp cần agent chạy được — khoá bước 3 tới khi xong bước 2.
    public func isEnabled(_ step: Step) -> Bool { step != .firstPage || agentReady }
    public var doneCount: Int { Step.allCases.filter(isDone).count }
    /// Ẩn khi user tắt, hoặc agent + trang đầu đều xong (user cũ như owner không thấy).
    public var isVisible: Bool { !dismissed && !(agentReady && hasFirstPage) }
}
```

### 5c. Test — file mới `app/ReadoTests/OnboardingChecklistTests.swift` (+ `python3 scripts/pbxproj_tool.py add --file app/ReadoTests/OnboardingChecklistTests.swift --group ReadoTests --target ReadoTests`)
1. Người mới (tất cả false) → visible, doneCount 0, firstPage disabled.
2. agentReady only → firstPage enabled, doneCount 1.
3. hasFirstPage + agentReady (user cũ) → invisible, cefr done dù cefrConfirmed false.
4. dismissed → invisible bất kể còn lại.
5. hasFirstPage nhưng agent chưa sẵn (proxy lỗi sau này) → vẫn visible, doneCount 2.

### 5d. AppModel
- `private(set) var activeAgentReady = false` — cập nhật cuối `reloadOverview()`:
  ```swift
  // ADR-041: proxy mặc định chưa deploy → chỉ agent BYOK có key mới tính "sẵn sàng".
  if let list = try? AnalysisAgentStore.list(on: database) {
      activeAgentReady = list.agents.first { $0.id == list.activeID }
          .map { !$0.isBuiltinProxy && $0.hasKey } ?? false
  }
  ```
  (Ghi TODO-comment: khi proxy deploy xong, đổi điều kiện thành `hasKey` — proxy luôn `hasKey = true`.)
- `var hasFirstPage: Bool { (dailyProgress?.pagesAnalyzed ?? 0) > 0 || collections.contains { $0.totalItems > 0 } }`
- `func addAgent(name: String, baseURL: String, model: String, apiKey: String?) -> String?` — copy thân `SettingsView.addAgent` (dòng 319-340) nhưng gọi `reloadOverview()` thay `reloadAgents()`; trả thông điệp lỗi hoặc nil. (Không refactor SettingsView trong task này.)

### 5e. Mở `AgentFormSheet` cho dùng lại — `app/Reado/SettingsView.swift`
- Bỏ `private` ở `AgentPreset` (394), `AgentFormSheet` (407), `KeyCheck` (592). Không đổi gì khác.

### 5f. File mới `app/Reado/OnboardingChecklistSection.swift` (+ pbxproj_tool add `--group Reado --target Reado`)
```swift
/// ADR-041: Section "Bắt đầu với Reado" đầu Home — 3 bước, mỗi bước suy trạng thái
/// từ dữ liệu thật. Không trang mẫu (NG-03).
struct OnboardingChecklistSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reado.onboarding.cefrConfirmed") private var cefrConfirmed = false
    @AppStorage("reado.onboarding.dismissed") private var dismissed = false
    @State private var showAgentForm = false
    let onOpenSettings: () -> Void
    let onCapture: () -> Void

    private var checklist: OnboardingChecklist { .init(cefrConfirmed:…, agentReady: model.activeAgentReady, hasFirstPage: model.hasFirstPage, dismissed: dismissed) }

    var body: some View {
        if checklist.isVisible {
            Section { cefrRow; agentRow; firstPageRow } header: {
                Text("Bắt đầu với Reado · \(checklist.doneCount)/3")
            } footer: {
                Button("Ẩn hướng dẫn") { Motion.run(reduceMotion: reduceMotion) { dismissed = true } }
                    .font(.caption)
            }
            .sheet(isPresented: $showAgentForm) {
                AgentFormSheet(agent: nil) { name, base, modelName, key in
                    model.addAgent(name: name, baseURL: base, model: modelName, apiKey: key)
                }
            }
        }
    }
}
```
Mỗi hàng: `HStack(spacing: 12) { Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle").foregroundStyle(done ? Theme.ok : Color.accentColor).contentTransition(.symbolEffect(.replace)); VStack(alignment: .leading) { title .headline; subtitle .caption .secondary }; Spacer(); <nút> }`, nút `.buttonStyle(.borderless)`.
- **Bước 1 CEFR:** title "Trình độ đọc", subtitle "Đang lọc từ theo: B2" (từ `model.loadLearningSettings()?.cefrLevels.map(\.rawValue).joined(separator: ", ")`, đọc 1 lần trong `.task`/`onAppear` vào `@State`). Chưa xong → 2 nút "Đúng" (`cefrConfirmed = true`) và "Đổi" (`cefrConfirmed = true; onOpenSettings()`).
- **Bước 2 Agent:** title "Kết nối agent phân tích", subtitle "Mặc định AI-Box — dán API key một lần." Chưa xong → nút "Thêm" mở `showAgentForm`. Sau khi sheet lưu, `model.addAgent` đã `reloadOverview()` → `activeAgentReady` cập nhật → hàng tự tick.
- **Bước 3 Trang đầu:** title "Chụp trang sách đầu tiên", subtitle khi disabled "Cần kết nối agent trước". Enabled → nút "Chụp" gọi `onCapture()`.
- Accessibility: mỗi hàng `.accessibilityElement(children: .combine)` + `.accessibilityValue(done ? "Đã xong" : "Chưa xong")`, nút giữ action riêng.

### 5g. Nối vào Home — `app/Reado/RootView.swift`
- `HomeTabView` thêm `let onCapture: () -> Void`; `homeList` chèn `OnboardingChecklistSection(onOpenSettings: onSettings, onCapture: onCapture)` **đầu** `List` (trước `dailyProgressRows`).
- `RootView` truyền `onCapture: openShutterCapture` (đích = kho tạm vì Home root `shutterTargetCollectionID == nil`).

**Verify T5:** `scripts/test.sh test -only-testing:ReadoTests/OnboardingChecklistTests` (5/5) → full suite (kỳ vọng tổng T1 + 5). Simulator **cài mới** (xoá app): Home hiện checklist 0/3, bước 3 xám; "Đúng" → 1/3; "Thêm" → form AI-Box → lưu key → 2/3; "Chụp" mở camera; lưu trang xong → checklist biến mất. Simulator có dữ liệu cũ + agent AI-Box (`scripts/sim_aibox.sh`) → không thấy checklist. "Ẩn hướng dẫn" → ẩn vĩnh viễn.

---

## Critical files (tổng)
| File | Task |
|---|---|
| `app/ReadoKit/Sources/ReadoKit/Review/IntervalPreview.swift` (mới) | T1 |
| `app/Reado/AppModel.swift` | T1, T5 |
| `app/Reado/Screens/ReviewQueueView.swift` | T1, T2, T4 |
| `app/ReadoTests/ReviewSchedulerTests.swift` | T1 |
| `app/Reado/Pronunciation.swift` (mới, pbxproj) | T2 |
| `app/Reado/AnalysisView.swift` | T2, T3 |
| `app/Reado/RootView.swift` | T2, T4, T5 |
| `app/Reado/ReadoApp.swift`, `ShellTabBar.swift`, `SessionDoneView.swift` | T4 |
| `app/ReadoKit/Sources/ReadoKit/Onboarding/OnboardingChecklist.swift` (mới) | T5 |
| `app/ReadoTests/OnboardingChecklistTests.swift` (mới, pbxproj) | T5 |
| `app/Reado/OnboardingChecklistSection.swift` (mới, pbxproj), `SettingsView.swift` | T5 |
| `docs/decisions-log.md` (ADR-040, 041), `docs/specs/journeys.md`, `docs/specs/prd.md` (1 dòng), `docs/ux/visual-redesign-plan.md` | T1, T2, T4, T5 |

## Verification chung (mỗi task)
1. Sửa → `scripts/test.sh test -only-testing:ReadoTests/<Class>`; trước `/rhandoff` chạy full `scripts/test.sh`, phải thấy `** TEST SUCCEEDED **` — không có thì không ghi "xong", không bịa số (CLAUDE.md §7).
2. `python3 scripts/pbxproj_tool.py check` xanh (test.sh tự chạy) khi có file app/test mới.
3. Chạy simulator iPhone 18 Pro, screenshot màn đã đổi (light + dark), bật Reduce Motion kiểm fallback.
4. `/rhandoff`: owner approve → cập nhật `docs/plans/ux-polish-r1.md` (tick task + commit hash) → commit chỉ hunk thật (flush churn pbxproj do xcodebuild re-sort).
