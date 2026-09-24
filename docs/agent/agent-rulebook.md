> Gộp từ vocabulary-structure.md + vocabulary-card-design.md + vocab-import-plan.md — nội dung không đổi, chỉ nhập làm một. 

## Phần 1 — Cấu trúc từ vựng — collection và các chế độ ôn tập

| Field | Value |
|---|---|
| Status | Draft, mở cho nghiên cứu tiếp |
| Created | 2026-09-07 |
| Last updated | 2026-09-18 |
| Revision | v2.2 — v2 viết lại theo mô hình collection; v2.1 vá schema (bảng `settings`, đối xứng `word_relations`, `review_logs.mode`) và đồng bộ sang PRD v0.3; v2.2 điền FSRS state vào `cards` / `review_logs` / `settings`, thêm bẫy 5, và ghi chú mục 4.1. Các hướng của v1 bị loại bỏ nằm ở [mục 11](#11-phụ-lục--những-hướng-đã-cân-nhắc-và-loại-bỏ) |
| Related | [prd.md](docs/specs/prd.md), [vision.md](docs/specs/vision.md), [vocabulary.md](docs/research/vocabulary.md), [review.md](docs/research/review.md) |
| Nguồn chính | [ref/pvo/pvo-2022-model.md](../../ref/pvo/pvo-2022-model.md) |
| Phạm vi | Trả lời câu hỏi: từ vựng được tổ chức thế nào, và cấu trúc đó cho phép ôn tập theo những cách nào |

**Tài liệu này tự chứa.** Nó được viết để một session mới, không có bối cảnh gì về
cuộc thảo luận sinh ra nó, vẫn đọc và tiếp tục được.

## Điều hướng

- [1. Phạm vi — tầng nào của bài toán](#1-phạm-vi--tầng-nào-của-bài-toán)
- [2. PVO — mô hình, và quan trọng hơn: PVO dùng để làm gì](#2-pvo--mô-hình-và-quan-trọng-hơn-pvo-dùng-để-làm-gì)
- [3. Collection — đơn vị tổ chức](#3-collection--đơn-vị-tổ-chức)
- [4. Feature A — Retain: ôn tập có phạm vi](#4-feature-a--retain-ôn-tập-có-phạm-vi)
- [5. Feature B — Expand: quan hệ ngữ nghĩa (R2)](#5-feature-b--expand-quan-hệ-ngữ-nghĩa-r2)
- [6. Schema](#6-schema)
- [7. Năm cái bẫy](#7-năm-cái-bẫy)
- [8. Đã chốt và chưa chốt](#8-đã-chốt-và-chưa-chốt)
- [9. Câu hỏi để nghiên cứu tiếp](#9-câu-hỏi-để-nghiên-cứu-tiếp)
- [10. Đã áp dụng vào tài liệu nào](#10-đã-áp-dụng-vào-tài-liệu-nào)
- [11. Phụ lục — những hướng đã cân nhắc và loại bỏ](#11-phụ-lục--những-hướng-đã-cân-nhắc-và-loại-bỏ)
- [12. Nguồn](#12-nguồn)

---

## 1. Phạm vi — tầng nào của bài toán

Câu hỏi về từ vựng trong Reado có hai tầng.

| Tầng | Câu hỏi | Tài liệu |
|---|---|---|
| Card | **Một thẻ** chứa gì, kiểm tra gì | [vocabulary.md](docs/research/vocabulary.md) |
| Tổ chức | **Các từ** được gom nhóm và liên hệ với nhau thế nào | Tài liệu này |
| Lịch | **Khi nào** một thẻ quay lại, và cần giữ gì để biết điều đó | [review.md](docs/research/review.md) |

Doc card-design dừng đúng ở ranh giới một thẻ. Nếu chiếu vào khung 9 aspect của
Nation mà nó dùng làm xương sống, ô trống lớn nhất là **associations** — từ này
gợi nhớ tới những từ nào khác, nó nằm ở đâu trong mạng lưới ý niệm của người học.
Một bộ thẻ phẳng gồm vài nghìn cặp `term → nghĩa` không mô phỏng được điều đó.

Tài liệu này lấp ô trống ấy bằng **hai cơ chế ở hai thời điểm khác nhau**, và cần
nói rõ ngay rằng chúng không ngang tầm nhau:

- **Collection** (R1) — người dùng tự gom từ theo bối cảnh đọc. Rẻ, không cần AI,
  chạy được từ từ đầu tiên. Nhưng nó là liên hệ theo **tình huống**, không phải
  theo nghĩa: biết `resilient` và `pandemic` cùng đến từ một cuốn sách không hề cho
  biết `resilient` gần nghĩa với `robust`. Nó lấp một phần ô trống, không lấp hết.
- **Quan hệ ngữ nghĩa từng cặp** (R2) — đồng nghĩa, trái nghĩa, gần nghĩa. Đây mới
  là phần chạm đúng vào `associations`, và là phần lấy cảm hứng từ PVO.

Thứ tự đó quan trọng: cơ chế thứ hai chỉ có ý nghĩa khi kho từ đã đủ dày, nên phần
lấp trọn vẹn buộc phải đợi. Chấp nhận được, vì phần rẻ dùng được ngay.

---

## 2. PVO — mô hình, và quan trọng hơn: PVO dùng để làm gì

Mô hình đầy đủ nằm ở [ref/pvo/pvo-2022-model.md](../../ref/pvo/pvo-2022-model.md).
Tóm tắt vừa đủ để đọc tiếp:

- **Concept** là node khái niệm; **Example** là câu có phần cấu trúc được highlight.
- Concept↔Concept chỉ có **hai** quan hệ: `Association` và `Type of`.
- Example↔Concept có **tám** quan hệ: `Idiom`, `Nominal`, `Agent`, `Patient`,
  `Action`, `Described by`, `Describing`, `Other phrase`.
- Mỗi Example mang năm tham số ngữ cảnh **TMRND**: Tone, Mode, Register, Nuance,
  Dialect.
- Example chưa nối với Concept nào thì mang nhãn `Undecided`, và nhãn tự mất khi
  có link đầu tiên.
- Một từ điển PVO trưởng thành ở tầm **vài trăm Concept**.

Hai điều PVO **không** có, và cả hai đều quan trọng:

**Không có spaced repetition.** PVO không lên lịch bất cứ thứ gì. Nó là hệ thống
lưu trữ và truy xuất. Toàn bộ phần mà Reado coi là trung tâm — FSRS, due date,
review log — không tồn tại trong PVO.

**Không có bảng `terms`.** Đơn vị nguyên tử là câu, không phải từ. Concept chỉ là
nhãn để nối. Đây là Lexical Approach được đóng cứng vào schema, và nó đúng là câu
hỏi mở số 3 ở mục 6 của doc card-design, giờ hiện ra dưới dạng một hệ thống thật
đã chạy nhiều năm.

### 2.1 Mục đích của PVO khác mục đích của Reado

Tác giả nói thẳng ngay đoạn mở đầu: PVO giúp *"tìm lại cụm từ cần thiết khi nói và
viết"*, và *"đặc biệt hữu ích với phiên dịch và giáo viên tiếng Anh"*.

| | PVO | Reado |
|---|---|---|
| Kỹ năng phục vụ | Production — nói, viết, dịch | Reception — đọc hiểu |
| Người dùng | Chuyên nghiệp, chấp nhận lao động thủ công | Người tự học, ma sát thấp là điều kiện sống còn |
| Cơ chế giữ từ | Truy xuất theo nhu cầu công việc | Spaced repetition theo lịch |
| Đơn vị lưu | Câu có highlight | Từ, kèm câu ví dụ |
| Ai tạo cấu trúc | 100% người dùng | Người dùng ở tầng collection, AI đề xuất ở tầng quan hệ |

Không có dòng nào ở trên nói PVO sai. Nó nói PVO **giải một bài toán khác**. Hệ
quả trực tiếp: vay mượn phải chọn lọc theo từng thành phần, không bê nguyên khối.

---

## 3. Collection — đơn vị tổ chức

### 3.1 Nó là gì

**Collection là một bối cảnh đọc do người dùng tự đặt tên.** Không phải thư mục,
không phải thẻ tag, không phải chủ đề do AI suy ra.

Hành trình thực tế:

| Tình huống | Collection |
|---|---|
| Bắt đầu đọc một cuốn sách | Tạo collection mang tên sách đó |
| Đọc tài liệu chuyên ngành khi làm việc | Một collection cho mảng chuyên ngành |
| Đột nhiên muốn đọc triết | Tạo collection mới |
| Quét vội một đoạn báo mạng, không muốn nghĩ | Rơi vào **kho tạm** |

Collection **thay thế** khái niệm `book` trong PRD hiện tại, không phải thêm vào
bên cạnh. Đây là điểm quan trọng về chi phí: PRD v0.2 giả định nguồn là sách giấy
(`book_title` + `page_number`), nhưng nguồn thật còn có báo và web — mà một bài
báo mạng thì không có "số trang". Collection bịt đúng lỗ hổng đó, và bịt bằng
cách bỏ bớt chứ không thêm vào.

### 3.2 Kho tạm

Collection mặc định luôn tồn tại, sắp theo thời gian, và người dùng gom từ theo lô
về collection khác khi rảnh.

Điểm thiết kế quyết định: **từ nằm trong kho tạm vẫn ôn được bình thường.** Đây
không phải hộp chờ xử lý mà là một cái kho dùng được ngay. Mọi inbox chứa thứ chưa
dùng được đều biến thành nghĩa địa sau vài tuần; kho này thì không, vì nếu người
dùng không bao giờ phân loại, nó chỉ **thoái hoá thành một collection mặc định
to** — vẫn học tốt, chỉ mất khả năng ôn theo phạm vi. Ai chăm phân loại thì được
thêm; ai lười thì không bị phạt.

Hệ quả schema: `collection_id` **không bao giờ null**, và bảng `collections` cần
cột `is_default` để luôn có chỗ tiếp nhận.

### 3.3 Vì sao collection tốt hơn topic tag do AI sinh

Bản v1 của tài liệu này đề xuất xin Gemini vài topic tag cho mỗi từ. Collection
làm đúng công việc đó và tốt hơn ở bốn điểm:

| | Topic tag AI | Collection |
|---|---|---|
| Nguồn gốc | AI suy đoán | **Chủ ý người dùng** |
| Trôi dạt tên gọi | Có — `finance` / `money` / `economy` nở ra trong ba tuần | Không, người dùng tự đặt và tự thấy danh sách |
| Chi phí | Vài chục token mỗi trang | **Không** |
| Hạ tầng chống drift | Controlled vocabulary, near-duplicate check bằng embedding | Không cần gì |
| Kiểu gom nhóm | Ngữ nghĩa — rủi ro interference (mục 4.3) | **Tình huống** — nằm ở vế có lợi |

Điểm cuối đáng nói riêng, và nó là một may mắn chứ không phải thiết kế: từ vựng
gom theo *bối cảnh đọc* là **thematic set**, không phải semantic set. Mục 4.3 giải
thích vì sao khác biệt đó lại quan trọng.

Toàn bộ tầng chống ontology drift — controlled vocabulary, embedding kNN, hàng đợi
duyệt tag — tồn tại **chỉ vì** tag do máy sinh. Người dùng tự đặt tên thì vấn đề
không phát sinh. Xem [mục 11](#11-phụ-lục--những-hướng-đã-cân-nhắc-và-loại-bỏ).

> **Cập nhật 2026-09-08 — owner mở lại AI topic tag với ba tiền đề mới:** (1) nhu cầu
> **một từ nhiều nhóm** mà `collection_id` đơn không phục vụ được; (2) AI sinh sẵn kèm
> lúc capture để user **không phải gõ**; (3) tag vẫn chỉ là bổ trợ — collection giữ vai
> trò trục tổ chức chính, drift tên gọi kiềm bằng việc user sửa được tag ở màn duyệt.
> Thiết kế + DDL ở [rich-vocab-cram-ddl.md](docs/research/review.md).

---

## 4. Feature A — Retain: ôn tập có phạm vi

### 4.1 Ba chế độ, một mệnh đề

```sql
select c.* from cards c
join vocab_items v on v.id = c.vocab_item_id
where c.due_at <= now()
  and (:collection_ids is null or v.collection_id = any(:collection_ids))
```

| Chế độ | Tham số |
|---|---|
| Ôn trong một collection | `collection_ids = [A]` |
| Trộn vài collection | `collection_ids = [A, B]` |
| Ôn tất cả | `collection_ids = null` |

Không join thêm, không bảng phụ, không enum mode. Muốn thêm trục lọc thứ hai
(`cefr`, trạng thái thẻ) thì thêm một mệnh đề `and (:x is null or ...)` cùng hình
dạng — **không cần migration**.

> **Ghi chú ngày 2026-09-07 — mệnh đề trên đủ cho *trục phạm vi*, không đủ cho cả
> hàng đợi.** Giữ nguyên câu SQL và kết luận ở trên, vì cả hai vẫn đúng trong phạm vi
> chúng phát biểu; phần thiếu nằm ở chỗ khác.
>
> Hai FR va nhau: **FR-09** cho thẻ mới `due_at` ngay trong ngày, nên nó *cũng* thoả
> `due_at <= now()`; nhưng **FR-11** chặn thẻ mới ở `daily_new_limit` và **không** chặn
> thẻ đến hạn ôn lại. Hai hạn mức khác nhau trên cùng một điều kiện đến hạn thì không
> nằm được trong một mệnh đề — hàng đợi cần **hai nhánh**, và theo đúng mục 4.4 thì hạn
> mức áp **trước** khi lọc phạm vi.
>
> Phần **vẫn đúng nguyên**: "thêm trục lọc không cần migration". Chỉ con số *một mệnh
> đề* là sai. Hình dạng query cụ thể thuộc solution design doc (PRD mục 13), không chốt
> ở đây. Lý lẽ đầy đủ:
> [review.md mục 6.1](docs/research/review.md#61-một-mệnh-đề-where-không-dựng-nổi-hàng-đợi).
>
> Kèm một chi tiết đã có câu trả lời rõ: *hôm nay đã giới thiệu bao nhiêu thẻ mới rồi?*
> Không cần cột counter — đếm từ `review_logs` những dòng `state_before = 'new'` trong
> ngày. Counter lệch với log là loại bug không quan sát được.

Về mặt truy vấn thì tầm thường. Về mặt hệ quả thì không, và hai mục dưới đây là
lý do.

### 4.2 Lọc hàng đợi có thể phá vỡ hợp đồng của scheduler

FSRS lên lịch dựa trên một giả định ngầm: **card đến hạn thì được ôn trong ngày
đó**. Khoảng cách kế tiếp được tính từ giả định đó. Khi người dùng bật chế độ "chỉ
ôn collection X", toàn bộ card đến hạn của collection Y bị bỏ qua — và nếu thói
quen đó kéo dài vài tuần, Y tích một khoản nợ mà scheduler không biết.

Cần phân biệt hai thứ hay bị gộp làm một:

| | Filtered study | Cram |
|---|---|---|
| Chọn card | Tập con của **card đến hạn** | Card **bất kỳ**, kể cả chưa đến hạn |
| Ghi review log | Có | Có, đánh dấu là cram |
| Cập nhật FSRS state | **Có** | **Không** |
| Rủi ro | Nợ dồn ở phạm vi bị bỏ qua | Không, nếu thực sự không đụng state |

Anki giải bài này bằng đúng cách tách đôi như vậy. Việc Reado cần làm không phải
phát minh, mà là **không vô tình trộn hai chế độ vào một**.

Ba quy tắc rút ra, đề xuất bổ sung vào FR-11:

1. Chế độ có phạm vi vẫn **cập nhật FSRS state bình thường**. Việc lọc chỉ thay
   đổi *tập con nào được ôn hôm nay*, không thay đổi cách chấm điểm.
2. Màn hình ôn có phạm vi phải **hiển thị số card đến hạn nằm ngoài phạm vi**. Nợ
   phải nhìn thấy được. Ẩn nó đi là cách chắc chắn nhất để nó phình ra.
3. Ôn card **chưa** đến hạn là một chế độ riêng, **không** ghi vào FSRS state.

### 4.3 Gom theo nghĩa gây nhiễu, gom theo tình huống thì không

Đây là phát hiện quan trọng nhất của mục 4, và nó đi ngược trực giác sư phạm
thông thường.

Có một dòng nghiên cứu SLA từ những năm 1990 — Tinkham và Waring là hai tên hay
được nhắc — tìm ra rằng học một loạt từ **cùng một nhóm nghĩa** (`shirt`, `pants`,
`socks`, `jacket`) thì **chậm hơn và sai nhiều hơn** so với học cùng số từ không
liên quan gì tới nhau. Cơ chế được cho là **interference**: các item quá giống
nhau về vai trò ngữ nghĩa sẽ cạnh tranh nhau lúc truy xuất, và người học nhớ được
"có một từ chỉ đồ mặc thân trên" nhưng không gọi ra đúng từ nào.

Điều này ngược với gần như mọi giáo trình, vốn luôn chia bài theo topic *Food*,
*Clothes*, *Transport*.

Một phân biệt quan trọng làm dịu kết luận trên:

| Kiểu gom | Định nghĩa | Ví dụ | Tác động |
|---|---|---|---|
| **Semantic set** | Cùng một *loại*, cùng superordinate | `shirt`, `pants`, `socks` | Gây nhiễu |
| **Thematic set** | Cùng một *tình huống*, khác loại | `frog`, `green`, `pond`, `jump` | Có lợi |

Woźniak, đi từ hướng hoàn toàn khác — kinh nghiệm vận hành SuperMemo — cũng cảnh
báo về việc học đồng thời hai item quá giống nhau. Ghi chú này đã nằm ở mục 6.5
của doc card-design. Hai nguồn độc lập, cùng một kết luận.

**Hệ quả, và đây là chỗ nó trở nên rất thực tế:**

1. **Collection là thematic set, nên nó an toàn.** Từ vựng gặp trong cùng một cuốn
   sách hay cùng một mảng công việc thuộc cùng một tình huống, không cùng một
   loại — đúng ô "có lợi" của bảng trên. Reado được lợi thế này **miễn phí**, chỉ
   nhờ việc người dùng gom từ theo bối cảnh đọc.
2. **Rủi ro dồn hết sang Feature B.** Đồng nghĩa và trái nghĩa chính là semantic
   set ở dạng thuần khiết nhất — `resilient`, `robust`, `sturdy`, `tough` là đúng
   điều kiện gây nhiễu, và các cặp `borrow`/`lend` là ví dụ kinh điển về việc học
   cạnh nhau rồi lẫn nhau vĩnh viễn. Mục 5 xử lý chuyện này bằng cách đổi *cách
   đặt câu hỏi*, không phải bằng cách bỏ feature.

**Cảnh báo epistemic:** các nghiên cứu trên được nhắc lại từ trí nhớ, chưa tra bản
gốc. Xem mục 12.

### 4.4 Tương tác với `daily_new_limit`

FR-11 đã có `daily_new_limit` để một buổi capture 25 trang không sinh ra 200 card
đến hạn cùng ngày. Chế độ có phạm vi đặt ra một câu hỏi mới: **giới hạn áp ở đâu?**

Nếu áp **theo từng collection**, người dùng có bốn collection đang hoạt động sẽ
nhận `4 × daily_new_limit` card mới mỗi ngày, và toàn bộ tác dụng bảo vệ biến mất.

Giới hạn phải áp **toàn cục**, trước khi lọc phạm vi. Phạm vi quyết định *card nào*
được chọn trong hạn mức, không nới hạn mức.

---

## 5. Feature B — Expand: quan hệ ngữ nghĩa (R2)

### 5.1 Cạnh từng cặp, không phải node khái niệm

PVO dùng node khái niệm: `resilient` nối vào concept `ADVERSITY`. Reado dùng
**cạnh trực tiếp giữa hai từ**: `resilient ~ robust`.

```sql
word_relations (
  id           uuid primary key,
  item_a       uuid not null references vocab_items(id) on delete cascade,
  item_b       uuid not null references vocab_items(id) on delete cascade,
  relation     text not null
               check (relation in ('synonym','antonym','near','association')),
  proposed_by  text not null check (proposed_by in ('ai','user')),
  confirmed_at timestamptz,        -- null = de xuat, chua duyet
  check (item_a < item_b),         -- quan he doi xung: chuan hoa thu tu
  unique (item_a, item_b, relation)
);
```

Hai ràng buộc cuối là chỗ dễ làm sai nhất. **Cả bốn quan hệ đều đối xứng** —
`resilient ~ robust` và `robust ~ resilient` là cùng một sự thật. Không chuẩn hoá
thứ tự thì cùng một quan hệ lưu được thành hai dòng, `unique` mất tác dụng, và mọi
truy vấn "từ nào liên quan tới X" phải `union` hai cột. Ép `item_a < item_b` lúc
ghi thì một quan hệ đúng một dòng, và truy vấn vẫn phải nhìn cả hai cột nhưng không
còn nguy cơ đếm trùng.

Nếu sau này thêm quan hệ **có hướng** — `type of` của PVO là ví dụ sẵn có — thì
`check` này phải bỏ, và khi đó thứ tự hai cột mang nghĩa. Ghi ra đây để lần sửa đó
là một quyết định có ý thức chứ không phải một dòng bị xoá cho hết lỗi.

`proposed_by` và `confirmed_at` phục vụ vòng lặp "AI đề xuất, người duyệt" ở mục
5.2: đề xuất chưa duyệt là `confirmed_at is null`, và biết ai đề xuất thì mới đo
được chất lượng gợi ý của AI.

Lý do chọn cạnh thay vì node: nhu cầu thực tế được mô tả là *"ôn từ có ngữ nghĩa gần nhau — cùng nghĩa,
trái nghĩa, gần nghĩa"*. Đó là quan hệ **từng cặp**, không phải tư cách thành viên
của một nhóm có tên. Cạnh trực tiếp trả lời đúng câu hỏi đó bằng một bảng.

Đánh đổi phải ghi rõ: **mất khả năng duyệt cây theo tên nhóm** như TREE của PVO.
Không có node `ADVERSITY` thì không có màn hình "xem tất cả từ thuộc nhóm nghịch
cảnh". Cụm từ vẫn hình thành qua việc đi theo các cạnh, nhưng chúng không có tên
và không ổn định. Nếu sau này thấy thiếu, thêm node là việc mở rộng chứ không phải
viết lại — cạnh vẫn còn nguyên giá trị.

### 5.2 Hai chế độ ôn

Trong PVO, người dùng tự nghĩ ra khái niệm và tự nối link, và **đó không phải hạn
chế kỹ thuật mà là phương pháp**: việc dừng lại tự hỏi "cụm này liên quan gì tới
cụm kia" chính là elaborative encoding — nhớ được vì đã phải tự sinh ra mối liên
hệ, chứ không phải vì đã đọc mối liên hệ đó.

Vision của Reado thì đi hướng ngược lại: *"không bắt người dùng gõ lại một chữ
nào"*. Cách né dở nhất là để AI nối hết — khi đó được phần truy xuất, mất phần ghi
nhớ, và cái graph thu về chỉ là một cái index.

Chỗ hoà giải: **AI đề xuất, người duyệt, và chính việc duyệt là buổi ôn.** Hai chế
độ dưới đây là hai nửa của vòng lặp đó.

**Chế độ 1 — Phân biệt.** Đây là nửa *xây* cấu trúc, và cách đặt câu hỏi là toàn
bộ vấn đề.

```
"The city proved remarkably ______ after the flood."

  [ resilient ]   [ robust ]   [ sturdy ]

→ Chọn xong mới hiện vì sao ba từ này khác nhau.
```

So sánh hai cách trình bày cùng một dữ liệu:

| Cách hỏi | Tác dụng |
|---|---|
| *"Ba từ này đều nghĩa là mạnh mẽ, học đi"* | Đúng điều kiện gây nhiễu ở mục 4.3 |
| *"Câu này hợp với từ nào?"* | **Luyện phân biệt** — chính là thứ đưa B2 lên C1 |

Vì thế chế độ này tên là **Phân biệt**, không phải "ôn theo nhóm nghĩa". Tên gọi
quyết định UI đi hướng nào, và hướng thứ hai dẫn thẳng vào cái bẫy.

Ràng buộc bắt buộc: chỉ áp cho **từ đã thuộc**, không dùng để giới thiệu từ mới.
Interference là vấn đề của giai đoạn học ban đầu; với từ đã nắm thì đối chiếu
đúng là thứ có giá trị nhất.

**Chế độ 2 — Gợi nhớ theo nhóm.** Đây là nửa *dùng* cấu trúc.

```
Từ đã thuộc: resilient

Còn nhớ những từ nào liên quan đã lưu không?
[ nghĩ trong đầu, rồi chạm để lật ]

→ withstand · endure · bounce back · robust (gần nghĩa) · fragile (trái nghĩa)
```

Chế độ này chạy theo **chiều ngược** với thẻ FSRS — thẻ thường là `từ → nghĩa`
(receptive), còn đây là `khái niệm → từ` (productive). Nó cho chiều productive mà
**không phải nhân đôi số thẻ**, tức tránh được đúng cái giá GP2 trong doc
card-design đã cảnh báo. Và nó chính là use case thật của PVO: phiên dịch mở cây
lên vì họ *cần một từ*, không phải vì quên nghĩa một từ.

**Cả hai chế độ không đụng FSRS state** — theo đúng quy tắc 3 ở mục 4.2. Chúng vẫn
ghi vào `review_logs`, nhưng với `mode` là `distinguish` hoặc `recall` thay vì
`srs`; chỉ `srs` mới được phép tính lại lịch. Một bảng log chung, một cột phân
biệt, không có bảng riêng nào cả (mục 6.1).

---

## 6. Schema

### 6.1 Năm bảng

```sql
collections (
  id          uuid primary key,
  name        text not null,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);

vocab_items (
  id               uuid primary key,
  collection_id    uuid not null references collections(id),
  term             text not null,
  term_normalized  text not null,
  pos              text not null, -- noun | verb | adj | adv | phrase | ...
  ipa              text,
  meaning_vi       text not null,
  example          text not null, -- cau that tren trang, KHONG phai AI tu nghi
  cefr             text,
  tags             text not null default '[]',  -- JSON array, owner MO LAI 2026-09-08 (xem docs/rich-vocab-cram-ddl.md)
  synonyms         text not null default '[]',  -- JSON array, idem
  antonyms         text not null default '[]',  -- JSON array, idem
  created_at       timestamptz not null default now()
  -- khong co unique: xem 6.3
);
create index on vocab_items (collection_id);    -- loc pham vi, muc 4.1
create index on vocab_items (term_normalized);  -- bo loc trich xuat, muc 6.3

cards (
  id             uuid primary key,
  vocab_item_id  uuid not null references vocab_items(id) on delete cascade,
  direction      text not null default 'receptive'
                 check (direction in ('receptive','productive')),

  -- fsrs state: khop 1:1 voi interface Card cua thu vien fsrs
  state           text not null default 'new'
                  check (state in ('new','learning','review','relearning')),
  stability       real not null default 0,  -- so ngay de R tut ve 90%
  difficulty      real not null default 0,  -- 1..10
  reps            int  not null default 0,
  lapses          int  not null default 0,
  learning_steps  int  not null default 0,  -- chi co nghia khi bat short-term
  scheduled_days  int  not null default 0,  -- interval DA hen lan truoc
  last_review_at  timestamptz,              -- null khi state = 'new'
  due_at          timestamptz not null,

  suspended_at    timestamptz,              -- leech, xem review-scheduling muc 7
  unique (vocab_item_id, direction)
);
create index on cards (due_at) where suspended_at is null;

review_logs (
  id          uuid primary key,
  card_id     uuid not null references cards(id) on delete cascade,
  mode        text not null check (mode in ('srs','cram','distinguish','recall')),
  rating      int  not null check (rating between 1 and 4), -- 1 again .. 4 easy

  -- anh chup TRUOC khi cham, khong phai ket qua sau
  state_before           text not null,
  stability_before       real not null,
  difficulty_before      real not null,
  learning_steps_before  int  not null,
  due_before             timestamptz not null,
  elapsed_days           int  not null,  -- so ngay THUC TE da troi qua
  scheduled_days         int  not null,  -- interval he thong DA hen

  reviewed_at timestamptz not null default now()
);
create index on review_logs (card_id, reviewed_at);

settings (
  id                 int primary key default 1 check (id = 1),
  cefr_level         text not null default 'B2',
  daily_new_limit    int  not null default 10,

  -- nui dieu tiet cua fsrs
  request_retention  real    not null default 0.9
                     check (request_retention between 0.7 and 0.99),
  maximum_interval   int     not null default 36500,
  enable_fuzz        boolean not null default true,
  day_cutoff_hour    int     not null default 4
                     check (day_cutoff_hour between 0 and 23),
  fsrs_params        jsonb,  -- null = dung tham so mac dinh
  fsrs_version       text    -- 'fsrs-6'; null khi fsrs_params null
);
```

Và ở R2, thêm một bảng duy nhất: `word_relations` (mục 5.1).

Hai bảng dễ bị bỏ sót khi đọc lướt:

**`settings` chỉ có đúng một hàng**, và ràng buộc `check (id = 1)` là cách nói
"một người dùng, một kho" thẳng vào schema thay vì để nó thành quy ước ngầm — khớp
NG-05. Nó khởi đầu vì hai giá trị bắt buộc phải có chỗ ở — `daily_new_limit` (mục 4.4)
và `cefr_level` (FR-15) — và giờ giữ thêm các núm điều tiết của FSRS. Trong đó
**`request_retention` là núm quan trọng nhất của cả hệ thống**: nó là thứ duy nhất
đánh đổi trực tiếp giữa "nhớ được bao nhiêu" và "phải ôn bao nhiêu thẻ mỗi ngày".
`fsrs_version` đi kèm `fsrs_params` không phải bookkeeping thừa — FSRS-5 dùng 19 tham
số, FSRS-6 dùng 21, nên lưu một mảng trần rồi nâng thư viện là silent breakage.

**`review_logs.mode` là cột giữ cho FSRS không bị hỏng.** Chỉ `srs` mới cập nhật
FSRS state; ba giá trị còn lại ghi log để thống kê nhưng không đụng lịch. Đây là
quy tắc 3 của mục 4.2 và ràng buộc của hai chế độ R2 (mục 5.2), viết thành một cột.
Ở R1 nó chỉ bao giờ mang giá trị `srs` — cram thuộc R2 — nên nó gần như miễn phí mà
giữ đường mở. Cột này **không** đủ để bảo vệ FSRS: xem bẫy 5 ở mục 7.

**`review_logs` lưu ảnh chụp *trước* khi chấm, không phải kết quả sau.** State sau là
output của hàm FSRS, suy ra được từ ba thứ `(state_before, elapsed_days, rating)`, nên
lưu nó là lưu thừa — và nếu tham số được optimize lại thì output cũ không còn khớp
hàm mới, thành dữ liệu gây nhiễu. Đổi lại, giữ state cũ là điều kiện để có undo.

#### Những field cố ý KHÔNG lưu

Ghi ra để lần sau không ai "phát hiện thiếu" rồi thêm lại:

| Field | Có trong thư viện | Vì sao không lưu |
|---|---|---|
| `cards.elapsed_days` | Có, đã **deprecated** | Giá trị dẫn xuất chỉ đúng đúng ngày review; hôm sau là sai mà không có gì báo. Suy ra từ `now() - last_review_at` |
| `review_logs.last_elapsed_days` | Có, đã **deprecated** | Suy ra được từ dòng log liền trước của cùng `card_id` |
| `cards.retrievability` | Không — thư viện tính khi cần | R là hàm của `stability` và thời gian đã trôi. Lưu nó là lưu một giá trị mục theo từng giờ |

Nguyên tắc chung, và nó giải thích luôn vì sao `review_logs` **được** lưu
`elapsed_days` trong khi `cards` thì không: **trên bảng state hiện tại, không lưu giá
trị sẽ mục; trên bảng log, sự thật đã đóng băng thì lưu được.** Và khi hai chỗ lệch
nhau thì **`reviewed_at` thắng** — `elapsed_days` chỉ là bản sao cho tiện, timestamp
là bản gốc.

Lý lẽ đầy đủ của cả ba dòng nằm ở
[review.md mục 3.3 và 4.1](docs/research/review.md#33-vì-sao-không-lưu-elapsed_days).

### 6.2 Sáu bảng đã chết

| Bảng | Vì sao không còn |
|---|---|
| `books` | Collection thay thế, và xử được cả nguồn báo/web mà `book` không mô tả nổi |
| `pages` | Không lưu bảng trang. Ảnh gốc vẫn cấm (NFR-04); nhu cầu "mở lại trang cũ" giờ phủ bằng `reading_sessions` — 10 phiên gần nhất mỗi collection có tên (Q-10, 2026-09-18) |
| `segments` | Bản song ngữ giờ sống trong **`reading_sessions`** — 10 phiên gần nhất mỗi collection có tên, local, không lên server, không export (Q-10 chốt 2026-09-18, ADR-029) |
| `vocab_occurrences` | Không còn nhiều lần xuất hiện để theo dõi — `example` nằm thẳng trên item |
| `topics` | Collection làm đúng việc đó bằng chủ ý người dùng (mục 3.3) |
| `term_topics` | Cùng lý do |

Mất mát có thật, và cần nói thẳng: **không tra cứu lại được toàn bộ lịch sử đọc.** FR-07 và
FR-13 rời khỏi phạm vi hẳn, và G-03 — mục tiêu "giữ lại toàn bộ lịch sử đọc" — chết
theo. Đổi lại là một mô hình năm bảng và G-04 gần hơn hẳn. (Cập nhật 2026-09-18, Q-10:
đọc lại được **10 phiên gần nhất mỗi collection có tên** — không phải lịch sử đầy đủ;
FR-07/FR-13 vẫn là bia mộ.)

Một chỗ dễ hiểu nhầm, cần chặn trước: **FR-05 và FR-06 không rời phạm vi.** Thứ chết
chỉ là phần *lưu trữ* của chúng. Màn hình đọc song ngữ và bản tóm tắt vẫn còn nguyên
— chúng là toàn bộ JTBD-01, tức nửa comprehend của sản phẩm — chỉ đổi tiền đề từ
*"mở lại một page đã lưu"* sang *"đọc trong phiên hiện tại"*. Cập nhật 2026-09-18
(Q-10): tiền đề đổi thêm lần nữa — đọc lại được **10 phiên gần nhất mỗi collection
có tên**; chỉ kho tạm là "đọc trong phiên" như cũ. Đọc bảng trên rồi kết
luận là bỏ luôn tính năng đọc song ngữ thì mất một nửa lý do Reado tồn tại.

### 6.3 Vì sao không có ràng buộc `unique`

Bản v1 đề xuất `unique (collection_id, term_normalized)`. Bỏ, vì nó nói dối.

Một từ có nhiều nghĩa. Có `unique` thì `run` chỉ được một dòng, nên ba nghĩa của
nó buộc phải nhồi vào một ô `meaning_vi` — đó **chính xác là nội dung Q-07** đang
treo trong PRD. Bỏ ràng buộc đi thì *"một dòng, một nghĩa"* trở thành lời khai
trung thực, và Q-07 tan hẳn mà không cần tầng `senses` nào.

Chống trùng vẫn cần, nhưng nó thuộc về chỗ khác: **bộ lọc lúc trích xuất**, vốn đã
là quyết định đã chốt ở GP1 của doc card-design. Từ nào người dùng đã thuộc — đo
bằng chính FSRS state — thì không trích nữa; nó đã hoàn thành nhiệm vụ. DB thì dễ
dãi, pipeline thì biết điều.

Đây là chỗ đặt đúng, vì **trùng lặp là câu hỏi sư phạm, không phải câu hỏi toàn
vẹn dữ liệu.** Một từ chưa thuộc mà gặp lại lần nữa thì gặp lại là *tốt*; một từ
đã thuộc thì đừng làm phiền nữa. Không ràng buộc `unique` nào diễn đạt được sự
phân biệt ấy.

### 6.4 Giải thích từng field

Cách dễ nhất để nhớ vì sao schema trông như vậy: **nó là hình chiếu của cái thẻ.**
GP1 đã chốt nguyên tắc "kiểm tra tối giản, hiển thị phong phú" — mặt trước ít, mặt
sau nhiều. Các field chia đúng theo hai mặt đó.

Một dòng thật làm mốc:

```
id              7f3a2c1e-...
collection_id   → "Sapiens"
term            "resilient"
term_normalized "resilient"
pos             "adj"
ipa             "/rɪˈzɪliənt/"
meaning_vi      "kiên cường, có sức phục hồi"
example         "The city proved remarkably resilient after the flood."
cefr            "B2"
created_at      2026-09-07T10:14:00Z
```

#### Nhóm định danh

**`id`** — khoá chính, kiểu **uuid** chứ không phải số tự tăng. Lý do cụ thể chứ
không phải theo trào lưu: NFR-03 yêu cầu ôn tập chạy được offline. Với uuid, client
tự sinh id ngay khi chưa có mạng, và lúc đồng bộ không phải đánh số lại. Với số tự
tăng thì phải hỏi server, hoặc cấp id tạm rồi ánh xạ lại — một tầng phức tạp không
đáng.

**`collection_id`** — sau khi cắt `books` và `pages`, **đây là mảnh ngữ cảnh duy
nhất còn sót lại**, và nó gánh hai việc. Một là bộ lọc phạm vi khi ôn. Hai là gợi ý
trí nhớ trên thẻ: nhìn "Sapiens" thì não phải tự dựng lại bối cảnh, và chính nỗ lực
đó làm nhớ lâu hơn — hiện tượng này có tên là **desirable difficulty**, làm khó vừa
đủ thì nhớ bền hơn. Field này **không bao giờ null** vì kho tạm luôn tồn tại.

#### Nhóm mặt trước — phần bị kiểm tra

**`term`** — thứ hiện ở mặt trước. Lưu **đúng dạng đã gặp**, không đưa về nguyên
thể: gặp `weathered the storm` thì lưu vậy, vì dạng thật sự đọc mới là dạng gắn với
ký ức. Q-06 đã chốt (ADR-032, 2026-09-22): không lemmatize — `running` và `run` là hai dòng.

**`term_normalized`** — chữ thường, cắt khoảng trắng thừa. Sau khi bỏ `unique`, nó
**đổi vai từ khoá ràng buộc thành khoá tra cứu**: Gemini trả về 8 từ từ một trang,
app chạy một truy vấn hỏi "trong 8 từ này, cái nào tui thuộc rồi", những từ đó bị
loại. Lưu thành cột riêng thay vì tính `lower(term)` khi cần, để index là index
thường chứ không phải functional index.

**`pos`** — loại từ, và giá trị của nó lớn hơn vẻ ngoài: **đây là công cụ phân biệt
nghĩa rẻ nhất**. `run (v)` là điều hành, `run (n)` là đợt chạy — cùng chuỗi ký tự,
nhưng thấy `(n)` ở mặt trước là biết ngay đang hỏi nghĩa nào. Nó cũng nuốt luôn
field `type` (word/phrase) của thiết kế cũ: `phrase` chỉ là một giá trị nữa của
`pos`, không cần cột riêng. Chính vì gánh việc phân biệt nghĩa nên nó để **`not
null`** — một dòng thiếu `pos` là một dòng không nói được nó đang hỏi nghĩa nào.
Khi AI không xác định nổi thì dùng giá trị thoát hiểm `other`, chứ không để trống.

#### Nhóm mặt sau — phần hỗ trợ, không bị chấm điểm

**`ipa`** — phiên âm. Có thể hỏi tại sao một app đọc lại cần, nhất là khi NG-01 đã
loại pronunciation practice. Lý do: người chỉ đọc mà không bao giờ nghe sẽ **tự
dựng một cách phát âm sai trong đầu**, rồi sau này nghe người bản ngữ nói đúng từ
đó lại không nhận ra. IPA là bảo hiểm rẻ nhất cho chuyện đó — một cột, không audio,
không tính năng luyện tập. Phủ aspect "spoken form" của Nation ở chi phí thấp nhất
mà không vi phạm NG-01.

**`meaning_vi`** — nghĩa tiếng Việt, tức đáp án. Dùng L1 thay vì định nghĩa tiếng
Anh là lựa chọn đúng cho B1–B2: nghĩa tiếng mẹ đẻ vào nhanh hơn và ít sai hơn. Ở
mức C1 thì định nghĩa tiếng Anh bắt đầu có lợi thế riêng, nhưng đó là field của
tương lai. Và như mục 6.3 đã nói — **một dòng một nghĩa** giờ mới thành thật.

**`example`** — câu chứa từ đó. Sau `term` thì đây là field quan trọng nhất bảng,
vì nó **là** nguyên lý 4 của vision viết dưới dạng một cột. Sau khi cắt hết trang
và ảnh, đây là thứ duy nhất còn nối từ vựng với ngôn ngữ thật. Nó cũng là nguyên
liệu bắt buộc cho chế độ Phân biệt ở R2 — không có câu thì không hỏi được "câu này
hợp từ nào".

> **Ràng buộc bắt buộc:** `example` phải là **câu thật trên trang sách**, không
> phải câu AI tự nghĩ ra. Ranh giới giữa authentic input và graded reader nằm đúng
> ở chỗ này (nguyên lý 1 của [vision.md](docs/specs/vision.md)). Đây là ràng buộc cần được
> kiểm ở tầng prompt lẫn tầng review trước khi lưu.

#### Nhóm siêu dữ liệu

**`cefr`** — A2 đến C1. Hai việc: lọc lúc trích xuất để người trình độ C1 không
nhận về từ A2 (FR-15), và lọc lúc ôn về sau. Nói thật thì trình độ CEFR của một từ
khá mơ hồ và do AI gán, nên coi nó là **gợi ý chứ không phải sự thật**. M-03 đang
đo tỷ lệ phải sửa tay — nếu `cefr` sai thường xuyên thì nó là ứng viên số một để
bỏ.

**`created_at`** — không phải bookkeeping thừa. Kho tạm sắp theo thời gian **là**
cơ chế gom từ theo lô: người dùng nhìn thấy "20 từ quét chiều hôm qua", chọn cả
cụm, ném vào một collection. Không có cột này thì kho tạm không dùng được.

---

## 7. Năm cái bẫy

**Bẫy 1 — bán số lượng collection.** Mô hình sai nhưng nghe rất hợp lý: *"collection
là giá trị người dùng nhận được, nên tính tiền theo nó là công bằng."* Nó tạo động
cơ ngược: người dùng nhồi mọi thứ vào hai collection để khỏi trả tiền, cấu trúc tổ
chức nát đi, sản phẩm tệ dần với chính người đang cân nhắc trả tiền. Thêm nữa, một
collection là một dòng trong bảng — nó **không tốn gì**, và người dùng cảm nhận
được điều đó. Mô hình đúng: chi phí biên thật nằm ở **mỗi lần gọi AI phân tích một
trang**, đúng thứ NFR-02 đang muốn đo. Tính tiền theo số trang thì giá bám sát chi
phí, và không ai bị phạt vì tổ chức dữ liệu gọn gàng. NG-06 vẫn giữ nguyên — chưa
làm gì cả — nhưng biết trước trục nào đúng thì tránh được việc thiết kế schema
quanh một trục sẽ phải bỏ.

**Bẫy 2 — coi lọc hàng đợi là chuyện của UI.** Mô hình sai: *"chỉ là thêm mệnh đề
`where`, không ảnh hưởng gì tới thuật toán."* Sai ở hai tầng cùng lúc: nó tạo nợ vô
hình ở phạm vi bị bỏ qua (mục 4.2), và nếu phạm vi là nhóm ngữ nghĩa thì nó còn chủ
động gom những từ **cạnh tranh nhau khi truy xuất** vào cùng một buổi (mục 4.3). Mô
hình đúng: phạm vi là quyết định sư phạm, không phải bộ lọc hiển thị.

**Bẫy 3 — tưởng có cấu trúc là có trí nhớ.** Mô hình sai: *"dựng xong mạng liên kết
thì sẽ nhớ từ tốt hơn."* Giá trị của PVO nằm ở **hành động tự nối link**, không nằm
ở cái graph thu được. Một mạng do AI sinh mà không ai duyệt là một cái index tra
cứu — hữu ích cho việc tìm lại, gần như vô ích cho việc ghi nhớ. Mô hình đúng: cái
đáng thiết kế kỹ không phải cấu trúc dữ liệu mà là **thao tác duyệt** (mục 5.2).

**Bẫy 4 (chỉ liên quan tới R2) — bê nguyên mô hình PVO.** Mô hình sai: *"PVO chạy
nhiều năm nên bộ quan hệ của nó đã được kiểm chứng."* Đúng, nhưng kiểm chứng cho
**phiên dịch đang cần sản sinh câu**. Người đó hỏi *"danh từ chỉ người hay nổi nóng
là gì"* và nhánh `Agent` trả lời đúng câu đó; người đọc sách không bao giờ hỏi câu
ấy. Cái giá rất thật: mỗi đề xuất kèm một quyết định tám lựa chọn thay vì một, và
hàng đợi duyệt từ vui thành cực hình. Cùng logic áp cho node khái niệm và TMRND —
xem [mục 11](#11-phụ-lục--những-hướng-đã-cân-nhắc-và-loại-bỏ).

**Bẫy 5 — tưởng `review_logs.mode` đã xử lý xong vấn đề của R2.** Mô hình sai:
*"loại log non-`srs` khỏi training data là đủ để FSRS không bị hỏng."* Nó bảo vệ được
**số học** của scheduler — không có review giả nào làm bẩn phép hồi quy — nhưng không
xoá được sự thật rằng người dùng **đã truy xuất từ đó**. Trí nhớ tăng lên; FSRS không
biết. Anki chấp nhận cái giá này vì cram là cửa thoát hiểm hiếm dùng; Reado thì không
thể, vì `distinguish` và `recall` là **feature trung tâm của R2**, thiết kế để dùng
thường xuyên. Mô hình đúng: quy tắc "không đụng FSRS state" bảo vệ *phép tính* nhưng
mua sự bảo vệ đó bằng một *sai lệch phép đo* — `stability` bị ước lượng thấp một cách
hệ thống, và vì `stability` cũng là thước đo của FR-10, bộ lọc "đã thuộc" sẽ **bỏ sót**
những từ thực ra đã thuộc rất chắc. Tức một sai lệch ở tầng lịch hiện ra thành thẻ
trùng ở tầng nội dung, và người dùng sẽ quy kết cho AI extraction chứ không cho
scheduler. Ba đường xử lý và lý do chưa chọn đường nào:
[review.md mục 8](docs/research/review.md#8-cái-bẫy--mode-bảo-vệ-số-học-không-bảo-vệ-phép-đo)
(PRD Q-11).

---

## 8. Đã chốt và chưa chốt

### Đã chốt — session sau không cần tranh luận lại

| Quyết định | Cơ sở |
|---|---|
| Collection **thay** `book`, không phải thêm vào | Mục 3.1 |
| Có collection mặc định làm kho tạm; từ trong kho vẫn ôn bình thường | Mục 3.2 |
| `collection_id` không bao giờ null; `collections.is_default` tồn tại vì lý do đó | Mục 3.2 |
| Không dùng topic tag do AI sinh — collection làm tốt hơn và miễn phí | Mục 3.3 |
| Không lưu **ảnh** trang; segment + summary chỉ sống trong `reading_sessions` — 10 phiên gần nhất mỗi collection có tên, kho tạm không lưu | Mục 6.2; Q-10 chốt 2026-09-18 |
| Bản song ngữ + summary giữ trong `reading_sessions`: 10 phiên gần nhất mỗi collection có tên | Mục 6.2; ADR-029 |
| Ba chế độ ôn = một mệnh đề `where`; thêm trục lọc không cần migration | Mục 4.1 |
| Chế độ có phạm vi vẫn cập nhật FSRS state; ôn card chưa đến hạn là chế độ riêng không đụng state | Mục 4.2 |
| Phải hiển thị số card đến hạn nằm ngoài phạm vi đang chọn | Mục 4.2 |
| `daily_new_limit` áp toàn cục, trước khi lọc phạm vi | Mục 4.4 |
| **Không có ràng buộc `unique`**; chống trùng nằm ở bộ lọc trích xuất | Mục 6.3 |
| Q-07 (từ đa nghĩa) **đã giải quyết** nhờ bỏ `unique` | Mục 6.3 |
| `pos` nuốt luôn field `type` (word/phrase), và để `not null` | Mục 6.4 |
| Bảng `settings` một hàng giữ `daily_new_limit` và `cefr_level` | Mục 6.1 |
| `review_logs.mode` phân biệt bốn chế độ; chỉ `srs` cập nhật FSRS state | Mục 6.1 |
| `word_relations` chuẩn hoá `item_a < item_b` vì cả bốn quan hệ đều đối xứng | Mục 5.1 |
| `example` bắt buộc là câu thật trên trang, không phải câu AI tự nghĩ | Mục 6.4 |
| GP3 (`collocations`, `register`, `word_parts`) bị bỏ — `example` đã chứa collocation tự nhiên | Mục 11 |
| Tầng PVO là cạnh từng cặp (`word_relations`), không phải node khái niệm; để R2 | Mục 5.1 |
| Hai chế độ R2 — Phân biệt và Gợi nhớ theo nhóm — không đụng FSRS state | Mục 5.2 |
| Chế độ Phân biệt chỉ áp cho từ đã thuộc | Mục 4.3, 5.2 |
| Monetization theo số trang phân tích, không theo số collection | Bẫy 1 |
| Đổi collection của một từ **không** đụng tới lịch FSRS của thẻ | FR-17 |
| `cards.state` có **bốn** giá trị; `learning` và `relearning` không được gộp | Mục 6.1 |
| `review_logs` lưu ảnh chụp **trước** khi chấm, không phải kết quả sau | Mục 6.1 |
| `elapsed_days` **không** lưu trên `cards` nhưng **có** lưu trên `review_logs`; lệch thì `reviewed_at` thắng | Mục 6.1, "field cố ý không lưu" |
| `settings` giữ `request_retention` (núm quan trọng nhất) và `fsrs_version` đi kèm `fsrs_params` | Mục 6.1 |
| `enable_fuzz` bật; hệ quả là **không** được tính lại `due_at` on the fly | Mục 6.1 |
| Hàng đợi cần **hai nhánh**; số thẻ mới trong ngày đếm từ `review_logs`, không dùng counter | Ghi chú mục 4.1 |

Các quyết định ở tầng thuật toán lịch ôn — chứ không phải tầng cột dữ liệu — nằm ở
[review.md mục 9](docs/research/review.md#9-đã-chốt-và-chưa-chốt). Giữ hai
bảng riêng có chủ ý: bảng này nói *schema trông như vậy vì sao*, bảng kia nói *thuật
toán cần gì*.

### Chưa chốt

Bốn câu đầu (Q-06/Q-08/Q-09/Q-10) đều đã chốt (2026-09-22 / 2026-09-18) — ghi ở
PRD mục 12 bảng *Đã trả lời*.

| Câu hỏi | Ghi chú |
|---|---|
| ~~Buffer cuộn giữ bao nhiêu trang, hết phiên có xoá không~~ | **Chốt 2026-09-18 (Q-10):** 10 phiên gần nhất mỗi collection có tên; kho tạm không lưu; phiên thứ 11 trôi |
| Ai sinh `word_relations` ở R2, và bao lâu một lần | AI đề xuất là chắc, nhưng trigger và chi phí chưa tính. Chưa vào PRD vì thuộc R2 |
| Hai chế độ R2 làm ước lượng thấp `stability` — xử lý thế nào | Bẫy 5. Ảnh hưởng cả FR-10 chứ không riêng tầng lịch. PRD Q-11, mốc: trước khi bật R2 |
| Có bật learning steps trong ngày không | Bật thì một thẻ quay lại trong cùng buổi, nên "còn bao nhiêu thẻ hôm nay" mất tính tất định. PRD Q-12 |
| Ngưỡng `lapses` để coi một thẻ là leech | Ngưỡng của Anki có thể không phù hợp với thẻ do AI sinh — xem PRD FR-19 |

---

## 9. Câu hỏi để nghiên cứu tiếp

Xếp theo mức ảnh hưởng tới thiết kế.

1. **Xác minh dòng nghiên cứu interference.** Tinkham, Waring, và các nghiên cứu
   phản biện sau đó. Ưu tiên số một vì mục 4.3 và 5.2 đang dựa vào nó để định hình
   cả một chế độ ôn.
2. **Bộ lọc "đã thuộc" nên chặt đến đâu.** Lọc quá tay thì bỏ sót nghĩa mới của từ
   cũ; lọc quá lỏng thì thẻ trùng chất đống. Đây là cơ chế chống trùng duy nhất còn
   lại nên nó gánh nhiều hơn vẻ ngoài.
3. **Người dùng có thật sự duyệt đề xuất quan hệ không.** Toàn bộ mục 5.2 dựa trên
   giả định việc duyệt đủ nhẹ để thành thói quen. Nếu sai thì Feature B chết. Rủi
   ro hành vi, không phải kỹ thuật, chỉ đo được bằng cách dùng thật.
4. **Kho tạm có thật sự được dọn không.** Mục 3.2 lập luận rằng nó thoái hoá êm
   nếu không dọn. Cần kiểm chứng bằng hành vi thật, vì nếu 90% từ nằm mãi trong kho
   thì chế độ ôn theo phạm vi mất phần lớn giá trị.
5. **Đơn vị lưu là câu hay là từ.** PVO chọn câu; Lexical Approach của Michael Lewis
   ủng hộ lựa chọn đó. Doc card-design đã ghi nhận câu hỏi này ở mục 6.3. Giờ đã có
   một hệ thống thật chạy nhiều năm theo hướng đó để khảo sát.
6. **Frequency band** (mục 6.2 doc card-design) tương tác thế nào với collection?
   Từ tần suất cao có nên được ưu tiên bất kể nằm ở collection nào không?
7. **Có nên khôi phục node khái niệm ở R3.** Mục 5.1 đánh đổi mất khả năng duyệt
   theo tên nhóm. Cần biết người dùng có thấy thiếu không trước khi thêm.
8. **Độ lớn của sai lệch ở bẫy 5.** Cơ chế thì rõ, nhưng chưa ai đo được R2 làm
   `stability` lệch bao nhiêu — có thể nhỏ tới mức không đáng làm gì. Câu hỏi này chặn
   đường Q-11, và nó chỉ trả lời được bằng dữ liệu dùng thật. Bốn câu hỏi khác ở tầng
   lịch nằm ở
   [review.md mục 9](docs/research/review.md#câu-hỏi-để-nghiên-cứu-tiếp).

---

## 10. Đã áp dụng vào tài liệu nào

Toàn bộ bảng dưới **đã được áp dụng** vào `prd.md` v0.3 và `vision.md` ngày
2026-09-07. Giữ lại làm bảng đối chiếu: nếu một chỗ trong PRD đọc thấy lạ, cột phải
nói vì sao nó thành ra như vậy.

> **PRD v0.4** (cùng ngày) đến từ [review.md](docs/research/review.md), không
> từ tài liệu này. Phần tài liệu này góp vào v0.4 là DDL ở mục 6.1, bẫy 5 ở mục 7, và
> ghi chú mục 4.1. Bảng đối chiếu v0.3 → v0.4 nằm ở
> [review.md mục 9](docs/research/review.md#đã-áp-dụng-vào-đâu).

### `prd.md` — từ v0.2 lên v0.3

| Mục | Thay đổi |
|---|---|
| G-03 | **Chết** — "giữ lại toàn bộ lịch sử đọc" không còn là mục tiêu. Thay bằng mục tiêu tổ chức từ vựng theo collection |
| NG-07 | Giữ nguyên non-goal, đổi lý do: không phải vì "nguồn là sách giấy" mà vì giữ đúng một input path |
| Mục 6 — Journey | Node lưu trữ chỉ còn vocab + collection; thêm nhánh buffer cuộn là ngõ cụt có chủ ý |
| FR-01 | Gán page vào `book` → gán vào **collection**; thêm luồng tạo collection và rơi vào kho tạm |
| FR-02 | Bỏ `type`, thêm `pos`; `segments` và `summary_vi` đánh dấu rõ là không lưu; thêm criterion buộc `example` là câu thật |
| FR-03 | Bỏ phần sửa `translation_vi` — sửa thứ không được lưu là công cốc |
| FR-05, FR-06 | **Giữ tính năng, bỏ lưu trữ** — đổi tiền đề từ "page đã lưu" sang "phiên đọc hiện tại", dựa trên buffer cuộn local |
| FR-07 | **Bỏ**, để bia mộ tại chỗ. Thay bằng FR-17 |
| FR-08 | Lọc theo collection thay vì theo sách; thêm criterion không gộp các dòng cùng `term` khác nghĩa |
| FR-10 | Viết lại hoàn toàn: bỏ dedupe theo `term_normalized`, chuyển sang bộ lọc "đã thuộc" lúc trích xuất |
| FR-11 | Thêm criterion `daily_new_limit` áp toàn cục, trước khi lọc phạm vi |
| FR-12 | Mặt trước thêm `pos`; mặt sau thêm tên collection |
| FR-13 | **Bỏ**, để bia mộ tại chỗ. Ngữ cảnh đã nằm trên thẻ ở FR-12 |
| FR-15 | Thêm `daily_new_limit` vào settings; trỏ tới bảng `settings` một hàng |
| FR-16 | Export theo collection; bỏ phần export page + segment |
| **FR-17 (mới)** | Collection Management — gồm criterion chốt rằng đổi collection không đụng lịch FSRS |
| **FR-18 (mới)** | Scoped Review — ba chế độ ở mục 4.1 và ba quy tắc ở mục 4.2 |
| NFR-03 | Ghi rõ buffer cuộn là local nên không cản offline; R2 phải tải sẵn được đề xuất quan hệ |
| NFR-04 | Từ rủi ro mở thành **ràng buộc đã thoả bằng thiết kế** — không ảnh, không toàn văn trang |
| M-08 (mới) | Tỷ lệ từ được dọn khỏi kho tạm, ngưỡng ≥ 50% sau 4 tuần |
| A-07, A-08 (mới) | Giả định người dùng chịu tạo collection, và giả định không cần đọc lại trang |
| Q-04, Q-05, Q-07 | Chuyển sang bảng **đã trả lời** |
| Q-08, Q-09, Q-10 (mới) | Ngưỡng "đã thuộc"; bộ lọc theo collection hay toàn cục; kích thước buffer |
| Mục 10 — Release scope | Collection, FR-17, FR-18 vào R1; `word_relations` và hai chế độ ôn vào R2 |

### `vision.md`

| Nguyên lý | Thay đổi |
|---|---|
| 1 — Authentic Input | Nguồn không chỉ là sách giấy; thêm báo mạng và tài liệu chuyên ngành |
| 4 — Context Is The Memory Anchor | Bỏ `tên sách + số trang`, nâng phát biểu lên mức "thẻ phải có chỗ bám"; collection là cách hiện thực hiện tại |
| 5 — Durable Data | **Thu hẹp phạm vi có ghi nhận** — nguyên lý giờ chỉ áp cho từ vựng, không áp cho artefact đọc. Cái giá được viết thẳng ra thay vì để trôi |

---

## 11. Phụ lục — những hướng đã cân nhắc và loại bỏ

Bản v1 của tài liệu này (viết cùng ngày, trước khi mô hình collection thành hình)
đề xuất một kiến trúc khác hẳn. Giữ lại đây để chuỗi lý do còn truy được, và để
session sau không đề xuất lại từ đầu.

| Hướng đã bỏ | Nó là gì | Vì sao bỏ | Điều kiện để xem lại |
|---|---|---|---|
| **Topic tag do AI sinh** | Xin Gemini 1–3 tag mỗi từ tại FR-02, dùng để ôn theo chủ đề | Collection làm đúng việc đó bằng chủ ý người dùng, miễn phí, không drift | ~~Nếu người dùng không chịu tạo collection và 90% từ nằm trong kho tạm~~ → **MỞ LẠI 2026-09-08 bởi owner** với tiền đề khác hẳn: 1 từ nhiều chủ đề + AI sinh sẵn kèm capture + user sửa được — xem [rich-vocab-cram-ddl.md](docs/research/review.md) |
| **Controlled vocabulary + near-duplicate check** | Namespace append-only, embedding cosine để chặn tag đồng nghĩa | Chỉ cần thiết khi tên nhóm do máy đặt. Người dùng tự đặt thì không phát sinh | Nếu quay lại tag do AI sinh |
| **Pipeline linking hai tầng** | Embedding kNN sinh ứng viên, LLM phân xử trên shortlist, `link_proposals` + `link_runs` | Xây cho việc gán concept hàng loạt. Quan hệ từng cặp ở R2 đơn giản hơn nhiều | Nếu R2 cho thấy đề xuất quan hệ cần chạy ở quy mô lớn |
| **Node khái niệm kiểu PVO** | Bảng `concepts` + `concept_edges` với `Association` / `Type of` | Nhu cầu thật là quan hệ từng cặp. Node là tầng gián tiếp không ai yêu cầu | Nếu thiếu màn hình duyệt theo tên nhóm (câu hỏi 9.7) |
| **Bộ tám semantic role của PVO** | `Agent`, `Patient`, `Action`, `Nominal`... | Phục vụ production cho phiên dịch; nhân số quyết định lên tám lần | Nếu Reado mở sang hỗ trợ viết |
| **TMRND** | Tone / Mode / Register / Nuance / Dialect trên mỗi mục | Năm cột cho một app đọc là quá nặng; `example` mang phần lớn thông tin đó ngầm | Nếu chuyển sang production |
| **`vocab_occurrences`** | Bảng riêng cho từng lần gặp một từ, kèm sách và số trang | Không lưu trang nữa; `example` nằm thẳng trên item | Nếu quay lại lưu lịch sử đọc — **2026-09-18 đã mở lại một phần (Q-10: 10 phiên/named collection)** |
| **`unique (collection_id, term_normalized)`** | Chống trùng ở tầng DB | Một từ nhiều nghĩa; ràng buộc này ép nói dối và giữ Q-07 sống | Nếu bộ lọc "đã thuộc" tỏ ra không đủ và thẻ trùng chất đống |
| **GP3 — `collocations`, `register`, `word_parts`** | Ba cột phủ nhóm Use của Nation, đã chốt R1 ở doc card-design | `example` đã chứa collocation một cách tự nhiên: câu *"proved remarkably resilient"* cho thấy cách dùng mà không cần cột riêng | Nếu M-03 hoặc trải nghiệm thật cho thấy người dùng vẫn dùng sai collocation |
| **Bảng lưu text trang kiểu bảo hiểm** | Ghi một lần, không UI, không truy vấn, phòng khi sau này cần | Toàn văn trang sách là bề mặt bản quyền lớn hơn hẳn một câu trích, và buffer cuộn đã phủ nhu cầu thực tế | Nếu xuất hiện nhu cầu đọc lại có thật — **đã xuất hiện 2026-09-18**: Q-10 chốt giữ hẹp 10 phiên/named collection, không phải bảng write-only này |

---

## 12. Nguồn

### Đã đọc trực tiếp

| Nguồn | Đường dẫn |
|---|---|
| Hồ Lê Vũ, *Hướng dẫn sử dụng PVO - phiên bản web-based* | https://vuenglishclass.blogspot.com/2021/09/phac-thao-cau-truc-pvo-moi.html |
| Bản distill của bài trên | [ref/pvo/pvo-2022-model.md](../../ref/pvo/pvo-2022-model.md) |
| Tài liệu nội bộ Reado | [vision.md](docs/specs/vision.md), [prd.md](docs/specs/prd.md), [vocabulary.md](docs/research/vocabulary.md) |

### Nhắc lại từ trí nhớ — CHƯA kiểm chứng

Những nguồn dưới đây được viện dẫn nhưng **chưa tra bản gốc**. Đừng coi các phát
biểu gắn với chúng là đã xác minh. Session sau nếu cần dựa vào chúng để chốt thiết
kế thì phải tra trước.

| Nguồn | Được dẫn để chứng minh điều gì | Dùng ở mục |
|---|---|---|
| Tinkham (1993, 1997) | Học từ cùng semantic set gây interference, chậm hơn nhóm không liên quan | 4.3, 5.2 |
| Waring (1997) | Kết quả tương tự, độc lập | 4.3 |
| Phân biệt semantic set và thematic set | Gom theo tình huống có lợi, gom theo loại thì hại | 3.3, 4.3 |
| Desirable difficulty | Làm khó vừa đủ lúc truy xuất thì nhớ bền hơn | 6.4 |
| Collins & Loftus (1975), spreading activation | Mental lexicon tổ chức theo liên tưởng, không theo alphabet | 1 |
| Paul Meara, *Connected Words* (2009) | Mạng lưới từ vựng L2 và cách nó thay đổi theo trình độ | 1 |
| Hành vi filtered deck của Anki | Có chế độ ôn lại không làm thay đổi lịch | 4.2 |
| Ưu thế của L1 gloss ở trình độ trung cấp | Nghĩa tiếng mẹ đẻ vào nhanh và ít sai hơn định nghĩa L2 | 6.4 |

**Một lưu ý epistemic về chính PVO.** PVO là **practitioner artifact** — sản phẩm
của một người dạy tiếng có kinh nghiệm, dùng thật trong lớp nhiều năm. Đó là bằng
chứng mạnh về **tính khả thi và tính hữu dụng trong thực hành**, nhưng **không**
phải bằng chứng về hiệu quả đã qua đối chứng. Không có nhóm control, không có số
liệu công bố. Vay mượn cấu trúc của nó là hợp lý; viện dẫn nó như bằng chứng khoa
học thì không.

## Phần 2 — Cấu trúc từ vựng cho spaced repetition — nghiên cứu nền

| Field | Value |
|---|---|
| Status | Draft, mở cho nghiên cứu tiếp |
| Created | 2026-09-07 |
| Last updated | 2026-09-07 |
| Related | [prd.md](docs/specs/prd.md), [vision.md](docs/specs/vision.md), [vocabulary.md](docs/research/vocabulary.md), [review.md](docs/research/review.md) |
| Phạm vi | Trả lời câu hỏi: một vocabulary card nên chứa gì, và cấu trúc nào giữ được từ lâu nhất |

**Tài liệu này tự chứa.** Nó được viết để một session mới, không có bối cảnh gì
về cuộc thảo luận sinh ra nó, vẫn đọc và tiếp tục được.

> **Cảnh báo trước khi đọc.** Sau khi mô hình dữ liệu chuyển sang **collection**
> (2026-09-07), ba quyết định trong tài liệu này đã chết: **GP3** ở mục 3, và hai
> dòng về `vocab_occurrences` trong bảng "Đã chốt" ở mục 5. Chúng được giữ lại và
> gạch ngang thay vì xoá, để chuỗi lý do còn truy được. GP1, GP2 và bộ lọc 1T vẫn
> còn hiệu lực. Mô hình hiện hành nằm ở
> [vocabulary.md](docs/research/vocabulary.md).

---

## 1. Ba truyền thống, và tại sao chúng mâu thuẫn nhau

Câu hỏi "một thẻ từ vựng nên chứa gì" có ba nguồn trả lời độc lập, và chúng đưa
ra ba câu trả lời khác nhau. Hiểu vì sao chúng khác nhau quan trọng hơn việc
chọn một bên.

### 1.1 Truyền thống học thuật — Paul Nation

Đây là khung được trích dẫn nhiều nhất trong second language acquisition. Nation
phân "biết một từ" thành **9 aspect** trong 3 nhóm, và mỗi aspect lại chia thành
**receptive** (hiểu khi gặp) và **productive** (dùng được khi cần):

| Nhóm | Ba aspect |
|---|---|
| **Form** | spoken form, written form, word parts |
| **Meaning** | form–meaning connection, concepts & referents, associations |
| **Use** | grammatical functions, collocations, constraints on use (register, tần suất) |

Hai điểm quan trọng của khung này:

- Việc học là **tăng dần** (incremental): form được nắm trước, rồi meaning, sau
  cùng mới tới use.
- Receptive và productive là **hai loại kiến thức khác nhau**, không suy ra được
  từ nhau. Nhận ra `resilient` khi đọc không có nghĩa là gọi ra được nó khi viết.

Nation cũng đưa ra khái niệm **learning burden**: mỗi từ cần học những gì, và
phần nào suy ra được từ kiến thức đã có.

### 1.2 Truyền thống cộng đồng — sentence mining

Từ cộng đồng tự học tiếng Nhật (Refold, AJATT, animecards), nay lan sang mọi
ngôn ngữ. Nguyên tắc trung tâm là **1T card** (one target):

> Chỉ tạo thẻ từ câu mà bạn hiểu mọi thứ trừ đúng **một** item. Câu có bốn từ lạ
> thì bỏ qua.

Lý do: nếu câu có nhiều chỗ không hiểu, bạn không biết mình đang fail vì cái gì,
và việc chấm điểm trở nên vô nghĩa.

Trong cộng đồng này có tranh luận nội bộ về mặt trước của thẻ:

| | Sentence card | Word card ("anime card") |
|---|---|---|
| Mặt trước | Cả câu chứa từ đích | Từ đích đứng một mình |
| Ngữ cảnh | Có ngay trên mặt trước | Ở mặt sau, dùng khi fail |
| Thời gian tạo | Cao hơn | Thấp hơn |
| Quyết định khi review | Phức tạp (phải xét hiểu cả câu) | Đơn giản (biết / không biết) |
| Giai đoạn phù hợp | Intermediate trở lên | Nền tảng, từ tần suất cao |

animecards.site lập luận word card vượt trội vì nó **kiểm tra ít thông tin hơn**,
nên quyết định "biết hay không" dễ hơn; não vốn nhận diện từ ngoài ngữ cảnh tốt,
và câu gốc chỉ cần có mặt để nhắc lại khi fail. AJATT gọi biến thể này là
**targeted sentence card** và kết luận nó *"lấy tốc độ của word card kết hợp
hiệu quả của việc học trong ngữ cảnh"*.

Một điểm cộng đồng này thống nhất: **cloze deletion không phù hợp cho học ngôn
ngữ**, vì bạn sẽ nhớ đúng cái chỗ trống trong đúng câu đó chứ không nội hoá được
ngôn ngữ.

### 1.3 Truyền thống SRS — Piotr Woźniak, SuperMemo

**Minimum information principle**: item phải đơn giản nhất có thể. Lý do không
phải cho tiện, mà là cơ chế trí nhớ:

- Memory phức tạp được kích hoạt **không trọn vẹn** hoặc theo thứ tự khác nhau
  tuỳ ngữ cảnh, nên mỗi lần review không tạo được mức tăng stability đều đặn.
- Item ghép buộc bạn phải ôn cả cụm theo nhịp của **sub-item khó nhất**. Tách ra
  thì mỗi phần được lên lịch theo nhịp riêng của nó, tiết kiệm thời gian dù số
  item tăng.

Nghịch lý cần lưu ý: Woźniak **khuyến nghị cloze deletion** rất mạnh — nó là một
trong 20 rules và là hạt nhân của incremental reading. Điều này trái ngược trực
tiếp với kết luận của cộng đồng học ngôn ngữ ở mục 1.2.

---

## 2. Nguyên tắc hoà giải — kết luận trung tâm

Bề mặt thì ba truyền thống xung đột: Nation nói một từ có 9 chiều kiến thức,
Woźniak nói thẻ phải tối giản, cộng đồng nói phải có ngữ cảnh câu.

Chỗ hoà giải nằm trong chính văn bản của Woźniak: nội dung dư thừa trên thẻ
**được phép**, miễn nó *không thuộc phần bị kiểm tra*. Nguyên văn ý đó là
redundant content phải "không compulsory và không cần cho việc chấm điểm".

> **Nguyên tắc:** phần **bị kiểm tra** phải tối giản. Phần **được hiển thị** có
> thể phong phú tuỳ ý.
>
> Dùng Nation để quyết định **lưu gì trong database**.
> Dùng Woźniak để quyết định **kiểm tra gì trên một thẻ**.
> Lưu 9 aspect, kiểm tra một.

Toàn bộ mục 3 là hệ quả của nguyên tắc này.

---

## 3. Ba giải pháp

### GP1 — Targeted word card (nên làm ở R1)

```
MẶT TRƯỚC   resilient
            (chỉ có vậy — đây là phần bị kiểm tra)

MẶT SAU     /rɪˈzɪliənt/  ·  kiên cường, có sức phục hồi
            ─────────────────────────────────────────
            "The city proved remarkably resilient after the flood."
            — collection: Sapiens
            (phần hỗ trợ, không bị chấm điểm)
```

**Cơ sở:** animecards.site và AJATT (mục 1.2), cộng nguyên tắc hoà giải ở mục 2.

**Tác động lên schema:** gần như **không có**. Bảng `vocab_items` chia đúng theo hai
mặt của thẻ — `term` và `pos` ở mặt trước; `meaning_vi`, `ipa`, `example` và tên
collection ở mặt sau. Xem
[vocabulary.md mục 6.4](docs/research/vocabulary.md#64-giải-thích-từng-field).

> **Sửa ngày 2026-09-07.** Đoạn này trước đây mô tả việc tách `vocab_terms` khỏi
> `vocab_occurrences`, và denormalize `book_title` + `page_number` vào occurrence.
> Cả hai đã chết cùng quyết định không lưu trang — xem bảng "Đã chốt" ở mục 5.

**Phần cần thêm — bộ lọc 1T, và đây là lợi thế riêng của Reado.** Nguyên tắc 1T
đòi hỏi biết từ nào người học *đã* biết. Ứng dụng thông thường không biết nên
phải dùng CEFR level làm proxy (đúng như FR-15 đang làm). Nhưng Reado tích luỹ
bảng `vocab_items` **cùng với lịch FSRS của từng thẻ**, tức biết được không chỉ từ
nào đã *gặp* mà từ nào đã *thuộc*. Lọc kết quả extraction theo đó là một câu SQL,
**không tốn thêm một token AI nào**.

Phân biệt "đã gặp" và "đã thuộc" là chỗ quyết định, và FR-10 chốt ở vế sau: ngưỡng
lọc đo bằng FSRS stability, không phải bằng sự tồn tại của một dòng. Từ đã gặp mà
chưa thuộc thì **nên** được đề xuất lại; chỉ từ đã hoàn thành nhiệm vụ mới bị bỏ
qua. Ngưỡng cụ thể là câu hỏi còn treo (PRD Q-08).

FR-15 lọc theo trình độ chung; bộ lọc này lọc theo vốn từ cá nhân. Cái sau tốt
hơn hẳn, và dữ liệu đã có sẵn.

### GP2 — Hai chiều receptive / productive (schema ở R1, feature ở R2)

Một term sinh ra hai card:

| Chiều | Mặt trước | Kiểm tra |
|---|---|---|
| Receptive | `resilient` | Nhận diện — phục vụ việc đọc |
| Productive | `kiên cường, có sức phục hồi` | Tái tạo — phục vụ nói và viết |

**Cơ sở:** cột sống của khung Nation (mục 1.1). Anki tách Note khỏi Card đúng vì
lý do này.

**Đánh đổi:** nhân đôi khối lượng ôn mỗi ngày. Cộng dồn với vấn đề giới hạn thẻ
mới (xem mục 5), đây là rủi ro thật.

**Tác động lên schema — cần sửa:** bản DDL đã bàn có

```sql
vocab_item_id uuid not null unique references vocab_items(id)
```

Cái `unique` đó chặn đường GP2. Nên đổi thành:

```sql
direction text not null default 'receptive'
  check (direction in ('receptive','productive')),
unique (vocab_item_id, direction)
```

Làm bây giờ gần như miễn phí; đổi unique constraint khi đã có dữ liệu và lịch ôn
thì là migration khó chịu. **Đề xuất: schema hỗ trợ ngay, R1 chỉ sinh thẻ
`receptive`** — vì mục tiêu của Reado là đọc sách.

### GP3 — Phủ nhóm Use của Nation (SUPERSEDED — không làm)

> **Đã bị loại bỏ ngày 2026-09-07.** Ba cột `collocations`, `register`,
> `word_parts` **không được đưa vào schema**. Lý do: `example` đã chứa collocation
> một cách tự nhiên — câu *"proved remarkably resilient"* cho thấy cách dùng mà
> không cần cột riêng, trong khi ba cột kia làm nặng cả prompt lẫn màn hình duyệt.
> Phần dưới giữ nguyên để chuỗi lý do còn truy được. Xem
> [vocabulary.md mục 11](docs/research/vocabulary.md#11-phụ-lục--những-hướng-đã-cân-nhắc-và-loại-bỏ)
> để biết điều kiện xem lại quyết định này.

Đây là khoảng trống lớn nhất trong schema hiện tại. Cặp `resilient = kiên cường`
chỉ phủ được một aspect duy nhất: form–meaning connection. Nó không cho biết
người ta nói *resilient economy*, *resilient system*, *resilient child* — nhưng
không nói *resilient food*. Đó là **collocations**, và với người học C1 thì
collocation chính là ranh giới giữa "đúng ngữ pháp" và "nghe như người bản ngữ".

```sql
alter table vocab_terms
  add column collocations text[],   -- ['resilient economy','prove resilient']
  add column register     text,     -- 'formal' | 'neutral' | 'informal' | 'literary'
  add column word_parts   text;     -- 're- + salire (nhay lai)'
```

Ba trường này Gemini trích được **trong cùng một lần gọi**, không thêm request —
chỉ tốn thêm ít output token.

**Lợi ích phụ:** nó giải quyết phần lớn vấn đề từ đa nghĩa (Q-07). Khi term mang
theo collocation của nó, `run` trong ngữ cảnh kinh doanh và `run` trong ngữ cảnh
chạy bộ tự phân biệt, không cần tách thành hai row.

> **Lập luận này đã bị vượt qua.** Q-07 được giải bằng cách rẻ hơn nhiều: **bỏ hẳn
> ràng buộc `unique`**, để `run` ở hai ngữ cảnh thành hai dòng riêng, mỗi dòng một
> nghĩa. Không cần collocation để phân biệt, và cũng không cần "không tách thành
> hai row" — tách ra mới là đúng.

`word_parts` phục vụ aspect thứ ba của nhóm Form, và với người học trình độ cao
nó có đòn bẩy lớn: hiểu `re-` và `-ent` giúp suy ra hàng trăm từ chưa gặp.

### So sánh

| | GP1 | GP2 | GP3 |
|---|---|---|---|
| Nền tảng | Cộng đồng + Woźniak | Nation (receptive/productive) | Nation (nhóm Use) |
| Aspect phủ được | Form + Meaning | Nhân đôi mọi aspect | Thêm Use + word parts |
| Thay đổi schema | Không | Một cột `direction` | Ba cột |
| Chi phí AI thêm | Không | Không | Nhỏ |
| Chi phí ôn tập | Thấp | **Gấp đôi** | Không đổi |
| Nên làm ở | **R1** | Schema R1, feature R2 | ~~R1~~ → **không làm** |

---

## 4. Ba cái bẫy

**Bẫy 1 — tưởng format thẻ là thứ quyết định.** Bài review nghiên cứu của
mikeydoes nói thẳng, và nó ngược với giọng điệu sôi nổi của cộng đồng: *"việc
item được ôn là từ hay câu là thứ yếu so với việc nó được ôn ở đúng khoảng thời
gian. SRS làm phần lớn công việc nặng bất kể format thẻ."* Reado đã dùng FSRS,
tức đã có phần chiếm phần lớn hiệu quả. Đừng để R1 chết vì tranh luận format.

**Bẫy 2 — dùng cloze deletion vì Woźniak khen nó.** Woźniak khuyến nghị cloze
cho kiến thức tổng quát. Cộng đồng học ngôn ngữ phản đối nó, với lý do cụ thể là
bạn nhớ cái chỗ trống chứ không nội hoá ngôn ngữ. Hai lĩnh vực, hai kết luận
trái nhau. Bẫy này dễ sập vì đọc 20 rules của Woźniak là con đường tự nhiên của
một engineer.

**Bẫy 3 — lấy 9 aspect của Nation làm đặc tả cho một thẻ.** Khung Nation mô tả
việc *biết một từ bao hàm những gì* — nó là bản đồ tri thức, không phải bản
thiết kế thẻ. Nhồi cả 9 aspect vào một mặt thẻ vi phạm trực diện minimum
information principle, và tạo ra những thẻ không học được: mỗi lần review kích
hoạt một phần khác nhau, stability không bao giờ tăng đều.

---

## 5. Đã chốt và chưa chốt

### Đã chốt — session sau không cần tranh luận lại

| Quyết định | Cơ sở | Tình trạng |
|---|---|---|
| Nguyên tắc "kiểm tra tối giản, hiển thị phong phú" | Mục 2 | Còn hiệu lực |
| GP1 làm ở R1; mặt trước chỉ có term | Mục 3, GP1 | Còn hiệu lực |
| Bộ lọc 1T đối chiếu vốn từ đã có, không tốn token AI | Mục 3, GP1 | Còn hiệu lực, và **quan trọng hơn trước** — xem ghi chú dưới |
| Tách `cards` khỏi bảng từ vựng | FR-09 cho phép một mục không trở thành thẻ | Còn hiệu lực |
| Không tự viết SRS algorithm; dùng `ts-fsrs` | NG-09 | Còn hiệu lực |
| Không dùng cloze deletion | Mục 1.2, mục 4 bẫy 2 | Còn hiệu lực |
| ~~Tách `vocab_terms` khỏi `vocab_occurrences`~~ | ~~FR-10 cần dedupe với nhiều câu gốc~~ | **Chết** — không còn bảng occurrence |
| ~~Denormalize câu gốc vào occurrence~~ | ~~NFR-04 + NFR-06~~ | **Chết** — `example` nằm thẳng trên item |
| ~~GP3 làm ở R1~~ | ~~Mục 3, GP3~~ | **Chết** — xem ghi chú ở GP3 |

Ba dòng gạch ngang bị loại bỏ ngày 2026-09-07 khi mô hình chuyển sang **collection**:
trang sách không còn được lưu, nên `vocab_occurrences` không còn lý do tồn tại và
câu gốc chuyển thẳng lên bảng từ vựng. Chi tiết ở
[vocabulary.md mục 6](docs/research/vocabulary.md#6-schema).

**Vì sao bộ lọc 1T quan trọng hơn trước:** ràng buộc `unique` ở tầng DB cũng đã bị
bỏ (một từ nhiều nghĩa thì phải được nhiều dòng). Bộ lọc 1T giờ là **cơ chế chống
trùng duy nhất còn lại** — từ nào người dùng đã thuộc thì không trích nữa.

### Chưa chốt

| Câu hỏi | Ghi chú |
|---|---|
| Thời điểm mở thẻ productive | GP2 để schema sẵn, chưa quyết khi nào bật. Lưu ý: chế độ "Gợi nhớ theo nhóm" ở R2 cho chiều productive mà không nhân đôi số thẻ |
| Giới hạn thẻ mới mỗi ngày là bao nhiêu | Schema đặt `daily_new_limit` mặc định 10, chưa kiểm chứng |

### Đã giải quyết

| Câu hỏi | Lời giải |
|---|---|
| **Q-07 — từ đa nghĩa** | Bỏ ràng buộc `unique` ở tầng DB. Mỗi nghĩa là một dòng riêng, nên "một dòng một nghĩa" thành lời khai trung thực và không cần tầng `senses`. Xem [vocabulary.md mục 6.3](docs/research/vocabulary.md#63-vì-sao-không-có-ràng-buộc-unique) |
| **Q-06 — lemmatize** | **Không lemmatize** — mỗi word form một dòng (`running` ≠ `run`, `took` ≠ `take`). Chốt 2026-09-22 |
| **Q-08 — ngưỡng "đã thuộc"** | **FSRS `stability ≥ 21 ngày`** (= Anki "mature", interval ≥ 21 ngày). Chốt 2026-09-22; không đo bằng số lần gặp |
| **Q-09 — phạm vi so khớp** | **Theo collection**, không toàn cục — nghĩa mới của từ cũ vẫn thêm khi sang sách khác; từ trùng giữa collection chấp nhận (user thấy dễ thì bấm Easy). Chốt 2026-09-22 |

---

## 6. Câu hỏi để nghiên cứu tiếp

Hạt giống cho session sau. Xếp theo mức độ ảnh hưởng tới schema.

1. **Word family và lemmatization theo Nation.** Q-06 đã chốt: không lemmatize, mỗi word form một dòng. Câu nghiên cứu còn lại (gộp word family) không mở lại Q-06; nếu làm thì là quyết định mới, không phải task R1.
2. **Frequency band.** Nation có các danh sách theo tần suất (2000/3000 từ đầu
   tiên), và có BNC/COCA. Reado có nên dùng tần suất để ưu tiên thẻ nào học
   trước, thay vì chỉ dựa vào thứ tự gặp trong sách?
3. **Lexical Approach của Michael Lewis.** Lập luận rằng đơn vị học nên là chunk
   / lexical phrase chứ không phải từ đơn. Nếu đúng thì `phrase` nên là giá trị
   mặc định của `pos`, không phải ngoại lệ. Đáng chú ý: PVO đã đóng cứng lựa chọn
   này vào schema — nó không có bảng `terms` nào cả, đơn vị lưu là nguyên câu.
4. ~~**Xử lý từ đa nghĩa (polysemy) trong tài liệu SLA.**~~ **Đã giải quyết** bằng
   việc bỏ ràng buộc `unique` — mỗi nghĩa một dòng. Câu hỏi lý thuyết vẫn còn giá
   trị nếu sau này cần gộp nghĩa, nhưng không còn chặn đường thiết kế nào.
5. **Nhiễu giữa các từ gần giống nhau (interference).** Woźniak cảnh báo về việc
   học hai item tương tự cùng lúc. **Đã có tiến triển:** dòng nghiên cứu
   Tinkham / Waring về semantic set và thematic set được tóm tắt ở
   [vocabulary.md mục 4.3](docs/research/vocabulary.md#43-gom-theo-nghĩa-gây-nhiễu-gom-theo-tình-huống-thì-không),
   và nó định hình cả chế độ ôn "Phân biệt" ở R2. Phần còn thiếu là **xác minh bản
   gốc** — đây là câu hỏi nghiên cứu ưu tiên số một hiện nay.
6. **FSRS optimizer.** FSRS huấn luyện lại tham số từ chính review log của người
   dùng. Cần bao nhiêu review log thì việc này có ý nghĩa? Đây là lý do bảng
   `review_logs` tồn tại. **Đã có tiến triển:** ngưỡng review tối thiểu đã bị bỏ khỏi
   Anki từ 24.06 (trước đó là 400, trước nữa 1000), nên câu hỏi chuyển từ *"chạy được
   chưa"* sang *"đáng chạy chưa"* — và tham số mặc định vẫn hơn SM-2 nên R1 không cần
   optimize. Phần cần tra tiếp và toàn bộ tầng lịch nằm ở
   [review.md](docs/research/review.md).
7. **Spoken form có đáng đầu tư không** trong một app tập trung vào đọc? IPA đã
   phủ một phần; audio/TTS là bước tiếp theo nhưng có thể ngoài phạm vi (NG-01
   loại trừ pronunciation practice).
8. **Timing của productive card.** Có bằng chứng nào về việc nên đợi bao lâu sau
   khi nắm receptive mới mở productive cho cùng một từ?

---

## 7. Nguồn

### Đã đọc trực tiếp

| Nguồn | URL |
|---|---|
| Nation, *Knowing a word*, Cambridge University Press (2022) | https://doi.org/10.1017/9781009093873.003 |
| The learnability of word knowledge aspects in Thai EFL learners (ERIC EJ1294888) — chứa bảng 9 aspect của Nation 2013 | https://files.eric.ed.gov/fulltext/EJ1294888.pdf |
| Components Approach, *The Routledge Handbook of Vocabulary Studies* | https://ebrary.net/323191/language_literature/components_approach |
| Woźniak, *Twenty rules of formulating knowledge* | https://www.supermemo.com/en/blog/twenty-rules-of-formulating-knowledge |
| Minimum information principle (supermemo.guru) | https://www.supermemo.guru/wiki/Minimum_information_principle |
| Knowledge structuring for learning (super-memory.com) | https://www.super-memory.com/english/ol/ks.htm |
| Refold Roadmap — Sentence Mining | https://refold.la/roadmap/library/sentence-mining |
| Animecards — Anki Card Types | https://animecards.site/ankicards/ |
| AJATT — Discussing various card templates | https://ajatt.top/blog/discussing-various-card-templates.html |
| Mikey Does — Sentence mining: what does the research say | https://mikeydoes.com/articles/sentence-mining-japanese-research/ |

### Chỉ thấy dẫn lại — CHƯA kiểm chứng

Các nghiên cứu dưới đây được **trích dẫn trong** hai bài của Refold và mikeydoes.
Bản gốc chưa được đọc, nên đừng coi các phát biểu gắn với chúng là đã xác minh.
Session sau nếu cần dựa vào chúng thì phải tra bản gốc trước.

| Nguồn dẫn lại | Được dẫn để chứng minh điều gì |
|---|---|
| Cepeda et al. (2008) | Spaced review ở khoảng tối ưu vượt trội massed practice |
| Nakata (2015) | So sánh expanding vs equal spacing; cả hai đều hơn massed practice |
| Webb (2020) | Incidental learning qua đọc/nghe là động lực chính của tăng trưởng vốn từ |
| Hulstijn (2001) | Người học nhớ tốt hơn khi có nỗ lực nhận thức và tương tác ngữ cảnh cao hơn |
| Nation (2001) | Deliberate study làm tăng việc "noticing" từ đích khi gặp lại trong input |

### Nguồn nêu trong mục 6 nhưng chưa tra

Michael Lewis, *The Lexical Approach*; các danh sách tần suất BNC/COCA; tài liệu
về FSRS optimizer. Đây là hướng cho session sau, không phải nguồn đã dùng.

## Phần 3 — Import từ vựng — plan (chiều ngược của FR-16)

| Field | Value |
|---|---|
| Created | 2026-09-09 |
| Last updated | 2026-09-09 |
| Trạng thái | **plan v1.0 — IMP-01→IMP-04 đã chốt 2026-09-09** (bảng chốt mục 3). Chưa có chữ GO code — owner đang đọc lại plan. Chưa viết dòng code nào |
| Scope v2 | ⚠️ **2026-09-18:** PRD v2 mục 10 chốt FR-20 = **nhập CSV gộp, KHÔNG nhập JSON**. Khi code, bỏ nhánh JSON/TSV của plan này, giữ atomic/remap/preview → ROADMAP task 3.10 |

---

## 1. Vì sao có feature này

FR-16 (export, task 3.7 ✅ 2026-09-08) mới làm xong **một chiều** của NFR-05:
mang dữ liệu *ra*. Nhưng phao cứu sinh được xây để phòng rủi ro iOS xoá storage
chỉ thật sự là phao khi có chiều *kéo về*: export một JSON đầy đủ mà không có
chỗ nhập lại thì dữ liệu học tập nhiều năm cứu được **ra khỏi** hố nhưng không
**vào lại** được app.

- **NFR-05 "không lock-in"** chỉ trọn vẹn khi có cả hai chiều. Đây là nửa còn
  thiếu của đúng FR-16, không phải feature mới từ đâu ra.
- **Ranh giới NG-07 (quan trọng, để không nhầm):** NG-07 cấm *"import PDF/ebook"*
  vì đó là **input path capture thứ hai** — nguồn từ vựng mới phải là ảnh chụp.
  Import trong plan này KHÔNG phải input path: nó chỉ nhận lại **đúng 2 định
  dạng chính Reado xuất ra** (JSON `reado-export` + TSV), tức khôi phục/ghép dữ
  liệu, không tạo đường lấy từ vựng mới nào. Một input path capture duy nhất
  vẫn là ảnh chụp — NG-07 nguyên vẹn.
- **Vị trí trong PRD:** PRD chưa có FR cho import. Plan đề xuất thêm
  **FR-20 — Data Import** đặt cạnh FR-16 (cùng chùm data portability), với
  criteria Given/When/Then soạn sẵn ở mục 8 — agent chỉ sửa PRD khi owner GO.

## 2. Đầu vào = đúng đầu ra của export

"cùng format như export" hiểu là: **import nhận đúng 2 định dạng mà màn Xuất dữ
liệu cho ra** (`domain/export.ts`). Không phát minh format thứ ba.

### 2.1 JSON `reado-export` v1 — khôi phục đầy đủ

Cấu trúc `buildJsonExport` (đã có): `format`, `version`, `exportedAt`, `scope`,
`counts`, `settings`, `vocabItems[]`, `cards[]`, `reviewLogs[]`.

- `vocabItems` mỗi dòng đủ mọi field kể cả rich vocab (`tags`/`synonyms`/`antonyms`) —
  file xuất **sau** task 3.12 mới có 3 field này; file cũ hơn thiếu → parser
  phải điền `[]`, không fail.
- `cards` mang **nguyên bộ state FSRS**; `reviewLogs` là ảnh chụp TRƯỚC khi chấm
  (điều cấm #1) — nhập về đúng như trong file, không tính lại gì.
- `settings` là whitelist (điều cấm #9): **không bao giờ** có `ai_api_key` hay
  `ai_base_url` — nên nhập settings cũng không bao giờ chạm secret.

### 2.2 TSV 7 cột — nhập từ vựng trần

Đúng header export ra: `term · pos · ipa · meaning_vi · cefr · example · collection`.

- Dòng bắt đầu `#` (directive/comments của Anki) → bỏ qua.
- Cột rỗng → `ipa`/`cefr` null. Cột `collection` **KHÔNG dùng làm điểm đến**
  (IMP-04 chốt: người dùng bắt buộc chọn collection đích) — chỉ hiển thị ở preview.
- **Mất mát cố ý:** TSV không có id, không FSRS state, không rich vocab →
  mọi hàng = 1 từ **mới** + 1 card `state='new'`, `due_at = now`. Hợp cho
  "mang từ từ Anki/nơi khác về", KHÔNG phải đường khôi phục. UI phải nói rõ điều
  này ở bản xem trước.

## 3. Ngữ nghĩa nhập — bốn câu hỏi sống còn

**ĐÃ CHỐT 2026-09-09 (owner trả lời qua ask):**

| ID | Chốt |
|---|---|
| IMP-01 | **Merge với remap id** — phương án (a): id không đụng giữ nguyên (kho trống → khôi phục y nguyên), đụng → sinh id mới + remap FK. KHÔNG lọc trùng. |
| IMP-02 | **Cả JSON + TSV** — phương án (a). |
| IMP-03 | **Checkbox "áp dụng cả cài đặt", mặc định TẮT** — phương án (a). Secrets không bao giờ nằm trong file (điều cấm #9). |
| IMP-04 | **BẮT BUỘC chọn collection đích khi nhập TSV** — chọn collection có sẵn hoặc tạo mới ngay tại màn nhập; cả file về MỘT collection, cột tên collection trong TSV bị **bỏ qua** (preview ghi chú rõ). JSON vẫn khôi phục theo collection gốc trong file. |

Dưới đây là ba phương án đã cân nhắc cho mỗi câu (giữ lại để truy lý do — lựa chọn
thắng là dòng in đậm ở bảng trên):

- **IMP-01 — nhập vào kho ĐÃ CÓ dữ liệu thì sao?**
  - (a) **Merge với remap id** ✅ — một thuật toán, hai chế độ (kho trống tự nhiên
    thành khôi phục y nguyên).
  - (b) Chỉ khôi phục vào **kho trống** — đơn giản, nuốt trọn use case "mất
    storage", nhưng vô dụng khi đổi máy mà máy mới đã có ít từ.
  - (c) Merge có **lọc trùng** — loại: va chốt "không có `unique`" (structure mục
    6.3 — một từ nhiều nghĩa nhiều dòng) và docs chưa từng định nghĩa khoá so
    khớp trùng nào; lọc nhầm là mất nghĩa của từ, tệ hơn trùng.
- **IMP-02 — nhận cả hai định dạng hay chỉ JSON?**
  - (a) **Cả JSON + TSV** ✅ — đối xứng trọn với export, TSV mở ra đường "chuyển
    từ từ Anki về".
  - (b) Chỉ JSON — gọn hơn một bước parse, nhưng bỏ đúng cột thứ 7 của FR-16
    (tên collection xuất ra *để* nhập vào công cụ khác) thì ngược lại cũng lẽ ra
    nhập từ nơi khác về được.
- **IMP-03 — `settings` trong file JSON có áp luôn không?**
  - (a) **Checkbox "áp dụng cả cài đặt", mặc định TẮT** ✅ — khôi phục máy mới bấm
    1 chạm; nhập ghép thêm vào kho cũ không vô tình đổi CEFR/hạn mức.
  - (b) Không bao giờ áp — an toàn tuyệt đối nhưng mất tiện khôi phục.
  - (c) Tự áp khi kho trống — "ma thuật", khó lường cho người dùng.
- **IMP-04 — TSV có tên collection CHƯA tồn tại thì sao?**
  → Owner chọn phương án thứ tư: **bắt buộc chọn collection đích (hoặc tạo mới)
  trước khi nhập** — không tự động map theo tên, không dồn kho tạm, không hỏi
  từng collection. Phương án đã cân nhắc rồi bỏ: (i) tạo collection mới theo tên
  trong cột — tự động có thể sinh bừa collection ngoài ý muốn; (ii) dồn kho tạm —
  phá tổ chức; (iii) hỏi từng collection — nhiều ma sát cho file trăm từ. Hệ quả:
  cột 7 của TSV chỉ còn ý nghĩa **hiển thị** ở preview, điểm đến do người dùng
  quyết.

## 4. Kiến trúc theo tầng (gương export 1:1)

Dependency rule giữ nguyên: `ui → usecase → repo interface`, pure builder trong
`domain`, string tiếng Việt chỉ ở `ui/`.

| Tầng | File | Trách nhiệm |
|---|---|---|
| Domain thuần | `app/src/domain/import.ts` | `parseReadoJson(text)` / `parseImportTsv(text)` → dataset hoặc danh sách lỗi VỊ TRÍ ĐÍCH XÁC (dòng + field); validate enum (`pos`, `cefr`, 4 `state`, rating 1–4…) ; `buildImportPlan(dataset, existingIds, opts) → ImportPlan` — sinh id mới chỗ đụng, remap `cards.vocab_item_id` / `logs.card_id`, map collection (đụng id khác tên → collection mới, `is_default=1` trong file → gộp vào kho tạm hiện tại). Không DB, không network, không chữ UI |
| Use-case | `app/src/domain/usecases/importData.ts` | Nhận NỘI DUNG (string), tự nhận diện JSON/TSV, parse → đọc id đang tồn tại (một lần) → plan → gọi repo. Trả về summary (từ/card/log/collection mới, thẻ đã-đến-hạn) + cảnh báo |
| Repo interface | `app/src/domain/repositories.ts` + `app/src/storage/repos/importer.ts` | `ImportRepository.importPlan(plan): Promise<void>` — **MỘT transaction**: insert collections → vocab_items → cards → review_logs (+ settings patch nếu bật). Lắp vào `ReadoRepos`/`createRepos`; memServices tự có vì repo test là SQLite thật |
| UI | `app/src/ui/screens/ImportScreen.tsx` + route AppRoot + link Home cạnh "⬇︎ Xuất dữ liệu" | Xem mục 5 |

Đối xứng đặt tên với export (`export.ts`/`exportData.ts`/`ExportScreen`).

## 5. Luồng UI (ImportScreen)

1. Home → **"⬆︎ Nhập dữ liệu"** (cạnh link Xuất).
2. Chọn file (`<input type="file">`, PWA iOS đi qua Files — hoạt động cả offline)
   **hoặc** dán nội dung vào textarea (đường thủ công luôn có, đối xứng NFR-05:
   phao không được phụ thuộc một đường duy nhất).
3. **"Phân tích"** → bản xem trước: định dạng nhận diện, số collection/từ/card/
   log sẽ nhập, dòng cảnh báo *"Y thẻ đã đến hạn — sẽ vào hàng đợi ngay"*.
   **Chưa ghi gì.**
4. **TSV — bắt buộc chọn điểm đến (IMP-04):** ô "Nhập vào collection" (select
   mọi collection hiện có + nút "+ Tạo collection mới" ngay tại màn — không rời
   flow, cùng tinh thần FR-01) + ghi chú *"cột tên collection trong file bị bỏ
   qua; cả file sẽ về collection này"*. **JSON không cần bước này** — collection
   đi theo cấu trúc trong file (mục 6.6), chỉ thêm checkbox cài đặt (IMP-03,
   mặc định TẮT).
5. **"Nhập vào kho"** (1 chạm, chỉ bật khi đủ điều kiện) → tóm tắt kết quả +
   link "→ Xem Kho từ vựng" + "← Về trang chủ".
6. File lỗi → KHÔNG ghi gì (atomic), báo rõ lỗi ở dòng nào (≤ 10 lỗi đầu).

## 6. Quy tắc dữ liệu — bẫy đã thấy trước

1. **Atomic** (điều cấm #3 + NFR-06): nhập nửa chừng = mất dữ liệu cải trang.
   Parse/validate xong hết, ghi đúng một transaction; lỗi giữa chừng → rollback sạch.
2. **Thứ tự insert** đúng FK: collections → vocab_items → cards → review_logs.
3. **Timestamp giữ nguyên `...Z`** từ file, đổi múi giờ nào cũng không quy đổi
   (điều cấm #7). `due_at`/`last_review_at`/`reviewed_at` qua lại y hệt.
4. **`due_at` cũ giữ nguyên** — thẻ đã quá hạn trong file vẫn quá hạn sau khi
   nhập. Đó là *đúng* đối với khôi phục; chỉ cảnh báo ở preview, không "chữa".
5. **Remap id dây chuyền:** cards trỏ vocab_item mới, logs trỏ card mới — không
   bao giờ để log trỏ nhầm card của dòng khác (mất undo + hỏng training data).
6. **Xử lý collection theo định dạng:**
   - *JSON* — `is_default=1` trong file không được sinh bản sao kho tạm; item của
     nó gộp vào kho tạm hiện tại. Collection thường: id lạ → tạo mới; id quen +
     tên khác → tạo mới id mới giữ tên; id quen + tên giống → dùng lại.
   - *TSV* — **KHÔNG đọc cột 7 làm nguồn collection** (IMP-04): toàn bộ hàng vào
     MỘT collection đích do người dùng chọn hoặc tạo mới ngay tại màn nhập. Không
     tự sinh collection từ tên trong file — cột 7 chỉ là thông tin hiển thị ở preview.
7. **Không ghi secret từ file**, kể cả khi file bị sửa tay nhét `ai_api_key` —
   parser chỉ nhận đúng whitelist của `ExportableSettings`, field lạ bị bỏ.
8. **Không bypass `daily_new_limit`:** thẻ mới nhập vào vẫn ăn hạn mức thường của
   FR-11 (không phá hợp đồng queue); nhập 300 từ mà hạn mức 10 → mỗi ngày ra 10.
9. **Card nhập `state='new'` có `due_at` = thời điểm nhập** cho TSV; JSON giữ
   nguyên `due_at` trong file.

## 7. Giữ nguyên mọi chốt cũ (không va chạm)

- **"Không `unique`"** trên vocab_items giữ nguyên → merge có thể tạo hàng trùng
  (chấp nhận — chống trùng là việc FR-10/Q-08/Q-09, không phải import).
- **Không lemmatize (Q-06):** `term_normalized` trong file giữ nguyên như export
  ra — không tính lại bằng luật khác (lệch với kho cũ thì bộ lọc sau này hỏng).
- **4 giá trị `state`:** validate đúng 4, không gộp (điều cấm #2).
- **NG-07:** giữ (đã giải thích mục 1).
- **NFR-06/NFR-07:** atomic + không secret (mục 6).

## 8. Tiêu chí chấp nhận — đề xuất FR-20 (soạn sẵn cho PRD)

Mirror từng criterion của FR-16 (PRD mục 6):

- **Given** file JSON `reado-export` v1, **when** nhập vào kho, **then** toàn bộ
  từ kèm `pos`/`ipa`/`meaning_vi`/`cefr`/câu gốc/rich vocab + card nguyên bộ
  FSRS + review log khôi phục y nguyên; kho trống thì id giữ nguyên.
- **Given** file TSV 7 cột của export và người dùng đã chọn (hoặc tạo) collection
  đích, **when** nhập, **then** từ mới đi về **đúng collection người dùng chọn**
  (cột tên collection trong file bị bỏ qua — IMP-04), mỗi từ một card new, không
  tự sinh collection từ tên trong file.
- **Given** kho đã có dữ liệu và file có id đụng, **when** nhập, **then** ghi
  thành công **không phá** dữ liệu cũ, id sinh lại, card/log trỏ đúng chủ mới.
- **Given** file sai format / sai version / cột thiếu / dòng hỏng, **when** nhập,
  **then** **không có gì được ghi** và chỉ rõ lỗi ở dòng nào.
- **Given** file có `settings` hợp lệ, **when** người dùng chọn áp dụng, **then**
  cài đặt đổi đúng; `ai_api_key`/`ai_base_url` không bao giờ được ghi từ file.

## 9. Đã chốt và chưa chốt

| Nhóm | Nội dung | Trạng thái |
|---|---|---|
| Đã chốt (từ docs có sẵn) | Đầu vào = đúng 2 định dạng export ra (không format mới) | ✅ theo FR-16/task 3.7 |
| Đã chốt (từ docs có sẵn) | Atomic 1 transaction; timestamp `...Z` giữ nguyên; không ghi secret; không lemmatize; 4 state; không `unique`; không bypass hạn mức FR-11 | ✅ các điều cấm + bảng Đã chốt research — mục 7 |
| Đề xuất, owner đảo được | Không tạo kho tạm thứ hai; remap id khi đụng; preview trước khi ghi; textarea paste luôn có | ✏️ plan mục 4–6 |
| Câu hỏi mở | **IMP-01** merge/remap · **IMP-02** JSON+TSV hay chỉ JSON · **IMP-03** settings checkbox · **IMP-04** collection lạ | ✅ **Đã chốt 2026-09-09 (owner):** merge + remap id · cả JSON + TSV · settings checkbox mặc định TẮT · TSV bắt buộc chọn collection đích (mục 3) |
| Chưa có | Chữ "code đi" của owner — đang đọc lại plan | ⬜ |

## 10. Checklist triển khai — task 3.16 (chỉ chạy sau GO)

1. ✅ 2026-09-09 — Owner trả lời IMP-01 → IMP-04 (bảng chốt mục 3, đã phản ánh
   vào doc này + archive/mvp-plan-pwa-gen).
2. `domain/import.ts` + unit test (gương `export.test.ts`): parse 2 định dạng,
   validate + lỗi theo dòng, remap, map collection (JSON) / đích do user chọn (TSV).
3. `storage/repos/importer.ts` + integration test trên SQLite thật (mimic
   `export.integration.test.ts`): 1 transaction, remap đúng, không tạo kho tạm 2,
   rollback khi lỗi giữa chừng.
4. `usecases/importData.ts` + summary.
5. `ImportScreen.tsx` + route AppRoot + link Home.
6. e2e `app/e2e/import-flow.mjs` (upload file thật qua `input[type=file]` hoặc
   paste textarea; mirror `export-flow.mjs`) + `npm run e2e:import`.
7. Gates: lint 0/0, typecheck sạch, test xanh, build sạch → commit chỉ `app/`.
8. Cập nhật archive/mvp-plan-pwa-gen (3.16 ✅ + mục 4 chốt IMP-xx) + PRD **FR-20** + pointer
   AGENTS/README theo convention.
