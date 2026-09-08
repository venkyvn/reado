/**
 * storage/repos/collections.ts — repo collection (FR-01 chọn/tạo inline, FR-17 default).
 */
import type { CollectionsRepository } from "../../domain/repositories";
import type { CollectionRow } from "../../domain/types";
import { newId, toUtcIso } from "../../domain/utils";
import type { AppDb } from "../db";

interface ColSql {
  id: string;
  name: string;
  is_default: number;
  created_at: string;
}

function map(row: ColSql): CollectionRow {
  return {
    id: row.id,
    name: row.name,
    isDefault: row.is_default === 1,
    createdAt: row.created_at,
  };
}

export function createCollectionsRepo(appDb: AppDb): CollectionsRepository {
  return {
    async list() {
      return appDb.all<ColSql>(
        "select id, name, is_default, created_at from collections order by is_default desc, created_at asc",
      ).map(map);
    },
    async getDefault() {
      const row = appDb.get<ColSql>("select id, name, is_default, created_at from collections where is_default = 1 limit 1");
      return row ? map(row) : null;
    },
    async create(name, isDefault, now) {
      const id = newId();
      appDb.exec("insert into collections (id, name, is_default, created_at) values (?, ?, ?, ?)", [
        id,
        name,
        isDefault ? 1 : 0,
        toUtcIso(now),
      ]);
      const row = appDb.get<ColSql>("select id, name, is_default, created_at from collections where id = ?", [id]);
      if (!row) throw new Error("tạo collection xong nhưng đọc lại không thấy");
      return map(row);
    },
  };
}