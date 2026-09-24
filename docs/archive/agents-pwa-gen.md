> ⚰️ **BIA MỘ (2026-09-18)** — AGENTS.md thế hệ PWA (09-07..09-10). Đã thay bằng bản v2 (09-17), nay là [docs/agent-rulebook.md](../agent-rulebook.md). Lưu để truy chuỗi lịch sử — ĐỪNG dùng làm quy tắc hiện hành.

# Cách làm việc với bộ docs Reado

Đọc file này trước khi làm bất cứ việc gì khác trong repo.

Khi bắt đầu công việc **triển khai**: đọc [docs/session-brief.md](docs/session-brief.md) ngay sau file này
— nó là bản đồ nhanh về *đang ở đâu, làm gì tiếp, cần tránh gì*. Chỉ mở thêm doc chi tiết khi task cụ thể yêu cầu.

Bộ docs này **đầy đủ về nội dung nhưng cố ý chưa đầy đủ về quyết định.** Một số câu
hỏi được để mở có chủ ý, và chúng được ghi rõ ràng thay vì bị đoán. File này tồn
để bạn không lấp những chỗ trống đó bằng mặc định hợp lý rồi đi tiếp — vì mỗi mặc định
như vậy sẽ thành load-bearing, và đảo lại thì đắt.

---

## 1. Thứ tự đọc

Đọc theo thứ tự này. Nó đi từ *vì sao* tới *cái gì* tới *thế nào*, và mỗi tầng giả
định tầng trên đã đọc.

| # | Doc | Bạn lấy được gì |
|---|---|---|
| 1 | [docs/vision.md](docs/vision.md) | Sáu nguyên lý. **Đây là công cụ xử lý mọi chỗ mơ hồ** — xem mục 4 |
| 2 | [docs/prd.md](docs/prd.md) | FR đánh số tới FR-19 (FR-07 và FR-13 đã bỏ, còn 17 cái sống) kèm acceptance criteria, cộng non-goals, metrics, open questions |
| 3 | [docs/research/vocabulary-structure.md](docs/research/vocabulary-structure.md) | Data model đầy đủ (mục 6), ba chế độ ôn theo phạm vi, và **vì sao** schema trông như vậy |
| 4 | [docs/research/review-scheduling.md](docs/research/review-scheduling.md) | FSRS cần giữ state gì, review log là gì, bốn chỗ còn hở |
| 5 | [docs/prompt-spec.md](docs/prompt-spec.md) | Hợp đồng giữa AI và data model — prompt và output schema cho FR-02 |
| 6 | [docs/research/vocabulary-card-design.md](docs/research/vocabulary-card-design.md) | Nền lý thuyết của thiết kế thẻ. Đọc khi cần biết *vì sao mặt trước chỉ có `term`* |
| — | [docs/db-schema.md](docs/db-schema.md) | Schema SQLite R1 **đã triển khai** + vì sao từng cột, indexes, seed, bẫy. Đọc khi đụng storage/DB/migration — nguồn DDL thật là `app/src/storage/schema.sql` |
| — | [docs/multi-client-sync.md](docs/multi-client-sync.md) | Hướng kiến trúc **tương lai** (sync server). **Later — không load-bearing** cho R1/R2 |
| — | [docs/sync-server-ddl.md](docs/sync-server-ddl.md) | Bản nháp DDL server cho sync tương lai. **Later — nháp chờ owner review** |
| — | [docs/rich-vocab-cram-ddl.md](docs/rich-vocab-cram-ddl.md) | Thiết kế + DDL migration v2 cho 2 enhance: tags/synonyms/antonyms + Targeted review cram |
| — | [docs/vocab-import-plan.md](docs/vocab-import-plan.md) | Plan import từ vựng — chiều ngược của FR-16. **IMP-01→04 đã chốt, CHƯA code** — đọc khi làm task 3.16 |
| — | [idea.md](idea.md) | Ý tưởng gốc của owner, một trang. Đọc để hiểu provenance |
| — | [ref/pvo/](ref/pvo/) | **Không đọc để build R1.** Nguồn tham khảo cho tầng liên kết từ vựng ở R2 |
| — | [ref/ui-ux-pro-max.md](ref/ui-ux-pro-max.md) | Kho kiến thức UI/UX trích chọn. **Chỉ là tham khảo** — tra khi làm UI Phase 2 |

### Quy ước viết docs — cần biết để đọc đúng

- **Bia mộ tại chỗ.** FR bị bỏ (FR-07, FR-13) và quyết định đã chết **không bị xoá** —
  nằm nguyên chỗ cũ, đánh dấu BỎ hoặc gạch ngang. Thấy mục đánh dấu BỎ thì **đừng implement**, cũng đừng xoá.
- **Số hiệu FR không liên tục.** FR mới lấy số tiếp theo nhưng đặt vào epic đúng nghĩa. Đọc theo epic, không theo số.
- **Bảng "Đã chốt và chưa chốt"** ở cuối mỗi research doc là hợp đồng. Xem mục 2.

---

## 2. Những gì KHÔNG được tranh luận lại

Mỗi research doc có bảng **"Đã chốt"** ở cuối — kết quả đã cân nhắc rồi loại bỏ phương án khác.

| Bảng | Ở đâu |
|---|---|
| Tổ chức từ vựng, data model, chế độ ôn theo phạm vi | [vocabulary-structure.md mục 8](docs/research/vocabulary-structure.md#8-đã-chốt-và-chưa-chốt) |
| Tầng lịch ôn, FSRS state, review log | [review-scheduling.md mục 9](docs/research/review-scheduling.md#9-đã-chốt-và-chưa-chốt) |
| Thiết kế thẻ | [vocabulary-card-design.md mục 5](docs/research/vocabulary-card-design.md#5-đã-chốt-và-chưa-chốt) |

Thấy dòng trong ba bảng đó có vẻ sai: **báo lại, đừng sửa.** Nhiều quyết định nhìn phản
trực giác cho tới khi đọc lý do — ví dụ *"không có ràng buộc `unique`"* là lựa chọn có
ý thức để một từ nhiều nghĩa được nhiều dòng.

Ranh giới cứng khác:

- **Non-goals** — [PRD mục 3](docs/prd.md#3-non-goals), NG-01 đến NG-09. Đáng chú ý:
  **NG-09 cấm tự viết SRS algorithm** (dùng thư viện FSRS có sẵn), **NG-07 giữ đúng một
  input path là ảnh chụp** — không thêm import PDF/ebook.
- **Những hướng đã cân nhắc và loại bỏ** —
  [vocabulary-structure.md mục 11](docs/research/vocabulary-structure.md#11-phụ-lục--những-hướng-đã-cân-nhắc-và-loại-bỏ).
  Nếu định đề xuất topic tag do AI sinh, node khái niệm kiểu PVO, hay ràng buộc `unique`
  — đọc chỗ đó trước. (Lưu ý: *topic tag do AI sinh* đã được owner **mở lại có chủ ý**
  2026-09-08 — xem [docs/rich-vocab-cram-ddl.md](docs/rich-vocab-cram-ddl.md) mục 1.)

---

## 3. Những gì PHẢI HỎI, không được tự quyết

[PRD mục 12](docs/prd.md#12-open-questions) liệt kê các câu hỏi còn mở. Chúng **không
phải chỗ trống chờ được lấp bằng phán đoán tốt nhất** — chúng là quyết định của owner.
Hỏi, rồi đợi trả lời.

### Chặn mọi dòng code

| ID | Câu hỏi | Trạng thái |
|---|---|---|
| **Q-01** ✅ | Platform: PWA mobile-first hay native app? | **Chốt 2026-09-08: PWA mobile-first** |
| **Q-02** ✅ | Dữ liệu local-only hay cloud ngay từ đầu? | **Chốt 2026-09-08: local-first, SQLite** |
| **Q-03** ✅ | API key trên device hay sau một backend proxy? | **Chốt 2026-09-08: BYOK — key trên device** |

### Chốt được trong lúc làm, nhưng vẫn phải hỏi

| ID | Câu hỏi | Trạng thái |
|---|---|---|
| Q-06 ✅ | Có lemmatize `term_normalized` không | **Chốt 2026-09-08: không lemmatize** |
| Q-08 📌 | Ngưỡng "đã thuộc" đặt ở đâu | **Chốt 2026-09-08: để sau khi có dữ liệu review thật** |
| Q-09 📌 | Bộ lọc "đã thuộc" so khớp trong một collection hay toàn cục | **Chốt 2026-09-08: để sau** |
| Q-10 ✅ | Buffer cuộn giữ bao nhiêu trang | **Chốt 2026-09-09: lưu 10 phiên đọc gần nhất PER COLLECTION** |
| Q-11 | Hai chế độ R2 làm ước lượng thấp `stability` — xử lý thế nào | **Chốt một phần 2026-09-08:** cram theo chủ đề đi đường "chấp nhận" |
| Q-12 ✅ | Có bật learning steps trong ngày không | **Chốt 2026-09-08: tắt ở MVP** |

**Q-04, Q-05 và Q-07 đã có lời giải** ở bảng cuối mục 12. Đừng hỏi lại, đừng thiết kế lại quanh chúng.

### Cách hỏi cho hiệu quả

Đừng hỏi *"dùng platform nào?"*. Hỏi kèm đánh đổi bạn đã tìm ra từ docs, ví dụ:
*"NFR-03 đòi ôn tập chạy offline và FR-11 muốn nhắc ôn hàng ngày. PWA thì trên iOS
không có push notification thật — owner có chấp nhận đánh đổi đó, hay đó là lý do đủ
để chọn native?"* Câu hỏi dạng đó trả lời được trong một phút.

---

## 4. Cách xử lý chỗ mơ hồ

Khi docs không nói rõ một chi tiết, làm theo thứ tự này:

1. **Chiếu vào sáu nguyên lý của [vision.md](docs/vision.md).** Chúng được viết để làm
   chính việc này. Mỗi nguyên lý có mục *"Chống lại"* nói rõ nó loại bỏ điều gì.
2. **Kiểm với non-goals và bảng "Đã chốt".** Nếu phương án va vào một trong hai, nó sai
   bất kể nghe hợp lý tới đâu.
3. **Nếu vẫn mơ hồ và nó ảnh hưởng dữ liệu hay lịch ôn — hỏi.** Nếu chỉ ảnh hưởng chi tiết
   hiển thị, chọn phương án đơn giản nhất và ghi lại lựa chọn đó.

### Acceptance criteria là test case

Mỗi FR có criteria dạng **Given / When / Then**. Dùng trực tiếp làm test — đừng viết lại
thành ngôn ngữ khác. PRD ghi rõ: *một FR chỉ được coi là xong khi **toàn bộ** criteria của
nó pass.* Đây là lý do bộ docs không có test strategy riêng: nó đã nằm trong FR.

---

## 5. Data model — dialect SQLite local-first (chốt 2026-09-08)

Năm bảng: `collections`, `vocab_items`, `cards`, `review_logs`, `settings`. Cộng
`word_relations` ở R2. Schema đầy đủ ở
[vocabulary-structure.md mục 6.1](docs/research/vocabulary-structure.md#61-năm-bảng).

**Q-02 đã chốt: local-first → engine là SQLite.** DDL trong doc structure viết bằng
**Postgres** — `uuid`, `timestamptz`, `jsonb`, partial index — nên DDL đó **không phải
dialect sẽ dùng**. Khi chuyển dialect bắt buộc nói rõ ba thứ:

1. `uuid` lưu dạng gì — đề xuất TEXT hex, client tự sinh (NFR-03 offline)
2. timestamp lưu dạng gì, và **có giữ được timezone không** — mất timezone là loại lỗi
   chỉ hiện ra khi owner đi công tác, lúc đó toàn bộ lịch ôn đã lệch
3. `fsrs_params` lưu dạng gì — đề xuất TEXT chứa JSON

**Bản schema đã triển khai trong code được tách thành doc riêng:**
[docs/db-schema.md](docs/db-schema.md) — nguồn DDL thật là `app/src/storage/schema.sql`
(migration v1), pragmas/seed ở `syncDb.ts`. Làm việc với DB thật thì đọc doc đó.

### Ba chỗ trong schema dễ implement sai

Cả ba đều đã ghi lý do trong docs, nhưng chúng phản trực giác nên dễ bị "sửa" thành sai:

| Chỗ | Sai thường gặp | Đúng |
|---|---|---|
| `cards.state` | Chỉ làm `new` và `review` | **Bốn** giá trị. `learning` và `relearning` là hai pha khác nhau; gộp lại thì FSRS chấm `difficulty` sai và sai đó **tích luỹ** |
| `review_logs` | Lưu state **sau** khi chấm | Lưu ảnh chụp **trước** khi chấm. Không có nó thì mất undo và mất training data |
| Không có `unique` trên `vocab_items` | Thêm `unique (collection_id, term_normalized)` vào cho "đúng" | Cố ý không có. Một từ nhiều nghĩa được nhiều dòng; chống trùng nằm ở bộ lọc lúc trích xuất (FR-10) |

---

## 6. Build gì trước — walking skeleton

[PRD mục 10](docs/prd.md#10-release-scope) liệt kê R1 gồm 17 FR. **Đừng build song song
cả 17.** Có một vòng lặp mỏng chứng minh được toàn bộ giả định rủi ro nhất, và nó nên
chạy end-to-end trước khi thêm bất cứ gì.

```
chup trang  →  phan tich  →  duyet & sua  →  luu vao kho  →  on tap
  FR-01         FR-02          FR-03           FR-09        FR-11 + FR-12
```

Cộng một thứ nữa: **collection mặc định** (phần `is_default` của FR-17). Nó bắt buộc vì
`collection_id` không bao giờ null, nên phải luôn có chỗ tiếp nhận từ chưa phân loại.

Vì sao đúng slice này:

- Nó là vòng lặp ở [PRD mục 6](docs/prd.md) và là hiện thực của nguyên lý 3 và 5 trong vision
- Nó là thứ **duy nhất** chứng minh được A-01 và A-02 — hai giả định mà nếu sai thì kiến
  trúc pipeline phải viết lại, và sản phẩm mất lý do tồn tại
- Nó đủ để đo **M-07**, thứ mà PRD gọi là *acceptance test thật của cả sản phẩm*: owner
  có bỏ hẳn quy trình Gemini thủ công hay không

Phần còn lại của R1 — FR-04, FR-05, FR-06, FR-08, FR-10, FR-14, FR-15, FR-16, FR-18,
FR-19, và phần còn lại của FR-17 — làm sau khi vòng trên chạy thật.

---

## 7. UI/UX — chưa có spec, và có ba bài toán thật

[PRD mục 13](docs/prd.md#13-out-of-scope) gạt *"thiết kế UI/UX chi tiết, wireframe,
design system"* ra khỏi phạm vi PRD. Nên **chưa có UI spec** — nhưng có ràng buộc cứng
rải trong các FR, và có ba bài toán mà không design system nào giải được.

### Ràng buộc cứng phải tuân

| Nguồn | Ràng buộc |
|---|---|
| NFR-08 | Từ lúc mở app tới lúc chụp được trang: **≤ 3 thao tác** |
| FR-12 | Mặt trước thẻ **chỉ** có `term` và `pos`. Mặt sau có `meaning_vi`, `ipa`, câu gốc, tên collection |
| FR-01 | Tạo collection mới **ngay trong flow capture**, không rời flow |
| FR-18 | Số card đến hạn **nằm ngoài** phạm vi đang chọn phải **nhìn thấy được** |
| FR-17 | Kho tạm sắp theo thời gian, chọn được **nguyên lô** rồi chuyển collection trong một thao tác |

### Ba bài toán tương tác — hỏi owner, đừng tự chọn

1. **Bản song ngữ trên màn hình điện thoại** ✅ — **Chốt 2026-09-08: xen kẽ theo đoạn**
   (bản gốc rồi bản dịch ngay dưới từng đoạn, 0 thao tác thêm). Nguyên lý 2 của vision nói
   bản dịch *"luôn nằm sẵn ngay cạnh bản gốc"*.
2. **Màn hình duyệt từ vựng (FR-03 + FR-09).** ✅ — **Chốt 2026-09-08 (owner): card rút
   gọn, chạm mở inline** (term + pos + nghĩa tắt + chip trạng thái + checkbox); **unverified
   xếp LÊN ĐẦU + đánh dấu đỏ**.
3. **Con số nợ ở FR-18.** Yêu cầu là nó phải nhìn thấy được. Nhưng trình bày quá mạnh thì
   owner bỏ luôn chế độ ôn theo phạm vi. Một con số, hai kết cục trái ngược tuỳ cách hiển thị.

### Nguồn tham khảo ngoài (không load-bearing)

[ref/ui-ux-pro-max.md](ref/ui-ux-pro-max.md) — trích chọn từ skill "UI UX Pro Max" (MIT):
24 UX guideline, bảng màu gợi ý, bản đồ guideline → màn hình Reado. Trả lời *"chi tiết hiển
thị nên thế nào"*, **không** trả lời ba bài toán tương tác trên — ba bài đó vẫn là quyết định
của owner, và đây cũng không phải UI spec.

---

## 8. Chỗ docs vẫn còn im lặng

Ghi ra để bạn không mất thời gian tìm:

- **Prompt baseline thủ công của owner** — nguyên văn ở
  [prompt-spec.md mục 2](docs/prompt-spec.md#2-chỗ-trống-chặn-đường--prompt-baseline). Bản
  tạm thời, sẽ tinh chỉnh theo M-03. Bản prompt dựng lại ở mục 3 chạy thử được, nhưng
  **đừng dùng kết quả của nó làm bằng chứng cho A-02** — bằng chứng phải so với baseline thật ở mục 2.
- **Solution design doc** — [docs/solution-design.md](docs/solution-design.md) (v0.1, owner
  duyệt 2026-09-08). Kiến trúc + module boundary (dependency rule: mọi tầng trỏ về `domain`,
  `domain` không trỏ ra), DDL SQLite đủ 3 thứ bắt buộc, queue hai nhánh, transaction + undo,
  BYOK trong `settings`. Các chỗ vẫn MỞ liệt kê ở mục 14.2 — không lấp thầm.
- **Hình dạng query dựng hàng đợi ôn tập.** Cố ý không chốt trong research doc. Điều đã chốt:
  cần **hai nhánh** (thẻ mới bị giới hạn, thẻ ôn lại thì không) — xem
  [review-scheduling.md mục 6.1](docs/research/review-scheduling.md#61-một-mệnh-đề-where-không-dựng-nổi-hàng-đợi).
- **Ranh giới transaction của một lần chấm thẻ.** Update `cards` và insert `review_logs` phải
  cùng một transaction, vì nếu log không ghi thì review đó mất khỏi training data vĩnh viễn.
- **Thư viện FSRS cụ thể.** `ts-fsrs` được dùng làm implementation tham chiếu trong docs,
  nhưng **nếu Q-01 ra native thì phải đổi binding** — danh sách state cần giữ không đổi một dòng.