/**
 * storage/repos/vocabItems.ts — repo từ vựng.
 *
 * persistCapture lưu vocab_items + cards tương ứng trong MỘT transaction:
 * nếu tách ra, một nửa lô lưu được nửa kia không mà không gì báo — đúng tinh
 * thần điều cấm #3 (ghi đa bước liên quan nhau phải cùng transaction).
 *
 * Callback transaction là ASYNC + `await` từng câu: DB nằm trong Worker (RPC),
 * quên await thì COMMIT đóng trước khi INSERT chạy.
 */
import type { VocabItemsRepository } from "../../domain/repositories";
import type { Pos, VocabItemRow } from "../../domain/types";
import { insertCardRow } from "./cardsSql";
import type { AppDb } from "../db";

interface VocabSql {
  id: string;
  collection_id: string;
  term: string;
  term_normalized: string;
  pos: string;
  ipa: string | null;
  meaning_vi: string;
  example: string;
  cefr: string | null;
  created_at: string;
}

function map(row: VocabSql): VocabItemRow {
  return {
    id: row.id,
    collectionId: row.collection_id,
    term: row.term,
    termNormalized: row.term_normalized,
    pos: row.pos as Pos,
    ipa: row.ipa,
    meaningVi: row.meaning_vi,
    example: row.example,
    cefr: row.cefr as VocabItemRow["cefr"],
    createdAt: row.created_at,
  };
}

export function createVocabItemsRepo(appDb: AppDb): VocabItemsRepository {
  return {
    async persistCapture(vocabRows, cardRows) {
      if (vocabRows.length === 0) return;
      await appDb.transaction(async (tx) => {
        for (const v of vocabRows) {
          await tx.exec(
            `insert into vocab_items (id, collection_id, term, term_normalized, pos, ipa, meaning_vi, example, cefr, created_at)
             values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [v.id, v.collectionId, v.term, v.termNormalized, v.pos, v.ipa, v.meaningVi, v.example, v.cefr, v.createdAt],
          );
        }
        for (const c of cardRows) await insertCardRow(tx, c);
      });
    },
    async listByCollection(collectionId) {
      const rows = await appDb.all<VocabSql>(
        "select * from vocab_items where collection_id = ? order by created_at asc",
        [collectionId],
      );
      return rows.map(map);
    },
    async listByScope(collectionId) {
      // `? is null` = lấy tất cả collection (FR-16 export toàn bộ kho). Bind cùng
      // một giá trị hai lần — SQLite không cho dùng lại một positional param.
      const rows = await appDb.all<VocabSql>(
        `select * from vocab_items
          where (? is null or collection_id = ?)
          order by created_at asc, term asc`,
        [collectionId, collectionId],
      );
      return rows.map(map);
    },
  };
}
