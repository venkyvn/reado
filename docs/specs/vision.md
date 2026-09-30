# Reado — Product Vision

> Tài liệu này trả lời câu hỏi **tại sao Reado đáng tồn tại**, không phải câu hỏi
> xây nó thế nào. Phần "thế nào là xong" nằm ở [PRD](docs/specs/prd.md).
> Vision có thể đổi khi sản phẩm lớn lên, nhưng chỉ giữ **luật hiện hành** — lịch sử
> quyết định và lý do đảo chiều nằm ở [decisions-log](docs/decisions-log.md).

---

## Introduction

Người học tiếng Anh ở trình độ trung cấp thường mắc kẹt ở một nghịch lý: họ đã
đủ giỏi để chán tài liệu dành cho người học, nhưng chưa đủ giỏi để đọc sách thật
mà không kiệt sức. Kết quả là họ đọc được vài trang rồi bỏ, hoặc đọc hết nhưng
không giữ lại được gì.

Reado không phải một app dạy tiếng Anh. Nó là công cụ cho người **đã tự học bằng
cách đọc sách thật**, và cần hai thứ mà công cụ hiện tại không cho: hiểu trọn
trang sách ngay lúc đọc, và giữ lại thứ đã học sau khi gấp sách.

Sáu nguyên lý dưới đây là ranh giới của sản phẩm. Mọi feature đề xuất trong
tương lai đều phải trả lời được: nó phục vụ nguyên lý nào?

---

## 1. Authentic Input Over Graded Readers

> **Philosophy:** Ngôn ngữ được tiếp thu khi ta hiểu được thứ chỉ khó hơn trình độ
> hiện tại một bậc — Stephen Krashen gọi đó là comprehensible input ở mức *i+1*.
> Điểm mấu chốt: nó phải **hiểu được**, chứ không phải **được làm cho dễ**.

**Với Reado:** Nguồn học là văn bản thật mà người dùng tự chọn — cuốn sách giấy
đang nằm trên bàn, bài báo mạng vừa mở ra, tài liệu chuyên ngành phải đọc cho công
việc. Reado không sản xuất nội dung, không biên tập lại, không đơn giản hoá câu
văn. Nó chỉ đứng cạnh người đọc.

**Chống lại:** Kho bài đọc do app soạn sẵn. Ngay khi Reado bắt đầu tự viết nội
dung, nó trở thành một graded reader nữa — và người dùng lại đọc thứ tiếng Anh
không ai thật sự viết ra.

---

## 2. Meaning Must Never Be Blocked

> **Philosophy:** Người ta bỏ dở một cuốn sách tiếng Anh không phải vì thiếu ý
> chí, mà vì gặp một câu không hiểu, rồi câu thứ hai, và mạch đọc đứt. Ma sát tích
> lại thành sự bỏ cuộc.

**Với Reado:** Bản dịch song ngữ theo từng đoạn nhỏ luôn nằm sẵn ngay cạnh bản
gốc. Người đọc tự quyết định khi nào liếc sang — không phải dừng lại, không phải
mở tab khác, không phải gõ lại câu vào ô tìm kiếm.

Bản dịch tốt còn là **thứ để học**, không chỉ để gỡ chỗ bí: đặt cạnh câu gốc, nó
cho thấy một ý tiếng Anh được chuyển sang tiếng Việt tự nhiên thế nào — cả cụm, cả
nhịp câu, chứ không phải từng chữ. Một bản dịch hay làm người ta muốn đọc tiếp.

**Chống lại:** Bắt người dùng "cố đoán nghĩa qua ngữ cảnh" như một kỷ luật bắt
buộc. Đoán nghĩa là kỹ năng tốt, nhưng ép buộc nó ở mọi câu thì chỉ làm người ta
đọc chậm lại và bỏ sớm hơn. Và bản dịch word by word khô cứng: nó gỡ được nghĩa
nhưng giết hứng đọc, và không dạy được gì về cách diễn đạt.

---

## 3. Capture At The Point Of Friction

> **Philosophy:** Từ đáng học nhất là từ vừa khiến bạn khựng lại. Đó là tín hiệu
> cá nhân, sinh ra từ chính lỗ hổng trong vốn từ của bạn — không một danh sách
> "1000 từ vựng B2" đóng sẵn nào biết được điều đó.

**Với Reado:** Từ vựng và cụm từ được trích ra từ chính trang sách người dùng vừa
đọc, lọc theo trình độ CEFR họ khai báo. Việc đưa một từ vào bộ ôn tập diễn ra
ngay tại thời điểm gặp nó, trong một thao tác.

AI chỉ **đề xuất**; người dùng là **người duyệt cuối**. AI đoán được từ nào khó với
một trình độ, nhưng không biết chắc từ nào làm chính người này khựng — và nó có thể
sai nghĩa. Giữ, bỏ, sửa trước khi lưu là quyền của người đọc.

**Chống lại:** Word list dựng sẵn tách rời khỏi việc đọc. Và cả thái cực ngược
lại: lưu tất cả mọi từ trong trang. Bộ ôn tập chứa thứ người dùng đã biết thì
chẳng mấy chốc sẽ bị bỏ.

---

## 4. Context Is The Memory Anchor

> **Philosophy:** Trí nhớ bám vào bối cảnh lúc ghi nhận. Một cặp từ trần trụi
> `resilient = kiên cường` là dữ liệu mồ côi; cũng từ đó nằm trong câu văn nơi
> bạn lần đầu gặp nó thì có chỗ để bám.

**Với Reado:** Mỗi thẻ ôn tập mang theo ngữ cảnh nơi nó được gặp — câu gốc, và tên
collection mà người dùng đã tự đặt. Ôn từ vựng đồng thời là ôn lại khoảnh khắc đọc.

Nguyên lý ở đây là **thẻ phải có chỗ bám**, không phải một danh sách field cụ thể
hay một bố cục mặt thẻ cụ thể. Hình thức hiện tại: mặt trước hỏi tối giản (chỉ từ),
mặt sau trả lời đủ (nghĩa, câu gốc, collection) — kiểm tra ít, hiển thị nhiều.
Collection thay cho `tên sách + số trang`, vì nguồn đọc thật còn có báo và web — mà
một bài báo mạng thì không có số trang. Chi tiết ở
[research/vocabulary.md](docs/research/vocabulary.md).

**Chống lại:** Thẻ không có câu gốc — nghĩa trần kiểu từ điển. Chúng dễ sinh ra
hàng loạt, và cũng dễ dẫn tới việc thuộc lòng bản dịch mà vẫn không dùng được từ đó
trong câu.

---

## 5. Durable Data, Not Disposable Chat

> **Philosophy:** Đây là nỗi đau khai sinh ra Reado. Hỏi AI về một trang sách cho
> ra câu trả lời rất tốt — rồi câu trả lời đó chìm vào chat history và biến mất
> khỏi đời sống học tập. Công sức bỏ ra là thật, kết quả giữ lại bằng không.

**Với Reado:** Từ vựng trích ra được lưu dưới dạng dữ liệu có cấu trúc, chứ không
phải một khối văn bản. Có cấu trúc thì mới lên lịch ôn được, tra cứu được, thống kê
được, và xuất ra được.

Thứ được giữ vĩnh viễn là **từ vựng**. Artefact đọc — text trang, bản dịch song
ngữ, tóm tắt — chỉ được giữ cho **vài phiên đọc gần nhất** của mỗi collection có
tên, đủ để mở lại mấy trang vừa đọc. Ảnh gốc không bao giờ được lưu.

Hai lý do cho giới hạn này: toàn văn trang sách là bề mặt bản quyền lớn hơn hẳn một
câu trích, và nhu cầu đọc lại có thật nhưng chỉ với vài trang gần nhất, không phải cả
cuốn.

**Chống lại:** Biến Reado thành một chat interface đẹp hơn. Nếu người dùng vẫn
phải copy thủ công từ câu trả lời sang nơi khác, Reado chưa giải quyết được gì.

---

## 6. Journey Over Summary

> **Philosophy:** Đọc bản tóm tắt thay cho việc đọc sẽ lấy đi đúng phần có giá trị
> nhất: quá trình vật lộn với câu chữ. Với người học ngoại ngữ, cái giá còn đắt
> hơn — quá trình đó *chính là* việc học.

**Với Reado:** Bản tóm tắt xuất hiện **sau** khi đọc, đóng vai trò công cụ tự
kiểm tra: *"mình hiểu đúng trang này chưa?"* Nó không thay thế trang sách.

Nguyên lý này **không** cấm ghi nhận tiến bộ — nó cấm tiến bộ ảo. Số đo có thật (số
thẻ vừa ôn, chuỗi ngày ôn, từ vừa lên mức) là phản chiếu hành trình. Mỗi từ đi qua
bốn mức, và mức cuối nằm ở chính việc đọc chứ không ở thẻ:

| Mức | Nghĩa |
|---|---|
| Mới | Đã lưu, chưa ôn |
| Đang học | Đang ôn, chưa vững |
| Đã nhớ | Scheduler ước lượng nhớ được lâu |
| **Đã thấm** | Gặp lại khi đọc sách thật và nhận ra |

**Chống lại:** Chế độ "đọc nhanh 10 cuốn sách qua tóm tắt". Điều đó có thể hợp lý
với một app đọc sách, nhưng với một app học ngôn ngữ thì nó phá huỷ chính cơ chế
tạo ra tiến bộ. Và tiến bộ ảo: điểm/XP, huy hiệu không gắn với việc đã làm, bảng
xếp hạng.

---

## Retention Is A Solved Problem — Use The Solution

Nguyên lý 3 và 4 nói về việc *thu thập* từ vựng. Việc *giữ* nó thì không cần phát
minh lại: đường cong quên của Ebbinghaus đã được biết đến hơn một thế kỷ, và
spaced repetition là câu trả lời đã được kiểm chứng qua nhiều thế hệ công cụ, từ
thẻ giấy Leitner đến SM-2 của SuperMemo, rồi FSRS mà Anki dùng hiện nay.

Reado không sáng tạo gì ở tầng này. Nó dùng một scheduler đã được chứng minh, và
dồn toàn bộ nỗ lực vào phần chưa ai làm tốt: **đưa đúng từ vào bộ ôn tập, kèm đủ
ngữ cảnh, mà không bắt người dùng gõ lại một chữ nào.** Ôn thêm ngoài lịch chỉ ghi
lại, không đổi lịch mà scheduler đã tính; lần nhận ra từ khi đọc cũng vậy.

Scheduler giải được **khi nào** ôn một thẻ, không giải được **bao nhiêu** thẻ đổ
vào. Đọc hăng một buổi là đủ sinh ra lượng thẻ mới mà nhiều ngày không học hết — và
con số tồn đọng đó đủ làm người ta bỏ app. Reado không đòi học hết: **mỗi ngày giữ
thêm vài từ là đủ**. Việc của app là ưu tiên từ đáng học trước — từ của thứ đang
đọc, từ gặp lại nhiều lần — và để phần còn lại được phép chờ.

---

## Conclusion

Triết lý cốt lõi của Reado:

> **Đọc sách thật. Không mất gì.**

Người dùng vẫn đọc thứ họ muốn đọc, ở độ khó thật của nó. Reado chỉ đảm bảo rằng
mọi **từ** họ học được trên đường đi đều ở lại với họ. Trang sách thì phần lớn
trôi đi, chỉ vài phiên gần nhất được giữ để đọc lại — đó là đánh đổi có chủ ý ở
nguyên lý 5.

Vòng lặp khép lại khi từ quay về trang sách:

> **đọc → khựng → giữ → ôn → nhận ra khi đọc tiếp**

Khoảnh khắc nhận ra một từ cũ giữa trang mới là bằng chứng mạnh nhất rằng Reado
đang làm đúng việc của nó.
