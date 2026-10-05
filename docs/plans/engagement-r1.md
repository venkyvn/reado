# Plan: engagement-r1 — tăng gắn bó (idea/tang_gang_bo.md) + dọn từ trùng cũ

> **Trạng thái:** open (2026-10-05) - T0 docs xong; T1-T8 chưa làm. T1/T2 chi tiết tới chữ ký + test; T3-T8 chi tiết hoá đầu mỗi session.

## Context

Fen muốn làm các ý tăng gắn bó trong `idea/tang_gang_bo.md`, kèm thêm một việc mới nhớ ra:
**dọn từ trùng đã có trong kho**. Lọc trùng toàn app khi duyệt (FR-10) đã xong ở
vocab-identity-r1 (ADR-066, `ecdca9b`), nhưng các dòng lưu **trước** ADR-066 vẫn trùng
(cùng `term_normalized+pos` ở nhiều bộ, mỗi bộ một thẻ ôn riêng). Hệ quả: một từ bị ôn hai
lần, và các con số "Gặp lại", "Đã nhớ" bị lệch.

Fen đã chốt (2026-10-05, trong session này):
- Làm ý **1, 2, 3, 4, 5, 6**. Ý 7 (chia sẻ) để sau.
- Streak: **giữ pill** trên toolbar, **đổi dòng nhắc** trong hero thành "N/7 ngày" (M-02).
- Gộp trùng: **fen duyệt từng nhóm** (mặc định chọn gộp, bỏ chọn dòng nghĩa khác).
- Thẻ được giữ: **thẻ tiến bộ nhất**; review_logs và encounters của dòng bị gộp chuyển
  sang dòng giữ lại; câu gốc + bộ của dòng bị gộp thành một lần `seen` có câu.

## Vấn đề & bằng chứng

- Trùng cũ: chưa có code gộp nào. Chỉ `cards` và `encounters` trỏ tới `vocab_items`, chỉ
  `review_logs` trỏ tới `cards`, tất cả đều `ON DELETE CASCADE`
  (`Database/Migration.swift:143-181`). Schema v7. `VocabRepository.knownSenses`
  (`Vocab/VocabRepository.swift:194`) đã nhóm sẵn theo `matureKey`: khoá nào có ≥ 2 dòng
  là một nhóm trùng.
- Engagement, hiện trạng (agent dò 2026-10-05):
  - Sheet gặp lại (`Reado/Shared/EncounterText.swift:88-197`) đã có "Gặp lại N lần" và
    haptic khi bấm Nhận ra. **Còn thiếu:** câu gốc lần đầu, "N ngày trước", mức thuộc.
  - `Mastery.level` (`ReadoKit/Review/Mastery.swift:25`) có sẵn nhưng chưa UI nào gọi.
  - Màn phân tích chưa có dòng "Trang này có N từ đã gặp".
  - Mặt sau thẻ (`Reado/Review/ReviewQueueView+Card.swift:~289`) chưa có "Gặp lần đầu".
    `ReviewItem` thiếu `createdAt`.
  - Phiên ôn chưa có điểm dừng giữa chừng: `ReviewQueue.loadFullQueue` không giới hạn số thẻ.
  - Dòng nhắc streak ở `HomeTabView.swift:182,186`.
  - Thanh 4 màu của Hub ở `Reado/Library/CollectionStatsHeader.swift:35-56`.
  - `segments[].phrases` đã lưu trong JSON của `reading_sessions` nhưng chưa được chọn ra
    để hiện.
  - Không có nguồn bền cho "số trang đã phân tích": `pagesAnalyzed` = `COUNT(*) FROM
    reading_sessions` (`Progress/DailyProgress.swift:71`), mà bảng này chỉ giữ 10 phiên
    mỗi bộ.
- **Tiêu chí dừng cho gộp trùng (đặt trước T1):** fen chạy query đếm khoá trùng
  (brief §2.13, hoặc xuất JSON FR-16 rồi đưa file).
  - **0 nhóm** → bỏ T1 và T2, ghi lý do vào ADR-067.
  - **Dưới ~5 nhóm** → hỏi fen có muốn xoá tay thay vì làm cả màn gộp không.

## Spec

- **Nguyên lý:**
  - #6: tiến bộ thật, không ảo. Mọi con số đều đếm từ `encounters`, `review_logs`,
    `vocab_items`.
  - #4: ngữ cảnh là mỏ neo. Câu gốc lần đầu; gộp trùng không làm mất câu.
  - Retention: "không đòi học hết" (ý 2).
  - #2: bản dịch là thứ để học (ý 4).
  - #5: dữ liệu bền (gộp trùng).
  - Không phạm NG nào. Không XP, không bảng xếp hạng (NG-04), không streak freeze.
- **FR / ADR đụng tới (T0 ghi):**
  - **FR-24 mới** — Gộp từ trùng (Epic E5, cạnh FR-16/FR-20). **ADR-067**.
  - **FR-22 sửa** — sheet hiện câu gốc lần đầu + "N ngày trước" + mức thuộc; haptic +
    animation khi Nhận ra đưa từ lên Đã thấm; dòng "Trang này có N từ bạn đã gặp".
  - **FR-14 sửa** — dòng nhắc trong hero là "Tuần này ôn N/7 ngày"; pill streak giữ nguyên.
    Thêm thẻ "Tuần qua" (ý 5).
  - **FR ôn tập + mặt thẻ** (grep `mặt sau` / FR-11 trong prd) — phiên ngắn 3 thẻ (ý 2);
    "Gặp lần đầu N ngày trước" (ý 6).
  - **Journey Hub** (grep `journeys.md`) — bản đồ chấm thay thanh 4 màu (ý 3).
  - **FR-02 phrases** (prompt-v6) — cụm đáng nhớ sau khi lưu (ý 4). **Không đổi prompt.**
  - **ADR-068** — gom quyết định engagement: streak đổi dòng nhắc (bổ sung ADR-038), phiên
    ngắn, tuần chuyện không đếm trang, tiêu chí chọn cụm.
- **In-scope:** ý 1–6, đổi dòng nhắc streak, màn gộp trùng.
- **Out-of-scope:**
  - Ý 7 (chia sẻ).
  - Notification tuần: thẻ tuần hiện trên Home, không gửi notification.
  - Đổi prompt (ý 4 dùng heuristic).
  - Ghi nhớ nhóm trùng đã bỏ qua: không thêm schema, nhóm đã bỏ qua hiện lại ở lần mở sau.
  - D4 (gạch chân từ cũ trong màn đọc PDF).
- **Lựa chọn chi tiết hiển thị (CLAUDE.md §6.4, ghi lại để fen bác nếu cần):**
  - Ý 4: chọn cụm có EN chứa một từ vừa lưu ở trang; không có thì lấy cụm dài nhất. Hiện ở
    dòng thứ hai của banner "Đã lưu".
  - Ý 5: không đếm trang (không có nguồn bền). Thẻ hiện trên Home từ lần mở đầu tiên của
    tuần mới; đóng thì lưu `UserDefaults` theo ngày đầu tuần; mọi số = 0 thì ẩn.
  - Ý 6: chỉ hiện khi từ đã lưu ≥ 7 ngày.
  - Ý 2: nút phụ "Ôn nhanh 3 thẻ · ~2 phút" dưới "Ôn ngay". Số đến hạn của hero giữ nguyên
    nên FR-14 không đổi.
- **Q mở:** không còn, các chỗ thiếu hợp đồng fen đã chốt ở trên. Q-11 không liên quan.

## Tầng 1 — HLD

- **ReadoKit (logic thuần, có test):**
  - `Vocab/DuplicateMerge.swift` (mới):
    - `groups(on:)` — tái dùng pattern SQL `term_normalized = ? AND lower(trim(pos)) = ?`
      (`VocabRepository.swift:290-299`).
    - `merge(on:keep:merge:now:)` — **một** `db.inTransaction`.
  - `Encounter/EncounterMatcher.swift` + `EncounterRepository.loadLexicon` — thêm
    `example`, `createdAt` vào `EncounterLexiconEntry`.
  - `Review/Mastery.swift` — helper `promotedToAbsorbed(before:after:)`.
  - `Review/ReviewQueue.swift` — `ReviewItem.createdAt`; giới hạn hàng đợi cho phiên ngắn.
  - `Progress/WeekSummary.swift` (mới) — 7 ngày học: từ đã lưu, từ gặp lại, lần nhận ra,
    số ngày ôn N/7, từ gặp nhiều nhất. Dùng lại `StreakCalendarService.reviewedDayStarts`.
  - `Analysis/MemorablePhrase.swift` (mới) — `pick(phrases:savedTerms:)`.
  - `Vocab/VocabRepository+Overview.swift` — `masteryDots(collectionID:)`.
- **Reado (UI, dùng skill `reado-ui`, verify bằng ảnh simulator):**
  - `ExportView` — section "Gộp từ trùng (N nhóm)" → màn mới `Library/DuplicateMergeView.swift`.
  - `EncounterSheet`, `AnalysisView`, `ReviewQueueView+Card`, `HomeTabView`/`HeroCard`,
    `SessionDoneView`, `CollectionStatsHeader`, banner ở `RootView.swift:172`.
- **Transaction (gộp trùng):** mỗi dòng bị gộp, trong **cùng một** transaction:
  1. `UPDATE review_logs SET card_id = <thẻ giữ> WHERE card_id = <thẻ gộp>`.
  2. `UPDATE encounters SET vocab_item_id = <dòng giữ>`, rồi xoá `recognized` thừa nếu cùng
     ngày học (giữ luật FR-22: tối đa một lần mỗi ngày).
  3. `INSERT encounters` loại `seen`: `sentence` = `example` của dòng gộp, `collection_id` =
     bộ của dòng gộp, `created_at` = `created_at` của dòng gộp.
  4. `DELETE vocab_items` của dòng gộp; thẻ đi theo cascade.

  **Luật chọn thẻ giữ:** thẻ không bị leech trước → `stability` cao nhất →
  `last_review_at` mới nhất → `created_at` cũ nhất. Trạng thái FSRS của thẻ giữ **không
  đổi** (không tự viết FSRS).
- **Rủi ro đã xét:** undo trong phiên ôn (`ReviewService.swift:123`) đọc log cuối theo
  `card_id`. Gộp chỉ mở được từ màn Dữ liệu, không mở được khi đang trong phiên ôn, nên
  undo không gặp log đã chuyển thẻ.
- **File cấm:** `project.pbxproj` (file mới chỉ cần tạo trong `app/Reado/**`), không thêm
  dependency, không đổi schema (vẫn v7), không đổi `Prompt.version`.
- **Ghi nhận, không sửa trong plan này:**
  - Bộ đếm overview dùng `Mastery.stabilityThreshold` cứng, bỏ qua setting `known_stability`
    (`VocabRepository+Overview.swift:85`).
  - `reviewedToday` chỉ đếm `mode='srs'`, còn streak đếm mọi mode
    (`DailyProgress.swift:80`). T4 thống nhất một luật cho N/7 + dòng nhắc (đếm mọi mode,
    giống streak).

## Tầng 2 — Tasks (1 task = 1 session)

**Thứ tự đề xuất:** T0 → (baseline trùng) → T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8.
Dọn trùng làm trước để các con số engagement (gặp lại, đã nhớ, bản đồ chấm) không bị
dòng trùng làm lệch.

### T0 — docs ✅ 2026-10-05 (docs-only, không chạy `scripts/test.sh`)

Văn bản GWT dưới đây là bản nháp đã chốt nội dung. Chép vào đúng chỗ, chỉ chỉnh câu chữ
cho khớp giọng file.

1. **`docs/specs/prd.md`** (file lớn: Grep rồi Read có offset).
   - **Ghi chú phiên bản:** thêm khối `> **v0.17 — engagement-r1: gộp từ trùng (FR-24) +
     tăng gắn bó.**` ngay sau khối v0.16 (L334). 3–5 câu: vì sao (dòng trùng trước ADR-066,
     ý tăng gắn bó), trỏ ADR-067/068.
   - **Bảng thay đổi** (cạnh các dòng L287–331), thêm:
     - `| FR-24 | **Mới** — gộp từ trùng trong kho (fen duyệt từng nhóm), Epic E5 |`
     - `| FR-22 | Sửa — sheet hiện câu gốc lần đầu + "N ngày trước" + mức; haptic khi lên Đã
       thấm; "Trang này có N từ bạn đã gặp" (ADR-068) |`
     - `| FR-14 | Sửa — dòng nhắc trong hero đổi thành "N/7 ngày"; thẻ "Tuần qua" (ADR-068) |`
     - `| FR-11 | Sửa — phiên ôn nhanh 3 thẻ (ADR-068) |`
     - `| FR-02 | Sửa — cụm đáng nhớ sau khi lưu trang, chọn từ `segments[].phrases` (ADR-068) |`
   - **FR-24 mới**, đặt ngay sau khối FR-20 (kết thúc ~L980), tiêu đề
     `#### FR-24 — Gộp từ trùng trong kho`:
     - **Given** kho có ≥ 2 dòng `vocab_items` cùng khoá `term_normalized + pos` (pos so
       không phân biệt hoa thường, đã trim — cùng khoá FR-10), **when** mở Dữ liệu → "Gộp
       từ trùng", **then** mỗi khoá là một nhóm. Mỗi dòng hiện nghĩa, collection, mức (4 mức
       vision #6). Mặc định chọn hết; dòng hệ thống sẽ giữ có nhãn "Giữ thẻ này".
     - **Given** một nhóm còn ≥ 2 dòng được chọn, **when** gộp, **then** giữ **một** dòng
       theo luật: thẻ không leech trước → `stability` cao nhất → `last_review_at` mới nhất →
       `created_at` cũ nhất. Các dòng được chọn còn lại gộp vào dòng đó. Dòng bỏ chọn
       không đổi gì.
     - **Given** gộp, **then** trong **một** transaction cho mọi nhóm đã chọn:
       - `review_logs` của thẻ gộp chuyển sang thẻ giữ.
       - `encounters` chuyển sang dòng giữ; `recognized` trùng ngày học (FR-11) với một
         `recognized` có sẵn thì bỏ bớt (giữ luật một lần/ngày của FR-22).
       - Mỗi dòng gộp thành một `encounters.seen` mang `example`, `collection_id`,
         `created_at` của chính nó, nên câu gốc không mất (vision #4).
       - Dòng gộp bị xoá (thẻ đi theo cascade).
       - Trạng thái FSRS của thẻ giữ **không đổi**. Dòng giữ ở nguyên collection của nó.
       - Lỗi bất kỳ → rollback, không đổi gì.
     - **Given** fen bỏ chọn tới mức nhóm còn < 2 dòng, **then** nhóm đó không gộp và không
       lưu lại quyết định. Lần mở sau nhóm vẫn hiện (không thêm schema).
     - **Given** 0 nhóm, **then** cửa "Gộp từ trùng" bị tắt, kèm chú thích "Không có từ trùng".
     - Đoạn văn cuối: FR-10 (ADR-066) chặn trùng mới, FR-24 dọn trùng cũ. Không có
       `unique` trên `vocab_items` (luật cứng giữ nguyên).
   - **FR-22, FR-14, FR-11, FR-02:** thêm GWT theo bảng "Spec" ở trên (ý 1, nhắc N/7 + thẻ
     tuần, phiên 3 thẻ, cụm đáng nhớ). Mỗi ý một bullet Given/When/Then. Câu chữ UI ghi
     đúng như bảng "Lựa chọn chi tiết hiển thị".
2. **`docs/decisions-log.md`** — thêm sau ADR-066, theo format Ngày / Bối cảnh / Quyết
   định / Lý do / Hệ quả:
   - **ADR-067 — Gộp từ trùng cũ (FR-24)**:
     - Bối cảnh: dòng trùng trước ADR-066.
     - Quyết định: fen duyệt từng nhóm, luật giữ thẻ, dòng gộp thành `seen`.
     - Lý do: không tự viết FSRS, không mất ngữ cảnh.
     - Hệ quả: "Gặp lại N lần" tăng 1 cho mỗi dòng gộp; tổng `review_logs` không đổi;
       không lưu nhóm đã bỏ qua; JSON xuất ra không nhập lại được nên phải nhắc backup.
   - **ADR-068 — Tăng gắn bó (engagement-r1)**: gom các quyết định ý 1–6 và dòng nhắc
     N/7 (bổ sung ADR-038, pill streak giữ nguyên). Ý 5 không đếm trang vì
     `reading_sessions` chỉ giữ 10 phiên/bộ. Ý 4 không đổi prompt. Ý 7 để sau.
3. **`docs/specs/solution-design.md` §6** (L177): thêm dòng
   `| 10 | Gộp từ trùng (FR-24) | Mọi nhóm đã chọn trong MỘT transaction — `DuplicateMerge.merge`; chuyển `review_logs`/`encounters`, thêm `seen`, xoá dòng gộp; không đụng FSRS thẻ giữ | ◻ |`.
4. **`docs/specs/journeys.md`**:
   - J-R1-D (L487): câu "Cửa vào" thêm "Gộp từ trùng"; thêm `### Happy path — gộp trùng`
     gồm 4 bước: mở → duyệt nhóm/bỏ chọn → xác nhận (nhắc xuất JSON) → về màn Dữ liệu,
     số nhóm cập nhật.
   - J2 header Hub (L214): ghi "thanh 4 màu → bản đồ chấm (engagement-r1 T6)".
5. **`CLAUDE.md` §5**: thêm một dòng `- **Chốt thêm 2026-10-05 (engagement-r1, ADR-067/068):**
   gộp trùng cũ do fen duyệt từng nhóm, giữ thẻ tiến bộ nhất; dòng nhắc streak đổi
   sang N/7 (pill giữ); làm ý 1–6 của tang_gang_bo, ý 7 để sau.`
6. **`ROADMAP.md`**: thêm dòng `3.21` sau `3.20` (L168), cùng format: engagement-r1, các
   task T0–T8, trạng thái T0 ✅.
7. **`idea/tang_gang_bo.md`**: frontmatter `status: planned`, `modified: 2026-10-05`, thêm
   `docs/plans/engagement-r1.md` vào `related`.

- **DoD:** chạy `/raudit` không báo link/anchor hỏng; dòng bia mộ FR-07/FR-13 còn nguyên;
  `grep -n 'FR-24' docs/specs/prd.md` có ≥ 3 chỗ (ghi chú, bảng, section).

### T1 — gộp trùng, ReadoKit

**File mới** `app/ReadoKit/Sources/ReadoKit/Vocab/DuplicateMerge.swift`:

```swift
/// FR-24 / ADR-067 — gộp dòng trùng khoá `matureKey` (term_normalized + pos) có từ trước ADR-066.
public enum DuplicateMerge {
    public struct Member: Equatable, Identifiable, Sendable {
        public var id: String { vocabItemID }
        public let vocabItemID: String
        public let term: String
        public let pos: String
        public let meaningVI: String
        public let example: String
        public let collectionID: String
        public let collectionName: String
        public let createdAt: String          // ISO Z
        public let cardID: String?            // thẻ receptive; nil nếu dòng không có thẻ
        public let state: String              // "new" khi không có thẻ
        public let stability: Double          // 0 khi không có thẻ
        public let lastReviewAt: String?
        public let isSuspended: Bool
        public let recognizedCount: Int
        public var level: Mastery.Level {
            Mastery.level(state: state, stability: stability, recognizedCount: recognizedCount)
        }
    }
    public struct Group: Equatable, Identifiable, Sendable {
        public var id: String { key }
        public let key: String                // VocabRepository.matureKey
        public let members: [Member]          // keeper(of: members) đứng đầu, còn lại theo created_at, id
    }
    public struct Selection: Equatable, Sendable {
        public let keeperID: String
        public let mergedIDs: [String]
    }
    public struct Summary: Equatable, Sendable {
        public let groupsMerged: Int
        public let rowsMerged: Int
    }
    public enum MergeError: Error, Equatable {
        case keyMismatch(keeperID: String, mergedID: String)
        case missingRow(String)
    }

    public static func groups(on db: SQLiteDatabase) throws -> [Group]
    public static func keeper(of members: [Member]) -> Member?   // hàm THUẦN
    public static func merge(on db: SQLiteDatabase, selections: [Selection]) throws -> Summary
}
```

- **`groups`:** một SELECT, gom nhóm trong Swift bằng
  `VocabRepository.matureKey(term: term_normalized, pos: pos)`. Chỉ giữ khoá có ≥ 2 dòng,
  sắp nhóm theo `key`.
  ```sql
  SELECT v.id AS id, v.term AS term, v.term_normalized AS term_normalized, v.pos AS pos,
         v.meaning_vi AS meaning_vi, v.example AS example, v.collection_id AS collection_id,
         col.name AS collection_name, v.created_at AS created_at,
         c.id AS card_id, c.state AS state, c.stability AS stability,
         c.last_review_at AS last_review_at, c.suspended_at AS suspended_at,
         (SELECT COUNT(*) FROM encounters e
           WHERE e.vocab_item_id = v.id AND e.kind = 'recognized') AS recognized_count
  FROM vocab_items v
  JOIN collections col ON col.id = v.collection_id
  LEFT JOIN cards c ON c.vocab_item_id = v.id AND c.direction = 'receptive'
  ORDER BY v.created_at, v.id;
  ```
- **`keeper`:** sắp theo thứ tự ưu tiên:
  1. `!isSuspended` trước;
  2. `stability` giảm dần;
  3. `lastReviewAt` giảm dần (nil xếp cuối, so chuỗi ISO cùng độ dài);
  4. `createdAt` tăng dần;
  5. `vocabItemID` tăng dần.

  Rỗng → nil. UI gọi lại hàm này trên các dòng **đang chọn** để nhãn "Giữ thẻ này" luôn
  đúng khi fen bỏ chọn dòng giữ.
- **`merge`:** **một** `db.inTransaction` bọc mọi selection; selection có `mergedIDs` rỗng
  thì bỏ qua. Đọc `DayContext.read(on: db)` một lần **trước** transaction. Với mỗi
  selection, nạp dòng giữ K (id, term_normalized, pos, card receptive) và tập "ngày có
  recognized" của K: mỗi `created_at` → `DayBoundary.window(now:timezone:dayCutoffHour:).start`
  (cùng cách với `StreakCalendarService.reviewedDayStarts`). Rồi với mỗi `mergedID` L:
  1. Nạp L; không có → `MergeError.missingRow`. So `term_normalized` +
     `lower(trim(pos))` với K; lệch → `MergeError.keyMismatch` (UI cũ/stale).
  2. Có cả thẻ của L và thẻ của K → `UPDATE review_logs SET card_id = ? WHERE card_id = ?`.
  3. Mỗi `recognized` của L: ngày của nó đã có trong tập → `DELETE FROM encounters WHERE
     id = ?`; chưa có → thêm ngày vào tập. Sau đó
     `UPDATE encounters SET vocab_item_id = K WHERE vocab_item_id = L`.
  4. Thêm `seen`: dùng lại `EncounterRepository.insert` (đổi `private static func insert`
     → `static func insert`, internal, không đổi chữ ký). Tham số: `kind: .seen`,
     `createdAt: L.created_at`, `sentence:` = `L.example` đã trim (rỗng → nil),
     `collectionID: L.collection_id`.
  5. `DELETE FROM vocab_items WHERE id = L` (cascade xoá thẻ L; log đã chuyển đi ở bước 2).

  Không gọi `ReviewService`, không ghi gì vào `cards` của K.

**File test mới** `app/ReadoKit/Tests/ReadoKitTests/DuplicateMergeTests.swift`:
- Dùng `Fixtures.seededDB()`, `insertCollection`, `insertVocab`, `insertCard`, `insertLog`
  (`TestSupport.swift`).
- `insertVocab` không nhận `example`. Cần câu gốc thì
  `db.run("UPDATE vocab_items SET example = ? WHERE id = ?")`.
- Chưa có fixture encounter thì INSERT thẳng.
- DB test dùng timezone `Asia/Ho_Chi_Minh`, cutoff mặc định 4h, nên ranh ngày học là 21:00Z.

| Test | Kiểm |
|---|---|
| `testGroupsOnlyKeysWithTwoOrMoreRows` | bank/noun ở bộ A+B, bank/verb, river → đúng 1 nhóm `bank|noun` |
| `testGroupKeyIgnoresPosCaseAndSpaces` | pos `"Noun"` và `"noun "` cùng nhóm |
| `testKeeperOrder` | bảng nhiều ca: leech thua dù stability cao; hoà stability → last_review mới hơn; hoà tiếp → created_at cũ hơn; nil last_review xếp cuối |
| `testMergeMovesReviewLogsToKeeperCard` | tổng `review_logs` trước = sau; mọi log về thẻ K |
| `testMergeKeepsKeeperFSRSUnchanged` | mọi cột FSRS của thẻ K (state, stability, difficulty, reps, lapses, due_at, last_review_at, suspended_at) y nguyên |
| `testMergeAddsSeenFromMergedRow` | có `seen` mới: sentence = example của L, collection_id = bộ của L, created_at = created_at của L |
| `testMergeMovesEncounters` | `seen`/`recognized` cũ của L giờ trỏ K |
| `testMergeDropsRecognizedOnSameLearningDay` | K recognized `2026-09-10T00:00:00Z`; L recognized `2026-09-10T10:00:00Z` (cùng ngày) → bị xoá; L recognized `2026-09-10T22:00:00Z` (ngày học sau) → giữ |
| `testUnselectedRowsUntouched` | nhóm 3 dòng, chỉ gộp 1 → dòng thứ 3 + thẻ + log nguyên vẹn |
| `testKeeperStaysInItsCollection` | K ở bộ B, L ở bộ A → sau gộp K vẫn ở B, A không còn từ đó |
| `testMergeRollsBackWhenAnySelectionInvalid` | selection 1 hợp lệ, selection 2 lệch khoá → ném `keyMismatch`, DB y như trước (đếm vocab/cards/logs/encounters) |
| `testMergeWithEmptySelectionsIsNoop` | `[]` và `mergedIDs: []` → Summary(0, 0) |

- **Chạy:** `scripts/test.sh test -only-testing:ReadoKitTests/DuplicateMergeTests` khi sửa;
  `scripts/test.sh kit` trước handoff.
- **DoD:** lane `kit` xanh; không đổi `Migration.currentVersion` (vẫn 7); không file nào
  trong `app/Reado` đổi; `EncounterRepositoryTests` vẫn xanh.

### T2 — màn "Gộp từ trùng", UI (dùng skill `reado-ui`)

1. **`app/Reado/App/AppModel+Collections.swift`**: thêm vào cuối, cạnh MARK Export,
   theo mẫu `AppModel+Leech.swift`:
   ```swift
   // MARK: — Gộp từ trùng (FR-24, ADR-067)
   func duplicateGroups() -> [DuplicateMerge.Group] {
       guard let database else { return [] }
       return read("nhóm từ trùng", fallback: []) { try DuplicateMerge.groups(on: database) }
   }
   /// Một transaction cho mọi nhóm; xong thì nạp lại Home/Hub.
   func mergeDuplicates(_ selections: [DuplicateMerge.Selection]) throws -> DuplicateMerge.Summary {
       guard let database else { throw ReviewError.modelUnavailable }
       let summary = try DuplicateMerge.merge(on: database, selections: selections)
       reloadOverview()
       return summary
   }
   ```
   `mergeDuplicates` ném lỗi để view tự hiện lỗi inline, giống `importRows`.
2. **`app/Reado/Shared/MasteryLevel+UI.swift`** (mới; T3/T6 sẽ dùng lại):
   `extension Mastery.Level { var title: String; var color: Color }`.
   - Tên: Mới / Đang học / Đã nhớ / Đã thấm.
   - Màu giống `CollectionStatsHeader.swift:35-56`: absorbed `Theme.ok`, remembered
     `Color.accentColor.opacity(0.6)`, learning `Theme.due`, new `Theme.surfaceStrong`
     (đọc file đó để lấy đúng tên token).
   - Đổi `CollectionStatsHeader` sang dùng extension này **chỉ khi** không đổi hiển thị; không
     chắc thì để nguyên.
3. **`app/Reado/Library/ExportView.swift`**:
   - Thêm `@State private var duplicateCount = 0`, `@State private var showMerge = false`.
   - Thêm `dedupeSection` vào `List` sau `importSection`: `Section("Dọn kho")` chứa nút
     `Label("Gộp từ trùng", systemImage: "arrow.triangle.merge")`, cuối dòng là số nhóm
     (`Typo.meta`, `.secondary`).
     - `.disabled(duplicateCount == 0)`.
     - Footer: count == 0 → "Không có từ trùng."; ngược lại → "Cùng chữ và loại từ ở nhiều
       bộ, lưu trước khi Reado tự gộp."
   - Đếm `duplicateCount = model.duplicateGroups().count` trong `.onAppear` hiện có và
     trong `onDismiss` của sheet.
   - `.sheet(isPresented: $showMerge, onDismiss: …) { DuplicateMergeView() }`, cùng kiểu
     `ImportView`.
4. **`app/Reado/Library/DuplicateMergeView.swift`** (mới), khung giống `ImportView`:
   `NavigationStack`, title "Gộp từ trùng", inline.
   - **State:** `groups: [DuplicateMerge.Group]` (nạp `.task { groups = model.duplicateGroups() }`),
     `excluded: Set<String>` (vocab id bị bỏ chọn), `errorMessage: String?`,
     `confirming = false`, `isMerging = false`.
   - **Tính toán:**
     - `selected(in:)` = members không nằm trong `excluded`.
     - `selections` = nhóm có ≥ 2 dòng chọn → `Selection(keeperID: keeper(of: sel)!.id,
       mergedIDs: sel bỏ keeper)`.
     - `groupCount = selections.count`; `rowCount` = tổng `mergedIDs`.
   - **Toolbar:** `.cancellationAction` "Huỷ" → dismiss; `.confirmationAction`
     "Gộp (\(groupCount))" → `confirming = true`, disabled khi `groupCount == 0 || isMerging`.
   - **Nội dung `List`:**
     - Section đầu (chỉ chữ, `.footnote`): "Mỗi nhóm giữ một thẻ ôn — thẻ nhớ tốt nhất. Câu
       gốc của dòng gộp vào vẫn còn ở mục "Gặp lại". Bỏ chọn dòng nào mang nghĩa khác."
     - Mỗi nhóm một `Section`, header `"\(members[0].term) · \(members[0].pos)"`.
     - Mỗi dòng: nút toggle (`checkmark.circle.fill` / `circle`, `Haptics.selection()`),
       `meaningVI` (body), dòng meta `"\(collectionName) · \(level.title)"` (`Typo.meta`).
       Dòng là keeper hiện tại có nhãn capsule "Giữ thẻ này".
     - Footer của nhóm khi còn < 2 dòng chọn: "Không gộp nhóm này."
     - `groups.isEmpty` → `ContentUnavailableView("Không có từ trùng", systemImage:
       "checkmark.seal", description: Text("Mỗi từ chỉ có một thẻ ôn."))`.
     - `errorMessage` → section lỗi giống `ExportView.errorSection`.
   - **`.confirmationDialog`:**
     - Title: "Gộp \(groupCount) nhóm (\(rowCount) dòng)?"
     - Message: "Không hoàn tác được. Nên Xuất JSON backup ở màn Dữ liệu trước."
     - Nút "Gộp" (`role: .destructive`) và "Huỷ".
     - Gộp thành công → `Haptics.success()` rồi dismiss. Lỗi → `errorMessage = "Lỗi gộp:
       …"` + `Haptics.error()`, rồi nạp lại `groups`.
   - Animation bọc `reduceMotion ? nil : Motion.reveal`, giống `ImportView`.
   - Thêm `#Preview` với `Group` giả (đọc các preview có sẵn trong `Reado/Library/` để
     theo cách dựng `AppModel` preview).
5. **Verify bằng ảnh** (skill `reado-ui`):
   - Grep `DebugLaunch` để xem cách seed dữ liệu và mở thẳng một màn.
   - Chụp màn có 2 nhóm (một nhóm 3 dòng, có một dòng bị bỏ chọn) và màn trống, iPhone Air,
     light + dark, thêm Dynamic Type lớn.
   - DebugLaunch không seed được dòng trùng thì ghi nợ "xem tay" vào brief §2, không bịa ảnh.
- **Chạy:** `scripts/test.sh build` khi đang sửa; `scripts/test.sh` full trước `/rhandoff`.
- **DoD:**
  - Test xanh.
  - Ảnh màn có nhóm + màn trống đã kiểm.
  - Nợ xem tay trên dữ liệu thật (gộp xong, mở thẻ giữ thấy "Gặp lại" có câu của dòng gộp;
    3 query baseline) ghi vào brief §2.

> **T3–T8 mới ở mức HLD.** Đầu mỗi session, bước đầu tiên là "chi tiết hoá T<n>" trên
> code mới nhất (chữ ký, SQL, số dòng, câu chữ UI, bảng test), như T1/T2 ở trên. Fen OK
> rồi mới code. Chỗ còn phải chốt khi chi tiết hoá:
> - T3: câu đang đọc lấy từ đâu (`EncounterSelection` có sẵn câu không); animation gì.
> - T5: cách truyền chế độ "nhanh" qua `ReviewQueueView`.
> - T6: kích thước chấm, cách xử lý bộ lớn, dùng popover hay sheet.
> - T8: khoá `UserDefaults` để nhớ đã đóng thẻ.

### T3 — Ý 1: khoảnh khắc nhận ra
- **Files:** `EncounterMatcher.swift`, `EncounterRepository.swift`, `Mastery.swift`,
  `EncounterText.swift` (sheet), `AnalysisView.swift`, `AppModel+Encounter.swift`.
- **Nội dung:**
  - Sheet: khối "Lần đầu · N ngày trước · ‹bộ›" chứa câu gốc, đặt cạnh câu đang đọc.
  - Chip mức thuộc.
  - Nhận ra đưa từ lên Đã thấm → `Haptics.success` + animation chuyển mức; tôn trọng
    `accessibilityReduceMotion`.
  - Màn phân tích: "Trang này có N từ bạn đã gặp" (N = số từ khác nhau được gạch chân).
- **Test:** ReadoKit: lexicon có `example`/`createdAt`, `promotedToAbsorbed`, đếm từ khác
  nhau trên trang. Ảnh sheet.
- **DoD:** `scripts/test.sh` xanh.

### T4 — Ý 6 + dòng nhắc N/7
- **Files:** `ReviewQueue.swift` (`createdAt`), `ReviewQueueView+Card.swift`,
  `DailyProgress.swift` (đếm `weekReviewDays`), `HomeTabView.swift`/`HeroCard.swift`.
- **Nội dung:**
  - Mặt sau thẻ: "Gặp lần đầu N ngày trước" khi từ đã lưu ≥ 7 ngày.
  - Hero: "Tuần này ôn N/7 ngày" thay cho dòng nhắc streak.
- **Test:** N/7 qua giờ chuyển ngày (FR-11); ngưỡng 7 ngày của ý 6.
- **DoD:** xanh, kèm ảnh mặt sau thẻ và ảnh hero.

### T5 — Ý 2: phiên ôn ngắn
- **Files:** `ReviewQueue.swift` (lấy N thẻ đầu, giữ thứ tự ưu tiên), `ReviewQueueView.swift`,
  `SessionDoneView.swift`, `HeroCard.swift`.
- **Nội dung:** xong 3 thẻ → màn xong có "Ôn tiếp (còn N)" và "Xong".
- **Test:** cắt hàng đợi; streak vẫn tính; lịch FSRS không đổi so với phiên thường.
- **DoD:** xanh.

### T6 — Ý 3: bản đồ trí nhớ theo bộ
- **Files:** `VocabRepository+Overview.swift` (`masteryDots`), `CollectionStatsHeader.swift`
  (thay thanh màu).
- **Nội dung:** chạm chấm → popover với từ, nghĩa, câu gốc. Màu dùng token sẵn có của
  thanh cũ.
- **Test:** số chấm mỗi mức khớp bộ đếm overview cũ. Ảnh Hub ở bộ nhỏ và bộ ~300 từ.
- **DoD:** xanh.

### T7 — Ý 4: cụm đáng nhớ
- **Files:** `Analysis/MemorablePhrase.swift` + test, `AppModel+Capture.swift`
  (`SaveConfirmation`), `RootView.swift` (banner).
- **Test:** chọn cụm chứa từ vừa lưu; không có thì lấy cụm dài nhất; không có cụm → không
  hiện dòng.
- **DoD:** xanh.

### T8 — Ý 5: câu chuyện tuần
- **Files:** `Progress/WeekSummary.swift` + test, `HomeTabView.swift` (thẻ "Tuần qua",
  đóng được).
- **Test:** biên tuần theo giờ chuyển ngày; mọi số = 0 → ẩn; từ gặp nhiều nhất (hoà → từ
  lưu trước).
- **DoD:** xanh. Xem tay vào thứ Hai trên máy thật → ghi vào brief §2.

## Verification (chung)

- Mỗi task: `scripts/test.sh test -only-testing:ReadoKitTests/<Class>` khi đang sửa, chạy
  full `scripts/test.sh` trước `/rhandoff`. UI chụp ảnh simulator iPhone Air theo skill
  `reado-ui`.
- Gộp trùng (sau T2): chạy lại 3 query baseline T0 của vocab-identity-r1 trên dữ liệu thật.
  Số khoá trùng phải về 0 (trừ nhóm fen chủ động giữ), tổng số review_logs không đổi.
- Plan chỉ được lưu `docs/plans/engagement-r1.md` khi fen OK. Sau OK chỉ làm **một** task.
