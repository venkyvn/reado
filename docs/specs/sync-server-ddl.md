# Sync Server DDL — bản nháp (Later, chờ owner review)

> **Trạng thái: NHÁP — Later — không load-bearing.** Bản này chỉ là bản vẽ để owner
> duyệt từng bảng; **không** được dùng để đổi bất kỳ dòng code/schema nào của R1/R2.
> Nền quyết định: [multi-client-sync.md](docs/research/review.md) mục 9 (server = source
> of truth) + mục 7 (MS-01/08/09/10 đã chốt 2026-09-08). Mọi chỗ agent **tự đề xuất**
> trong bản này được gắn nhãn `[đề xuất]` — chưa chốt cho tới khi owner duyệt.

| Field | Value |
|---|---|
| Created | 2026-09-08 |
| Trạng thái | Nháp v0.1 — chờ owner review từng mục |
| Dialect | Postgres (Supabase: `public` schema, auth là `auth.users`, RLS bật) |
| Nền chốt | Server = source of truth · SaaS đa user (MS-01) · không lưu ảnh (MS-08) · kho tạm per-device (MS-10) · LWW `modified_at` (MS-09) |

---

## 1. Phạm vi bản nháp

**Trả lời:** hình dạng 6 bảng server (5 bảng dữ liệu + `graves`) + `user_settings`,
cơ chế USN một đếm chung, tombstone tự sinh bằng trigger, RLS từng user, và contract
của hai hàm `sync_push` / `sync_pull`.

**Không trả lời:** wire protocol chi tiết (JSON shape, retry, token), reuse cho
browser CRUD (Supabase PostgREST tự lo), và các câu hỏi còn mở MS-02/04/05/06/11/12/13
— liệt kê ở mục 8.

## 2. Các quyết định của bản nháp

| # | Quyết định | Lý do | Nguồn |
|---|---|---|---|
| D-1 | Timestamp server giữ **TEXT ISO-8601 UTC** như client (không dùng `timestamptz`) | Round-trip byte-bằng nhau; so sánh LWW là so chuỗi (định dạng cố định nên thứ tự chuỗi = thứ tự thời gian); không có chuyện trôi precision/timezone khi convert | Hệ quả của AGENTS mục 5 + note mục 9.4.4 |
| D-2 | `user_id uuid NOT NULL DEFAULT auth.uid()` — **không** FK vào `auth.users` | Xoá account trong auth không được phép kéo theo xoá lịch sử học tập; RLS đã đủ chặn người lạ | `[đề xuất]` |
| D-3 | **Một sequence USN toàn cục** `global_usn_seq` cho mọi user + mọi bảng | Pull chỉ cần "usn > cursor"; user đọc thêm điều kiện `user_id = me` nên không rò rỉ; một đếm duy nhất tránh bài toán per-tenant sequence (race) | Note mục 9.2 lỗ hổng #2 |
| D-4 | Tombstone (bảng `graves`) **tự sinh bằng AFTER DELETE trigger** — kể cả dòng chết do cascade | Xoá qua đường nào (browser CRUD, sync, cascade) cũng thành mộ; thiết bị khác không bao giờ bỏ sót | Note mục 9.2 lỗ hổng #4 |
| D-5 | Trigger `BEFORE INSERT OR UPDATE` gán `usn = nextval(...)` cho MỌI đường ghi | Browser CRUD (PostgREST) và sync cùng đi qua một cửa gán USN — không có đường ghi nào quên bump | Note mục 4.1 + 9.2 #8; MS-11 chốt cuối = trigger hay write service: **draft chọn trigger** `[đề xuất]` |
| D-6 | RLS `user_id = auth.uid()` trên mọi bảng | SaaS đa user (MS-01) — bảo mật ở tầng DB, không trông chờ app | MS-01 |
| D-7 | Server `collections` **không có** `is_default` | Kho tạm là con trỏ per-device nằm local, không sync (MS-10); cột đó chỉ sống ở client | MS-10 |
| D-8 | `user_settings` chứa tập con sync được; **BYOK (`ai_*`) + `default_collection_id` không bao giờ lên server** | Secrets giữ device (NFR-07 + mục 4.5); con trỏ kho tạm giữ device (MS-10) | NFR-07, MS-10, MS-12 `[đề xuất tập con]` |
| D-9 | `review_logs` trên server là **insert-only** (upsert = `on conflict do nothing`) | Log là ảnh chụp lịch sử, không có "phiên bản mới hơn" — cùng id push lại là retry, giữ nguyên dòng đầu | Note mục 4.3; MS-03 vẫn MỞ cho trường hợp 2 device chấm cùng thẻ |
| D-10 | `graves` giữ **vô hạn** (không purge) | Quy mô cá nhân chấp nhận được; purge chỉ khi có cơ chế heartbeat thiết bị — không thiết kế trước | MS-13 |

## 3. Hạ tầng sync (sequence + trigger functions)

```sql
-- MỘT đếm USN toàn cục (D-3). Số nhảy có khe hở là bình thường (cursor dùng ">", không dùng "liền kề").
create sequence global_usn_seq as bigint start with 1;

-- Đồng hồ chuẩn cho mọi timestamp TEXT của server (D-1)
create or replace function utc_iso(ts timestamptz default now())
returns text language sql immutable as
$$ select to_char(ts at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') $$;

-- Bump USN + điền modified_at nếu thiếu — gắn lên MỌI bảng dữ liệu (D-5)
create or replace function trg_bump_usn()
returns trigger language plpgsql as $$
begin
  new.usn := nextval('global_usn_seq');            -- server cấp, client KHÔNG được tự đánh
  if new.modified_at is null then
    new.modified_at := utc_iso();                  -- đường browser CRUD không gửi modified_at
  end if;
  return new;
end $$;

-- Tombstone tự sinh mỗi khi một dòng biến mất (D-4) — cascade đè thì mỗi con chết tự có mộ
create or replace function trg_make_grave()
returns trigger language plpgsql as $$
begin
  insert into graves (id, original_table, deleted_at, user_id, usn)
  values (old.id, tg_table_name, utc_iso(), old.user_id, nextval('global_usn_seq'))
  on conflict (id, original_table) do nothing;    -- mộ đã có (ví dụ grave từ device A áp trước) → giữ nguyên
  return old;
end $$;
```

Gắn trigger vào từng bảng (5 bảng dữ liệu):

```sql
create trigger t_bump_collections before insert or update on collections for each row execute function trg_bump_usn();
create trigger t_grave_collections after delete on collections for each row execute function trg_make_grave();
-- ... lặp y hệt cho vocab_items, cards, review_logs
-- user_settings: chỉ có t_bump (xem mục 4.6)
```

## 4. DDL bảng

Quy tắc chung của mọi bảng: `id text` (32 hex, như client), timestamp TEXT (D-1),
ba cột envelope `user_id / modified_at / usn` ở cuối, RLS (mục 5). Cột nội dung **giữ
nguyên vẹn** tên + check từ `app/src/storage/schema.sql` — trừ hai chỗ: bỏ `is_default`
(D-7) và nới `unique` thêm `user_id` (đa tenant).

### 4.1 `collections`

```sql
create table collections (
  id          text not null check (id ~ '^[0-9a-f]{32}$') primary key,
  name        text not null,
  created_at  text not null,
  -- is_default: KHÔNG có ở server (D-7)
  user_id     uuid not null default auth.uid(),
  modified_at text not null,
  usn         bigint not null default -1
);
```

### 4.2 `vocab_items`

```sql
create table vocab_items (
  id               text not null check (id ~ '^[0-9a-f]{32}$') primary key,
  collection_id    text not null references collections(id) on delete restrict,
  term             text not null,
  term_normalized  text not null,
  pos              text not null check (pos in ('noun','verb','adj','adv','phrase','other')),
  ipa              text,
  meaning_vi       text not null,
  example          text not null,
  cefr             text check (cefr in ('A2','B1','B2','C1')),
  tags             text not null default '[]',   -- JSON array, owner 2026-09-08 — docs/rich-vocab-cram-ddl.md
  synonyms         text not null default '[]',
  antonyms         text not null default '[]',
  created_at       text not null,
  user_id          uuid not null default auth.uid(),
  modified_at      text not null,
  usn              bigint not null default -1
);
```

> `on delete restrict` — xoá collection phải xử lý con trước (đúng flow FR-17 của app).
> Trên server, "xoá collection" luôn là: xoá từ → (cascade cards/logs + graves tự sinh) → xoá collection.

### 4.3 `cards`

```sql
create table cards (
  id             text not null check (id ~ '^[0-9a-f]{32}$') primary key,
  vocab_item_id  text not null references vocab_items(id) on delete cascade,
  direction      text not null default 'receptive' check (direction in ('receptive','productive')),
  state          text not null default 'new' check (state in ('new','learning','review','relearning')),
  stability      double precision not null default 0,
  difficulty     double precision not null default 0,
  reps           integer not null default 0,
  lapses         integer not null default 0,
  learning_steps integer not null default 0,
  scheduled_days integer not null default 0,
  last_review_at text,
  due_at         text not null,
  suspended_at   text,
  user_id        uuid not null default auth.uid(),
  modified_at    text not null,
  usn            bigint not null default -1,
  unique (user_id, vocab_item_id, direction)   -- nới thêm user_id so với client (đa tenant)
);
```

### 4.4 `review_logs` (insert-only theo D-9)

```sql
create table review_logs (
  id                    text not null check (id ~ '^[0-9a-f]{32}$') primary key,
  card_id               text not null references cards(id) on delete cascade,
  mode                  text not null check (mode in ('srs','cram','distinguish','recall')),
  rating                integer not null check (rating between 1 and 4),
  state_before          text not null,
  stability_before      double precision not null,
  difficulty_before     double precision not null,
  learning_steps_before integer not null,
  due_before            text not null,
  elapsed_days          integer not null,
  scheduled_days        integer not null,
  reviewed_at           text not null,
  user_id               uuid not null default auth.uid(),
  modified_at           text not null,
  usn                   bigint not null default -1
);
```

### 4.5 `graves` (tombstone)

```sql
create table graves (
  id             text not null check (id ~ '^[0-9a-f]{32}$'),
  original_table text not null check (original_table in ('collections','vocab_items','cards','review_logs')),
  deleted_at     text not null,                -- đóng vai modified_at của "sự kiện xoá" (LWW)
  user_id        uuid not null default auth.uid(),
  usn            bigint not null default -1,
  primary key (id, original_table)
);
```

> `deleted_at` là đồng hồ so cho chính sách "xoá thắng update khi `deleted_at ≥
> modified_at`" (multi-client-sync mục 9.4.4). Trigger mục 3 tự điền bằng `utc_iso()`.

### 4.6 `user_settings` (per-user, sync được — D-8)

```sql
create table user_settings (
  user_id           uuid not null default auth.uid() primary key,  -- đúng 1 dòng mỗi user
  cefr_level        text not null default 'B1',
  daily_new_limit   integer not null default 10,
  request_retention double precision not null default 0.9,
  maximum_interval  integer not null default 36500,
  enable_fuzz       integer not null default 1 check (enable_fuzz in (0,1)),
  day_cutoff_hour   integer not null default 4 check (day_cutoff_hour between 0 and 23),
  fsrs_params       text,
  fsrs_version      text,
  modified_at       text not null,
  usn               bigint not null default -1
);
-- trigger: chỉ t_bump (bảng này không tombstones — user xoá account thì auth tự dọn phía auth)
```

**Không có trên server (chỉ device-local):** `ai_provider / ai_base_url / ai_api_key /
ai_model` (BYOK — NFR-07), `default_collection_id` (MS-10), `sync_state` (cursor của device).

### 4.7 Indexes

```sql
-- Pull: where user_id = me and usn > cursor order by usn
create index idx_collections_owner_usn on collections (user_id, usn);
create index idx_vocab_owner_usn      on vocab_items (user_id, usn);
create index idx_vocab_owner_term     on vocab_items (user_id, term_normalized);
create index idx_cards_owner_usn      on cards (user_id, usn);
create index idx_cards_owner_due      on cards (user_id, due_at) where suspended_at is null;
create index idx_logs_owner_usn       on review_logs (user_id, usn);
create index idx_logs_owner_card      on review_logs (user_id, card_id, reviewed_at);
create index idx_graves_owner_usn     on graves (user_id, usn);
create index idx_graves_owner_table   on graves (user_id, original_table);
```

## 5. RLS (MS-01 — bảo mật nằm ở tầng DB)

Mẫu chung, lặp cho 6 bảng (`collections`, `vocab_items`, `cards`, `review_logs`,
`graves`, `user_settings`):

```sql
alter table collections enable row level security;

create policy collections_owner on collections
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
-- ... lặp với tên policy/bảng tương ứng cho 5 bảng còn lại
```

Kèm hướng dẫn Supabase: `revoke all on <tbl> from anon, authenticated;` xong `grant`
lại qua policy (mặc định dự án Supabase đã làm để cả PostgREST lẫn sync client).

## 6. Contract push/pull

### 6.1 Luật bất biến (thứ phải implement đúng khi spike — sửa ở đây thì phải qua owner)

| # | Luật |
|---|---|
| P1 | `sync_push(batch)` chạy trong **một transaction**; mỗi item độc lập — item lỗi KHÔNG rollback cả batch, gom vào `rejected` |
| P2 | **Insert** (id chưa có): luôn nhận — TRỪ khi đã có tombstone cùng `(id, table)` với `deleted_at ≥ payload.modified_at` (chặn hồi sinh trái phép) |
| P3 | **Update**: nhận khi `payload.modified_at ≥ row.modified_at`; ngược lại từ chối → `rejected` kèm bản hiện tại để client pull về |
| P4 | **Tie** (`payload.modified_at = row.modified_at`): nhận — trigger cấp USN mới nên "USN lớn hơn thắng" đúng chốt 9.4.4 |
| P5 | **Grave**: nếu dòng sống tồn tại và `live.modified_at > payload.deleted_at` → reject (giữ row, KHÔNG upsert mộ). Ngược lại: upsert tombstone `deleted_at = max(existing, payload)` rồi xoá dòng sống (nếu tồn tại) |
| P6 | **Update trỏ tới id đã chết / cha không tồn tại** (FK mồ côi — ví dụ log cho card đã bị xoá ở device kia): bỏ item này → `rejected` với reason; **không** insert lại để hồi sinh |
| P7 | `review_logs` theo D-9: push chỉ **insert**; cùng id đến lần hai là retry → `on conflict do nothing`, không đổi dòng đầu |
| P8 | Thứ tự item trong batch do **client topo-sort**: collections → vocab → cards → logs → graves (graves áp cuối batch); `user_settings` upsert theo P2/P3 với key `user_id`, vị trí trong batch tự do |
| P9 | Client chỉ đánh "sạch" (`usn ≠ -1`) cho id nào **được server xác nhận**; kết quả trả về per-item: `applied (id, usn_mới)` hoặc `rejected (id, reason, current_row?)` |
| P10 | `sync_pull(cursor, limit)`: trả mọi dòng (5 bảng + graves) có `usn > cursor AND user_id = me`, **order by usn**, phân trang bằng usn lớn nhất; client áp nguyên batch pull trong một transaction (update → graves xoá local) rồi mới lưu cursor mới |

Luồng một phiên (kế thừa draft agent ngoài, giữ nguyên): **login bắt buộc trước khi
sync** (guest không push — guest-first nghĩa là local-only cho tới khi claim) → `push`
(bước 1) → `pull` (bước 2). Client nhận lại usn từ push để xoá dòng dirty, hoặc nhận
lại qua pull kế tiếp (idempotent).

### 6.2 Bản nháp hàm (minh hoạ — NHÁP, chưa test; spike khi Later)

```sql
create or replace function sync_push(p_batch jsonb)
returns jsonb language plpgsql as $$
-- p_batch = {"items":[{"tbl":"collections","id":"<hex32>","row":{...}}, ...]}
-- Item "graves" dùng {"tbl":"graves","id":"<hex32>","row":{"original_table":"...","deleted_at":"..."}}
-- (Đoạn này minh hoạ mức ý tưởng; bản spike phải implement ĐÚNG P1..P9 ở trên.)
begin
  -- vòng lặp theo thứ tự client gửi (P8). Với mỗi item:
  --   tbl = graves  → P5: upsert tombstone (greatest deleted_at), xoá dòng sống nếu thỏa LWW, ngược lại reject
  --   tbl = review_logs → insert ... on conflict (id) do nothing (P7)
  --   tbl = collections/vocab_items/cards → P2+P3+P4:
  --     gate P2 trước: có grave cùng (id,tbl) với deleted_at >= payload.modified_at → rejected (reason "resurrect")
  --     insert into <tbl> select (jsonb_populate_record(null::<tbl>, item->'row')).*
  --     on conflict (id) do update set <các cột nội dung> = excluded.<tương ứng>
  --     where excluded.modified_at >= <tbl>.modified_at
  --     returning id, usn;   -- không có dòng trả về ⇒ stale ⇒ rejected (P3)
  --   FK error (P6) bắt ở item-level ⇒ rejected
  -- Đầu ra: {"applied":[{"id":"...","tbl":"...","usn":123}, ...],
  --          "rejected":[{"id":"...","tbl":"...","reason":"stale|orphan|resurrect","current":{...}}, ...]}
end $$;

create or replace function sync_pull(p_after_usn bigint, p_limit int default 500)
returns jsonb language plpgsql as $$
-- union all 6 bảng (5 data + graves):
--   select 'collections' as tbl, to_jsonb(c) as row, c.usn from collections c
--   where c.user_id = auth.uid() and c.usn > p_after_usn
--   union all ... (lặp cho vocab_items, cards, review_logs, graves theo cột riêng)
--   order by usn limit p_limit
-- Đầu ra: {"items":[{tbl, row, usn}, ...], "has_more": bool}
end $$;

grant execute on function sync_push(jsonb) to authenticated;
grant execute on function sync_pull(bigint, int) to authenticated;
```

> `sync_push`/`sync_pull` chạy `security invoker` — RLS (mục 5) đã giới hạn từng dòng,
> nên không cần `security definer` và không có đường lọt tenant khác.

## 7. Bẫy đã biết trước

1. **Đồng hồ device lệch** — LWW dùng `modified_at` của client; device đồng hồ sai sẽ
   luôn thắng (nhanh) hoặc luôn thua (chậm). Đây là rủi ro đã chấp nhận khi chốt
   MS-09; nếu sau này thành đau thật thì nâng cấp sang optimistic concurrency
   (base_usn) — không sửa chữa trong lúc dùng.
2. **Không bao giờ cho app tự ghi `usn`** — mọi giá trị client gửi lên đều bị trigger
   `trg_bump_usn` ghi đè (D-5). Đây là điểm tựa duy nhất của toàn hệ; bỏ trigger đi là
   chết toàn bộ cơ chế.
3. **Cascade đẻ graves hàng loạt** — xoá một vocab kéo theo N card + M log; mỗi con có
   một grave + một USN. Đúng thiết kế (mục 4.2), chỉ cần biết trước khi đo dung lượng.
4. **Retry phải nguyên batch** — upsert/do-nothing làm batch push idempotent; client
   gãy mạng giữa chừng thì gửi lại y nguyên, không cần đánh dấu gì phức tạp.
5. **Cursor là per-user** — `sync_state` device-local giữ map `user → last_sync_usn`;
   đổi account trên một máy phải đổi cursor theo. Lấy số của user A bắn sang user B
   là lệch ngay.
6. **graves vô hạn** — chấp nhận (D-10); KHÔNG ai được tự ý `delete from graves` khi
   chưa có cơ chế heartbeat thiết bị (MS-13).

## 8. Còn mở (không nằm trong bản nháp này)

| ID | Việc |
|---|---|
| MS-02 | Mobile App native hay Capacitor (ảnh hưởng bên client, không đổi DDL này) |
| MS-04 | Browser thin-client chấp nhận luôn online? |
| MS-05 | Trigger sync: tay / tự động / realtime? (quyết định hạ tầng pull) |
| MS-06 | BYOK per-device giữ mãi hay có proxy Later? (không lên server — bất kể câu trả lời) |
| MS-11 | Chốt cuối đường ghi gán USN: trigger (bản này đề xuất) hay write service riêng? |
| MS-12 | Danh sách `user_settings` sync được trong 4.6 — `[đề xuất]`, owner duyệt |
| MS-13 | Đời sống của change log/graves: vô hạn (hiện tại) hay snapshot + heartbeat? |
| — | **Spike bắt buộc khi Later mở:** đo push/pull với 10k dòng; hai thiết bị push đồng thời một dòng; test đồng hồ lệch; đo trigger trên path browser CRUD |

## Appendix A — phía client khi Later mở (migration additive, KHÔNG chạy bây giờ)

Nền là schema R1 đã đóng băng (`app/src/storage/schema.sql`). Khi Later thật sự mở,
migration **chỉ thêm cột**, không sửa cột cũ:

```sql
-- lặp cho collections, vocab_items, cards, review_logs:
alter table collections add column user_id     text    not null default 'guest';
alter table collections add column modified_at text    not null default '';  -- backfill = created_at lúc migrate
alter table collections add column usn         integer not null default -1;

-- vocab_items thêm 3 cột nội dung (owner 2026-09-08 — docs/rich-vocab-cram-ddl.md mục 2):
alter table vocab_items add column tags     text not null default '[]';
alter table vocab_items add column synonyms text not null default '[]';
alter table vocab_items add column antonyms text not null default '[]';

-- thêm bảng mới (client):
create table graves (
  id             text not null,
  original_table text not null,
  deleted_at     text not null,
  user_id        text not null default 'guest',
  usn            integer not null default -1,
  primary key (id, original_table)
);
create table user_settings (               -- bóng của 4.6, KEY theo user
  user_id       text primary key,
  cefr_level    text not null default 'B1',
  -- ... các cột còn lại như 4.6 ...
  modified_at   text not null,
  usn           integer not null default -1
);
create table sync_state (
  user_id        text primary key,          -- cursor theo từng user (bẫy 5)
  last_sync_usn  bigint not null default 0,
  last_synced_at text
);
-- settings (bảng R1) GIỮ NGUYÊN: BYOK + device-local; Later thêm cột default_collection_id (MS-10)
```

Toàn bộ cột `is_default` hiện có của `collections` **giữ nguyên ở client** (vẫn dùng
cho R1); payload sync lên server chỉ cần **bỏ** cột này (D-7).