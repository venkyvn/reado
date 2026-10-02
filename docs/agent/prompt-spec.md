# Prompt Spec — hợp đồng giữa AI và data model

| Field | Value |
|---|---|
| Status | **Draft — baseline đã có ở mục 2** (owner cung cấp 2026-09-08; bản tạm, mở cho tinh chỉnh theo M-03) |
| Created | 2026-09-07 |
| Last updated | 2026-09-08 |
| Revision | v1.1 — điền prompt baseline ở mục 2 |
| Related | [prd.md](docs/specs/prd.md) FR-02, [vision.md](docs/specs/vision.md), [research/vocabulary.md](docs/research/vocabulary.md), [research/vocabulary.md](docs/research/vocabulary.md) |
| Phạm vi | Trả lời câu hỏi: gửi gì cho AI, nhận về đúng structure nào, và làm sao biết cái nhận về là thật |

**Tài liệu này tự chứa.** Nó được viết để một session mới, không có bối cảnh gì về
cuộc thảo luận sinh ra nó, vẫn đọc và tiếp tục được.

> **Đọc cảnh báo ở mục 2 trước khi dùng doc này để implement.** Prompt baseline —
> artefact mà A-02 lấy làm chuẩn chất lượng — **đã được owner cung cấp và dán nguyên
> văn ở mục 2** (2026-09-08; bản tạm thời, tinh chỉnh theo M-03). Phần prompt ở mục 3
> vẫn là bản **dựng lại** từ [docs/idea.md](docs/idea.md) và FR-02, không phải bản gốc.

## Điều hướng

- [1. Vì sao doc này tồn tại](#1-vì-sao-doc-này-tồn-tại)
- [2. Chỗ trống chặn đường — prompt baseline](#2-chỗ-trống-chặn-đường--prompt-baseline)
- [3. Prompt dựng lại](#3-prompt-dựng-lại)
- [4. Output schema](#4-output-schema)
- [5. Mapping sang data model và sang FR-02](#5-mapping-sang-data-model-và-sang-fr-02)
- [6. Xác minh `example`](#6-xác-minh-example)
- [7. Những gì KHÔNG hỏi AI](#7-những-gì-không-hỏi-ai)
- [8. Cách kiểm chứng A-01 và A-02](#8-cách-kiểm-chứng-a-01-và-a-02)
- [9. Đã chốt và chưa chốt](#9-đã-chốt-và-chưa-chốt)

---

## 1. Vì sao doc này tồn tại

[PRD mục 13](docs/specs/prd.md#13-out-of-scope) xếp nội dung prompt vào *"chi tiết triển khai của
FR-02"*. Chỗ xếp đó đánh giá thấp mức độ quan trọng của nó, vì ba mệnh đề nặng nhất
trong PRD đều đứng trên chính artefact này:

| ID | Nội dung | Rủi ro nếu sai |
|---|---|---|
| **A-01** | *Một* lần gọi multimodal làm được OCR + dịch + trích vocab, trả structured output | **Kiến trúc pipeline phải viết lại** |
| **A-02** | Chất lượng output tự động ngang prompt thủ công hiện tại của owner | **M-07 không đạt và sản phẩm mất lý do tồn tại** |
| **M-07** | Owner bỏ hẳn quy trình Gemini thủ công | PRD gọi đây là *acceptance test thật của cả sản phẩm* |

Ba dòng đó nói cùng một điều: **prompt không phải chi tiết triển khai, nó là sản phẩm.**
Phần app còn lại — capture, lưu, lên lịch, ôn — đều là hạ tầng phục vụ output của một
lần gọi này.

Doc này cũng là chỗ duy nhất định nghĩa **hợp đồng** giữa AI và data model. Không có nó,
mỗi người implement lại tự nghĩ ra một JSON schema, và không ai có chuẩn để so.

---

## 2. Chỗ trống chặn đường — prompt baseline

> **Đã có — owner cung cấp ngày 2026-09-08, dán nguyên văn bên dưới.** Owner gọi đây
> là bản *tạm thời* để tham chiếu: prompt đích của Reado (structured output) sẽ được
> tinh chỉnh tiếp theo M-03, và nếu đổi AI provider thì đổi prompt ở tầng đó — baseline
> ở đây là thước đo chất lượng, không phụ thuộc provider.
>
> Vì sao giữ bản gốc **nguyên văn, không chỉnh sửa**:
>
> 1. **A-02 lấy chính nó làm chuẩn.** Không có bản gốc thì mệnh đề *"chất lượng ngang
>    prompt thủ công"* không kiểm được — không có gì để so.
> 2. **Nó đã qua kiểm nghiệm thật.** Owner đã dùng nó nhiều tháng trên sách thật. Đó là
>    dữ liệu về cái gì hoạt động, và không tái tạo được bằng suy luận.
> 3. **Nó là baseline để đo hồi quy.** Khi prompt được sửa để ra structured output, cần
>    biết bản sửa tốt hơn hay tệ hơn bản gốc.

**Phạm vi buộc phải đọc đúng:** prompt này có hai nửa, và chỉ nửa đầu là baseline cho
A-02:

- Nửa đầu — *"Khi tôi gửi ảnh chụp trang sách…"* — tương ứng với quy trình FR-02 đang
  tự động hoá: song ngữ theo đoạn, trích từ vựng kèm phiên âm, tóm tắt. Đây là chuẩn
  để so chất lượng.
- Nửa sau — *"Khi tôi nhắn một câu/đoạn tiếng Anh trực tiếp…"* (dịch chi tiết, phân
  tích ngữ pháp) — là thao tác thủ công khác của owner. Phần giải thích ngữ pháp nằm
  **ngoài phạm vi Reado** theo **NG-08**. Giữ nguyên ở đây để không thất lạc, nhưng nó
  không phải chuẩn cho FR-02.

```
Khi tôi gửi ảnh chụp trang sách hoặc một đoạn văn bản tiếng Anh:
1. Trình bày dạng Song ngữ Anh - Việt theo từng đoạn nhỏ (Paragraph-by-Paragraph):
   - [Gốc]: Đoạn tiếng Anh nguyên bản.
   - [Dịch]: Bản dịch tiếng Việt sát nghĩa, mượt mà.
2. Trích xuất "Từ vựng & Cụm từ hay (Vocabulary & Phrases)": Bao gồm từ/cụm từ, phiên âm, nghĩa và ngữ cảnh.
3. Tóm tắt "Ý chính (Key Takeaways)": Ý cốt lõi của trang sách/văn bản.

Khi tôi nhắn một câu/đoạn tiếng Anh trực tiếp:
- Dịch chi tiết, phân tích cấu trúc ngữ pháp và làm rõ ngữ cảnh sử dụng.
```

Mục 3 dùng được để chạy thử A-01, nhưng **đừng coi kết quả của nó là bằng chứng cho
A-02** — bằng chứng phải đến từ việc so với output của chính baseline trên.

### Cái đã giữ được

[docs/idea.md](docs/idea.md) có ghi lại *yêu cầu* của prompt, dù không phải prompt text. Năm
điểm, và mục 3 dựng lại từ đây:

- Đóng vai **một dịch giả chuyên nghiệp có kiến thức sư phạm**
- Trình bày **song ngữ Anh–Việt theo từng đoạn nhỏ**
- `gốc`: Anh nguyên bản — `dịch`: bản dịch tiếng Việt **mượt mà, sát nghĩa**
- Trích xuất **từ vựng và cụm từ hay**, kèm phiên âm, **theo trình độ người đọc** (B1, B2)
- **Tóm tắt ý chính**

---

## 3. Prompt dựng lại

> **Đây là bản dựng lại, không phải bản gốc.** Nguồn: năm yêu cầu ở mục 2 cộng
> acceptance criteria của [FR-02](docs/specs/prd.md). Dùng được để chạy thử A-01; **không** dùng
> làm chuẩn cho A-02.
>
> **Đã lệch code:** bản dưới đây là prompt multimodal gốc, trước ADR-034 (OCR
> trên máy + text-mode). Prompt THẬT đang chạy nằm ở
> `app/ReadoKit/Sources/ReadoKit/Analysis/Prompt.swift` (`Prompt.version`,
> hiện tại **5** — ADR-037: OCR tự dò ranh giới đoạn bằng hình học trước khi
> đưa vào prompt). Đổi luật `\n\n`/paragraph thì sửa `Prompt.swift`, không sửa
> khối code dưới đây.

```
Bạn là một dịch giả chuyên nghiệp có kiến thức sư phạm về giảng dạy tiếng Anh.

Đầu vào là ảnh một trang văn bản tiếng Anh nguyên bản — có thể là trang sách giấy,
bài báo mạng, hoặc tài liệu chuyên ngành. Trình độ người đọc: {CEFR_LEVEL}.

Đọc toàn bộ văn bản trên trang và trả về JSON đúng schema được cung cấp, gồm ba phần:

1. segments — chia văn bản thành các đoạn nhỏ theo đúng thứ tự xuất hiện trên trang.
   Mỗi đoạn gồm:
   - source_en: nguyên văn tiếng Anh, GIỮ ĐÚNG TỪNG CHỮ như trên trang. Không sửa
     lỗi, không chuẩn hoá, không lược bỏ. Đây là bản ghi của trang.
   - translation_vi: bản dịch tiếng Việt mượt mà và sát nghĩa. Ưu tiên cách diễn đạt
     tự nhiên của người Việt hơn là dịch từng chữ.

2. vocabulary — từ vựng và cụm từ đáng học đối với người ở trình độ {CEFR_LEVEL}.
   Bỏ qua những từ quá cơ bản so với trình độ đó. Mỗi phần tử gồm:
   - term: từ hoặc cụm từ, GIỮ ĐÚNG DẠNG XUẤT HIỆN trên trang. Gặp
     "weathered the storm" thì trả về đúng vậy, không đưa về nguyên thể.
   - pos: một trong noun | verb | adj | adv | phrase | other. Không bao giờ để trống;
     không xác định được thì dùng "other".
   - ipa: phiên âm IPA của term.
   - meaning_vi: nghĩa tiếng Việt trong ĐÚNG NGỮ CẢNH của trang này. Nếu từ có nhiều
     nghĩa, chỉ trả nghĩa đang được dùng ở đây.
   - cefr: một trong A2 | B1 | B2 | C1.
   - example: câu chứa term, TRÍCH NGUYÊN VĂN từ trang. Đây là ràng buộc bắt buộc:
     không được tự đặt câu, không được sửa câu, không được ghép câu. Câu này phải
     xuất hiện y nguyên trong một phần tử source_en ở trên.

3. summary_vi — tóm tắt ý chính của trang bằng tiếng Việt.

Nếu một từ trên trang có hai nghĩa khác nhau ở hai chỗ khác nhau, trả về nó thành
HAI phần tử riêng trong vocabulary, mỗi phần tử một nghĩa và một example.

Nếu ảnh không đọc được hoặc không chứa văn bản tiếng Anh, trả về vocabulary và
segments rỗng thay vì đoán.
```

Bốn chỗ trong prompt trên là quyết định đã chốt ở doc khác, không phải lựa chọn ngẫu hứng:

| Chỗ | Vì sao | Nguồn |
|---|---|---|
| `source_en` giữ đúng từng chữ | Nó là **nguyên liệu xác minh** `example` ở mục 6. Cho AI "sửa lỗi" là mất cơ chế xác minh | FR-02 |
| `term` giữ đúng dạng xuất hiện | Dạng thật sự đọc mới là dạng gắn với ký ức. Q-06 đã chốt: không lemmatize. Chuẩn hoá chữ thường làm phía client | structure mục 6.4 |
| `meaning_vi` chỉ một nghĩa | Không có ràng buộc `unique`, nên "một dòng một nghĩa" là lời khai trung thực | structure mục 6.3 |
| Từ đa nghĩa tách thành hai phần tử | Cùng lý do trên. Đây là Q-07 **đã được giải** | PRD mục 12 |

---

## 4. Output schema

Structured output, không phải prose — đó là toàn bộ điểm khác biệt giữa Reado và quy
trình thủ công hiện tại (PRD mục 1, điểm rò rỉ thứ nhất).

```json
{
  "type": "object",
  "required": ["segments", "vocabulary", "summary_vi"],
  "additionalProperties": false,
  "properties": {
    "segments": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["source_en", "translation_vi"],
        "additionalProperties": false,
        "properties": {
          "source_en":      { "type": "string", "minLength": 1 },
          "translation_vi": { "type": "string", "minLength": 1 },
          "phrases": {
            "type": "array", "maxItems": 6,
            "items": {
              "type": "object",
              "required": ["en", "vi"],
              "additionalProperties": false,
              "properties": {
                "en": { "type": "string", "minLength": 1 },
                "vi": { "type": "string", "minLength": 1 }
              }
            }
          }
        }
      }
    },
    "vocabulary": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["term", "pos", "ipa", "meaning_vi", "cefr", "example"],
        "additionalProperties": false,
        "properties": {
          "term":       { "type": "string", "minLength": 1 },
          "pos":        { "type": "string",
                          "enum": ["noun","verb","adj","adv","phrase","other"] },
          "ipa":        { "type": "string" },
          "meaning_vi": { "type": "string", "minLength": 1 },
          "cefr":       { "type": "string", "enum": ["A2","B1","B2","C1"] },
          "example":    { "type": "string", "minLength": 1 },
          "tags":       { "type": "array", "items": { "type": "string" }, "maxItems": 4 },
          "synonyms":   { "type": "array", "items": { "type": "string" }, "maxItems": 3 },
          "antonyms":   { "type": "array", "items": { "type": "string" }, "maxItems": 3 }
        }
      }
    },
    "summary_vi": { "type": "string" }
  }
}
```

Ba chi tiết của schema là có chủ ý:

**`additionalProperties: false` ở mọi cấp.** Không phải khó tính vô ích: nó bắt provider
tuân thủ, và nó chặn việc field lạ lặng lẽ chảy vào code rồi thành phụ thuộc ngầm. FR-02
đã có criterion *"AI trả về dữ liệu không đúng schema thì hiển thị lỗi và cho retry, và
không lưu bản ghi hỏng"* — cờ này là cách thi hành nó.

**`pos` là enum có `other`.** `pos` để `not null` trong schema DB vì nó là **công cụ
phân biệt nghĩa rẻ nhất** — thấy `run (n)` là biết đang hỏi nghĩa nào. Nhưng bắt AI luôn
xác định đúng là bất khả, nên phải có giá trị thoát hiểm. Không có `other` thì AI sẽ
đoán bừa một `pos` sai, và sai thì tệ hơn là thừa nhận không biết.

**`ipa` không có `minLength`.** Có từ và cụm từ không có phiên âm hợp lý — một cụm bốn
chữ thì IPA của nó là gì? Cho phép chuỗi rỗng thay vì bắt AI bịa.

**`segments[].phrases` — optional, prompt-v6 (T2a 2026-10-02, FR-05 criterion mới).** Cặp
cụm EN↔VI chạm-sáng trong đoạn — thuần hiển thị, **không** vào `vocab_items`. `maxItems 6`
chặn AI chảy văn thành chú giải từng-chữ (đi ngược nguyên lý #2 — bản dịch là để học văn
phong, không phải word-by-word). Không `required`: output v5 (chưa có field này) vẫn hợp
lệ. Luật substring (`en` ⊂ `source_en`, `vi` ⊂ `translation_vi`) + cắt 6 thi hành ở
`AnalysisResponseNormalizer`, **không** ở decoder — cặp sai bị bỏ im lặng, không huỷ cả
segment (khác `vocabulary`: luật "không lưu bản ghi hỏng" của FR-02 chỉ áp cho vocabulary).

**`tags` / `synonyms` / `antonyms` — optional, owner mở lại 2026-09-08.** Ba field này
bổ trợ hiển thị, **không** đưa vào `required` — output cũ vẫn hợp lệ, không phá
`additionalProperties: false`. `maxItems` chặn AI chảy văn: đề xuất ban đầu 5/6 đã được
owner chốt lại **2026-09-09 là 4 tags / 3 synonyms / 3 antonyms (RV-1)** và đã đo với
prompt v2 (kết quả ở mvp-plan-pwa-gen.md (đã xoá, ADR-044) mục 7 — 100% item có field, 0 lần vượt hạn mức). Con số
khớp `RICH_LIMITS` trong `app/src/domain/verify.ts`.

---

## 5. Mapping sang data model và sang FR-02

### `vocabulary[]` → `vocab_items`

Đây là nhóm **duy nhất được lưu**. Schema đầy đủ ở
[vocabulary.md mục 6.1](docs/research/vocabulary.md#61-năm-bảng).

| Cột DB | Nguồn | Ghi chú |
|---|---|---|
| `id` | **client sinh** | uuid, sinh được khi offline — xem structure mục 6.4 |
| `collection_id` | **luồng capture** (FR-01) | Không bao giờ null; chưa chọn thì vào kho tạm |
| `term` | `vocabulary[].term` | Nguyên dạng |
| `term_normalized` | **client tính** | Chữ thường, cắt khoảng trắng thừa. **Không** nhờ AI. Q-06 đã chốt: không lemmatize |
| `pos` | `vocabulary[].pos` | |
| `ipa` | `vocabulary[].ipa` | Rỗng thì lưu null |
| `meaning_vi` | `vocabulary[].meaning_vi` | |
| `example` | `vocabulary[].example` | **Phải qua xác minh ở mục 6 trước khi lưu** |
| `cefr` | `vocabulary[].cefr` | Coi là gợi ý, không phải sự thật — M-03 đang đo tỷ lệ sai |
| `created_at` | **hệ thống** | Cột này làm cho kho tạm dùng được (structure mục 6.4) |
| `tags` / `synonyms` / `antonyms` | — | **Không có cột trên SQLite R1** (`db.md` A.2). Đừng thêm. Rich vocab là R2 |

### `segments[]` và `summary_vi` → `reading_sessions`, không vào `vocab_items`

Hai nhóm này phục vụ FR-05 (đọc song ngữ) và FR-06 (tóm tắt). App ghi chúng vào
`reading_sessions` khi đích là collection có tên, tối đa 10 phiên rồi trim
(Q-10 / ADR-029). Kho tạm không ghi phiên. Không lưu ảnh.

**`segments[]` còn một nhiệm vụ thứ hai**: nó là nguyên liệu xác minh ở mục 6.

Điều đó tạo ra một phụ thuộc đáng ghi lại: hai nhóm dữ liệu tưởng rời nhau lại cần nhau,
và đó là **một lý do nữa để giữ đúng một lần gọi**. Tách OCR thành bước riêng thì
`example` mất chỗ đối chiếu.

### Bộ lọc "đã thuộc" KHÔNG thuộc prompt

FR-10 lọc bỏ những từ owner **đã thuộc**, đo bằng FSRS `stability`. Việc đó xảy ra
**phía client, sau khi nhận response**, bằng một truy vấn trên `term_normalized`.

Đừng đưa danh sách từ đã biết vào prompt. Ba lý do: nó tốn token tuyến tính theo kích
thước kho, nó rò dữ liệu học tập của owner ra provider, và bản chất nó là một phép join
mà DB làm tốt hơn. Doc card-design gọi đây là *"một câu SQL, không tốn thêm một token AI
nào"*.

---

## 6. Xác minh `example`

FR-02 gọi *"`example` là câu thật trên trang"* là **ràng buộc bắt buộc**. Ràng buộc nào
không có cách thi hành thì không phải ràng buộc, nên mục này định nghĩa cách thi hành.

Vì sao nó đáng công: sau khi quyết định **không lưu trang**, câu ví dụ là **chỗ neo duy
nhất còn lại** của [nguyên lý 1](docs/specs/vision.md#1-authentic-input-over-graded-readers). Ranh
giới giữa authentic input và graded reader nằm đúng ở chỗ câu đó có thật hay không. AI
tự đặt câu ví dụ thì Reado đã âm thầm trở thành cái nó thề không trở thành.

### Thuật toán

```
page_text ← nối tất cả segments[].source_en, cách nhau một khoảng trắng

chuẩn hoá cả page_text và example:
  - unicode NFKC
  - nháy cong  ' ' " "  →  nháy thẳng  ' "
  - gạch – —  →  gạch -
  - gộp mọi chuỗi whitespace thành một khoảng trắng
  - bỏ khoảng trắng đầu/cuối
  - chữ thường

verified   ← normalize(example) là substring của normalize(page_text)
has_term   ← normalize(term) là substring của normalize(example)
```

Kết quả phân ba nhánh:

| Điều kiện | Trạng thái | Hành vi ở màn hình duyệt (FR-03) |
|---|---|---|
| `verified` và `has_term` | **verified** | Chọn sẵn để lưu, như bình thường |
| `verified` nhưng không `has_term` | **suspect** | Hiện cảnh báo — câu có thật nhưng không chứa từ đang học, tức thẻ vô dụng |
| không `verified` | **unverified** | **Không** chọn sẵn; owner giữ hoặc sửa nếu muốn |

Ba quy tắc bắt buộc kèm theo:

1. **Không tự loại item trong im lặng.** Tỷ lệ `unverified` là tín hiệu chất lượng prompt
   trực tiếp nhất mà hệ thống có. Ẩn nó đi là mất tín hiệu, và mất luôn khả năng biết
   prompt đang xấu đi.
2. **Không tự sửa `example`.** Nếu không khớp, đó là việc của owner ở FR-03. Hệ thống
   đoán câu đúng là đúng thứ ràng buộc này ngăn.
3. **Ghi lại tỷ lệ.** Nó là đầu vào cho M-03 (tỷ lệ item bị sửa tay ≤ 10%).

### Chỗ thuật toán này sẽ vấp

Nói trước để không ai ngạc nhiên: **so khớp chuỗi chính xác có thể quá chặt.** Ba nguyên
nhân thực tế:

- **Từ bị gạch nối qua dòng** — `compre-\nhensive` trên trang. Chuẩn hoá whitespace
  không giải quyết được, cần bước nối gạch nối riêng.
- **OCR sai một ký tự** — `rn` đọc thành `m` là lỗi cổ điển. Một ký tự sai làm substring
  fail toàn bộ câu.
- **AI cắt câu ở chỗ khác** — nó có thể trả về nửa câu, hoặc gộp hai câu.

Nếu tỷ lệ `unverified` cao trong lúc thử thật, cần một nhánh **"gần khớp"** — ví dụ tỷ lệ
token trùng liên tiếp vượt một ngưỡng. Cố ý **chưa** đặc tả nhánh đó, vì ngưỡng đoán
trên giấy thì vô nghĩa; nó phải đến từ số liệu thật. Xem mục 9.

---

## 7. Những gì KHÔNG hỏi AI

Danh sách này tồn tại vì mỗi mục dưới đây **nghe rất hợp lý** và đã bị loại có lý do.
Thêm chúng vào prompt là đảo một quyết định đã chốt ở doc khác.

| Đừng hỏi | Vì sao | Nguồn |
|---|---|---|
| `collocations`, `register`, `word_parts` | GP3 **đã bị loại bỏ**. `example` đã chứa collocation một cách tự nhiên — *"proved remarkably resilient"* cho thấy cách dùng mà không cần cột riêng. Ba field này làm nặng cả prompt lẫn màn hình duyệt | card-design GP3, structure mục 11 |
| ~~Topic tag / chủ đề của từ~~ | ~~Đã bị loại bỏ. Collection làm đúng việc đó bằng chủ ý người dùng, miễn phí, và không bị trôi dạt tên gọi~~ **Owner MỞ LẠI 2026-09-08:** AI sinh sẵn kèm lúc capture (user không phải gõ) + user sửa được; collection vẫn là trục tổ chức chính, tag chỉ là bổ trợ | structure mục 3.3 + 11; lý do mới ở [rich-vocab-cram-ddl.md](docs/research/review.md) mục 1 |
| ~~Từ đồng nghĩa / trái nghĩa~~ | ~~Thuộc `word_relations` ở R2, và cơ chế là AI đề xuất, người duyệt — không phải sinh kèm lúc trích xuất~~ **Owner MỞ LẠI 2026-09-08:** thêm 2 cột hiển thị bổ trợ do AI sinh kèm lúc capture; `word_relations` R2 **không bị huỷ** — nó vẫn là cơ chế *luyện* cặp quan hệ | structure mục 5; [rich-vocab-cram-ddl.md](docs/research/review.md) mục 1 |
| Dạng nguyên thể của `term` | Q-06 đã chốt: không lemmatize. Client chỉ chữ thường + trim | structure mục 6.4 |
| Câu ví dụ do AI tự đặt | Ràng buộc bắt buộc của FR-02, và là chỗ neo của nguyên lý 1 | mục 6 |
| Nên đưa từ nào vào bộ ôn tập | Đó là quyết định của owner ở FR-09, và của bộ lọc `stability` ở FR-10 | FR-09, FR-10 |
| Giải thích ngữ pháp | **NG-08** | PRD mục 3 |
| Audio / hướng dẫn phát âm | **NG-01**. `ipa` là chỗ dừng có chủ ý | PRD mục 3 |

Nguyên tắc chung, và nó là cách nhớ nhanh cả bảng trên: **hỏi AI những gì chỉ có trên
trang sách; đừng hỏi những gì DB đã biết hoặc owner phải tự quyết.**

---

## 8. Cách kiểm chứng A-01 và A-02

Việc này **không** cần app, **không** cần chốt Q-01/Q-02/Q-03, và làm được ngay. Nó nên
đi trước mọi dòng code, vì nó có thể phủ định cả kiến trúc.

### Chuẩn bị

- **5–10 ảnh trang thật**, phủ đủ ba nguồn ở nguyên lý 1: sách giấy, ảnh chụp màn hình
  bài báo mạng, tài liệu chuyên ngành. Cố tình lấy vài ảnh **chụp xấu** — A-03 giả định
  ảnh chụp điều kiện thường là đủ, và đây là chỗ kiểm nó luôn.
- Với mỗi ảnh, **output prompt thủ công của owner** để so.

### Đo gì

| Đo | Kiểm giả định nào | Ngưỡng |
|---|---|---|
| Một lần gọi trả đúng schema, không cần bước OCR riêng | **A-01** | Phải đạt, nếu không thì kiến trúc pipeline đổi |
| Tỷ lệ `example` `verified` theo mục 6 | Chất lượng prompt | Chưa có ngưỡng — số đo đầu tiên **là** cái đặt ngưỡng |
| Từ vựng trích ra so với bản thủ công: thiếu gì, thừa gì | **A-02** | Owner tự đánh giá, đây là phán đoán định tính |
| Chất lượng bản dịch so với bản thủ công | **A-02** | Owner tự đánh giá |
| Độ trễ mỗi trang | **NFR-01** | Mục tiêu ≤ 15s, p95 ≤ 30s — PRD nói đây là giả định cần đo lại |
| Chi phí mỗi trang | **NFR-02** | Chỉ **đo và ghi lại** ở R1, chưa chốt ngưỡng |

### Kết quả xấu nghĩa là gì

Nói trước để kết quả xấu không bị hiểu thành thất bại của cả ý tưởng:

- **Schema fail nhưng nội dung tốt** → vấn đề structured output, thử lại với schema
  chặt hơn hoặc provider khác. Chưa đụng tới A-01.
- **Một lần gọi không kham nổi cả ba nhóm** → A-01 sai. Tách OCR thành bước riêng, và
  **cơ chế xác minh ở mục 6 phải thiết kế lại** vì `segments[]` không còn đến cùng lúc.
- **Tỷ lệ `verified` thấp** → có thể là prompt, có thể là thuật toán so khớp quá chặt
  (mục 6). Phân biệt hai nguyên nhân bằng cách đọc tay chục câu fail.
- **Chất lượng kém hơn bản thủ công** → A-02 sai, và đây là kết quả nghiêm trọng nhất.
  Nhưng nó chỉ kết luận được khi **prompt baseline ở mục 2 đã có**.

---

## 9. Đã chốt và chưa chốt

### Đã chốt

| Quyết định | Cơ sở |
|---|---|
| Một lần gọi trả cả ba nhóm; structured output chứ không phải prose | FR-02, A-01 |
| `additionalProperties: false` ở mọi cấp schema | Mục 4 |
| `pos` là enum bắt buộc, có giá trị thoát hiểm `other` | FR-02, structure mục 6.4 |
| `source_en` giữ nguyên văn, không cho AI sửa lỗi | Mục 3 — nó là nguyên liệu xác minh |
| `term_normalized` tính phía client, không nhờ AI | Mục 5 |
| Bộ lọc "đã thuộc" chạy phía client sau response, không đưa vào prompt | Mục 5 |
| `example` phải qua xác minh ba nhánh trước khi được chọn sẵn để lưu | Mục 6 |
| Không tự loại và không tự sửa item `unverified` | Mục 6 |
| Từ đa nghĩa trả về nhiều phần tử, mỗi phần tử một nghĩa | structure mục 6.3 |
| Tám thứ ở mục 7 **không** hỏi AI — ~~đủ tám~~ **còn sáu** từ 2026-09-08: topic tag + synonym/antonym được owner mở lại (xem mục 7) | Mục 7, rich-vocab-cram-ddl.md |

### Chưa chốt

| Câu hỏi | Ghi chú |
|---|---|
| ~~**Prompt baseline nguyên văn**~~ | **Đã cung cấp 2026-09-08** — nguyên văn ở mục 2. Là bản *tạm thời* của owner, nên vẫn dõi theo M-03 |
| Có cần nhánh "gần khớp" khi xác minh `example` không, và ngưỡng bao nhiêu | Chỉ trả lời được bằng tỷ lệ fail thật. Ngưỡng đoán trên giấy là vô nghĩa — mục 6 |
| Có giới hạn số item mỗi trang không | Docs chưa nói. Không giới hạn thì `daily_new_limit` gánh hết; giới hạn thì phải chọn bỏ từ nào |
| Provider nào, model nào | A-06 và dependency ở PRD mục 11 chọn Gemini làm mặc định, nhưng lớp gọi AI phải cô lập được để đổi |
| Xử lý ảnh chụp nhiều trang một lúc | FR-01 giả định một trang một lần. Chưa ai hỏi về chụp hai trang mở |

### Câu hỏi để nghiên cứu tiếp

1. **Prompt có nên chia thành hai lần gọi khi ảnh xấu?** A-03 giả định ảnh chụp thường là
   đủ. Nếu sai, một bước tiền xử lý ảnh có thể rẻ hơn là đổi cả kiến trúc.
2. **`cefr` do AI gán chính xác tới đâu?** M-03 sẽ đo. Doc structure mục 6.4 đã nói nếu
   nó sai thường xuyên thì đây là ứng viên số một để bỏ khỏi schema.
3. **Có nên cho owner sửa prompt trong app không?** Nó là núm mạnh nhất ảnh hưởng chất
   lượng, nhưng cũng là cách nhanh nhất để tự làm hỏng output. Chưa ai hỏi.
