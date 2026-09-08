-- schema.sql — DDL SQLite của Reado R1, chuyển từ docs/solution-design.md mục 5.
--
-- Ba chỗ bắt buộc khi chuyển dialect (AGENTS mục 5):
--   1. uuid        → TEXT 32 ký tự hex không gạch, client sinh (crypto.randomUUID)
--   2. timestamptz → TEXT ISO-8601 UTC `...Z` (giữ tính tuyệt đối; "ngày" tính ở tầng đọc)
--   3. jsonb       → TEXT chứa JSON (fsrs_params) — R1 không query JSON
--
-- Ghichú 2026-09-08: DEFAULT cefr_level ở đây là 'B1' (owner xác nhận B1 ở task
-- 0.5), KHÁC văn bản solution-design ghi 'B2' — mâu thuẫn đã ghi MVP_PLAN mục 4.
-- KV dựa vào "Chốt về product" (B1) chứ không theo typo trong bản nháp DDL.

create table collections (
  id          text primary key,
  name        text not null,
  is_default  integer not null default 0 check (is_default in (0,1)),
  created_at  text not null
);

create table vocab_items (
  id               text primary key,
  collection_id    text not null references collections(id),
  term             text not null,          -- đúng dạng đã gặp, KHÔNG đưa về nguyên thể
  term_normalized  text not null,          -- lowercase + trim; KHÔNG lemmatize (Q-06)
  pos              text not null check (pos in ('noun','verb','adj','adv','phrase','other')),
  ipa              text,
  meaning_vi       text not null,
  example          text not null,          -- câu thật trên trang (đã qua xác minh FR-02)
  cefr             text check (cefr in ('A2','B1','B2','C1')),
  created_at       text not null
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
  due_at         text not null,               -- UTC; KHÔNG tính lại on the fly (fuzz!)

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
  cefr_level       text not null default 'B1',  -- owner chốt B1 2026-09-08
  daily_new_limit  integer not null default 10,

  -- BYOK (Q-03) — key của CHÍNH user, lưu local (NFR-07)
  ai_provider      text not null default 'gemini',
  ai_base_url      text not null default 'https://generativelanguage.googleapis.com',
  ai_api_key       text,                     -- null = chưa nhập; app nhắc khi capture đầu tiên
  ai_model         text,

  request_retention real not null default 0.9,
  maximum_interval  integer not null default 36500,
  enable_fuzz       integer not null default 1 check (enable_fuzz in (0,1)),
  day_cutoff_hour   integer not null default 4 check (day_cutoff_hour between 0 and 23),

  fsrs_params       text,   -- JSON: 19 (FSRS-5) hoặc 21 (FSRS-6) phần tử; null = default
  fsrs_version      text    -- version đi cùng params — tránh silent breakage
);