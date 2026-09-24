# Session Brief — Nguồn duy nhất cho agent mỗi session mới (reado_v2)

> Đọc `CLAUDE.md` trước, rồi file này (Turn 1). Từ Turn 2 cấm đọc lại.
> Kho luật đầy đủ: `docs/agent/agent-rulebook.md` — chỉ mở khi task chạm điều khoản.

---

## 1. Tình trạng hiện tại (cập nhật 2026-09-24)

- **Phase 2 hoàn tất ✅ CLOSED** (2026-09-24, owner e2e iPhone thật pass; 59/59 test xanh, commit `7ca9d2f`)
- **Phase 3 — Task 3.1 FR-16 Data Export ✅** — 55/55 test xanh (iPhone 18 Pro 2026-09-24), commit `d23e19a` (bàn giao trước ghi nhầm `0a8244c`).
  - `ExportService`: TSV 7 cột Anki-compatible (lọc theo collection, escape tab/newline, giữ tiếng Việt) + JSON FSRS backup (toàn bộ máy, NFR-07 chặn key).
  - `ExportView`: chọn collection + nút Xuất CSV/Xuất JSON + ShareSheet.
  - `ExportTests`: 12 test.
- **Phase 3 — Task 3.2 FR-19 Leech ✅** — 70/70 test xanh (iPhone 18 Pro), commit `7ea032e`.
  - `LeechService`: đếm lapse tích luỹ, suspend khi `lapses >= leech_lapses`, `unsuspend`/`deleteCard`/`fetchLeeches`, idempotent. Hook ở `AppModel.grade` SAU `ReviewService.record` (cùng luồng).
  - `Seeder.defaultLeechLapses` = 6 🔶 **TẠM, chưa chốt** — chờ Q-08 (PRD FR-19: "ngưỡng cụ thể chưa chốt… thấp hơn Anki 8"). UI sinh lại thẻ để task sau.
  - `LeechTests`: 15 test (đọc/tắt threshold, suspend boundary, idempotent, unsuspend/delete, fetchLeeches, loại khỏi queue, e2e grade chain).
- **Phase 3 — Task 3.3 FR-04 Capture failure ✅** — 91/91 test xanh (iPhone 18 Pro), commit `fb7f53a` (+ `1364be4` fix build).
  - G1 ảnh mờ/không đọc được → báo riêng + CTA "Chụp lại"; G2 trang không phải tiếng Anh → "không hỗ trợ" + "không tính phí". Không bịa dữ liệu.
  - `AnalysisError.suggestsRecapture` · `AppModel.analysisFailure` + `prepareRecapture()` · `AnalysisView.failureView` · RootView onDismiss mở lại chụp.
  - ⚠️ Sửa kèm bug tiền-ẩn: `d23e19a` làm mất `PBXFileReference` của `AnalysisTests.swift` → 16 test FR-02/FR-03 bị skip ngầm ("70/70" không chạy chúng). Khôi phục → 91/91.
- **Phase 3 — Task 3.6 FR-14 Daily Progress ✅** — 98/98 test xanh (iPhone 18 Pro), commit `7263fb1`.
  - `DailyProgressService` (ReadoKit/Progress): "sẽ ôn hôm nay" = nhánh due + nhánh new trong hạn mức (FR-11 — KHÔNG tổng `due_at` thô) · backlog thẻ new vượt quota RIÊNG · trang đã phân tích (`reading_sessions`, = 0 tới khi FR-05/06 ghi) · streak theo giờ chuyển ngày `DayBoundary` (04:00, không nửa đêm). Leech tự loại (`suspended_at IS NULL`).
  - `AppModel.dailyProgress` + `loadDailyProgress(db:)` (reloadOverview gọi kèm) · RootView bỏ CTA "N thẻ đến hạn" thô → header DailyProgress; hết hạn mức → chỉ báo "N thẻ mới đang chờ", không CTA giả. Sheet Ôn tập `onDismiss` reload lại.
  - `DailyProgressTests`: 7 test — dueToday quota-aware (13 = 10 new + 3 due, không 18) · backlog riêng · leech loại · streak liên tiếp/gap/hôm-nay-chưa-ôn/cutoff-vs-midnight · số trang.
- **Phase 3 — Task 3.7 FR-15 Settings ✅** — 107/107 test xanh (iPhone 18 Pro), commit `e1f5d5a`.
  - `SettingsService` (ReadoKit/Settings): `LearningSettings` (cefrLevel/dailyNewLimit/dayCutoffHour) + `CEFRLevel` (A2–C1) + `load`/`update`. Validate `daily_new_limit` 0–999 (D-lim-0: 0 hợp lệ) + `day_cutoff_hour` 0–23; update CHỈ chạm 3 cột học tập — `request_retention` + núm FSRS ngoài phạm vi (R1 không mở user).
  - `SettingsView`: Picker CEFR + Stepper hạn mức + Stepper giờ chuyển ngày + bảng chỉ-đọc "Thuật toán ôn tập" (retention/max interval/fsrs-6). CEFR có hiệu lực lần capture kế tiếp (AnalyzerFactory đọc live); trang đã phân tích không chạy lại.
  - `AppModel`: bỏ SQL inline `readDailyNewLimit` → `SettingsService`; thêm `loadLearningSettings()` / `saveLearningSettings()` (reloadOverview sau save). RootView thêm gear CTA → sheet.
  - `SettingsTests`: 9 test — seed default · load chưa seed · update persist · CEFR feed analyzer · reject -1/1000/24 · không chạm cột FSRS · limit 0 → nhánh new rỗng chỉ còn due.
- **Phase 3 — Task 3.5 FR-08 + FR-17 ✅** — 122/122 test xanh iPhone 18 Pro (2026-09-24), commit `0a5de27`.
  - FR-08 danh sách từ: `VocabRepository.listVocabulary` (đủ trường + tên collection; `order = .byTerm` gộp cùng `term` cạnh nhau không gộp, `.byDateAdded` cho kho tạm J6) + `CollectionDetailView` thay scaffold (term/pos/ipa/meaning_vi/cefr/example).
  - FR-17(a+b+c): `allCollectionSummaries` (tên/số từ/đến hạn/lần thêm gần nhất — thay query overview cũ ở AppModel) + Home hiện "lần thêm gần nhất" + CTA "Tạo collection" · `renameCollection`/`deleteCollection` (kho tạm → `cannotDeleteDefault`; còn từ → `hasWords(n)` bắt chuyển đi) · kho tạm "Sắp xếp" chọn lô chuyển collection — `moveVocabularyItems` chỉ đổi `collection_id`, GIỮ nguyên FSRS.
  - `CollectionError` (notFound/cannotDeleteDefault/hasWords) + 15 test mới `VocabularyListTests` (list/thứ tự/lọc/move-giữ-FSRS/rename/delete/summary). Shortcut Home (tối đa 2) **để task riêng** (owner chốt 2026-09-24 — gắn J2 hub + Home).
- **Phase 3 — Task 3.9 FR-18 Scoped Review ✅** — 129/129 test xanh iPhone 18 Pro (2026-09-24), commit `5060ada`.
  - Ba chế độ phạm vi (tất cả / một / vài collection): `ReviewQueue` thêm `scope: Set<String>?` (nil = tất cả) vào `newCardIDs`/`dueCardIDs`/`loadFullQueue` + `dueOutsideScopeCount`. `daily_new_limit` áp **TOÀN CỤC trước khi lọc** (FR-11 — `newIntroducedCount` không đổi) — test `testGlobalDailyNewLimitAppliedBeforeScope` khoá lại.
  - Nợ ngoài phạm vi = **chỉ card `review`/`relearning` due** (thẻ new là backlog FR-14 riêng) — hiện banner "Còn N thẻ đến hạn ngoài phạm vi" + empty-state J5 + CTA "Ôn tất cả".
  - UI: nút "Phạm vi" → `ScopePickerSheet` multi-select (bỏ chọn hết ≡ tất cả, không sinh `Set` rỗng). `AppModel.reviewScope` + `dueOutsideScope` + `loadReviewQueue(scope:)`.
  - 7 test mới `ScopedReviewTests` (lọc một/mix/tất cả, quota toàn cục, nợ ngoài trừ future/suspended). **Cram = R2 CHƯA làm** (cột `review_logs.mode` để sẵn; R1 vẫn ghi `srs`).
- **Phase 3 — Task 3.10 FR-20 CSV Import ✅** — 141/141 test xanh iPhone 18 Pro (2026-09-24), commit `602ded5`.
  - `CSVImport` (ReadoKit/Vocab): parse tab/comma quote-aware + delimiter-detect từ header + map cột theo tên; khớp collection **không hoa thường GIỮ dấu** qua `fold` = trim + `lowercased()` Unicode (owner chốt 24-09 — `"SÁCH"≈"sách"`, `"Đá"≠"Đã"`); collection trống→kho tạm, lạ→tạo mới; card `new`/due hôm nay mirror `saveCapture`; term trùng→cảnh báo `duplicateTerm` KHÔNG tự loại (không `unique`); atomic 1 transaction.
  - `ImportView`: fileImporter (CSV/TSV/plainText) + preview (checkbox mặc định chọn hết, sửa field, badge "trùng", bỏ dòng) + toolbar "Gộp (N)"; file hỏng→báo lỗi không hiện preview.
  - `ExportView` thêm section "Nhập" → sheet ImportView. 12 test `CSVImportTests`.
- **Phase 3 — Task 3.12 Reminder ôn tập ✅** — 148/148 test xanh iPhone 18 Pro (2026-09-24), commit `caa958f`.
  - `LearningSettings` + `reminderEnabled`/`reminderMinutes` (default tắt / 20:00) · `SettingsService` load/update 5 cột (reminder có default param → call-site FR-15 cũ vẫn compile).
  - Migration **v2**: `ALTER settings ADD reminder_enabled/reminder_minutes` (default 0/1200) + `currentVersion = 2`.
  - `ReminderService` (time/describe thuần) + `NotificationScheduler` (UNUserNotificationCenter: bật→xin quyền + UNCalendarNotificationTrigger lặp hằng ngày; tắt→dọn pending). Hook: ReadoApp `.task` khôi phục lịch lúc khởi động + `saveLearningSettings` đồng bộ sau lưu.
  - `SettingsView` section "Nhắc ôn tập" (Toggle + wheel 15'). 7 test `ReminderTests`.
- **Phase 3 — Task shortcut Home (FR-17 phần còn lại) ✅** — 158/158 test xanh iPhone 18 Pro (2026-09-24), commit `a48b1e6`.
  - `HomeShortcutService` (ReadoKit/Settings): đọc/ghi 2 slot `settings.home_shortcut_1_id/2_id` theo thứ tự slot, validate app-rule db.md A.2.2 (`tooMany`/`duplicate`/`isInbox`/`notFound`), ghi 2 cột trong MỘT transaction; xoá collection → `ON DELETE SET NULL` tự bỏ slot (shortcut lỗi không mở route chết).
  - `HomeShortcutToggle` (component dùng chung): ON khi còn slot → ghim; đã đủ 2 → chooser "Chọn shortcut để thay" (không tự thay ngầm, cancel giữ nguyên). Toggle OFF → bỏ, giữ thứ tự slot compact.
  - RootView section "Đang đọc trên Home" (pin + due badge) mở thẳng Collection Hub · SettingsView mục "Đang đọc trên Home" (J-R1-S) · kho tạm không hiện control.
  - 10 test `HomeShortcutTests` (thứ tự slot / dup / tooMany / inbox / missing / xoá clear slot / compact / lọc rỗng).
- **T0 — cửa Dữ liệu Home + "Xuất bộ này" ✅** — 158/158 test xanh iPhone 18 Pro, commit `2907666` (thuần UI). Review journeys phát hiện `ExportView` build + test từ 3.1 nhưng **đứt cửa vào** (RootView khai báo `showExport` + sheet, không nút bật). Vá: RootView nút "Dữ liệu" toolbar bottom (không cạnh bánh răng — NFR-08) · `ExportView.init(initialCollectionIDs:)` · CollectionDetailView nút "Xuất bộ này" menu `⋯` → sheet export collection đang đứng.
- **T1 — J2 hub + FR-05/06 phiên đọc song ngữ ✅** — 165/165 test xanh iPhone 18 Pro, commit `a7a2e15` (9 files, +564/−11; +7 test `ReadingSessionTests`).
  - `ReadingSession` + `ReadingSessionRepository` (ReadoKit/Session): codec `{source_en, translation_vi}` (decode lỗi→rỗng), `listSessions` mới-trước, `insertInsideTransaction` (KHÔNG mở transaction riêng — chèn trong transaction #4 của `saveCapture`).
  - `saveCapture` thêm `segments`/`summaryVI` (default rỗng): ghi phiên CÙNG transaction, chỉ collection có tên (kho tạm KHÔNG lưu phiên — Q-10/ADR-029), trim 10 mới nhất/collection.
  - UI: `AnalysisView` picker "Lưu vào" + truyền segments/summary; `CollectionDetailView` "Ôn bộ này" (FR-18 scoped) + "Chụp trang vào bộ này" (`analysisTargetCollectionID`) + "Phiên đọc (N/10)" → `ReadingSessionView` (song ngữ ADR-007 + nút ẩn/hiện dịch ADR-030 + summary thu gọn FR-06).
  - ⚠️ **Chưa làm "Từ session này collect thêm"** (J2 bước 7) — schema đã chối `session_id` trên vocab_items; ghi ROADMAP §4 chờ owner.
- **T2 — J-R1-P streak heatmap (lens FR-14) ✅** — 171/171 test xanh iPhone 18 Pro, commit `55c2685` (7 files, +656/−45; +6 test `StreakCalendarTests`).
  - `StreakCalendarService` (ReadoKit/Progress): heatmap **18 tuần 7×18** + streak hiện tại/dài nhất; số thẻ ôn đếm `review_logs` + số trang `reading_sessions`, gộp theo giờ chuyển ngày FR-11. Refactor `DailyProgressService.streak` delegate sang đây (MỘT logic streak cho Home + lịch; 7 test streak cũ guard).
  - `StreakCalendarView`: heatmap vừa khít phone (không scroll ngang, `aspectRatio 18/7`), màu = cường độ thẻ ôn; tap ô → chi tiết NGAY dưới lưới; CTA còn due→Ôn / 0 due→Chụp (không Cram, không share — NG-04). Home ô Streak bấm được.
  - Lựa chọn hiển thị: tuần bắt đầu thứ Hai · ngày chỉ-chụp = ô xám (proposal J-R1-P "streak = ngày Ôn") · "dài nhất" = toàn lịch sử.
- **Port UI lab + vá gap IA ✅** — 182/182 test xanh iPhone 18 Pro (2026-09-24). Chuỗi: `6247dfe` (visual redesign Theme tokens + `.tint`) → `bafd867` (chủ đề accent Hệ thống + 3 palette + flip 3D + `card()`) → `13888d5` (IA 3 tab + pin Home 5 + CEFR đa level + Ôn nhanh scope) → `97f6a4d` (dọn dead code + rename HomeShortcut→HomePin) → `9c1becc` (vá gap).
  - **Vá gap IA (`9c1becc`)** — 7 món theo [plan](qr/implementation/reado-ia-gaps.plan.md), không thêm suite test (chạy 182 sẵn có): (1) kho tạm luôn hiện trên Home (row inbox, không tính vào k/5, không ghim) · (2) shutter nổi chỉ còn Home root / Kho root / Hub — `ShellRoute` enum + `suppressFloatShutter` tắt khi đang đọc phiên (streak + phiên đọc mất shutter) · (3) dest ngay trên camera hệ thống (overlay chip tên bộ + nút + thư viện, `hitTest` pass-through cho nút chụp) · (4) "Chọn tất cả"/"Bỏ chọn" row đầu Section từ vựng · (5) gỡ section FSRS chỉ-đọc khỏi Settings (giữ cột DB + `request_retention`) · (6) theme mặc định Rừng + cờ `reado.appliedForestDefault` một lần (không kéo Chàm/Nâu-về) · (7) `togglePin`/`toggleReviewPriority`/`setReviewAll` throw thật + `.alert` trên Kho (hết no-op nuốt lỗi).
  - ⚠️ Món 3 (overlay camera) **cần verify on-device** — simulator không có camera, picker rơi photoLibrary.
- **Git:** HEAD `9c1becc`. ⚠️ History đã reword toàn bộ — hash cũ trong journal/session-brief từ T2 trở về (`55c2685`, `a7a2e15`, `2907666`, `602ded5`…) **không còn resolve**; hash mới tương ứng xem `git log` (vd T2 = `729e8f2`).
- **MockAnalyzer:** proxy 0.7 chưa deploy → vẫn dùng mock (owner chốt 19-09).
- **Task tiếp — port UI lab + gap IA xong (HEAD `9c1becc`).** **Q-06/Q-08/Q-09 đã chốt 2026-09-22 (ADR-032):** không lemmatize · "đã thuộc" = `stability ≥ 21` · so khớp theo collection. Còn gate: 3.8 (chỉ còn chờ dữ liệu thật để bật) · ngưỡng leech FR-19 (số lapse) · 3.11 (0.7 proxy + 1.5 adapter) · 3.13 (dữ liệu thật) · cram FR-18 (R2) · "Từ session collect thêm" (chờ chốt).

## 2. Chờ owner (không tự bắt đầu)

1. Dán prompt baseline thủ công cho A-02 (`docs/agent/agent-rulebook.md` mục 8) — vẫn trống, chặn A-02/0.8.
2. Duyệt ghi nhận ROADMAP mục 4 còn lại: query shape `ReviewQueue` (đã chốt 2.5) · **ngưỡng leech FR-19 = 6 TẠM — chốt số** (Anki mặc định 8; KHÔNG gộp với Q-08 — Q-08 "đã thuộc" = `stability ≥ 21` đã chốt 2026-09-22).
3. **Task tiếp (port UI lab + gap IA xong, commit `9c1becc`):** hết task không-gate-Q-*/proxy. **Q-06/Q-08/Q-09 đã chốt 2026-09-22 (ADR-032)** — không lemmatize · "đã thuộc" = `stability ≥ 21` · so khớp theo collection. Còn lại đều chờ mở gate — 3.8 (chỉ còn dữ liệu thật) · ngưỡng leech FR-19 (số lapse) · 3.11 (0.7 proxy + 1.5 adapter) · 3.13 (dữ liệu thật) · cram FR-18 (R2) — và chờ owner chốt hướng "Từ session này collect thêm" (J2 bước 7 — lệch schema, ROADMAP §4).

## 2.1 Đã xong — FR-01 Capture (2026-09-19, commit `8a743f8`)

- Camera/photos picker + crop xoay TOCropViewController + JPEG nén ≤1600px + SHA256 hash.
- **40/40 test xanh.**

## 2.2 Đã xong — FR-02 AI Analysis phần local, mock (2026-09-19, commit `e5fba85`)

- Prompt + PROMPT_VERSION · AnalysisResponseDecoder (schema #4) · ReadoProxyClient (multipart idempotency) · VerifyEngine fallback · AnalyzerFactory · MockAnalyzer (chờ 0.7).
- **51/51 test xanh.**

## 2.3 Đã xong — FR-03/09 Duyệt & sửa trước lưu (2026-09-19, commit `cd85123`)

- ReviewDraft + ReviewDraftBuilder (sort unverified/suspect + validate/normalize) · AppModel.saveSelection(drafts:) · AnalysisView ADR-008 (card inline, checkbox, badge, toolbar "Lưu (N)") · discardAnalysis().
- SD 10.3 chốt: sửa example không đổi nhãn verification.
- **56/56 test xanh.**

## 2.4 + 2.5 Đã xong — FR-17 `is_default` + FR-11/12 Hàng đợi & chấm (2026-09-20, commit `7ca9d2f`)

- **FR-17 `is_default` (2.4):** `saveCapture(on:collectionID:nil)` rơi vào kho tạm (is_default=1), không null. Test: `testSaveCaptureWithoutCollectionGoesToDefaultInbox`.
- **FR-11/12 Hàng đợi + chấm (2.5):**
  - `ReviewQueue.ReviewItem` + `loadFullQueue(on:dailyNewLimit:now:)` — hai nhánh: **new** bị chặn quota (đếm từ review log, FR-11) + **due/relearning** không bị giới hạn, `suspended_at IS NULL`, ORDER BY `due_at`. Snapshots TRƯỚC cho undo.
  - `ReviewQueueView`: card lật 3D · vuốt trái = Again(1) / vuốt phải = Good(3) (ADR-025) · nút Hard/Easy · undo nổi 1 bước · ProgressView / emptyView / doneView / errorView.
  - `AppModel.loadReviewQueue()` · `.grade(cardID:snapshot:rating:)` · `.undoReview(cardID:logID:snapshot:)`.
  - `RootView` Home shell: CTA "Ôn tập" toolbar + card Due tổng hợp ở đầu List.
  - **59/59 test xanh** (+3 test mới).

## 2.6 Đã xong — FR-04 Capture failure handling (2026-09-24, commit `fb7f53a` + `1364be4`)

- `AnalysisError.suggestsRecapture`: imageUnreadable/notEnglishText = true (chụp ảnh khác), lỗi tạm = false (retry cùng ảnh hợp lý). Message notEnglishText thêm "không hỗ trợ" + "không tính phí".
- `AppModel.analysisFailure: AnalysisError?` (giữ loại lỗi, thay chuỗi) + computed `analysisError` + `prepareRecapture()` (dọn state + pendingRecapture).
- `AnalysisView.failureView` (switch theo loại lỗi → CTA "Chụp lại"/"Chụp trang khác"/"Thử lại") + `recapture()`.
- `RootView` onDismiss sheet phân tích → mở lại CaptureView khi `pendingRecapture`.
- **91/91 test xanh** (+5: 3 enum-level CaptureFailureTests + 2 map error envelope AnalysisTests).
- ⚠️ **Bug tiền-ẩn đã sửa (`1364be4`):** `d23e19a` (FR-16) xoá mất dòng `PBXFileReference` của `AnalysisTests.swift` → 16 test FR-02/FR-03 không được biên dịch vào test bundle. Mốc "70/70" (3.2) không chạy chúng; con số test thật kể từ 3.1 là 55.

## 3. Bẫy máy này

- Không dùng `swift build` — luôn `xcodebuild` với 3 cờ cache vào workspace: `TMPDIR="$PWD/.tmp"` + `-derivedDataPath "$PWD/DerivedData"` + `-clonedSourcePackagesDirPath "$PWD/.xcode-packages"`; sandbox chặn `~/Library` → cần `danger-full-access` khi chạy simulator.
- `Reado.xcodeproj` viết tay objectVersion 60; local package dùng `XCSwiftPackageProductDependency`.
- `ISO8601FormatStyle()` trần không parse nổi — phải compose đủ field (xem `ISOTimestamp.swift`).
- `swift-fsrs` pin `4fbaf20`, `FSRSDefaults.defaultWv6` (21 trọng số).
- SQLite `COLLATE NOCASE` chỉ gập ASCII — gập tiếng Việt là việc tầng app.
- TOCropViewController lần build đầu cần mạng (SPM từ xa).
- iPhone simulator trên máy này là **iPhone 18 Pro** (không phải iPhone 16).
- `scripts/pbxproj_tool.py` lệnh `remove` **bị hỏng** (hàm `remove_file` high-level ở cuối file shadow bản low-level → TypeError). Thêm file: dùng `add`; cần gỡ: sửa tay 1 dòng pbxproj + grep-verify, hoặc sửa tool trước.
- File test Swift PHẢI có đủ 4 dòng trong pbxproj (PBXBuildFile + PBXFileReference + group child + sources phase). Thiếu PBXFileReference → file bị skip **ngầm** (không lỗi build), test "thừa xanh". Nghi ngờ thì kiểm `nm -gU ReadoTests.xctest`.
- `xcodebuild test` đôi khi treo **sau khi** test đã xong ("Failure collecting diagnostics from simulator: Timed out after 600s") — kết quả test đã in xong. Chạy background + Monitor `/tmp/build.log` bắt dòng `Executed N tests`/`TEST SUCCEEDED`, đừng ngồi chờ `BUILD SUCCEEDED` tới cùng.

## 4. Nhật ký

→ `docs/journal/` — đọc 2–3 entry gần nhất khi cần biết việc vừa xong và vì sao.
→ Journal v2: `docs/journal/2026-09-19.md` (tái cấu trúc + FR-01/02/03).
