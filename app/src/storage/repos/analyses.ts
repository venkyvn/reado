/**
 * storage/repos/analyses.ts — repo bảng `analyses` (migration v2).
 *
 * Mỗi dòng là MỘT trang đã phân tích THÀNH CÔNG — sự kiện thật, không phải
 * counter (cùng luật FR-11: "đếm từ log, không từ cột counter", vì counter và
 * log lệch nhau là lỗi không ai quan sát được). FR-14 đếm `count(*)` ở đây;
 * NFR-02 lưu latency + token cho M-03 về sau.
 *
 * Mọi lời gọi `appDb` đều `await`: DB nằm trong Worker (facade RPC — xem db.ts).
 */
import type { AnalysesRepository } from "../../domain/repositories"
import type { AppDb } from "../db"

export function createAnalysesRepo(appDb: AppDb): AnalysesRepository {
  return {
    async insert(record) {
      await appDb.exec(
        `insert into analyses (id, analyzed_at, cefr, provider, model, prompt_version,
                               latency_ms, tokens_in, tokens_out)
         values (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          record.id,
          record.analyzedAt,
          record.cefr,
          record.provider,
          record.model,
          record.promptVersion,
          record.latencyMs,
          record.tokensIn,
          record.tokensOut,
        ],
      )
    },
    async countAll() {
      const row = await appDb.get<{ c: number | bigint }>("select count(*) as c from analyses")
      return Number(row?.c ?? 0)
    },
  }
}
