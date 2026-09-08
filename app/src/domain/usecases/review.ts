/**
 * domain/usecases/review.ts — FR-11 (hàng đợi hai nhánh) + FR-12 (chấm + undo).
 *
 * Chấm thẻ: toàn bộ snapshot TRƯỚC khi chấm vào review_logs; transaction nằm ở
 * storage (appendGrade). Undo một bước để trong memory của phiên ôn: snapshot
 * đầy đủ (kể cả reps/lapses mà log theo research schema không chứa) giữ trong
 * UI và truyền lại đây — đúng thiết kế solution-design mục 8.2.
 */
import { Ratings, fsrsCardFromStored, stateName, storedFieldsFromCard } from "../scheduler";
import type { AppServices } from "../services";
import { dayBounds } from "../time";
import type { CardState, CardWithContext, ReviewLogRow } from "../types";
import { applyNewLimit } from "../queue";
import type { QueuePlan } from "../queue";
import { newId, toUtcIso } from "../utils";

export interface DueQueueResult {
  plan: QueuePlan;
  cards: CardWithContext[];
  dayLabel: string;
  /** Tổng số card trong phiên này (FR-11: cho biết còn bao nhiêu card hôm nay). */
  total: number;
  /** Card mới bị hoãn vì hết hạn mức hôm nay. */
  deferredNew: number;
}

export async function buildDueQueue(svc: AppServices, now: Date): Promise<DueQueueResult> {
  const settings = await svc.repos.settings.get();
  const bounds = dayBounds(now, settings.dayCutoffHour, svc.timeZone());
  const nowIso = toUtcIso(now);

  const [reviewCards, newCards, introducedToday] = await Promise.all([
    svc.repos.cards.listDueReviews({ nowUtc: nowIso, scopeCollectionIds: null, limit: null }),
    svc.repos.cards.listDueNews({ nowUtc: nowIso, scopeCollectionIds: null, limit: null }),
    svc.repos.logs.countIntroducedNew(toUtcIso(bounds.dayStart), toUtcIso(bounds.dayEnd)),
  ]);

  const plan = applyNewLimit(reviewCards, newCards, introducedToday, settings.dailyNewLimit);
  const withContext =
    plan.cards.length > 0 ? await svc.repos.cards.loadWithContext(plan.cards.map((c) => c.id)) : [];
  const byId = new Map(withContext.map((c) => [c.id, c]));
  const ordered: CardWithContext[] = [];
  for (const c of plan.cards) {
    const full = byId.get(c.id);
    if (full) ordered.push(full);
  }
  return {
    plan,
    cards: ordered,
    dayLabel: bounds.dayLabel,
    total: ordered.length,
    deferredNew: plan.newDeferred.length,
  };
}

export interface GradeInput {
  card: CardWithContext;
  rating: keyof typeof Ratings;
  now: Date;
}

export interface GradeResult {
  updatedCard: CardWithContext;
  log: ReviewLogRow;
}

export async function gradeCard(svc: AppServices, input: GradeInput): Promise<GradeResult> {
  const fsrsCard = fsrsCardFromStored(input.card, input.now);
  const outcome = svc.scheduler.grade(fsrsCard, Ratings[input.rating], input.now);
  const snapshot = outcome.snapshot;
  const fields = storedFieldsFromCard(outcome.card);

  const log: ReviewLogRow = {
    id: newId(),
    cardId: input.card.id,
    mode: "srs", // R1 chỉ có srs (solution-design mục 5)
    rating: snapshot.rating,
    stateBefore: (stateName(snapshot.stateBefore).toLowerCase() as CardState) || "review",
    stabilityBefore: snapshot.stabilityBefore,
    difficultyBefore: snapshot.difficultyBefore,
    learningStepsBefore: snapshot.learningStepsBefore,
    dueBefore: toUtcIso(snapshot.dueBefore),
    elapsedDays: snapshot.elapsedDays,
    scheduledDays: snapshot.scheduledDays,
    reviewedAt: toUtcIso(snapshot.gradedAt),
  };

  await svc.repos.logs.appendGrade(log, input.card.id, fields);
  const updatedCard: CardWithContext = { ...input.card, ...fields };
  return { updatedCard, log };
}

export interface UndoInput {
  logId: string;
  /** Snapshot ĐẦY ĐỦ trước lúc chấm — UI giữ trong memory của phiên ôn. */
  restoreCard: CardWithContext;
}

/** Undo một bước (FR-12 criterion cuối): delete log sai + khôi phục card. */
export async function undoGrade(svc: AppServices, input: UndoInput): Promise<void> {
  const { restoreCard } = input;
  await svc.repos.logs.rollbackGrade(input.logId, restoreCard.id, {
    state: restoreCard.state,
    stability: restoreCard.stability,
    difficulty: restoreCard.difficulty,
    reps: restoreCard.reps,
    lapses: restoreCard.lapses,
    learningSteps: restoreCard.learningSteps,
    scheduledDays: restoreCard.scheduledDays,
    lastReviewAt: restoreCard.lastReviewAt,
    dueAt: restoreCard.dueAt,
  });
}