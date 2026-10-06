# QA chờ xem tay (fen)

> Mỗi mục là một việc fen cần chạm/xem trên máy; xong thì đánh `[x]`. Mục mới do `/rhandoff` thêm.
> Dạng: `- [ ] QA-NN — <việc> · máy: sim/thật · plan: <đường dẫn>`.

## Từ visual-polish-r1 (đóng 2026-10-06, workflow-docs-r1 D2)
- [ ] QA-V1 — xem Ôn (2 mặt thẻ), SessionDone, Kho, CollectionDetail, Streak (light + dark) · máy: sim · plan: docs/plans/done/visual-polish-r1.md
- [ ] QA-V2 — Analysis (cần AI thật) · máy: thật · plan: docs/plans/done/visual-polish-r1.md
- [ ] QA-V3 — fen xem tay 4 màn trên máy thật theo DoD (touch ≥ 44pt, contrast, Dynamic Type, Reduce Motion) · máy: thật · plan: docs/plans/done/visual-polish-r1.md

## Từ workflow-docs-r1 (đóng 2026-10-06)
- [ ] QA-W1 — đo tiêu chí thành công sau 30 commit `feat`/`fix`: brief bị sửa ≤ 15% commit, ≤ 2 file md mỗi commit `feat`, `CLAUDE.md` ≤ ~7,5KB; tiêu chí không đạt thì mở plan sửa riêng · máy: sim · plan: docs/plans/done/workflow-docs-r1.md
- [ ] QA-W2 — session mới sau `/clear`: hỏi 5 câu (thêm file Swift, Q-09, test 1 lớp ReadoKit, ngưỡng leech, debug OCR) — câu cuối phải kích hoạt skill `reado-diagnostics`; đọc file trong `app/ReadoKit/` rồi hỏi luật migration · máy: sim · plan: docs/plans/done/workflow-docs-r1.md
- [ ] QA-W3 — `prompt_eval.py --swift-func pdfText --limit 1` trên thư mục diagnostics PDF (chờ OW-10) · máy: thật · plan: docs/plans/done/workflow-docs-r1.md
- [ ] QA-W4 — xoá 3 nhánh remote đã lỗi thời: `git push origin --delete claude/eager-ptolemy-trkabr claude/magical-dijkstra-6axsi4 claude/wizardly-newton-dk2pgu` (giữ `upbeat-tesla-nc1rx2` tới khi mở plan CI) · máy: sim · plan: docs/plans/done/workflow-docs-r1.md

## Từ structure-review-r1
(không có nợ xem tay — plan là review tĩnh, T1 chưa từng code)

## Chuyển từ brief §2 cũ (2026-10-06, workflow-docs-r1 T9)

Ánh xạ số cũ → ID mới: §2.1→OW-01 · §2.3→OW-03 · §2.6→OW-06 · §2.9→QA-09 · §2.10→QA-10 + OW-10 · §2.11→QA-11 · §2.12→OW-12 · §2.13→OW-13 · §2.14→QA-14 · §2.15→QA-15 · §2.16→QA-16 · §2.2/2.4/2.5/2.7/2.8 đã xong (bỏ).
Journal và plan đã đóng giữ nguyên số cũ.

- [ ] QA-09 — home-eevas-r1: T3 màn "Từ hay quên" (vuốt trái "Đưa lại hàng đợi", vuốt phải "Xoá" + `confirmationDialog`, `contextMenu`); T4 gõ tìm kiếm thật (debounce, kết quả/thứ tự trên simulator hoặc máy thật) · máy: sim/thật · plan: docs/plans/done/home-eevas-r1.md
- [ ] QA-10a — pdf-reader-r1 T3: lật trang bằng tay, "Đổi PDF…", "Gỡ PDF", xoá file ngoài Files → "Chọn lại file" · máy: sim/thật · plan: docs/plans/pdf-reader-r1.md
- [ ] QA-10b — pdf-reader-r1 T4: chạm CTA → phân tích thật → lưu → quay lại trang đọc (cần agent thật) · máy: thật · plan: docs/plans/pdf-reader-r1.md
- [ ] QA-11 — pdf-nav-r1: (a) chạm trang ẩn/hiện chrome (ADR-060); (b) vuốt ngang lật trang có bị cử chỉ "vuốt mép trái để back" giành không; (c) Cài đặt → "Đọc PDF": tông giấy + Slider độ đậm (ADR-061/062) · máy: thật · plan: docs/plans/done/pdf-nav-r1.md
- [ ] QA-14a — vocab-identity-r1: "Từ mới mỗi ngày" = 1 → phân tích 2 trang, trang 2 báo đủ hạn mức · máy: sim/thật · plan: docs/plans/done/vocab-identity-r1.md
- [ ] QA-14b — vocab-identity-r1: bỏ chọn hết từ mới → nút "Ghi gặp lại N từ" + banner · máy: sim/thật · plan: như trên
- [ ] QA-14c — vocab-identity-r1: lưu trang PDF có từ cũ ở bộ khác rồi chạy 3 query T0 (khoá trùng không tăng) · máy: thật · plan: như trên
- [ ] QA-14d — vocab-identity-r1: lật thẻ ≥ 2 ngữ cảnh ở Dynamic Type lớn — mặt sau trắng ở `accessibility-extra-large` kể cả khi bỏ khối ngữ cảnh (có thể lỗi có sẵn: ScrollView trong `.drawingGroup()`; thật thì mở bug riêng) · máy: sim · plan: như trên
- [ ] QA-15 — engagement-r1 T2 màn "Gộp từ trùng" (FR-24): bấm chọn/bỏ chọn dòng (nhãn "Giữ thẻ này" đổi theo), hộp thoại xác nhận, **gộp thật trên dữ liệu thật** (xuất JSON backup trước; xong mở thẻ giữ xem mục "Gặp lại" có câu; chạy lại 3 query T0), mục "Dọn kho" cuối màn Dữ liệu khi cuộn xuống (không bị ShellTabBar che) · máy: thật · plan: docs/plans/done/engagement-r1.md
- [ ] QA-16a — engagement-r1 T3: bấm "Nhận ra ✓" thật (chip → "Đã thấm" + "Lên mức Đã thấm" + haptic) · máy: thật · plan: docs/plans/done/engagement-r1.md
- [ ] QA-16b — engagement-r1 T5: chấm 3 thẻ thật → "Xong phiên nhanh" + "Ôn tiếp" · máy: thật · plan: như trên
- [ ] QA-16c — engagement-r1 T6: chạm/kéo chọn chấm ở Hub + bộ ~300 từ · máy: thật · plan: như trên
- [ ] QA-16d — engagement-r1 T7: lưu trang thật → cụm thật trong banner · máy: thật · plan: như trên
- [ ] QA-16e — engagement-r1 T8: đóng thẻ "Tuần qua" rồi mở lại sang tuần mới; thẻ khi cuộn xuống ở cỡ chữ lớn · máy: thật · plan: như trên
