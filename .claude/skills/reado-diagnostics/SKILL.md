---
name: reado-diagnostics
description: Đọc log chẩn đoán DebugTrace (ADR-037) khi kết quả OCR hoặc phân tích trên máy thật/simulator bị sai — ngắt đoạn lạ, mất dòng, model trả rác, lỗi phân tích — hoặc khi cần so prompt mới với prompt đang chạy. Dùng khi fen nói đã cắm máy / mở simulator, gửi ảnh kết quả sai, hoặc hỏi vì sao một trang ra như vậy.
---

# Reado diagnostics

Log chỉ có khi app build DEBUG (fen bấm Run trong Xcode là Debug). Ngoại lệ NFR-04 chỉ áp cho log này.

## Kéo về và đọc
1. Simulator đang boot: `scripts/pull_diagnostics.sh sim`.
   Máy thật: `scripts/pull_diagnostics.sh device` lần đầu chỉ in danh sách máy rồi thoát — chạy lại với `scripts/pull_diagnostics.sh device <udid>`.
2. Script in ra thư mục `.tmp/diagnostics/<ts>/`. Đọc tóm tắt trước: `python3 scripts/diag_summary.py <thư mục>` (thêm `--full` khi cần segment/vocab; mặc định chỉ in 5 lần mới nhất, `--last N`/`--last 0` đổi số lần).
3. Không mở thẳng `events.jsonl` / `analysis.json`; cần chi tiết thì grep đúng analysis id.

Mỗi lần phân tích là một thư mục `analyses/<id>/` (ảnh, OCR, từng hàng kèm lý do ngắt đoạn, response, lỗi). App giữ 30 lần gần nhất.

## So prompt
`python3 scripts/prompt_eval.py --diagnostics .tmp/diagnostics/<ts> --prompt scripts/prompts/v5.txt --prompt app/ReadoKit/Sources/ReadoKit/Analysis/Prompt.swift`
- Output Markdown ở `.tmp/prompt-eval/` để fen chấm cạnh nhau. Không commit (bản quyền sách).
- Script tự đọc key trong `.env`; agent không tự mở `.env`.
- `--swift-func text|pdfText` chọn hàm trong `Prompt.swift` (mặc định `text`); với trang PDF dùng `--swift-func pdfText`, thư mục diagnostics phải là lần phân tích PDF. `--prompt git:<rev>` lấy `Prompt.swift` ở commit cũ, khỏi giữ snapshot `.txt`.

## Báo lại
Nêu analysis id + bằng chứng (dòng nào, lý do ngắt). Ngưỡng ngắt đoạn: ADR-037; engine OCR: ADR-064. Đổi prompt là đụng hợp đồng → `/rplan` (`docs/agent/prompt-spec.md`).
