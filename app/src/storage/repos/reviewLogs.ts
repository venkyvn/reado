/**
 * storage/repos/reviewLogs.ts — repo review_logs.
 *
 * Hai phương thức quan trọng nhất hệ thống, mỗi cái MỘT transaction (điều cấm #3):
 * - appendGrade: insert log (ảnh chụp TRƯỚC khi chấm) + update card → cùng tx.
 *   Nếu log không ghi mà card đã đổi, review đó mất khỏi training data vĩnh viễn.
 * - rollbackGrade: delete log bấm nhầm + khôi phục card về snapshot trước chấm.
 */
import type { ReviewLogsRepository } from "../../domain/repositories";
import type { CardState, ReviewLogRow } from "../../domain/types";
import type { AppDb } from "../db";
import { updateSrsFieldsSql } from "./cards";

interface LogSql {
  id: string;
  card_id: string;
  mode: string;
  rating: number;
  state_before: string;
  stability_before: number;
  difficulty_before: number;
  learning_steps_before: number | bigint;
  due_before: string;
  elapsed_days: number | bigint;
  scheduled_days: number | bigint;
  reviewed_at: string;
}

function map(row: LogSql): ReviewLogRow {
  return {
    id: row.id,
    cardId: row.card_id,
    mode: row.mode as ReviewLogRow["mode"],
    rating: row.rating,
    stateBefore: row.state_before as CardState,
    stabilityBefore: row.stability_before,
    difficultyBefore: row.difficulty_before,
    learningStepsBefore: Number(row.learning_steps_before),
    dueBefore: row.due_before,
    elapsedDays: Number(row.elapsed_days),
    scheduledDays: Number(row.scheduled_days),
    reviewedAt: row.reviewed_at,
  };
}

export function createReviewLogsRepo(appDb: AppDb): ReviewLogsRepository {
  return {
    async appendGrade(log, cardId, fields) {
      appDb.transaction((tx) => {
        tx.exec(
          `insert into review_logs (id, card_id, mode, rating, state_before, stability_before,
                                     difficulty_before, learning_steps_before, due_before,
                                     elapsed_days, scheduled_days, reviewed_at)
           values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            log.id,
            log.cardId,
            log.mode,
            log.rating,
            log.stateBefore,
            log.stabilityBefore,
            log.difficultyBefore,
            log.learningStepsBefore,
            log.dueBefore,
            log.elapsedDays,
            log.scheduledDays,
            log.reviewedAt,
          ],
        );
        updateSrsFieldsSql(tx, cardId, fields);
      });
    },
    async rollbackGrade(logId, cardId, fields) {
      appDb.transaction((tx) => {
        tx.exec("delete from review_logs where id = ?", [logId]);
        updateSrsFieldsSql(tx, cardId, fields);
      });
    },
    async countIntroducedNew(fromUtc, toUtc) {
      const row = appDb.get<{ c: number | bigint }>(
        `select count(*) as c from review_logs
         where state_before = 'new' and reviewed_at >= ? and reviewed_at < ?`,
        [fromUtc, toUtc],
      );
      return Number(row?.c ?? 0);
    },
    async getById(logId) {
      const row = appDb.get<LogSql>("select * from review_logs where id = ?", [logId]);
      return row ? map(row) : null;
    },
  };
}