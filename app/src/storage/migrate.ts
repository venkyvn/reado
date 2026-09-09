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
