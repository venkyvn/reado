/**
 * storage/migrate.ts — migration đánh số tăng dần, bảng `_migrations`.
 *
 * Nguyên tắc (solution-design mục 5): KHÔNG sửa DDL của version cũ — mỗi lần
 * đổi schema là một file migration mới gắn sau. Bảng _migrations là hạ tầng,
 * không nằm trong schema sản phẩm.
 *
 * Chạy trên `SyncDb` (lõi đồng bộ) vì migration luôn diễn ra ở nơi DB sống:
 * trong Worker lúc boot (browser) hoặc in-process (Node/vitest) — không bao giờ
 * đi qua RPC, để boot không phụ thuộc mạng message.
 */
import schemaSql from "./schema.sql?raw";
import type { SyncDb } from "./syncDb";
import { toUtcIso } from "../domain/utils";

interface Migration {
  version: number;
  name: string;
  sql: string;
}

export const MIGRATIONS: readonly Migration[] = [
  { version: 1, name: "schema R1", sql: schemaSql },
  {
    // v2 — bảng sự kiện "đã phân tích một trang" (task 3.5, FR-14 + NFR-02):
    //   - FR-14 "số trang đã phân tích" = COUNT(*) ở đây. Sự kiện thật chứ
    //     KHÔNG phải counter trong settings — cùng luật "đếm từ log, không từ
    //     cột counter" của FR-11 (counter và log lệch nhau là lỗi vô hình).
    //   - NFR-02 "đo và ghi lại": mỗi lần gọi lưu latency + token bên cạnh
    //     provider/model/cefr/prompt_version — là dữ liệu M-03 cần về sau.
    //   - KHÔNG ghi api_key (điều cấm #9). Ảnh không lưu (NFR-04) — chỉ số đo.
    // Ghi chú đánh số: bảng tags/synonyms/antonyms của task 3.12 giờ là v3
    // (docs/rich-vocab-cram-ddl.md đã ghi chỗ này).
    version: 2,
    name: "analyses FR-14/NFR-02",
    sql: `
      create table analyses (
        id             text primary key,
        analyzed_at    text not null,   -- UTC ISO-8601
        cefr           text,            -- cefr_level dùng cho lần gọi này
        provider       text,
        model          text,
        prompt_version integer,
        latency_ms     integer,
        tokens_in      integer,
        tokens_out     integer
      );
      create index idx_analyses_time on analyses (analyzed_at);
    `,
  },
  {
    // v3 — Rich Vocabulary (task 3.12, docs/rich-vocab-cram-ddl.md mục 2):
    // 3 cột TEXT JSON trên vocab_items (tags/synonyms/antonyms), AI sinh kèm
    // capture + user sửa được. Rỗng = '[]'. Chọn TEXT JSON thay bảng junction
    // vì payload sync nhẹ + quy mô cá nhân — đã cân nhắc trong doc mục 2.
    // Additive-only: không đụng một dòng DDL nào của v1.
    version: 3,
    name: "rich vocab tags/synonyms/antonyms",
    sql: `
      alter table vocab_items add column tags     text not null default '[]';
      alter table vocab_items add column synonyms text not null default '[]';
      alter table vocab_items add column antonyms text not null default '[]';
    `,
  },
  {
    // v4 — Kho phiên đọc bền theo collection (task 3.15, Q-10-reopen 2026-09-09).
    // A-08 của PRD bị bác bỏ bằng thực tế dùng thử: user MUỐN đọc lại trang đã
    // đọc → lưu lại text bài đọc (segments + summary). Ảnh trang VẪN cấm
    // (phần ảnh của NFR-04 giữ nguyên; chỉ nới phần text — ghi MVP_PLAN mục 1/4).
    //
    //   - 1 dòng = 1 trang đã phân tích thành công (một lần gọi AI).
    //   - `id` = id của dòng analyses tương ứng (hai bảng ghi cùng lúc) —
    //     provenance trực tiếp, không cần cột FK riêng.
    //   - `segments` TEXT JSON [{sourceEn, translationVi}] — đủ để vẽ lại màn
    //     đọc; KHÔNG lưu ảnh, KHÔNG lưu page_text thô.
    //   - `vocabulary` TEXT JSON AnalyzedItem[] — bắt buộc phải giữ: gloss tô
    //     từ ở màn đọc VÀ nút "Chọn từ" của trang CHƯA lưu đều cần vocabulary
    //     (không có nó thì trang chưa lưu không thể duyệt/lưu lần sau). Bản
    //     này có thể stale sau khi user sửa từ ở màn duyệt — chấp nhận: gloss
    //     chỉ là trợ giúp đọc, nguồn sự thật là vocab_items.
    //   - `vocab_count` để thẻ tóm tắt không phải parse JSON mỗi lần list.
    //   - saved_at null = trang CHƯA được "Chọn từ → Lưu" — luật "lưu 1 lần"
    //     (bug 6723302) giờ persist theo DB thay vì chết theo phiên.
    //   - Trim 10 mới nhất/collection nằm ở repo (mỗi lần insert, cùng một
    //     transaction) — không dùng trigger, thấy được bằng test.
    version: 4,
    name: "reading sessions per collection",
    sql: `
      create table reading_sessions (
        id             text primary key,          -- = analyses.id của lần gọi
        collection_id  text not null references collections(id) on delete cascade,
        segments       text not null,             -- JSON [{sourceEn, translationVi}]
        vocabulary     text not null default '[]',-- JSON AnalyzedItem[]
        summary_vi     text not null default '',
        vocab_count    integer not null default 0,
        created_at     text not null,             -- UTC ISO-8601
        saved_at       text,                      -- null = chưa "Chọn từ → Lưu"
        saved_count    integer not null default 0
      );
      create index idx_rsessions_coll_time on reading_sessions (collection_id, created_at desc);
      create index idx_rsessions_time on reading_sessions (created_at desc);
    `,
  },
];

/** Áp các migration chưa chạy (trong một transaction), trả version hiện tại. */
export function migrate(db: SyncDb): number {
  db.exec(`create table if not exists _migrations (
    version integer primary key,
    name text not null,
    applied_at text not null
  )`);
  // Bảng hạ tầng thứ hai: marker boot chứng minh dữ liệu sống qua reload (xem
  // bootProbe.ts). Cùng nhóm với _migrations — KHÔNG phải schema sản phẩm, nên
  // không nằm trong schema.sql và không cần một version migration riêng.
  db.exec(`create table if not exists _boot_probe (
    key text primary key,
    value text not null
  )`);
  db.transaction(() => {
    const row = db.get<{ v: number }>("select max(version) as v from _migrations");
    let current = row?.v ?? 0;
    for (const m of MIGRATIONS) {
      if (m.version <= current) continue;
      db.exec(m.sql);
      db.exec("insert into _migrations (version, name, applied_at) values (?, ?, ?)", [
        m.version,
        m.name,
        toUtcIso(new Date()),
      ]);
      current = m.version;
    }
  });
  return db.get<{ v: number }>("select max(version) as v from _migrations")?.v ?? 0;
}
