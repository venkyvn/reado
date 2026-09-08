/**
 * storage/migrate.ts — migration đánh số tăng dần, bảng `_migrations`.
 *
 * Nguyên tắc (solution-design mục 5): KHÔNG sửa DDL của version cũ — mỗi lần
 * đổi schema là một file migration mới gắn sau. Bảng _migrations là hạ tầng,
 * không nằm trong schema sản phẩm.
 */
import schemaSql from "./schema.sql?raw";
import type { AppDb } from "./db";
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
export function migrate(appDb: AppDb): number {
  appDb.exec(`create table if not exists _migrations (
    version integer primary key,
    name text not null,
    applied_at text not null
  )`);
  appDb.transaction(() => {
    const row = appDb.get<{ v: number }>("select max(version) as v from _migrations");
    let current = row?.v ?? 0;
    for (const m of MIGRATIONS) {
      if (m.version <= current) continue;
      appDb.exec(m.sql);
      appDb.exec("insert into _migrations (version, name, applied_at) values (?, ?, ?)", [
        m.version,
        m.name,
        toUtcIso(new Date()),
      ]);
      current = m.version;
    }
  });
  return appDb.get<{ v: number }>("select max(version) as v from _migrations")?.v ?? 0;
}