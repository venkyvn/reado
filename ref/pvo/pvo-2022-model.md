# PVO 2022 — mô hình dữ liệu (distilled)

| Field | Value |
|---|---|
| Loại | Reference — nguồn bên ngoài, distilled |
| Nguồn | Hồ Lê Vũ, *Hướng dẫn sử dụng PVO - phiên bản web-based*, Mr Vu's English Classes |
| URL | https://vuenglishclass.blogspot.com/2021/09/phac-thao-cau-truc-pvo-moi.html |
| Ngày bài viết | 2021-09-05 (nội dung mô tả PVO 2022) |
| Distilled | 2026-09-07 |
| Dùng cho | [docs/research/vocabulary-structure.md](../../docs/research/vocabulary-structure.md) |

**Phạm vi bản distill này.** Bài gốc dài, và khoảng 80% là hướng dẫn thao tác UI:
đăng ký, đăng nhập, quên mật khẩu, đổi email, các thông báo lỗi từng màn hình.
Toàn bộ phần đó bị **bỏ**. Chỉ giữ lại thứ có giá trị thiết kế: mô hình dữ liệu,
các bộ quan hệ, bộ tham số ngữ cảnh, cơ chế duyệt cây, và vài pattern vận hành
đáng học. Khi cần đối chiếu nguyên văn thì quay lại URL trên.

---

## 1. PVO là gì, và dùng cho ai

> "PVO là phần mềm **từ điển cá nhân**, cho phép người dùng lưu và tra cứu lại tất
> cả những từ vựng/cấu trúc đáng nhớ tích lũy trong quá trình học tiếng kéo dài
> nhiều năm. Việc lưu từ được thực hiện theo **cơ chế liên kết liên tưởng
> (association)** […] giúp nhớ từ lâu hơn đồng thời tạo điều kiện dễ dàng để
> **tìm lại cụm từ cần thiết khi nói và viết**."

Và ngay sau đó, đối tượng:

> "Phần mềm này đặc biệt hữu ích với **phiên dịch và giáo viên tiếng Anh**, những
> người thường xuyên cần tra cứu từ vựng, ghi nhớ hàng loạt thông tin chi tiết
> liên quan đến ngữ cảnh sử dụng từ và xây dựng tư liệu bài giảng."

Hai câu này định vị PVO chính xác, và cần đọc kỹ trước khi vay mượn bất cứ thứ gì
từ nó:

- Mục đích chính là **production** — lấy ra được cụm từ đúng lúc cần nói hoặc viết.
- Đối tượng là **người dùng chuyên nghiệp**, chấp nhận lao động thủ công đáng kể.
- Hoàn toàn **không có spaced repetition**. PVO không lên lịch gì cả. Nó là hệ
  thống lưu trữ và truy xuất, không phải hệ thống ghi nhớ theo lịch.

Ẩn dụ trung tâm của tác giả:

> "Hệ thống từ vựng của người dùng được cấu hình như một cái cây, bao gồm hệ thống
> mắt xích khái niệm (**CONCEPT**) kết nối nhau theo cấp bậc, và mỗi ví dụ
> (**EXAMPLE**) chứa cấu trúc cần nhớ như một chiếc lá được gắn theo một hay một
> nhóm Concept."

![Mô hình cây từ vựng PVO](<PVO - 01. Mô hình cây từ vựng giới thiệu.png>)

Đọc hình: `Root concept` là thân cây. **Rễ và cây bụi phía dưới** là các Concept
khác nối vào nó (`Child 1..3` bên trái, `Parent 1..2` bên phải), nối qua nhãn
`Association` hoặc `Type of`. **Tán lá phía trên** là các Example, gom thành cụm
theo loại quan hệ, mỗi cụm kèm số lượng: `Nominal` 180, `Patient` 150, `Action`
120, `Idioms` 120, `Describing` 80, `Other phrases` 50, `Described by` 30.

Điểm đáng chú ý ở hình: **quan hệ Concept–Concept nằm ngang, quan hệ Example–Concept
nằm dọc**. Đó là hai trục độc lập, không phải một cây phân cấp duy nhất.

---

## 2. Database structure

![PVO database structure](<PVO database structure.png>)

### Các bảng cốt lõi

| Bảng | Cột đáng chú ý | Vai trò |
|---|---|---|
| `dictionaries` | `user_id`, `name`, `last_view_at` | Một user có nhiều từ điển độc lập |
| `concepts` | `dictionary_id`, `title`, `description`, `deleted_at` | Node khái niệm. `description` là definition tuỳ chọn |
| `concept_links` | `name`, `user_id`, `sort_number`, `deleted_at` | **Bộ loại quan hệ Concept–Concept, do user định nghĩa** |
| `concept_concepts` | `child_id`, `parent_id`, `concept_link_id` | Cạnh có hướng giữa hai Concept, mang một loại quan hệ |
| `examples` | `detail`, `detail_html`, `note`, `tone_id`, `register_id`, `dialect_id`, `mode_id`, `nuance_id` | Câu ví dụ. **`detail_html` chứa markup highlight** |
| `example_links` | `name`, `type`, `user_id`, `sort_number` | **Bộ loại quan hệ Example–Concept, do user định nghĩa** |
| `example_concepts` | `concept_id`, `example_id`, `example_link_id` | Cạnh many-to-many giữa Example và Concept, mang một loại quan hệ |
| `tones` / `modes` / `registers` / `nuances` / `dialects` | `title`, `sort_number`, `user_id` | Năm bảng lookup riêng biệt, mỗi bảng scoped theo user |

Ngoài ra: `users`, `style_settings` (định dạng hiển thị phần highlight),
`backup_settings` (lịch backup tự động), `logs`.

### Ba quan sát cấu trúc quan trọng nhất

**Quan sát 1 — PVO không có bảng `terms`.** Không hề có bảng nào lưu "từ vựng".
Đơn vị nguyên tử lưu trữ là **`examples`**, tức nguyên câu, với phần cấu trúc cần
nhớ được đánh dấu bên trong `detail_html`. Concept chỉ là **nhãn để nối**, không
phải mục từ điển. Đây là khác biệt cấu trúc lớn nhất so với mọi app flashcard
thông thường, và nó chính là Lexical Approach được đóng cứng vào schema.

**Quan sát 2 — bộ quan hệ là dữ liệu, không phải enum.** `concept_links` và
`example_links` là bảng có `user_id` và `sort_number`, nghĩa là mỗi người dùng có
thể tự mở rộng bộ quan hệ của mình. Danh sách ở mục 3 dưới đây là **giá trị mặc
định hệ thống**, không phải ràng buộc cứng.

**Quan sát 3 — cạnh Concept–Concept có hướng và chống chu trình.** `child_id` /
`parent_id` là hai cột riêng, và phần mềm chặn chu trình một cách tường minh (xem
mục 5).

---

## 3. Bộ giá trị hệ thống

### CONCEPT LINK — quan hệ giữa hai Concept

```
No link
Association
Type of
```

Chỉ có hai loại thật (`No link` là giá trị dùng để **xoá** quan hệ đã có). Đây là
điểm quan trọng: tầng khái niệm được giữ **cực kỳ tối giản** — một quan hệ phân
loại (`Type of`, mang tính taxonomy) và một quan hệ liên tưởng tự do
(`Association`).

### EXAMPLE LINK — quan hệ giữa Example và Concept

```
No link
Idiom
Nominal
Agent
Patient
Action
Described by
Describing
Other phrase
```

Tám loại. Đọc kỹ thì đây thực chất là **semantic role labeling** quanh một khái
niệm. Với concept `ANGER` chẳng hạn:

| Quan hệ | Trả lời câu hỏi |
|---|---|
| `Nominal` | Gọi tên khái niệm này thế nào? (*rage*, *fury*) |
| `Agent` | Ai/cái gì thực hiện? (*hothead*) |
| `Patient` | Ai/cái gì chịu tác động? |
| `Action` | Hành động tương ứng là gì? (*fly off the handle*) |
| `Describing` | Cụm nào mô tả khái niệm này? |
| `Described by` | Khái niệm này được mô tả bằng gì? |
| `Idiom` | Thành ngữ liên quan |
| `Other phrase` | Phần còn lại |

Bộ này được thiết kế cho người **cần sản sinh ngôn ngữ**: đang dịch một câu, biết
mình cần "danh từ chỉ người hay nổi nóng" thì tra đúng nhánh `Agent` của concept
`ANGER`. Nó không phải bộ phân loại phục vụ việc đọc hiểu.

### TMRND — năm tham số ngữ cảnh của mỗi Example

Giá trị mặc định của cả năm đều là `Neutral`.

| Tham số | Các giá trị |
|---|---|
| **Tone** | Neutral, Informal, Formal, Slightly informal, Slightly formal |
| **Mode** | Neutral, Spoken, Written |
| **Register** | Neutral, Academic, Literature, Business, Law, Journalism, Medicine, Other |
| **Nuance** | Neutral, Old fashioned, Humorous, Oft positive, Oft negative |
| **Dialect** | Neutral, American, British, Other |

Với `Other` (Register và Dialect), tên cụ thể được ghi vào phần Notes.

TMRND không phải phát minh của phần mềm — nó là **nguyên tắc nền tảng của cả
phương pháp giảng dạy**. Trong syllabus lớp TẠP I, TMRND xuất hiện ngay buổi 1 như
khung phân tích khác biệt giữa các cách diễn đạt, và các cấu trúc học được tổng
kết kèm "TMRND clusters" chính là để phục vụ việc lưu vào PVO sau đó.

---

## 4. Example — cách một mục được nhập

1. Gõ hoặc dán nội dung Example vào ô nội dung.
2. **Bôi đen và highlight** những cụm từ cần nhớ (`Ctrl+H`). Một Example có thể có
   nhiều phần được highlight.
3. Chọn Tone / Mode / Register / Nuance / Dialect.
4. Notes tuỳ chọn — tác giả gợi ý ba nhóm: *Sources* (nguồn: báo, phim, tiểu
   thuyết, hội thoại), *Translation* (nghĩa tiếng Việt), *Other notes* (chú thích
   khác, ví dụ cultural schemas).
5. Nối Example với **một hoặc nhiều** Concept, mỗi liên kết mang một quan hệ riêng
   trong bộ tám ở mục 3.
6. `Save & Reset`.

Vài chi tiết vận hành đáng ghi nhận:

- **Bắt buộc phải có ít nhất một phần được highlight.** Không highlight thì không
  lưu được (`No highlighted parts`). Nghĩa là hệ thống từ chối lưu một câu trơn —
  phải chỉ rõ *cấu trúc nào* đáng nhớ trong câu đó.
- **Giới hạn 2000 ký tự** cho nội dung Example.
- **Định nghĩa trùng lặp:** hai Example trùng nếu nội dung **và phần highlight**
  giống hệt nhau. Cùng một câu nhưng highlight khác nhau thì vẫn là **hai Example
  riêng biệt**. Đây là một quyết định thiết kế rất có chủ ý.
- **`Re-use the same parameters when reset`** — giữ lại TMRND và Sources/Notes cho
  Example kế tiếp, phục vụ việc nhập hàng loạt từ cùng một nguồn.
- Sau khi `Save & Reset` thì không sửa được ở màn hình này nữa; phải qua EDIT.

### Trạng thái `Undecided`

Nếu người dùng lưu một Example mà chưa nối với Concept nào, hệ thống hỏi lại và
cho phép đánh dấu nó là **`Undecided`**. Example ở trạng thái này:

- tìm lại được qua option `Search undecided examples`;
- **tự động mất nhãn `Undecided`** ngay khi được nối với một Concept bất kỳ;
- **tự động quay lại `Undecided`** nếu người dùng xoá hết link trong lúc edit.

Đây là một pattern hay: hệ thống cho phép **hoãn quyết định phân loại** mà không
mất dữ liệu, và tự động dọn nhãn khi quyết định được đưa ra. Toàn bộ dữ liệu di cư
từ PVO bản cũ cũng đổ vào đúng trạng thái này.

---

## 5. Concept — cách tầng khái niệm được duy trì

- Concept gồm `title` (bắt buộc) và `definition` (tuỳ chọn).
- **Chống trùng tên tuyệt đối:** lỗi `Concept already exists` chặn mọi trường hợp
  trùng, cả khi tạo mới lẫn khi đổi tên. Đây là cơ chế giữ cho namespace khái niệm
  không phình ra một cách hỗn loạn.
- **Không tự nối chính mình:** `A concept can't link to itself`.
- **Chống chu trình:** nếu A đang là con của B mà người dùng cố nối B thành con của
  A, hệ thống báo `Circular link` và đề nghị **đảo chiều** quan hệ hiện có thay vì
  tạo thêm cạnh.
- **Không xoá được Concept đang có Example nối vào.** Cảnh báo kèm số lượng, và
  cho phép nhảy thẳng sang SEARCH để xem danh sách Example đó mà xử lý.
- Có phím tắt `Ctrl+S` liệt kê **toàn bộ** Concept theo alphabet ở bất kỳ màn hình
  nào — nghĩa là tác giả coi việc "biết mình đang có những khái niệm nào" là thao
  tác thường xuyên, cần truy cập tức thì.

Chi tiết nhỏ nhưng nói lên nhiều điều về quy mô thực tế: bài viết cảnh báo đừng
lạm dụng nút Refresh danh sách Concept **"nhất là khi bạn đã có vài trăm Concept
trở lên"**. Vậy một từ điển PVO trưởng thành nằm ở tầm **vài trăm Concept**, chứ
không phải hàng nghìn.

---

## 6. TREE — hai chế độ duyệt

### SIMPLE (bản mobile chỉ có chế độ này)

Chọn một Root Concept, màn hình hiện:

1. **Child Concepts bên trái, Parent Concepts bên phải.** Double-click bất kỳ cái
   nào thì nó trở thành Root mới và cả cây cập nhật theo.
2. **Danh sách quan hệ ở trên**, và đây là chi tiết thiết kế quan trọng: *"chỉ mối
   quan hệ nào đã có ví dụ được link thì mới hiển thị"*, kèm **số lượng Example**
   của quan hệ đó — đúng như các con số 180/150/120 trên hình cây ở mục 1. Nhánh
   rỗng không chiếm chỗ.
3. Click vào một quan hệ thì hiện danh sách Example tương ứng, **theo thứ tự nhập,
   cũ nhất trên cùng**.
4. Có **browsing history** với mũi tên tiến/lùi giữa các Root Concept đã xem.

### FULL (chỉ trên PC)

Mô phỏng cây thư mục Windows. Root Concept là thư mục gốc chứa ba thư mục con:
`Parents`, `Children`, `Examples` — trong đó `Examples` lại chứa các thư mục con
theo từng loại quan hệ. Mỗi thư mục hiện số entry trong ngoặc; `(0)` thì click
không có tác dụng.

Nửa dưới bên phải hiện **mạng lưới liên kết Concept–Concept** của Concept đang
chọn, trong đó Root ban đầu được đánh dấu bằng **viền nét đứt** để không mất
phương hướng khi duyệt. Double-click bất kỳ node nào trong mạng lưới cũng biến nó
thành Root mới.

Cách hiển thị nội dung Example ở nửa dưới:

```
<nội dung, có phần highlight>

[Tone] [Mode] [Register] [Nuance] [Dialect]

<notes, in nghiêng>
```

Với quy tắc: **tham số nào mang giá trị mặc định `Neutral` thì không hiện**. Nếu
cả năm đều mặc định thì bỏ luôn cả dòng. Đây là biểu hiện của nguyên tắc
*minimalistic approach* mà tác giả nêu ở phần giới thiệu — chỉ hiển thị thông tin
mang tính phân biệt.

---

## 7. SEARCH — cách một cụm từ được tìm lại

Đây là lý do tồn tại của toàn bộ cấu trúc trên. Tiêu chí tìm có thể kết hợp:

- chuỗi ký tự (tìm trong cả nội dung Example lẫn Notes);
- Tone / Mode / Register / Nuance / Dialect (mặc định `ALL`);
- **một hoặc nhiều linked Concept** — và quan trọng: nếu nhập nhiều Concept thì
  chỉ tìm Example nào nối **đồng thời với tất cả** các Concept đó (giao, không phải
  hợp);
- `Search undecided examples` — checkbox này tự động bị disable nếu đã chọn ít nhất
  một Concept, vì hai điều kiện loại trừ nhau về mặt logic.

Việc lọc giao nhiều Concept là thứ làm cho mạng lưới có giá trị thực tế: *"cụm nào
vừa liên quan `ANGER` vừa liên quan `WORKPLACE` và ở register `Business`"* là một
câu hỏi mà từ điển thường không trả lời được.

---

## 8. Pattern vận hành đáng học

Ba thứ nằm ngoài mô hình dữ liệu nhưng đáng ghi lại:

**Backup trước mọi thao tác phá huỷ.** Hệ thống tự động xuất Excel và gửi email
trước năm thời điểm: trước Recover, trước Transfer từ PVO cũ, trước Transfer giữa
hai từ điển, trước Delete một từ điển, và theo lịch định kỳ. Email backup có ghi
rõ nó thuộc trường hợp nào trong năm. Với dữ liệu tích luỹ nhiều năm, đây là phản
xạ đúng.

**Phân biệt Recovery và Transfer.** `Data Recovery` là **ghi đè** — xoá sạch từ
điển đích rồi nạp lại. `Transfer` là **hợp nhất** — Concept trùng tên thì chập làm
một và gộp toàn bộ link của cả hai; Example trùng cũng chập và gộp link, giữ TMRND
của bản đích và bỏ của bản nguồn. Hai thao tác nghe giống nhau nhưng ngữ nghĩa
ngược nhau, và tác giả nói rõ điều đó.

**Di cư có mất mát, và thừa nhận thẳng.** Khi lên bản 2022, bộ quan hệ
Concept–Concept và Example–Concept thay đổi và **không tương thích ngược**. Hệ quả:
*"dữ liệu duy nhất có thể chuyển sang hệ thống mới là toàn bộ Examples"* — mọi liên
kết cũ mất trắng, và tất cả Example nhập về đều mang nhãn `Undecided`.

Bài học cho Reado: **tầng liên kết là tầng dễ vỡ nhất khi schema đổi.** Example thì
sống sót vì nó tự chứa; graph thì không. Đáng cân nhắc khi thiết kế.

---

## 9. Những gì bản distill này cố tình bỏ

Để session sau không phải đoán: đã bỏ toàn bộ phần REGISTER, LOGIN, ACCOUNT, danh
sách thông báo lỗi từng màn hình, thao tác UI của DICTIONARY và BACKUP, hướng dẫn
export file `.mdb` từ PVO bản Access cũ, và mô tả bố cục pixel của các giao diện.
Những phần đó là đặc thù triển khai của PVO, không mang thông tin thiết kế cho
Reado.

---

## 10. Reado cuối cùng dùng gì, không dùng gì

Cập nhật 2026-09-07, sau khi thiết kế của Reado chốt ở
[docs/research/vocabulary-structure.md](../../docs/research/vocabulary-structure.md).

Mục này tồn tại để session sau **không đọc lại bài gốc rồi đề xuất lại từ đầu**
những thứ đã cân nhắc và loại bỏ có lý do.

### Đã dùng

| Thành phần PVO | Reado dùng thế nào |
|---|---|
| Ý tưởng gom từ theo bối cảnh do người dùng tự đặt tên | Thành **collection** — nhưng phẳng, không phân cấp |
| `Undecided` — hoãn phân loại mà không mất dữ liệu | Thành **kho tạm**, với một khác biệt quan trọng: từ trong kho tạm **vẫn ôn được**, còn Example `Undecided` của PVO thì chỉ nằm chờ |
| Chỉ hiện nhánh có nội dung, kèm số đếm | Nguyên tắc UI cho màn hình chọn phạm vi ôn |
| Backup trước mọi thao tác phá huỷ | Giữ làm nguyên tắc vận hành |
| Bài học "tầng liên kết là tầng dễ vỡ nhất khi schema đổi" | Lý do `word_relations` để tới R2, sau khi mô hình cốt lõi đã ổn định |

### Không dùng

| Thành phần PVO | Vì sao không | Điều kiện xem lại |
|---|---|---|
| **Node khái niệm** (`concepts` + `concept_concepts`) | Nhu cầu thật của Reado là quan hệ **từng cặp** giữa hai từ (`resilient ~ robust`). Node là một tầng gián tiếp không ai yêu cầu | Nếu thiếu màn hình duyệt theo tên nhóm |
| **Bộ tám quan hệ Example↔Concept** (`Agent`, `Patient`, `Action`, `Nominal`, `Idiom`, `Describing`, `Described by`, `Other phrase`) | Đây là semantic role labeling phục vụ **production** cho phiên dịch. Người đọc sách không bao giờ hỏi "danh từ chỉ người hay nổi nóng là gì". Cái giá: mỗi quyết định phân loại nhân lên tám lần | Nếu Reado mở sang hỗ trợ viết |
| **TMRND** (Tone, Mode, Register, Nuance, Dialect) | Năm cột cho một app đọc là quá nặng, và câu ví dụ đã mang phần lớn thông tin đó ngầm | Nếu chuyển sang production |
| **Đơn vị lưu là câu có highlight** | Đảo ngược toàn bộ schema đã chốt của Reado (đơn vị là từ) để đổi lấy lợi ích chưa chứng minh. Ghi nhận như hướng nghiên cứu | Nếu Lexical Approach được xác minh là đúng cho ngữ cảnh của Reado |
| **Multi-dictionary** | NG-05 — một người dùng, một kho. Collection đã phủ nhu cầu chia nhiều mảng | Nếu Reado thành đa người dùng |
| **Tìm kiếm theo giao nhiều tiêu chí** | PVO tìm theo **giao** vì phiên dịch cần chính xác. Reado ôn theo **hợp** vì lấy thừa vài từ chỉ tốn 10 giây, còn bỏ sót một từ mới là mất mát | Nếu xuất hiện nhu cầu tra cứu chính xác thay vì ôn tập |

### Khác biệt gốc rễ, đáng nhớ hơn cả hai bảng trên

PVO tối ưu cho **truy xuất đúng lúc cần dùng**; Reado tối ưu cho **ghi nhớ theo
lịch**. Mọi khác biệt thiết kế ở trên đều suy ra được từ một câu đó. Khi phân vân
có nên mượn thêm thứ gì từ PVO, hỏi trước: *thứ này phục vụ việc tìm lại, hay phục
vụ việc nhớ?*
