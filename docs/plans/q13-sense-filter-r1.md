# Plan: q13-sense-filter-r1

> **Trạng thái:** open (2026-10-02) - Q-13: bộ lọc FR-10 ẩn nghĩa mới cùng `pos` mà không ai biết; 5 phương án, khuyến nghị B (gập thay vì xoá); chờ fen chốt 2 câu cuối file, chưa code

## Context
Q-13 (`CLAUDE.md` §5): khoá so khớp FR-10 là `term_normalized|pos` trong một collection
(`VocabRepository.matureKey`, `app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift:123`).
`ReviewDraftBuilder.drafts(excludingMature:)` (`app/ReadoKit/Sources/ReadoKit/Analysis/ReviewDraft.swift:101`)
**xoá hẳn** item khớp khỏi màn duyệt. Hệ quả: `bank` (n.) đã thuộc nghĩa "ngân hàng", trang mới dùng
"bờ sông" (cũng n.) → bị ẩn. Cặp tương tự: `charge` (phí / cáo buộc), `spring` (mùa xuân / lò xo).
Người dùng không có cách biết — màn rỗng (`AnalysisView.swift` `emptyVocabView`) chỉ ghi "Các từ trên
trang đã thuộc rồi, hoặc không có từ nào cần thêm".

Phạm vi thực tế hẹp hơn tên gọi: Q-09 so khớp **theo collection**, nên chỉ xảy ra khi nghĩa mới gặp
trong **cùng bộ** (cùng cuốn sách) — đúng ca đa nghĩa trong một cuốn.

**Lệch spec phát hiện kèm (code ≠ GWT):** `matureKeys` trả khoá nếu **bất kỳ** dòng nào cùng khoá đã
thuộc. Term+pos có hai dòng — "ngân hàng" (đã thuộc) + "bờ sông" (vừa lưu, `new`) — vẫn bị ẩn, trong khi
FR-10 GWT 3 nói từ **chưa** thuộc gặp lại thì vẫn đề xuất. Tức là lưu được nghĩa mới rồi cũng không gặp
lại nó ở màn duyệt.

**Kênh lộ duy nhất hiện có:** FR-22 — popover gạch chân ở `ReadingSessionView` liệt kê mọi dòng của
term (kèm nghĩa trong kho). Nhưng chỉ sau khi lưu, chỉ collection có tên, và trang mà mọi từ đều bị
lọc thì `saveCapture` không chạy (`guard !items.isEmpty`) → không có phiên đọc lẫn encounter "thấy".

## Spec
- FR / journey: FR-10 (`prd.md` §FR-10, GWT 1–4) · J1 bước 4 + bảng "Vocab rỗng sau FR-10" (`journeys.md`) ·
  J2 bước 4 (cùng rule J1). Đã chốt liên quan: Q-06 không lemmatize · Q-07 mỗi nghĩa một dòng, không tầng
  `senses` · Q-08 `stability >= 21` · Q-09 theo collection. prompt-spec §5: bộ lọc chạy phía client, không
  đưa từ đã biết vào prompt.
- Nguyên lý: #3 Capture At The Point Of Friction — "AI chỉ đề xuất; người dùng là người duyệt cuối" (bộ lọc
  hiện quyết thay người dùng mà không báo) đối với "Chống lại: bộ ôn chứa thứ người dùng đã biết" (lý do bộ
  lọc tồn tại). #5 Durable Data — nghĩa mới bị nuốt là dữ liệu học mất. #4 Context — nghĩa mới + câu mới là
  một thẻ khác. NG: không đụng.
- In-scope: cách màn duyệt xử lý item khớp khoá "đã thuộc"; ca term+pos có cả dòng thuộc lẫn chưa thuộc.
- Out-of-scope / không đụng: schema (không cột/bảng mới), transaction #4 (`saveCapture` vốn cho lưu dòng
  trùng khoá — không `unique`), prompt v6, ngưỡng Q-08, phạm vi Q-09, FR-22.

## Phương án

| | Phương án | Công | Rủi ro / đụng luật |
|---|---|---|---|
| **A** | Giữ nguyên, ghi giới hạn vào FR-10 | docs | Nghĩa mới vẫn mất im lặng |
| **B** | **Gập thay vì xoá:** item đã thuộc xuống nhóm "Đã thuộc · N" cuối tab Từ vựng, gập sẵn, không chọn sẵn, không chiếm suất preselect 5. Mỗi dòng: *Trang này: ‹meaning_vi AI›* · *Trong kho: ‹meaning_vi các dòng cùng khoá›*. Chọn → lưu thành dòng mới như mọi item | ReadoKit (truy vấn trả nghĩa + builder tách 2 nhóm) + 1 section UI | Sửa câu chữ FR-10 GWT 1 ("loại khỏi danh sách" → "khỏi danh sách chính") |
| **C** | So nghĩa phía client: `meaning_vi` của AI không chồng âm tiết nào với nghĩa trong kho → badge "Nghĩa mới?", đưa lên danh sách chính, không chọn sẵn | vừa | Paraphrase tiếng Việt ("kiên cường"/"bền bỉ") → báo nhầm → từ đã thuộc quay lại làm phiền (trái "Chống lại" #3); ngưỡng chồng là số tự đặt |
| **D** | AI lượt 2 chỉ cho item trùng: gửi term + câu trang + nghĩa trong kho → "cùng nghĩa?" | lớn (prompt-spec, decoder, nhánh lỗi) | Phá "đúng một lần gọi" + "không đưa từ đã biết vào prompt" (prompt-spec §5); thêm latency + tiền BYOK |
| **E** | Khoá theo nghĩa trong schema (sense id/gloss AI gán) | lớn + migration | **Loại** — dựng lại tầng `senses` Q-07 đã bỏ; AI gán nhãn nghĩa không ổn định giữa các lần gọi |

**Khuyến nghị: B.** Giải đúng chỗ Q-13 nêu ("không có cách biết") mà vẫn giữ mục đích bộ lọc (không làm
phiền: gập, không chọn sẵn). Không chặn C sau này — nếu dùng thật thấy cần, badge "Nghĩa mới?" đặt
**trong** nhóm gập (không lên danh sách chính) giảm hẳn giá của báo nhầm.

## Tầng 1 — HLD (nếu chọn B)
- **ReadoKit** (logic thuần, lane `kit`):
  - `VocabRepository.matureSenses(on:collectionID:) -> [String: [String]]` — khoá `term|pos` → `meaning_vi`
    của các dòng đã thuộc (cùng điều kiện `matureKeys`: đúng collection, `state = 'review'`,
    `stability >= known_stability ?? 21`, `suspended_at IS NULL`). `matureKeys` thay bằng `Set(keys)` hoặc
    giữ làm wrapper — chọn khi code.
  - `ReviewDraftBuilder`: trả thêm nhóm `matureHidden` (draft + nghĩa trong kho); không preselect, không tính
    vào `preselectLimit`. Chọn một item trong nhóm → đi qua `selected(_:)` như mọi draft.
  - Câu hỏi 2 bên dưới quyết định thêm cột mức thuộc của **từng** dòng cùng khoá hay không.
- **Reado**: `AnalysisView` tab Từ vựng thêm section gập; "Lưu (N)" đếm cả item chọn từ nhóm gập. Chỉ còn
  nhóm gập → màn rỗng ghi kèm "N từ đã thuộc được ẩn" + nhóm bên dưới (chi tiết hiển thị — CLAUDE.md §6.4).
- **Protocol / transaction**: không đổi. `saveCapture` (transaction #4) giữ nguyên.
- **File cấm**: `project.pbxproj`; schema/migration; `Prompt*.swift`.

## Tầng 2 — Tasks (nếu chọn B)
1 task = 1 session. Cả hai cần Mac (cloud không build/test iOS). Làm T1 trước.

### T1 — kit: nghĩa trong kho + builder tách nhóm gập
- Files: `app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift`,
  `app/ReadoKit/Sources/ReadoKit/Analysis/ReviewDraft.swift`, `app/Reado/App/AppModel+Settings.swift`
  (`matureKeysForCapture` → trả nghĩa), test `ReadoKitTests` (ReviewDraft + VocabRepository).
  Docs: `prd.md` FR-10 GWT 1 (+ GWT 3 theo câu 2), ADR-056, `CLAUDE.md` §5 chuyển Q-13 sang "Chốt".
- Test: item khớp khoá → nằm `matureHidden` kèm đủ nghĩa trong kho; không preselect; không chiếm suất 5
  (trang 6 verified + 1 đã thuộc → vẫn chọn sẵn 5 verified kia); khác collection không khớp (Q-09); thẻ leech
  `suspended_at` không tính; `known_stability` NULL → 21; ca câu 2.
- DoD: `scripts/test.sh kit` xanh; call-site cũ biên dịch (`scripts/test.sh build`).

### T2 — UI: section "Đã thuộc · N" + fixture chụp
- Files: `app/Reado/Analysis/AnalysisView.swift` (+ component row nếu tách), fixture `analysis-fixture`
  (`scripts/sim_screens.sh --fixture` / seed) thêm một từ đã thuộc cùng khoá. Docs: `journeys.md` J1 bước 4
  + bảng "Vocab rỗng sau FR-10".
- Test: full `scripts/test.sh`; ảnh `sim_screens.sh open analysis-fixture` light/dark — nhóm gập đóng sẵn,
  mở ra thấy hai nghĩa, chọn → "Lưu (N)" tăng.
- DoD: full xanh + ảnh; journal + brief.

## Câu hỏi cho fen (Q-13 — chưa chốt, không tự chọn)
1. **Hướng:** A · **B** (khuyến nghị) · C · D?
2. **Term+pos có cả dòng đã thuộc lẫn chưa thuộc** (lệch spec ở Context) xử lý sao?
   - (i) Vào nhóm gập, liệt kê mọi nghĩa kèm mức thuộc — nghiêng về đây vì máy không biết trang đang dùng
     nghĩa nào; phải sửa câu chữ FR-10 GWT 3.
   - (ii) Sửa code theo GWT 3 — chỉ ẩn khi **mọi** dòng cùng khoá đã thuộc, còn lại lên danh sách chính
     (trang dùng nghĩa đã thuộc thì từ đó cũng lên lại).
