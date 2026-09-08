/**
 * domain/scheduler.ts — lớp mỏng bọc ts-fsrs (NG-09: cấm tự viết SRS).
 *
 * Q-12 (chốt 2026-09-08): learning steps TẮT ở MVP. Cơ chế verify bằng máy
 * (đầu dò Node 2026-09-08) là `generatorParameters({ enable_short_term: false })`:
 *   - thẻ mới + bất kỳ rating nào → state Review, interval ≥ 1 ngày;
 *   - review + Again → vẫn Review (không rơi vào Relearning);
 *   - `learning`/`relearning` không bao giờ xuất hiện ở R1.
 *
 * BẪY ĐÃ VERIFY — ánh xạ review_logs:
 *   - `log.state/stability/difficulty` của ts-fsrs = ảnh chụp TRƯỚC khi chấm ✓
 *   - NHƯNG `log.due` = ngày review TRƯỚC ĐÓ (dùng tính elapsed), KHÔNG phải
 *     `due` trước khi chấm. `due_before` phải chụp từ card trong tay trước khi
 *     gọi `grade` — snapshot trong file này tự làm việc đó.
 *   - `log.scheduled_days` = interval hệ thống ĐÃ hẹn (pre) ✓ dùng được.
 */

import {
  createEmptyCard,
  fsrs,
  generatorParameters,
  Rating,
  State,
  type Card,
  type FSRSParameters,
  type RecordLogItem,
} from "ts-fsrs";
import type { CardState } from "./types";

/** Ánh xạ 4 nút chấm → FSRS rating (1 Again .. 4 Easy). */
export const Ratings = {
  Again: Rating.Again,
  Hard: Rating.Hard,
  Good: Rating.Good,
  Easy: Rating.Easy,
} as const;
export type RadoRating = (typeof Ratings)[keyof typeof Ratings];

export interface SchedulerConfig {
  /** settings.request_retention — mặc định 0.9 (FR-15). */
  requestRetention: number;
  /** settings.maximum_interval — mặc định 36500. */
  maximumInterval: number;
  /** settings.enable_fuzz — mặc định true; tắt trong test cho deterministic. */
  enableFuzz: boolean;
}

/**
 * Ảnh chụp TRƯỚC khi chấm — ghi vào bảng review_logs (research:
 * log là pre-rating snapshot; không có nó thì mất undo và mất training data).
 */
export interface PreGradeSnapshot {
  stateBefore: number;
  stabilityBefore: number;
  difficultyBefore: number;
  learningStepsBefore: number;
  /** due của card TẠI THỜI ĐIỂM chấm — chụp thủ công, không tin `log.due`. */
  dueBefore: Date;
  /** Số ngày thực tế đã trôi qua kể từ lần ôn trước. */
  elapsedDays: number;
  /** Interval hệ thống đã hẹn ở lần trước. */
  scheduledDays: number;
  rating: number;
  gradedAt: Date;
}

export interface GradeOutcome {
  /** Card SAU khi chấm → update bảng cards. */
  card: Card;
  /** Ảnh chụp TRƯỚC khi chấm → insert review_logs. */
  snapshot: PreGradeSnapshot;
}

export interface Scheduler {
  /** Thẻ mới (state=New, due=now, stability/difficulty=0). */
  createNewCard(now: Date): Card;
  /** Chấm một card. Thuần, không đụng DB — transaction thuộc storage layer. */
  grade(card: Card, rating: RadoRating, now: Date): GradeOutcome;
}

export function createScheduler(cfg: SchedulerConfig): Scheduler {
  const params: FSRSParameters = generatorParameters({
    request_retention: cfg.requestRetention,
    maximum_interval: cfg.maximumInterval,
    enable_fuzz: cfg.enableFuzz,
    enable_short_term: false, // Q-12 — hằng số cho MVP
  });
  const f = fsrs(params);

  return {
    createNewCard(now: Date): Card {
      return createEmptyCard(now);
    },
    grade(card: Card, rating: RadoRating, now: Date): GradeOutcome {
      const snapshot: PreGradeSnapshot = {
        stateBefore: card.state as number,
        stabilityBefore: card.stability,
        difficultyBefore: card.difficulty,
        learningStepsBefore: card.learning_steps,
        dueBefore: new Date(card.due), // BẪY log.due — xem header
        elapsedDays: card.elapsed_days,
        scheduledDays: card.scheduled_days,
        rating,
        gradedAt: now,
      };
      const result: RecordLogItem = f.next(card, now, rating);
      return { card: result.card, snapshot };
    },
  };
}

/** Tiện ích đọc state ở dạng tên (debug/log) — ngậm State từ ts-fsrs. */
export function stateName(state: number): string {
  return State[state] ?? `unknown(${state})`;
}

// ---------------------------------------------------------------------------
// Ánh xạ hàng DB ↔ thẻ ts-fsrs — chỗ duy nhất trong domain được chuyển đổi
// hai hình dạng. DB lưu camelCase/ISO-8601, ts-fsrs dùng snake + Date/ms.

const STATE_BY_NAME: Record<CardState, State> = {
  new: State.New,
  learning: State.Learning,
  review: State.Review,
  relearning: State.Relearning,
};

const DAY_MS = 24 * 60 * 60 * 1000;

export interface StoredSrsFields {
  state: CardState;
  stability: number;
  difficulty: number;
  reps: number;
  lapses: number;
  learningSteps: number;
  scheduledDays: number;
  lastReviewAt: string | null;
  dueAt: string;
}

/** Hàng cards → thẻ ts-fsrs để chấm. `elapsed_days` tính từ last_review (như
 *  Scheduler.init của ts-fsrs tự làm — đặt sẵn để snapshot vào review_logs). */
export function fsrsCardFromStored(row: StoredSrsFields, now: Date): Card {
  const lastReviewMs = row.lastReviewAt ? Date.parse(row.lastReviewAt) : undefined;
  const elapsedDays =
    row.state !== "new" && lastReviewMs !== undefined
      ? Math.max(0, Math.floor((now.getTime() - lastReviewMs) / DAY_MS))
      : 0;
  return {
    due: new Date(row.dueAt),
    stability: row.stability,
    difficulty: row.difficulty,
    elapsed_days: elapsedDays,
    scheduled_days: row.scheduledDays,
    reps: row.reps,
    lapses: row.lapses,
    state: STATE_BY_NAME[row.state],
    learning_steps: row.learningSteps,
    last_review: lastReviewMs !== undefined ? new Date(lastReviewMs) : undefined,
  };
}

/** Thẻ ts-fsrs sau khi chấm → bộ field ghi vào bảng cards. */
export function storedFieldsFromCard(card: Card): StoredSrsFields {
  return {
    state: (stateName(card.state).toLowerCase() as CardState) || "review",
    stability: card.stability,
    difficulty: card.difficulty,
    reps: card.reps,
    lapses: card.lapses,
    learningSteps: card.learning_steps,
    scheduledDays: card.scheduled_days,
    lastReviewAt: card.last_review ? card.last_review.toISOString() : null,
    dueAt: card.due.toISOString(),
  };
}