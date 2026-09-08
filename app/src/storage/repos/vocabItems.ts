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
import type { LibraryFilter } from "../../domain/repositories";
import type { LibraryItemRow, Pos, VocabItemRow } from "../../domain/types";
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

interface LibrarySql extends VocabSql {
  collection_name: string;
  card_state: LibraryItemRow["cardState"];
}

function mapLibrary(row: LibrarySql): LibraryItemRow {
  return { ...map(row), collectionName: row.collection_name, cardState: row.card_state };
}

/** Ba mức lọc null-tự-do của FR-08: "? is null" là bỏ qua tiêu chí đó. Cột phải
 *  ghi ĐỦ tiền tố bảng — alias (`card_state`) KHÔNG dùng được trong WHERE. */
const FILTER_COLS = {
  collection_id: "v.collection_id",
  cefr: "v.cefr",
  card_state: "c.state",
} as const;
type FilterKey = keyof typeof FILTER_COLS;
function filterClauses(keys: readonly FilterKey[]): string {
  return keys.map((k) => `  and (? is null or ${FILTER_COLS[k]} = ?)`).join("\n");
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
    async listLibrary(filter: LibraryFilter) {
      // JOIN cards để lấy state (mỗi item có đúng 1 card ở R1) và collections để
      // lấy TÊN. collate nocase để "Run" và "run" nằm cạnh nhau; bên trong cùng
      // term thì theo thứ tự lưu — pos + câu gốc phân biệt các nghĩa (FR-08 c3).
      const rows = await appDb.all<LibrarySql>(
        `select v.*, col.name as collection_name, c.state as card_state
          from vocab_items v
          join cards c on c.vocab_item_id = v.id
          join collections col on col.id = v.collection_id
          where 1 = 1
          ${filterClauses(["collection_id", "cefr", "card_state"])}
          order by v.term collate nocase asc, v.created_at asc`,
        [
          filter.collectionId, filter.collectionId,
          filter.cefr, filter.cefr,
          filter.state, filter.state,
        ],
      );
      return rows.map(mapLibrary);
    },
  };
}