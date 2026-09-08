/**
 * domain/queue.ts — hàng đợi ôn tập HAI NHÁNH (FR-11, solution-design mục 7).
 *
 * - NHÁNH 1: card review/relearning đến hạn — KHÔNG giới hạn, thứ tự due_at asc.
 * - NHÁNH 2: card mới — giới hạn còn lại = dailyNewLimit − số đã GIỚI THIỆU hôm
 *   nay (đếm từ review_logs, state_before='new', trong ngày học — đếm GLOBAL
 *   trước khi lọc phạm vi). Thứ tự due_at asc = thứ tự lưu vào kho.
 *
 * File này thuần: nhận dữ liệu đã lấy từ storage, trả kế hoạch. SQL nằm ở
 * storage/repos/cards.ts; "hôm nay" đi qua domain/time.ts (dayBounds).
 */
import type { CardRow } from "./types";

export interface QueuePlan {
  /** Thứ tự cuối cùng hiển thị: nhánh 1 rồi nhánh 2. */
  cards: CardRow[];
  /** Card mới thực sự được đưa vào hôm nay. */
  newIncluded: CardRow[];
  /** Card mới bị hoãn sang ngày sau (vượt hạn mức). */
  newDeferred: CardRow[];
  introducedToday: number;
  newRemaining: number;
  dailyNewLimit: number;
}

export function applyNewLimit(
  reviewCards: CardRow[],
  newDueCards: CardRow[],
  introducedToday: number,
  dailyNewLimit: number,
): QueuePlan {
  const remaining = Math.max(0, dailyNewLimit - introducedToday);
  const newIncluded = newDueCards.slice(0, remaining);
  const newDeferred = newDueCards.slice(remaining);
  return {
    cards: [...reviewCards, ...newIncluded],
    newIncluded,
    newDeferred,
    introducedToday,
    newRemaining: Math.max(0, remaining - newIncluded.length),
    dailyNewLimit,
  };
}

/** Số card người dùng sẽ gặp trong phiên này. */
export function dueCount(plan: QueuePlan): number {
  return plan.cards.length;
}