/**
 * storage/repos/cardsSql.ts — câu SQL card dùng chung cho nhiều repo.
 *
 * Tách riêng để vocabItems (persistCapture) và cards (repo chính) dùng cùng một
 * câu INSERT — một chỗ đổi, không lệch nhau.
 *
 * Async vì `AppDb` là facade RPC sang Worker (xem db.ts) — gọi trong transaction
 * thì phải `await`, nếu không câu INSERT sẽ chạy SAU khi COMMIT đã đóng.
 */
import type { CardRow } from "../../domain/types";
import type { AppDb } from "../db";

export async function insertCardRow(appDb: AppDb, c: CardRow): Promise<void> {
  await appDb.exec(
    `insert into cards (id, vocab_item_id, direction, state, stability, difficulty, reps, lapses,
                        learning_steps, scheduled_days, last_review_at, due_at, suspended_at)
     values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      c.id,
      c.vocabItemId,
      c.direction,
      c.state,
      c.stability,
      c.difficulty,
      c.reps,
      c.lapses,
      c.learningSteps,
      c.scheduledDays,
      c.lastReviewAt,
      c.dueAt,
      c.suspendedAt,
    ],
  );
}
