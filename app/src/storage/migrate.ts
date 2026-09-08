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
