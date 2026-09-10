/**
 * storage/repos/readingSessions.ts — repo `reading_sessions` (migration v4,
 * task 3.15, Q-10-reopen 2026-09-09).
 *
 * INVARIANT quan trọng nhất: mỗi collection giữ TỐI ĐA 10 phiên MỚI NHẤT —
 * trim chạy trong CÙNG transaction với insert nên không đường nào (nhiều tab,
 * boot xen giữa) làm vượt giới hạn. Cũ nhất tự trôi đúng như "10 trang gần
 * nhất" mà owner muốn, nhưng bền theo DB thay vì chết theo phiên.
 *
 * `segments` + `vocabulary` là TEXT JSON — parse bằng JSON.parse trong
 * try/catch: dòng hỏng (JSON vỡ) trả segments/vocabulary rỗng thay vì làm sập
 * cả màn đọc (cùng tinh thần guard json_valid của rich vocab, task 3.12).
 * Summary vẫn trả nguyên vẹn.
 *
 * `vocabulary` ở đây có thể STALE sau khi user sửa từ ở màn duyệt (repo này
 * không sync ngược) — chấp nhận có chủ ý: gloss chỉ là trợ giúp đọc, nguồn sự
 * thật là vocab_items (xem comment migration v4).
 *
 * Mọi lời gọi `appDb` đều `await`: DB nằm trong Worker (facade RPC — db.ts).
 */
import type { ReadingSessionsRepository } from "../../domain/repositories"
import type { AnalyzedItem, ReadingSessionRow, Segment } from "../../domain/types"
import type { AppDb } from "../db"

interface SessionSql {
  id: string
  collection_id: string
  segments: string
  vocabulary: string
  summary_vi: string
  vocab_count: number | bigint
  created_at: string
  saved_at: string | null
  saved_count: number | bigint
}

/** Chỉ trim khi có-collection: 10 mới nhất mỗi collection (Q-10-reopen). */
export const SESSIONS_PER_COLLECTION = 10

/** Parse JSON array + lọc phần tử sai shape — không bao giờ ném. */
function parseJsonArray<T>(raw: string, guard: (o: Record<string, unknown>) => T | null): T[] {
  try {
    const parsed: unknown = JSON.parse(raw)
    if (!Array.isArray(parsed)) return []
    return parsed.flatMap((s) => {
      if (typeof s !== "object" || s === null) return []
      const item = guard(s as Record<string, unknown>)
      return item === null ? [] : [item]
    })
  } catch {
    // JSON hỏng → trả rỗng nhưng KHÔNG ném: metadata khác vẫn còn giá trị.
    return []
  }
}

const segmentGuard = (o: Record<string, unknown>): Segment | null =>
  typeof o.sourceEn === "string" && typeof o.translationVi === "string"
    ? { sourceEn: o.sourceEn, translationVi: o.translationVi }
    : null

const vocabGuard = (o: Record<string, unknown>): AnalyzedItem | null =>
  typeof o.term === "string" && typeof o.meaningVi === "string"
    ? {
        term: o.term,
        pos: o.pos as AnalyzedItem["pos"],
        ipa: typeof o.ipa === "string" ? o.ipa : "",
        meaningVi: o.meaningVi,
        cefr: (o.cefr ?? null) as AnalyzedItem["cefr"],
        example: typeof o.example === "string" ? o.example : "",
        verification: o.verification as AnalyzedItem["verification"],
        tags: Array.isArray(o.tags) ? (o.tags as string[]) : [],
        synonyms: Array.isArray(o.synonyms) ? (o.synonyms as string[]) : [],
        antonyms: Array.isArray(o.antonyms) ? (o.antonyms as string[]) : [],
      }
    : null

function map(row: SessionSql): ReadingSessionRow {
  return {
    id: row.id,
    collectionId: row.collection_id,
    segments: parseJsonArray(row.segments, segmentGuard),
    vocabulary: parseJsonArray(row.vocabulary, vocabGuard),
    summaryVi: row.summary_vi,
    vocabCount: Number(row.vocab_count),
    createdAt: row.created_at,
    savedAt: row.saved_at,
    savedCount: Number(row.saved_count),
  }
}

const COLUMNS = `id, collection_id, segments, vocabulary, summary_vi, vocab_count, created_at, saved_at, saved_count`

export function createReadingSessionsRepo(appDb: AppDb): ReadingSessionsRepository {
  return {
    async insert(record) {
      await appDb.transaction(async (tx) => {
        await tx.exec(
          `insert into reading_sessions (${COLUMNS})
           values (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            record.id,
            record.collectionId,
            JSON.stringify(record.segments),
            JSON.stringify(record.vocabulary),
            record.summaryVi,
            record.vocabCount,
            record.createdAt,
            record.savedAt,
            record.savedCount,
          ],
        )
        // Trim: giữ 10 created_at mới nhất của collection vừa ghi. Tie-break
        // bằng id (hex ngẫu nhiên) — không đẹp nhưng tất định, không xoá lẫn.
        await tx.exec(
          `delete from reading_sessions
           where collection_id = ?
             and id not in (
               select id from reading_sessions
               where collection_id = ?
               order by created_at desc, id desc
               limit ?
             )`,
          [record.collectionId, record.collectionId, SESSIONS_PER_COLLECTION],
        )
      })
    },

    async listByCollection(collectionId) {
      const rows = await appDb.all<SessionSql>(
        `select ${COLUMNS} from reading_sessions
         where collection_id = ?
         order by created_at desc, id desc
         limit ?`,
        [collectionId, SESSIONS_PER_COLLECTION],
      )
      return rows.map(map)
    },

    async listRecent(limit) {
      const rows = await appDb.all<SessionSql>(
        `select ${COLUMNS} from reading_sessions
         order by created_at desc, id desc
         limit ?`,
        [limit],
      )
      return rows.map(map)
    },

    async getById(id) {
      const row = await appDb.get<SessionSql>(
        `select ${COLUMNS} from reading_sessions where id = ?`,
        [id],
      )
      return row ? map(row) : null
    },

    async markSaved(id, savedAt, savedCount) {
      await appDb.exec(`update reading_sessions set saved_at = ?, saved_count = ? where id = ?`, [
        savedAt,
        savedCount,
        id,
      ])
    },
  }
}
