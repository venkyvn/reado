# scripts/verify — kiểm chứng A-01/A-02 (Phase 0)

Đọc trước khi chạy. Chi tiết nền tảng: `docs/agent/prompt-spec.md` mục 8.

## Cách chạy

```bash
cp .env.example .env    # điền MODEL, API_KEY (CHỈ trong .env — không commit)
node --env-file=.env scripts/verify/verify.mjs
```

Kết quả in ra console + lưu `scripts/verify/output/last-run.json` và raw output từng
ảnh trong `scripts/verify/output/raw/` (cả hai đã gitignore).

## Owner cần bỏ gì vào đây (task 0.3)

- **5–10 ảnh trang thật**: sách giấy / bài báo mạng / tài liệu kỹ thuật. Cố ý vài
  ảnh chụp xấu (A-03). Định dạng: `.jpg` `.jpeg` `.png` `.webp`.
- **Tuỳ chọn, khuyến khích 3–5 bản**: file cùng tên đuôi `.manual.txt` — nội dung là
  output prompt thủ công của owner cho đúng trang đó. Script chỉ đếm dòng và nhắc
  bạn so bằng mắt; A-02 là phán đoán định tính của owner (prompt-spec mục 8).

Ví dụ:

```
samples/
  page-01.jpg            ← ảnh trang thật
  page-01.manual.txt     ← output Gemini thủ công của owner cho trang đó
  page-02.png
  article-03.webp
  ...
```

## Lưu ý bản quyền

Ảnh là trang sách/báo có bản quyền → thư mục `samples/*` bị gitignore. Đây là dữ
liệu test tạm, cùng tinh thần NFR-04 (không lưu toàn văn trang). Xoá sau khi Phase 0
đóng nếu muốn.

## Đọc kết quả

| Cột | Nghĩa |
|---|---|
| `status OK/FAIL/ERR` | OK = một lần gọi ra JSON đúng schema mục 4 (A-01); FAIL = sai schema; ERR = lỗi API |
| `verified/suspect/unverified` | Ba nhánh xác minh `example` — thuật toán prompt-spec mục 6 |
| `lat` | Độ trễ một lần gọi (ms) → tổng hợp p50/p95 so với NFR-01 |
| `tok` / `cost` | Token theo `usageMetadata`; cost chỉ tính khi `.env` có `PRICE_*_PER_1M` |
| `note: N term không xuất hiện trên page_text` | Chẩn đoán OCR/cắt câu — không phải nhánh verdict |

**Cảnh báo (mục 8):** prompt script dùng là **bản dựng lại** (prompt-spec mục 3).
Kết quả chứng minh được A-01, nhưng A-02 phải so với prompt baseline nguyên văn
(mục 2) + output thủ công của owner — không được lấy bảng script làm bằng chứng A-02.

## Kiểm tra link docs (`check-doc-links.mjs`)

```bash
node scripts/verify/check-doc-links.mjs    # exit 1 nếu có link nội bộ/anchor hỏng
```

Quét **file sống** (root `*.md` + `docs/` trừ `journal/`, `archive/`): link nội bộ
theo quy ước gốc-repo `docs/...` (resolve gốc-repo trước, fallback file-relative),
anchor theo slug GitHub (giữ `_`, mỗi space → `-`, heading trùng lặp tự `-1`),
tệp mồ côi, và liệt kê link ngoài (không verify mạng). Reference-style link chỉ
cảnh báo, không làm exit 1. Chạy sau mỗi đợt sửa docs để chặn link chết.

---

## A/B nén ảnh trước khi gửi (`ab-compress.mjs`)

Câu hỏi: **có nên resize + JPEG-hoá ảnh trước khi gửi Gemini** (thay vì gửi nguyên
bytes gốc như `app/src/ui/imageToolkit.ts` đang làm), và nếu có thì chốt thông số nào?
Gemini tính token ảnh theo **pixel** (≈ W×H/258), nên ảnh photo 3024×4032 ăn hàng
chục nghìn token mỗi lần Analyze — đây là đòn tiết kiệm chính, không phải dung lượng
upload.

```bash
node scripts/verify/ab-compress.mjs ref/sample --dry   # chỉ tạo biến thể + đo size, KHÔNG gọi API
node --env-file=.env scripts/verify/ab-compress.mjs ref/sample
```

Bốn biến thể cho mỗi ảnh (reference = `goc`):

| id | là gì |
|---|---|
| `goc` | bytes gốc, mime theo đuôi file — **đường sản xuất hiện tại**, dùng làm reference |
| `jpg95-full` | JPEG q0.95 giữ nguyên size — đường "có crop" hiện tại |
| `jpg80-1400` | resize cạnh dài ≤ 1400px + JPEG q0.80 — sweet spot đang đề xuất |
| `jpg85-1600` | resize cạnh dài ≤ 1600px + JPEG q0.85 — biên trên an toàn |

Không bao giờ **upscale** (`sips -Z` tự upscale ảnh nhỏ — script đã chặn). Nén bằng
`sips` (chỉ macOS) — Lanczos, tốt hơn `drawImage` của app, nên kết quả là **giới hạn
lạc quan** cho app thật.

Đo gì: bytes/pixel/token ước lượng + token thật (`usageMetadata`), latency, schema,
và so với reference trên cùng ảnh — **CER%** toàn văn trang, từ mất/thêm, term mất/thêm,
số term chung bị đổi nghĩa. Kết quả: bảng console + `output/ab-last-run.json` + ảnh
biến thể ở `output/ab-variants/` (mở bằng mắt được).

**Đọc kết quả cho đúng:** `temperature=0` (lệch app có chủ ý) để tách biến "ảnh" khỏi
nhiễu lấy mẫu; CER nhỏ vẫn có thể là nhiễu — tín hiệu thật là khi chất lượng **xấu đi
theo độ nén** (1400 tệ hơn 1600 rõ rệt). Ảnh mẫu nhỏ hơn ngưỡng thì cột resize vô
nghĩa, cần **ảnh photo full-res thật** mới đo được phần tiết kiệm token.
