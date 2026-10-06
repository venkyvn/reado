# PRD — changelog theo phiên bản

> Dời nguyên văn từ `docs/specs/prd.md` ngày 2026-10-06 (workflow-docs-r1 T8). Lịch sử thay đổi, **không phải hợp đồng hiện hành** —
> yêu cầu hiện hành đọc ở `prd.md`; quyết định hiện hành ở `CLAUDE.md` §5 + index `docs/decisions-log.md`.

## Ghi chú phiên bản (đầu tài liệu)

> **v0.3 — đồng bộ theo mô hình collection.** Ba thay đổi ở tầng khái niệm, mọi thứ
> khác suy ra từ chúng:
>
> 1. **`book` + `page_number` được thay bằng `collection`** — một bối cảnh đọc do
>    người dùng tự đặt tên, xử được cả nguồn báo và web vốn không có số trang.
> 2. **Trang không còn được lưu.** Bản song ngữ và summary chỉ sống trong phiên đọc.
>    G-03 chết theo, FR-07 và FR-13 bị bỏ, NFR-04 được thoả bằng thiết kế.
> 3. **Chống trùng chuyển từ ràng buộc `unique` sang bộ lọc lúc trích xuất**, nên
>    một từ nhiều nghĩa được nhiều dòng. Q-07 tan.
>
> Nghiên cứu nền và các hướng đã cân nhắc rồi loại bỏ nằm ở
> [research/vocabulary.md](docs/research/vocabulary.md).

> **v0.4 — tầng lịch ôn được viết ra.** v0.3 dùng chữ "FSRS" ở chín chỗ mà chưa nói
> hệ thống cần **giữ** những gì để FSRS chạy được. v0.4 lấp chỗ đó. Không có thay đổi
> nào ở tầng khái niệm; tất cả là hệ quả của việc đọc kỹ cơ chế:
>
> 1. **Ranh giới ngày trở thành cấu hình.** Nửa đêm hệ thống không phải ranh giới ngày
>    của người học đêm, và streak ở FR-14 đứt oan nếu dùng nó.
> 2. **FR-19 mới — Leech Handling.** FR-10 lọc từ *đã thuộc*; chưa có gì xử lý từ
>    *không bao giờ thuộc*. Ở Reado, một leech thường là dấu hiệu **thẻ sai** chứ không
>    phải người học kém, vì thẻ do AI sinh.
> 3. **Q-11 và Q-12 mới.** Q-11 là chỗ duy nhất mà cơ chế của Anki không cover được
>    thiết kế R2 của Reado, và nó ảnh hưởng cả FR-10.
>
> Toàn bộ lý lẽ ở [research/review.md](docs/research/review.md).

> **v0.5 — hai chỗ FR va nhau được xử, và prompt có spec.** Không có yêu cầu mới nào;
> v0.5 chỉ làm cho những thứ đã yêu cầu trở nên **kiểm được**:
>
> 1. **FR-14 chốt hiện con số nào.** FR-09 cho card mới đến hạn ngay trong ngày, nên
>    capture 25 trang tạo hàng trăm card cùng `due_at` hôm nay; nhưng FR-11 chỉ đưa
>    `daily_new_limit` vào hàng đợi. Trang chủ hiện tổng số là hiện đúng con số gây
>    choáng mà `daily_new_limit` tồn tại để ngăn.
> 2. **FR-02 có cách thi hành ràng buộc `example`.** *"Câu thật trên trang"* trước đây
>    là lời hứa không kiểm được, nên sẽ bị bỏ qua lúc implement — mà nó là chỗ neo duy
>    nhất còn lại của nguyên lý *Authentic Input* sau khi bỏ lưu trang.
> 3. **[prompt-spec.md](docs/agent/prompt-spec.md) mới.** Prompt và output schema từng bị xếp vào
>    *chi tiết triển khai* ở mục 13, nhưng A-01, A-02 và M-07 đều đứng trên nó. Doc này
>    cũng ghi rõ một chỗ trống chặn A-02: prompt baseline thủ công chưa có trong repo.
>
> Kèm theo, [CLAUDE.md](CLAUDE.md) ở root nói thứ tự đọc, những gì không được tranh
> luận lại, và những câu hỏi phải hỏi thay vì tự quyết.

> **v0.6 — chiều ngược của FR-16.** NFR-05 đòi mang dữ liệu đi được; round-trip còn
> thiếu nhập CSV từ vựng. **FR-20 mới** — gộp CSV vào kho (không `unique`, preview
> để bỏ dòng, card `new`). Đây **không** phải path capture thứ hai: đến v0.6 vẫn chỉ
> có ảnh là lối đưa trang vào — PDF/ebook là non-goal (NG-07 bản gốc). Cửa UI tách
> khỏi Settings (FR-15) — xem [journeys.md](docs/specs/journeys.md) J-R1-D.

> **v0.7 — đường vào nhanh cho collection đang đọc.** FR-17 cho phép chọn tối đa
> hai named collection để hiện trên Home. Đây chỉ là shortcut vào Collection Hub,
> không pin một session cụ thể và không biến artefact đọc thành dữ liệu durable.
> Collection thứ ba phải thay một shortcut hiện có bằng lựa chọn rõ ràng, không
> tự thay ngầm.

> **v0.8 — Q-01 đến Q-03 chốt theo nghĩa native local-first.** R1 là app **iOS**
> (SwiftUI), kho từ và FSRS trên **SQLite máy**, Gemini đi qua **proxy** (NFR-07).
> PWA + BE đầy (chốt 2026-09-08) là quyết định chết — chuỗi lý do ở
> [research/tech-stack.md](docs/research/tech-stack.md) mục 2.1. NFR-03 **không** hoãn
> sang R2. Dashboard web sản phẩm thuộc Later. Solution design viết được sau bản
> này; file đó **vẫn chưa có**.

> **v0.10 — FR-22 gặp lại từ cũ khi đọc.** Vòng lặp của vision (đọc → khựng → giữ → ôn →
> *nhận ra khi đọc tiếp*) thiếu mắt xích cuối: Reado chưa biết, và chưa cho người dùng
> ghi lại, lúc họ gặp lại một từ đã có trong kho. M-06 là thước đo trực tiếp. FR-22 thêm
> bảng `encounters` **ngoài FSRS** (schema v4, ADR-048): "thấy" tự ghi khi lưu trang,
> "nhận ra" do người dùng chạm — cả hai **không đổi lịch ôn**. Q-06 (không lemmatize)
> giữ nguyên; Q-09 chỉ cho FR-10, FR-22 so khớp **xuyên collection** (đảo 2026-10-05 —
> xem v0.16/ADR-066: FR-10 giờ cũng so khớp toàn app, cùng phạm vi FR-22).

> **v0.9 — Q-03 hybrid BYOK.** Chốt 2026-09-17 *“app không gọi Gemini thẳng”*
> **không bị xoá** — bia mộ tại chỗ ở mục 12. Thay bằng: proxy Reado (key `.env`
> server) vẫn là **mặc định**; user thêm được nhiều agent OpenAI-compatible
> (tên + `base_url` + `model` + key) và chọn một agent active cho **cả** FR-02
> (một lần gọi multimodal — không tách OCR). Key user: Keychain, không SQLite,
> không FR-16. **FR-21 mới**, Epic E5. Walking skeleton vẫn đi proxy.

> **v0.11 — ADR-049: bỏ proxy Reado, Q-03 đảo thành BYOK-only.** Chốt 2026-10-01.
> v0.9 "hybrid" **không bị xoá** — bia mộ tại chỗ ngay trên. Thay bằng: `proxy/`
> và `ReadoProxyClient` xoá hẳn; agent mặc định `kind = reado_proxy` chỉ còn là
> hàng placeholder "chưa chọn agent" (không hiện trong UI, không gọi mạng). FR-02
> **chỉ** còn agent BYOK OpenAI-compat (FR-21) — không còn "mặc định sẵn dùng",
> user phải thêm agent trước khi chụp trang đầu. Lý do: `proxy.reado.app` chưa
> bao giờ deploy (ADR-041), app đã OCR trên máy từ ADR-034 — proxy chỉ còn là
> code chết. NFR-07 chỉ còn vế key user ở Keychain, vế "key sản phẩm `.env` proxy"
> là bia mộ. Chi tiết: [decisions-log.md ADR-049](docs/decisions-log.md).

> **v0.12 — FR-23 đọc PDF trong Reado, đảo một phần NG-07.** Chốt 2026-10-04. Đọc
> PDF trước đây phải đi vòng qua screenshot; giờ Reado đọc PDF tại chỗ (không chép
> file vào app, chỉ giữ bookmark + trang đang đọc) và phân tích trang đang đọc —
> cửa thu từ vựng **thứ hai**, song song ảnh chụp (FR-01). NG-07 **không bị xoá**,
> chỉ còn giữ phần EPUB/ebook và việc chép file vào app. Chi tiết:
> [decisions-log.md ADR-058](docs/decisions-log.md).

> **v0.13 — FR-23 thêm điều hướng trang + Mục lục (pdf-nav-r1).** Chốt 2026-10-04.
> Fen thử sách thật 254 trang: vuốt từng trang không đủ. Thêm gõ số trang + Mục
> lục đọc outline sẵn có trong file (đảo dòng "mục lục" khỏi "Không thuộc phạm vi
> R1" của FR-23). Thanh tab ẩn khi đang đọc PDF; chạm vào trang ẩn/hiện thêm nav
> bar + thanh đáy; tông nền đọc (vài tông giấy + kéo thả độ đậm). **ADR-060 cùng
> ngày** bỏ thanh kéo trang + nút ◀ ▶ ban đầu sau khi fen xem tay thấy không cần.
> **ADR-061 cùng ngày** mở rộng tông nền từ nhị phân Trắng/Nâu sang vài tông +
> Slider độ đậm, và cố định màu viền trang (không theo Dark Mode) sau khi fen báo
> viền trên/dưới tối gần đen khi đọc khổ dọc. **ADR-062 cùng ngày** dọn control
> tông nền từ Menu trên toolbar reader sang Section "Đọc PDF" ở màn Cài đặt. Không
> đổi schema/prompt. Chi tiết: [decisions-log.md ADR-059](docs/decisions-log.md),
> [ADR-060](docs/decisions-log.md), [ADR-061](docs/decisions-log.md),
> [ADR-062](docs/decisions-log.md).

## Thay đổi FR theo phiên bản (đầu §7)

**Thay đổi ở v0.3.** Số hiệu FR được **giữ nguyên** cho requirement còn sống, để
tham chiếu chéo từ các doc research không gãy. FR bị bỏ thì để lại bia mộ tại chỗ
thay vì xoá; FR mới lấy số tiếp theo và được đặt vào epic đúng nghĩa của nó, nên
thứ tự số trong tài liệu không còn liên tục.

| FR | Trạng thái ở v0.3 |
|---|---|
| FR-01, FR-02, FR-05, FR-06, FR-08, FR-10, FR-11, FR-12, FR-16 | Sửa |
| FR-07, FR-13 | **Bỏ** — xem bia mộ tại chỗ |
| FR-17, FR-18 | **Mới** |
| FR-03, FR-04, FR-09, FR-14, FR-15 | Không đổi về bản chất |

| FR | Trạng thái ở v0.4 |
|---|---|
| FR-11, FR-12, FR-15 | Sửa — thêm criterion ở tầng lịch |
| FR-19 | **Mới** |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.5 |
|---|---|
| FR-02 | Sửa — thêm criterion thi hành ràng buộc `example` |
| FR-14 | Sửa — chốt con số hiển thị khi hạn mức thẻ mới có hiệu lực |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.6 |
|---|---|
| FR-20 | **Mới** — nhập CSV từ vựng, Epic E5 |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.7 |
|---|---|
| FR-17 | Sửa — tối đa hai shortcut collection đang đọc trên Home |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.9 |
|---|---|
| FR-21 | **Mới** — analysis agents (proxy mặc định + BYOK OpenAI-compat), Epic E5 |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.10 |
|---|---|
| FR-22 | **Mới** — gặp lại từ cũ khi đọc (gạch chân + "Nhận ra", bảng `encounters`), Epic E2 |
| FR-05 | Criterion 3 (chạm từ trong đoạn → nghĩa + IPA) được FR-22 mở rộng sang từ cũ trong kho |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.12 |
|---|---|
| FR-23 | **Mới** — đọc PDF trong Reado, cửa thu từ vựng thứ hai (bảng `pdf_sources`, prompt riêng), Epic E1. Đảo một phần NG-07 |
| NG-07 | Nội dung viết lại: chỉ còn EPUB/ebook + chép file vào app |

| FR | Trạng thái ở v0.13 |
|---|---|
| FR-23 | Sửa — thêm GWT điều hướng trang (gõ trang/Mục lục), thanh tab ẩn khi đọc, chạm ẩn chrome, tông nền đọc chọn ở Cài đặt (vài tông + độ đậm). "Không thuộc phạm vi R1" bỏ "mục lục" (ADR-059/060/061/062) |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.14 |
|---|---|
| FR-02 | Sửa — thêm GWT soát OCR trên máy bằng Apple Intelligence (tiền xử lý, mọi agent) (ADR-063) |
| FR-21 | Sửa — thêm kind `apple_intelligence` (agent builtin, mặc định khi chưa chọn agent nào) (ADR-063) |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.15 |
|---|---|
| FR-02 | Sửa — engine OCR mặc định `liveText` (ADR-064); **bỏ GWT soát OCR bằng LLM của v0.14** — gỡ hẳn (ADR-065), xem callout ngay dưới |
| Còn lại | Không đổi |

| FR | Trạng thái ở v0.16 |
|---|---|
| FR-09 | Sửa — chọn sẵn theo ngân sách ngày còn lại (`daily_new_limit` trừ số đã lưu hôm nay), không còn cố định 5/trang (vocab-identity-r1, ADR-066) |
| FR-10 | Sửa — so khớp "đã thuộc" đổi phạm vi **toàn app**, không còn theo collection (đảo Q-09/ADR-032 → ADR-066); nhóm gập đổi tên "Đã thuộc" → "Đã có trong kho", mở rộng gồm mọi từ đã có (đang học + đã thuộc) |
| FR-22 | Sửa — `encounters` ghi kèm câu gốc + collection nguồn khi `seen`; popover + mặt sau thẻ hiện ngữ cảnh gặp lại (ADR-066) |
| Còn lại | Không đổi |

> **v0.16 — đảo Q-09 cho FR-10, thống nhất phạm vi so khớp với FR-22 (vocab-identity-r1).**
> Chốt 2026-10-05 (ADR-066). Q-09 (ADR-032, 2026-09-22) giới hạn bộ lọc "đã thuộc" trong
> cùng collection vì lúc đó "gặp lại từ chưa thuộc" chỉ ghi nhận được bằng cách tạo thêm
> một dòng `vocab_items`. FR-22 (v0.10) đã lấp đúng chỗ đó bằng bảng `encounters` xuyên
> mọi collection — giữ Q-09 cũ cho FR-10 giờ chỉ còn cái giá (thẻ trùng sinh ra mỗi lần
> gặp lại một từ ở collection khác), không còn cái lợi. FR-10 đổi sang so khớp **toàn
> app**, cùng phạm vi FR-22. Nhóm gập (Q-13/ADR-056) đổi tên và mở rộng: "Đã có trong kho"
> gồm mọi từ đã có (không chỉ từ đã thuộc) — mặc định không tạo thẻ, chỉ ghi `seen` kèm
> câu; "Nghĩa khác" vẫn lưu thẻ mới nếu người dùng xác nhận. Đi kèm: FR-09 đổi chọn sẵn
> cố định 5/trang sang ngân sách bám `daily_new_limit`, và `encounters` thêm cột
> `sentence`/`collection_id` (migration v7) để FR-22 hiện được ngữ cảnh gặp lại. Chi tiết:
> [decisions-log.md ADR-066](docs/decisions-log.md), [plans/vocab-identity-r1.md](docs/plans/done/vocab-identity-r1.md).

| FR | Trạng thái ở v0.17 |
|---|---|
| FR-24 | **Mới** — gộp từ trùng trong kho (fen duyệt từng nhóm), Epic E5 (ADR-067) |
| FR-22 | Sửa — sheet hiện câu gốc lần đầu + "N ngày trước" + mức; haptic khi lên Đã thấm; dòng "Trang này có N từ bạn đã gặp" (ADR-068) |
| FR-14 | Sửa — dòng nhắc trong hero đổi thành "N/7 ngày"; thẻ "Tuần qua" (ADR-068) |
| FR-11 | Sửa — phiên ôn nhanh 3 thẻ (ADR-068) |
| FR-02 | Sửa — cụm đáng nhớ sau khi lưu trang, chọn từ `segments[].phrases`; không đổi prompt (ADR-068) |
| Còn lại | Không đổi |

> **v0.17 — engagement-r1: gộp từ trùng cũ (FR-24) + tăng gắn bó.** Chốt 2026-10-05
> (ADR-067, ADR-068). FR-10 (ADR-066) chỉ chặn trùng **mới**; các dòng lưu trước đó cùng
> `term_normalized + pos` ở nhiều bộ vẫn mỗi dòng một thẻ ôn riêng, nên một từ bị ôn nhiều
> lần. FR-24 cho fen duyệt từng nhóm và gộp, giữ thẻ tiến bộ nhất (không tự viết FSRS), còn
> câu gốc của dòng gộp thành một lần gặp lại. Song song, các ý trong `idea/tang_gang_bo.md`
> được làm theo vision #6 (tiến bộ thật, không ảo): khoảnh khắc nhận ra (FR-22), phiên ôn
> nhanh (FR-11), dòng nhắc "N/7 ngày" (FR-14, bổ sung ADR-038 — pill streak giữ nguyên),
> cụm đáng nhớ (FR-02). Chi tiết: [decisions-log.md ADR-067/068](docs/decisions-log.md),
> [plans/done/engagement-r1.md](docs/plans/done/engagement-r1.md).
