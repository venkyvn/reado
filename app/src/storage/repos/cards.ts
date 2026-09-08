/**
 * storage/repos/cards.ts — repo card: hai nhánh hàng đợi (FR-11) + JOIN lấy
 * dữ liệu hiển thị thẻ (FR-12).
 *
 * Hình dạng query hai nhánh theo solution-design mục 7. Lưu ý implement đã ghi
 * trong doc: SQLite không bind list trực tiếp — khi scopeCollectionIds khác
 * null thì nở placeholder `IN (?, ?, ...)` theo số phần tử. Ở R1 scope luôn
 * null (FR-18 thuộc Phase 3) nhưng nhánh nở vẫn có sẵn cho đúng hợp đồng.
 *
 * Mọi lời gọi `appDb` đều `await`: DB nằm trong Worker (facade RPC — xem db.ts),
 * quên await là câu SQL chạy lạc khỏi transaction.
 */
import type { CardsRepository, ListDueParams, SrsFields } from "../../domain/repositories";
import type { CardRow, CardState, CardWithContext } from "../../domain/types";
import type { AppDb } from "../db";
import { insertCardRow } from "./cardsSql";

interface CardSql {
  id: string;
  vocab_item_id: string;
  direction: string;
  state: string;
  stability: number;
  difficulty: number;
  reps: number | bigint;
  lapses: number | bigint;
  learning_steps: number | bigint;
  scheduled_days: number | bigint;
  last_review_at: string | null;
  due_at: string;
  suspended_at: string | null;
}

function mapCard(row: CardSql): CardRow {
  return {
    id: row.id,
    vocabItemId: row.vocab_item_id,
    direction: row.direction as CardRow["direction"],
    state: row.state as CardState,
    stability: row.stability,
    difficulty: row.difficulty,
    reps: Number(row.reps),
    lapses: Number(row.lapses),
    learningSteps: Number(row.learning_steps),
    scheduledDays: Number(row.scheduled_days),
    lastReviewAt: row.last_review_at,
    dueAt: row.due_at,
    suspendedAt: row.suspended_at,
  };
}

/** Nở mệnh đề IN cho danh sách id (scope) hoặc trả rỗng nếu list trống. */
function expandIn(column: string, ids: string[] | null): { clause: string; bind: string[] } {
  if (ids === null) return { clause: "", bind: [] };
  if (ids.length === 0) {
    // Phạm vi rỗng → không có card nào thuộc về (chống `IN ()` lỗi cú pháp).
    return { clause: ` AND ${column} IS NULL `, bind: [] };
  }
  return { clause: ` AND ${column} IN (${ids.map(() => "?").join(", ")}) `, bind: ids };
}

const CARD_COLS = `id, vocab_item_id, direction, state, stability, difficulty, reps, lapses,
  learning_steps, scheduled_days, last_review_at, due_at, suspended_at`;

/**
 * Thêm alias vào từng cột của CARD_COLS — bắt buộc khi JOIN, vì `id` và
 * `created_at`-style column tồn tại ở cả cards lẫn vocab_items (SQLite báo
 * "ambiguous column name"). Giữ CARD_COLS làm nguồn tên cột duy nhất.
 */
function cardCols(alias: string): string {
  return CARD_COLS.split(",")
    .map((c) => `${alias}.${c.trim()}`)
    .join(", ");
}

function dueQuery(opts: ListDueParams, stateClause: string): { sql: string; bind: (string | number | null)[] } {
  const scope = expandIn("c.vocab_item_id", opts.scopeCollectionIds);
  const bind: (string | number | null)[] = [opts.nowUtc, ...scope.bind];
  const limitClause = opts.limit !== null ? ` limit ${Math.floor(opts.limit)}` : "";
  return {
    sql: `select ${CARD_COLS} from cards c
          where c.state ${stateClause}
            and c.due_at <= ?
            and c.suspended_at is null
            ${scope.clause}
          order by c.due_at asc
          ${limitClause}`,
    bind,
  };
}

export function createCardsRepo(appDb: AppDb): CardsRepository {
  return {
    async insertBatch(rows) {
      await appDb.transaction(async (tx) => {
        for (const r of rows) await insertCardRow(tx, r);
      });
    },
    async listDueReviews(opts) {
      const q = dueQuery(opts, `in ('review','relearning')`);
      const rows = await appDb.all<CardSql>(q.sql, q.bind);
      return rows.map(mapCard);
    },
    async listDueNews(opts) {
      const q = dueQuery(opts, `= 'new'`);
      const rows = await appDb.all<CardSql>(q.sql, q.bind);
      return rows.map(mapCard);
    },
    async loadWithContext(cardIds) {
      if (cardIds.length === 0) return [];
      const ph = cardIds.map(() => "?").join(", ");
      const rows = await appDb.all<CardSql & {
        term: string;
        pos: string;
        meaning_vi: string;
        ipa: string | null;
        example: string;
        collection_name: string;
      }>(
        `select c.id, c.vocab_item_id, c.direction, c.state, c.stability, c.difficulty,
                c.reps, c.lapses, c.learning_steps, c.scheduled_days, c.last_review_at,
                c.due_at, c.suspended_at,
                v.term, v.pos, v.meaning_vi, v.ipa, v.example,
                col.name as collection_name
         from cards c
         join vocab_items v on v.id = c.vocab_item_id
         join collections col on col.id = v.collection_id
         where c.id in (${ph})`,
        cardIds,
      );
      // Giữ đúng thứ tự hàng đợi (SQLite không sắp theo danh sách IN được).
      const byId = new Map<string, CardWithContext>();
      for (const r of rows) {
        byId.set(r.id, {
          ...mapCard(r),
          term: r.term,
          pos: r.pos as CardWithContext["pos"],
          meaningVi: r.meaning_vi,
          ipa: r.ipa,
          example: r.example,
          collectionName: r.collection_name,
        });
      }
      const out: CardWithContext[] = [];
      for (const id of cardIds) {
        const full = byId.get(id);
        if (full) out.push(full);
      }
      return out;
    },
    async listByScope(collectionId) {
      // Export cần card theo collection, mà cards không giữ collection_id → JOIN
      // sang vocab_items. Alias bắt buộc (xem cardCols).
      const rows = await appDb.all<CardSql>(
        `select ${cardCols("c")} from cards c
           join vocab_items v on v.id = c.vocab_item_id
          where (? is null or v.collection_id = ?)
          order by c.due_at asc`,
        [collectionId, collectionId],
      );
      return rows.map(mapCard);
    },
  };
}

/** Cập nhật TOÀN BỘ field FSRS + lịch — bản SQL duy nhất cho chấm thẻ và undo
 *  (điều cấm #8: due_at luôn đọc từ DB, không tính lại ở UI). */
export async function updateSrsFieldsSql(appDb: AppDb, cardId: string, f: SrsFields): Promise<void> {
  await appDb.exec(
    `update cards set state = ?, stability = ?, difficulty = ?, reps = ?, lapses = ?,
                      learning_steps = ?, scheduled_days = ?, last_review_at = ?, due_at = ?
     where id = ?`,
    [f.state, f.stability, f.difficulty, f.reps, f.lapses, f.learningSteps, f.scheduledDays, f.lastReviewAt, f.dueAt, cardId],
  );
}
