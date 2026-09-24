> ⚰️ **BIA MỘ (2026-09-18; chuyển vào archive 2026-09-18).** Mô tả kiến trúc thế hệ PWA, đã bị thay bởi các quyết định v2 (09-17): iOS native + proxy hybrid. Bản solution design v2 thay tại chỗ ở [solution-design.md](../solution-design.md) (ROADMAP task 0.6, 2026-09-18). File này chỉ còn giá trị tham khảo lịch sử — KHÔNG lấy làm nền cho work mới.

# Solution Design — Reado R1

| Field | Value |
|---|---|
| Status | **v0.1 — owner duyệt 2026-09-08** ("OK — scaffold ngay", archive/mvp-plan-pwa-gen mục 6). Mọi quyết định "mở" vẫn gắn nhãn, không có chỗ bị lấp thầm |
| Created | 2026-09-08 |
| Last updated | 2026-09-08 |
| Related | [prd.md](../prd.md) (FR/NFR/M/A), [prompt-spec.md](../prompt-spec.md) (hợp đồng AI), [research/vocabulary-structure.md](../research/vocabulary-structure.md) (schema logic), [research/review-scheduling.md](../research/review-scheduling.md) (FSRS), [research/vocabulary-card-design.md](../research/vocabulary-card-design.md) (thẻ), [mvp-plan-pwa-gen.md](mvp-plan-pwa-gen.md) (tiến độ PWA cũ) |
| Phạm vi | Trả lời "thế nào" cho **R1**. Kiến trúc, data layer, AI layer, hàng đợi, PWA. Không lặp lại spec — mỗi quyết định trỏ về FR/NFR nguồn |

**Tài liệu này tự chứa.** Nó được viết để một session mới không có bối cảnh cuộc
thảo luận vẫn đọc và implement được, nhưng nó **giả định đã đọc nhóm docs ở bảng
trên**. Thứ gì docs kia đã chốt thì doc này chỉ trỏ tới, không tranh luận lại; thứ
gì docs kia còn mở thì doc này ghi rõ "MỞ", không tự điền.

---

## 1. Doc này trả lời câu hỏi gì

PRD mục 13 đẩy kiến trúc kỹ thuật ra ngoài với điều kiện Q-01 → Q-03 phải chốt
trước. Ba câu đó đã chốt 2026-09-08 (PWA mobile-first · SQLite local-first · BYOK),
nên doc này ra đời. Nó là bản đồ cho hai mốc:

- **Phase 1:** scaffold `app/` (task 1.3) đứng trên đúng ranh giới module ở mục 3.
- **Phase 2:** walking skeleton — `chụp → phân tích → duyệt & sửa → lưu → ôn` với
  FR-01 → FR-02 → FR-03 → FR-09 → FR-11 + FR-12 và collection mặc định (FR-17), đúng
  slice đã chốt trong AGENTS mục 6.

## 2. Nền quyết định đã chốt (không tranh luận lại)

| # | Quyết định | Nguồn |
|---|---|---|
| Q-01 | PWA mobile-first; iOS không có push thật (chấp nhận) | AGENTS mục 3 |
| Q-02 | Local-first, **SQLite** — client giữ toàn bộ DB, server (nếu có sau này) chỉ là relay | AGENTS mục 3, 5 |
| Q-03 | **BYOK**: user nhập API key + base URL trong app (default Gemini); không backend, không proxy ở MVP | AGENTS mục 3 |
| Q-06 | **Không lemmatize** `term_normalized` — giữ nguyên dạng từ | AGENTS mục 3 |
| Q-10 | Buffer cuộn **10 trang, xoá khi hết phiên** — ⚠ **ĐẢO 2026-09-09:** 10 phiên đọc (text+dịch) bền PER COLLECTION, bảng `reading_sessions`; xem mục 11 (bia mộ) + AGENTS mục 3 | AGENTS mục 3 |
| Q-12 | **Learning steps TẮT** ở MVP — thẻ mới sau lần chấm đầu đi thẳng vào review (interval ≥ 1 ngày) | AGENTS mục 3 |
| Q-08/Q-09 | Ngưỡng "đã thuộc" + phạm vi bộ lọc FR-10: **MỞ, chốt sau khi có dữ liệu thật** — cùng FR-19 leech | AGENTS mục 3 |
| — | Stack **Vite + React + TS**; storage chính SQLite-WASM + OPFS, fallback IndexedDB/Dexie | archive/mvp-plan-pwa-gen mục 1 + task 1.2 |
| — | Provider mặc định **Gemini API chính thức**; model khả dụng đã kiểm thật: `gemini-3.6-flash` | archive/mvp-plan-pwa-gen mục 1 + kết quả 0.4 |
| — | UI-1 bản song ngữ **xen kẽ theo đoạn** | AGENTS mục 7 |
| — | **iPhone là thiết bị test chính**; ưu tiên SPIKE storage trên iPhone | archive/mvp-plan-pwa-gen mục 1 |
| — | App code nằm trong **subfolder `app/`** của repo | archive/mvp-plan-pwa-gen mục 1 |

Ba quyết định trong research docs mà implement hay quên (AGENTS mục 5):

1. `cards.state` có **bốn** giá trị (`new`/`learning`/`relearning`/`review`) — không gộp.
2. `review_logs` lưu **ảnh chụp TRƯỚC khi chấm** (suy ra được state-sau, giữ được undo).
3. **Không có `unique`** trên `vocab_items` — một dòng là một nghĩa.

## 3. Kiến trúc tổng thể

### 3.1 Hình thái

```
app/
  src/
    domain/      — thuần TS, KHÔNG import DB/network. FSRS wrapper + queue + verification
    storage/     — interface repository + adapter SQLite (về sau dễ đổi binding)
    ai/          — interface provider + adapter Gemini + prompt + validate schema
    ui/          — React: pages/components; CHỈ nói chuyện với domain qua use-case
    app/         — bootstrap, settings, service worker đăng ký
```

**Dependency rule** (một chiều, ai cũng trỏ về `domain`, `domain` không trỏ ra ngoài):

- `ui` dùng `domain`; `domain` không biết data ở đâu — nó nhận/trả dữ liệu thuần.
- `storage` và `ai` **implement interface do `domain` định nghĩa** (repository pattern).
- `ai` là một "repository" kiểu khác: vào = ảnh, ra = dữ liệu thuần; domain xác minh.

Vì sao quan trọng từ ngày đầu:

1. **Lối đi Capacitor/native sau này** (đã hứa trong PRD mục 11): đổi chỉ ở binding
   — SQLite native thay SQLite-WASM, camera native thay input file. `domain` + `ui`
   không đổi một dòng.
2. **Offline ôn tập** (NFR-03) gần như miễn phí: domain không mạng, storage local.
3. **Kiểm thử rẻ**: logic ôn/hàng đợi/undo là pure function, test không cần DB.

### 3.2 Module ngăn gọn

| Module | Trách nhiệm chính | FR phục vụ |
|---|---|---|
| `domain/scheduler.ts` | Bọc `ts-fsrs`: `createCard()`, `grade(card, rating) → {card mới, log}` — thuần | FR-09, FR-12 |
| `domain/queue.ts` | Dựng hàng đợi hai nhánh (mục 7), đếm hạn mức, tính "hôm nay" (mục 6) | FR-11, FR-14, FR-18 |
| `domain/verify.ts` | Normalize + ba nhánh verified/suspect/unverified + kiểm schema (prompt-spec mục 6 + 4) | FR-02 |
| `storage/db.ts` + `schema.sql` | Mở DB, migration, transactions | — |
| `storage/repos/` | `collections`, `vocabItems`, `cards`, `reviewLogs`, `settings` | FR-08, FR-16, FR-17 |
| `ai/provider.ts` | Interface `analyzePage(imageBase64, opts) → AnalyzeResult` | FR-02 |
| `ai/gemini.ts` | Adapter Gemini (đã chứng minh bằng script Phase 0) | FR-02 |
| `ai/prompt.ts` | Prompt + version — prompt là sản phẩm, version cùng git | FR-02 |
| `ui/pages/` | 8 màn hình (mục 10) | — |

Mọi chỗ vẽ UI để sau vào `ui/` — không bao giờ gọi AI hay mở DB trực tiếp trong
component; đi qua domain/storage để ranh giới mục 3.1 tồn tại thật.

## 4. Storage — SQLite-WASM + OPFS, fallback Dexie

### 4.1 Quyết định

| Tiêu chí | SQLite-WASM + OPFS | IndexedDB (qua Dexie) |
|---|---|---|
| Khớp Q-02 "SQLite local-first" | ✅ DDL và semantics đúng chốt | ❌ Không phải SQL; tự viết lại join/transaction |
| Query hai nhánh + filter FR-08 | ✅ SQL thật | ⚠️ Phải diễn đạt bằng API key- range |
| Transaction `cards`+`review_logs` | ✅ ACID | ⚠️ Transaction manual, dễ lệch |
| iOS Safari | ⚠️ OPFS history ngắn — **rủi ro chính, cần SPIKE** | ✅ Ổn định lâu năm |
| Lối đi native sau này | ✅ SQL nguyen re-use trực tiếp | ❌ Bỏ tất |

**Chọn SQLite-WASM + OPFS làm chính** vì hai lý do không đảo được: (1) Q-02 đã chốt
SQLite — nghiêng theo IndexedDB là ngầm đổi quyết định đã chốt; (2) toàn bộ logic
query phức nhất (hàng đợi mục 7) là SQL thật — viết lại bằng Dexie là nguồn bug thứ
hai. Compromise nằm ở chỗ khác: repository interface là ranh giới, nên **nếu SPIKE
trên iPhone thất bại, adapter Dexie viết sau mà domain không đổi** (đúng tinh thần
"SQLite chính, Dexie fallback" đã ghi trong task 1.2).

### 4.2 Rủi ro iOS và biện pháp

Rủi ro #1 của toàn bộ kiến trúc này: trình duyệt iOS có thể **thu hồi storage sau
~7 ngày** không mở app nếu người dùng chưa Add to Home Screen (chạy từ tab Safari).
Mitigation đã định sẵn, thứ tự ưu tiên:

1. **SPIKE trước hết** (bước 1 của Phase 2): cài DB + ghi + đọc lại trên iPhone —
   verify hành vi OPFS thật, không tin đồn.
2. **A2HS prompt** nhẹ nhàng trong app (PWA thêm vào Home Screen thì OS bảo vệ data).
3. **FR-16 export làm sớm** trong Phase 3 như phao cứu sinh (đã chốt archive/mvp-plan-pwa-gen mục 1).
4. Fallback Dexie nếu 1 thất bại.

Điều **không** được làm ngầm: nhảy sang IndexedDB "cho nhanh" trước khi chạy SPIKE —
đó là lấp một chỗ MỞ mà không ai nhìn.

### 4.3 Ngữ nghĩa timestamp — cái bẫy đi công tác

Lưu **mọi timestamp dưới dạng UTC tuyệt đối**, TEXT ISO-8601 dạng
`YYYY-MM-DDTHH:MM:SS.sssZ`. Không lưu offset giờ địa phương. Lý do chính xác là lỗi
AGENTS mục 5 đã cảnh báo: lưu giờ địa phương thì khi owner đi công tác đổi múi giờ,
toàn bộ lịch ôn lệch mà không có gì báo. UTC là điểm neo chung; "ngày học" là khái
niệm hiển thị được tính ở tầng đọc, không phải tầng lưu.

`due_at` so sánh trực tiếp với `now()` (đều UTC) — khó sai.

## 5. DDL SQLite (chuyển dialect từ Postgres của research) — 3 thứ bắt buộc phải nói rõ

> **Bản DDL đã triển khai trong code** được tách thành doc riêng:
> [db-schema.md](../db-schema.md) — nguồn áp dụng thật là
> `app/src/storage/schema.sql` (migration v1). Khối DDL dưới đây là bản thiết kế đóng
> băng từ 2026-09-08; hai khác biệt đã biết với `schema.sql` (cefr `B1` thay `B2`,
> PRAGMA nằm ngoài schema.sql) ghi ở db-schema.md mục 8.

AGENTS mục 5 bắt buộc nói rõ 3 chỗ khi chuyển dialect:

| Việc | Quyết định |
|---|---|
| `uuid` lưu dạng gì | **TEXT, 32 ký tự hex không dấu gạch**, client tự sinh qua `crypto.randomUUID()` (NFR-03 offline — không hỏi server xin id) |
| `timestamptz` giữ timezone không | **TEXT ISO-8601 UTC với `Z`** (mục 4.3). Giữ được tính tuyệt đối; "ngày" tính ở tầng đọc với múi giờ device + `day_cutoff_hour` (mục 6) |
| `jsonb` → gì | **TEXT chứa JSON** (`fsrs_params`). SQLite không có jsonb; không khai thác JSON trong query nào của R1 nên TEXT là đủ và thành thật |

DDL (bổ sung duy nhất so với research schema: 4 cột BYOK trong `settings` — hệ quả
trực tiếp của Q-03, không phải quyết định mới):

```sql
PRAGMA journal_mode = WAL;       -- an toàn dữ liệu thật (NFR-06) + snapshot; LƯU Ý (đo 2026-09-08): trên OPFS SQLite tự dùng journal_mode=delete (KHÔNG có WAL) — độ bền dựa vào transaction, không phải WAL (archive/mvp-plan-pwa-gen mục 4)
PRAGMA foreign_keys = ON;

create table collections (
  id          text primary key,           -- uuid hex, client sinh
  name        text not null,
  is_default  integer not null default 0
              check (is_default in (0,1)),
  created_at  text not null               -- ISO-8601 UTC '...Z'
);

create table vocab_items (
  id               text primary key,
  collection_id    text not null references collections(id),
  term             text not null,          -- đúng dạng đã gặp, KHÔNG đưa về nguyên thể
  term_normalized  text not null,          -- lowercase + trim; KHÔNG lemmatize (Q-06)
  pos              text not null
                   check (pos in ('noun','verb','adj','adv','phrase','other')),
  ipa              text,
  meaning_vi       text not null,
  example          text not null,          -- câu thật trên trang
  cefr             text check (cefr in ('A2','B1','B2','C1')),
  created_at       text not null
  -- CỐ Ý không có unique (research mục 6.3): một dòng = một nghĩa
);
create index idx_vocab_collection on vocab_items (collection_id);
create index idx_vocab_termnorm   on vocab_items (term_normalized);

create table cards (
  id             text primary key,
  vocab_item_id  text not null references vocab_items(id) on delete cascade,
  direction      text not null default 'receptive'
                 check (direction in ('receptive','productive')),

  -- fsrs state — BỐN giá trị, không gộp (research mục 3.2)
  state          text not null default 'new'
                 check (state in ('new','learning','review','relearning')),
  stability      real not null default 0,
  difficulty     real not null default 0,
  reps           integer not null default 0,
  lapses         integer not null default 0,
  learning_steps integer not null default 0,  -- Q-12: tắt → luôn 0 ở R1
  scheduled_days integer not null default 0,
  last_review_at text,                        -- null khi state='new'
  due_at         text not null,               -- UTC; KHÔNG trường nào tính lại on the fly (fuzz!)

  suspended_at   text,                        -- FR-19 leech (ngưỡng MỞ)
  unique (vocab_item_id, direction)
);
create index idx_cards_due on cards (due_at) where suspended_at is null;

create table review_logs (
  id                    text primary key,
  card_id               text not null references cards(id) on delete cascade,
  mode                  text not null check (mode in ('srs','cram','distinguish','recall')),
  rating                integer not null check (rating between 1 and 4), -- 1 Again .. 4 Easy

  -- ảnh chụp TRƯỚC khi chấm — nguồn của undo và training data
  state_before          text not null,
  stability_before      real not null,
  difficulty_before     real not null,
  learning_steps_before integer not null,
  due_before            text not null,
  elapsed_days          integer not null,
  scheduled_days        integer not null,

  reviewed_at           text not null
);
create index idx_logs_card_time on review_logs (card_id, reviewed_at);

create table settings (
  id               integer primary key default 1 check (id = 1),
  cefr_level       text not null default 'B2',
  daily_new_limit  integer not null default 10,

  -- BYOK (Q-03, chốt 2026-09-08) — key của CHÍNH user, lưu local (NFR-07)
  ai_provider      text not null default 'gemini',
  ai_base_url      text not null default 'https://generativelanguage.googleapis.com',
  ai_api_key       text,                     -- null = chưa nhập; app nhắc khi capture đầu tiên
  ai_model         text,

  request_retention real not null default 0.9,
  maximum_interval  integer not null default 36500,
  enable_fuzz       integer not null default 1 check (enable_fuzz in (0,1)),
  day_cutoff_hour   integer not null default 4  check (day_cutoff_hour between 0 and 23),

  fsrs_params       text,   -- JSON: mảng 19 (FSRS-5) hoặc 21 (FSRS-6) phần tử; null = default
  fsrs_version      text    -- ghi version đi cùng params — mảng trần mà thiếu version là silent breakage
);
```

Ghi chú implement:

- `boolean` → `integer 0/1` + `check` (SQLite không có boolean).
- Migration: schema version duy trì bằng bảng `_migrations`; mỗi lần đổi schema là
  một file migration đánh số tăng dần — nguyên tắc giống backend, không tự ý đổi
  DDL của version cũ.
- `review_logs.mode` ở R1 chỉ mang `srs`; cột giữ sẵn cho R2. Nếu thấy code ghi
  mode khác → bug.

## 6. "Một ngày" là gì — day cutoff

Không dùng nửa đêm hệ thống (review-scheduling mục 6.2). Định nghĩa duy nhất trong
toàn app:

> **Ngày học** bắt đầu lúc `day_cutoff_hour` (giờ địa phương của device, mặc định 4)
> và kéo dài 24h.

Mọi phép tính "hôm nay" — hạn mức thẻ mới, streak FR-14, số đến hạn FR-11 — phải đi
qua một hàm duy nhất `dayBounds(nowUtc, cutoffHour)` (domain) trả về
`[dayStartUtc, dayEndUtc)` dùng múi giờ device. Đây là chỗ duy nhất được đụng giờ địa
phương. Streak và hàng đợi dùng chung hàm này thì màn hình home không bao giờ nói
hai điều khác nhau về cùng một ngày (FR-14 criterion cuối).

Hàm này thuần → có unit test đầu tiên ngay khi scaffold (vùng lệch múi giờ).

## 7. Hàng đợi hai nhánh

FR-09 cho thẻ mới `due_at` ngay trong ngày, nên `due_at <= now()` không đủ (PRD mục
11 đã ghi). Hai nhánh tách biệt:

```
// đếm "đã giới thiệu hôm nay" — từ LOG, không counter (review-scheduling mục 6.1):
//   số dòng review_logs có state_before='new' và reviewed_at trong [dayStartUtc, dayEndUtc)
//   Toàn cục, KHÔNG theo phạm vi (FR-11: hạn mức áp trước khi lọc phạm vi)

// NHÁNH 1 — thẻ ôn lại (review/relearning): KHÔNG giới hạn
select * from cards
where state in ('review','relearning')
  and due_at <= :nowUtc
  and suspended_at is null
  and (:scopeIds is null or vocab_item_id in (...phạm vi...))
order by due_at asc;

// NHÁNH 2 — thẻ mới: giới hạn còn lại = daily_new_limit − giớiThiệuHômNay
select * from cards
where state = 'new'
  and due_at <= :nowUtc            -- FR-09: thẻ mới due ngay
  and suspended_at is null
  and (:scopeIds is null or vocab_item_id in (...phạm vi...))
order by due_at asc                -- tức thứ tự tạo (due_at = lúc tạo)
limit :remainingNew;
```

Chú ý implement: SQLite không bind list trực tiếp — khi `scopeIds` khác null thì nở
placeholder `IN (?, ?, ...)` theo số phần tử. Đoạn `in (...)` là giả mã cho chỗ đó;
code thật phải xử lý nở. Phạm vi rỗng (collection hết thẻ) → mảng con rỗng, không lỗi.

Thẻ mới trong ngày **được giới thiệu theo thứ tự lưu vào kho**. Khi
`state='new'` chưa từng chấm, giữ nguyên vậy; sau chấm đầu nó sang review theo Q-12
(không pha learning).

## 8. Chấm thẻ — transaction + undo

### 8.1 Một lần chấm = MỘT transaction

```
begin;
  insert into review_logs (… ảnh chụp TRƯỚC khi chấm, rating, mode='srs', reviewed_at)
  update cards set state=?, stability=?, difficulty=?, reps=?, lapses=?,
                   scheduled_days=?, last_review_at=?, due_at=?
       where id = :cardId;
commit;
```

Dữ liệu đi vào log là **trạng thái trước** (research mục 4). Nếu log không ghi mà
card đã đổi — review mất khỏi training data vĩnh viễn — nên hai câu lệnh **không
bao giờ** tách transaction.

### 8.2 Undo (FR-12 criterion cuối)

Bản chất của undo = bước lùi chính xác. Snapshot trước lúc chấm đã nằm trong
transaction trên; undo dùng **chính snapshot đó** (giữ trong memory của phiên ôn)
để quay ngược — một transaction thứ hai:

1. `delete from review_logs where id = :logId` (bản ghi sai biến mất khỏi training
   data — đúng, vì đó là bấm nhầm);
2. `update cards` khôi phục từng cột về giá trị snapshot.

**Phạm vi:** một bước — nút undo hiện ngay sau khi chấm, biến mất khi sang card kế
hoặc rời màn hình. Không dựng chuỗi undo nhiều tầng ở R1 (không FR nào đòi).

## 9. Learning steps OFF — hệ quả lên ts-fsrs

Q-12 tắt learning steps. Cách thể hiện trong `ts-fsrs`:

- `fsrs()` được tạo với config **không có learning steps** (mảng bước rỗng/vô hiệu
  hoá short-term phase) — thẻ mới sau lần chấm đầu tiên đi **thẳng sang `review`**
  với interval ≥ 1 ngày, kể cả bấm Again (ngày hôm sau gặp lại, không phải vài phút).
- Bất biến kiểm soát ở domain: `state='learning'` **không bao giờ xuất hiện** ở R1.
  Thấy state đó trong test là fail.

**ĐÃ CHỐT BẰNG CODE 2026-09-08 (hết MỞ):** cú pháp chính xác là
`generatorParameters({ enable_short_term: false })`. Bằng chứng không phải đọc doc
thư viện — là đầu dò Node chạy ts-fsrs 5.4.2 + 12 test xanh ở `app/src/domain/`:

- Thẻ mới + Again/Hard/Good/Easy → `card.state=Review`, `scheduled_days` 1/2/3/6, `due` ≥ ngày mai. `learning`/`relearning` không bao giờ xuất hiện.
- 3 test mục 9 chạy xanh (`scheduler.test.ts`): new+Again→Review, new+Good→due≥mai, review+Again→vẫn Review.

Việc đầu tiên của task 1.3 là viết 3 unit test đó: (1) card mới không rơi vào
`learning`; (2) chấm Good đêm nay → `due_at` ≥ ngày mai; (3) chấm Again → vẫn
`due_at` ≥ ngày mai. Đã làm xong 2026-09-08. ~~Nếu thư viện không hỗ trợ `state`
hành xử đúng chốt, báo lại owner — không âm thầm bật steps.~~ Thư viện hỗ trợ;
`R1` sẽ không có UI nào bật steps (núm bật lại thuộc R2 — mục 14.1).

## 10. AI layer — BYOK, cô lập provider, xác minh

### 10.1 Interface

```ts
// ai/provider.ts
interface AnalyzeResult {
  segments:     { source_en: string; translation_vi: string }[];
  vocabulary:   VocabularyItem[];   // 6 field theo prompt-spec mục 4
  summary_vi:   string;
}
analyzePage(imageBase64: string, mime: string): Promise<AnalyzeResult>;
```

`ai/gemini.ts` là adapter duy nhất hit network. Nó đọc 4 giá trị BYOK từ `settings`
(ai_provider/ai_base_url/ai_api_key/ai_model) — provider khác sau này chỉ là adapter
mới chung interface, đúng yêu cầu PRD mục 11 ("lớp gọi AI được cô lập để đổi
provider mà không viết lại app"). Request shape đã chứng minh hoạt động bằng script
Phase 0 (response_mime_type + response_schema), tái chế nguyên dạng.

Prompt nằm trong `ai/prompt.ts` kèm hằng `PROMPT_VERSION` — version đi cùng git, vì
prompt là sản phẩm (prompt-spec mục 1), và cần truy được "đợt kết quả này do prompt
nào sinh ra" khi đo M-03.

### 10.2 Xác minh bằng máy trước khi hiện cho người dùng

- Validate schema trước (mục 3 domain/verify) — lỗi schema → màn lỗi + retry,
  **không lưu bản ghi hỏng** (FR-02).
- Đối chiếu từng `example` với `segments[].source_en` ghép lại (prompt-spec mục 6;
  thuật toán đã chạy đúng 20/20 ở Phase 0). Item không khớp → nhãn **chưa xác minh**,
  mặc định bỏ chọn; người dùng vẫn sửa/giữ được (FR-02 criterion, FR-03).
- Ảnh mờ / không phải tiếng Anh → báo cụ thể, không tính phí lần gọi đó vào lịch sử
  (FR-04) — lịch sử là thứ Phase 3/NFR-02 cần, chốt sau.

### 10.3 Cost & số đo

NFR-02: R1 chỉ **đo và ghi lại** — mỗi lần gọi lưu token (usageMetadata) + thời
gian vào `last-run.json`-tương đương trong app (chỉ trong log, chưa cần màn hình).
Không đặt ngưỡng; khi có số thật rồi mới hỏi owner ngưỡng.

> **Cập nhật 2026-09-09 (task 3.5):** "ghi lại" giờ được persist thực sự — mỗi trang
> phân tích thành công là một dòng bảng `analyses` (migration v2: latency, token,
> provider/model/cefr/prompt_version; không key, không ảnh). Trang chủ FR-14 đếm số
> trang từ bảng này. Xem `docs/db-schema.md` mục 4.6.

## 11. Buffer cuộn — 10 trang, phiên, không persist

> ⚠ **BIA MỘ (Q-10-reopen, owner 2026-09-09 — task 3.15):** toàn bộ mục này đã bị
> thay thế. A-08 của PRD ("người dùng không cần đọc lại trang đã đọc") bị bác bằng
> thực tế dùng thử — mở lại app thấy mất phiên chụp là mất, không phải hành vi chấp
> nhận được. Quyết định mới của owner: lưu **chỉ text + dịch** của 10 phiên gần nhất
> **PER COLLECTION** vào bảng `reading_sessions` (migration v4) — phần ảnh của NFR-04
> vẫn giữ nguyên; DB là nguồn duy nhất, buffer in-memory đã xoá khỏi code. Chi tiết
> quyết định (3 điểm owner chốt) + DDL + vì sao từng cột: `docs/db-schema.md` mục 4.7
> + archive/mvp-plan-pwa-gen mục 1/4. Nội dung cũ bên dưới giữ nguyên để truy chuỗi lý do.

Bản song ngữ (FR-05/FR-06) và kết quả analysis của trang **trước khi lưu** đều không
vào DB; kể cả đã lưu vocabulary thì segments/summary vẫn chỉ là bộ nhớ phiên. Cụ thể:

- `domain/buffer.ts` giữ danh sách tối đa **10 trang** (Q-10), mỗi trang chỉ giữ
  `segments[]`, `summary_vi`, `vocabulary[]` + `imagePreview` (data URL nhỏ) cho thao
  tác "xem lại"; **ảnh gốc full-res không giữ sau analysis** (NFR-04).
- Hết phiên (đóng tab/app) → toàn bộ mất. Hành vi đúng, không phải bug (FR-06).
- Khi trang thứ 11 sắp đẩy trang cũ nhất ra và trang đó còn vocabulary chưa chọn lưu
  → cảnh báo trước khi trôi (FR-05 criterion cuối).

## 12. UI — màn hình và thứ tự build

### 12.1 Màn hình R1 (8)

| Màn | FR | Ghi chú design |
|---|---|---|
| Home | FR-14, FR-18 | Số đến hạn **thực sự sẽ ôn** (đã áp hạn mức) + phần tồn nhãn riêng + số trang đã phân tích + streak theo giờ chuyển ngày + nút Capture |
| Capture | FR-01, FR-17 | Tạo collection inline; mặc định = kho tạm; ≤ 3 thao tác từ mở app (NFR-08) |
| Analysis progress | FR-02 | Loading UX **phải đẹp** — đo Phase 0 p50 ≈ 18,9s, vượt ý định ban đầu; không màn hình đứng im |
| Read view | FR-05, FR-06 | Song ngữ xen kẽ (UI-1 chốt); tap từ → nghĩa + IPA tại chỗ; toggle ẩn/hiện dịch |
| Review & edit | FR-03, FR-09, FR-10 | Sửa mọi field; item chưa xác minh đánh dấu + bỏ chọn sẵn; mặc định chọn tất cả |
| Review | FR-11, FR-12 | Mặt trước `term`+`pos`; mặt sau `meaning_vi`+`ipa`+câu gốc+collection; 4 nút; undo 1 bước; số nợ ngoài phạm vi luôn thấy (FR-18) |
| Vocab list + Collections | FR-08, FR-17 | Filter collection/cefr/trạng thái; chuyển kho tạm nguyên lô; xoá collection phải chuyển từ trước |
| Settings | FR-15 | CEFR + daily limit + **BYOK** (key, base URL, model); request_retention để ẩn R1 |

Đây **không phải UI spec** — [PRD mục 13](../prd.md#13-out-of-scope) gạt
wireframe/design system khỏi phạm vi, và AGENTS mục 7 nhắc lại. Chi tiết thị giác tra
`ref/ui-ux-pro-max.md` khi ráp UI. **Ba bài toán tương tác (AGENTS mục 7):**
UI-1 ✅ chốt (xen kẽ theo đoạn); **UI-2** ✅ chốt 2026-09-08 (card rút gọn mở inline,
unverified lên đầu — đã build task 2.3); **UI-3** con số nợ FR-18 hiển thị ra sao —
vẫn MỞ, hỏi owner khi dựng task 3.9 (không tự chọn).

### 12.2 Thứ tự build (walking skeleton)

1. Scaffold PWA + DB + 1 unit test ngày-cutoff (task 1.3) → chạy trên iPhone.
2. SPIKE storage: ghi/đọc DB trên iPhone.
3. Capture → Analysis → Read view (FR-01, FR-02, FR-04, FR-05, FR-06) — chứng minh
   pipeline một lần gọi chạy trong app thật.
4. Review & edit → Save (FR-03, FR-09, FR-17 default collection).
5. Review queue + chấm + undo (FR-11, FR-12).
6. Màn phụ còn lại (FR-08, FR-15, FR-16, FR-14, FR-18).
7. FR-10/FR-19 bật khi Q-08/Q-09/ngưỡng leech chốt (task 3.1).

Mỗi bước xong = **toàn bộ acceptance criteria của các FR nó chạm pass** (contract
AGENTS mục 4).

## 13. PWA mechanics

- Manifest + service worker: shell (HTML/JS/CSS) cache → mở được offline.
- Dữ liệu ôn không qua SW (local DB) — ôn offline miễn phí; chỉ analysis cần mạng
  (NFR-03).
- A2HS prompt nhẹ (mitigation rủi ro iOS, mục 4.2). Không push (Q-01 chấp nhận).

## 14. Quyết định doc này đưa ra (ghi để truy) vs chỗ vẫn MỞ

### 14.1 Đề xuất mới của doc này (không phải chốt của owner — báo nếu không đồng ý)

| Quyết định | Lý do |
|---|---|
| Timestamp = TEXT ISO-8601 UTC `Z` | Mục 4.3 |
| uuid = hex 32 ký tự không gạch | Đơn giản nhất cho SQLite + client-sinh |
| `fsrs_params` = TEXT JSON | Mục 5 |
| 4 cột BYOK nằm trong bảng `settings` | Q-03 hệ quả trực tiếp; một chỗ cấu hình duy nhất |
| Undo 1 bước, trong-memory snapshot | Mục 8.2 |
| A2HS prompt | Mục 13 |
| tắt learning steps = `generatorParameters({ enable_short_term: false })` | Verify bằng code 2026-09-08 (mục 9); không phải đề xuất — là kết quả đo |

### 14.2 Vẫn MỞ (đã có mốc chốt riêng — KHÔNG lấp ở đây)

| Việc | Mốc |
|---|---|
| ~~Behaviour chi tiết của `ts-fsrs` khi tắt learning steps~~ — **ĐÃ CHỐT bằng code 2026-09-08** (`enable_short_term: false`, xem mục 9) | ~~Task 1.3, bước 1~~ Xong — 12 test xanh |
| SQLite-WASM + OPFS có sống được trên iPhone không | SPIKE đầu Phase 2 (mục 4.2) |
| Q-08/Q-09 ngưỡng "đã thuộc" + phạm vi FR-10; ngưỡng leech FR-19 | Khi có dữ liệu thật — task 3.1 |
| ~~UI-2,~~ UI-3 (bài toán tương tác còn lại) | ~~màn duyệt~~ Chỉ còn số nợ FR-18 — hỏi owner khi dựng task 3.9 |
| Tên model mặc định cho app (BYOK: user nhập; có gợi ý `gemini-3.6-flash`) | Owner chốt khi cấu hình lần đầu |
| Q-11 (R2) | Trước R2 |

Tất cả các chỗ MỞ này nếu người implement sau "thấy hiển nhiên" thì **giá trị của
hiển nhiên không được dùng** — điều cần làm là hỏi owner, đúng cam kết AGENTS mục 3.