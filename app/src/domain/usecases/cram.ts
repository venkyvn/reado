/**
 * domain/usecases/cram.ts — task 3.13: Targeted review — ôn theo chủ đề (tag).
 *
 * Q-11 đã CHỐT MỘT PHẦN (owner 2026-09-08, D-3): cram đi đường "chấp nhận" —
 * buổi ôn tức thì KHÔNG dịch chuyển lịch dài hạn. Vì vậy:
 *  - chấm cram KHÔNG gọi scheduler.grade, KHÔNG đụng một cột nào của cards;
 *  - chỉ insert review_logs với mode='cram' (giá trị nằm sẵn trong schema R1);
 *  - ảnh chụp vẫn là TRƯỚC khi chấm (điều cấm #1), scheduled_days = 0;
 *  - undo cram = xoá log vừa chèn (card không đổi nên không có gì để khôi phục).
 *
 * Phiên cram KHÔNG giới hạn bởi daily_new_limit và KHÔNG lọc due_at — nó nằm
 * ngoài hàng đợi thường (docs/rich-vocab-cram-ddl.md mục 5).
 */
import { fsrsCardFromStored, Ratings } from "../scheduler";
import type { AppServices } from "../services";
import type { CardWithContext, ReviewLogRow, TagCount } from "../types";
import { newId, toUtcIso } from "../utils";

/** Mọi tag trong kho + số card mỗi tag (màn chọn tag). */
export function listCramTags(svc: AppServices): Promise<TagCount[]> {
  return svc.repos.vocabItems.listAllTags();
}

/** Dựng phiên cram: mọi card có item mang ÍT NHẤT một tag đã chọn. */
export async function buildCramSession(
  svc: AppServices,
  tags: string[],
): Promise<CardWithContext[]> {
  if (tags.length === 0) return [];
  const cards = await svc.repos.cards.listByTags(tags);
  if (cards.length === 0) return [];
  return svc.repos.cards.loadWithContext(cards.map((c) => c.id));
}

export interface CramGradeInput {
  card: CardWithContext;
  /** "Again" | "Hard" | "Good" | "Easy" — đường UI giống hệt màn ôn thường. */
  rating: keyof typeof Ratings;
  now: Date;
}

export interface CramGradeResult {
  log: ReviewLogRow;
}

/** Chấm MỘT card trong phiên cram: log mode='cram', cards KHÔNG đổi. */
export async function gradeCram(svc: AppServices, input: CramGradeInput): Promise<CramGradeResult> {
  // elapsed_days tính cùng công thức như đường srs (fsrsCardFromStored) để log
  // cram có số liệu quen thuộc; KHÔNG gọi grade nên outcome không tồn tại.
  const elapsed = fsrsCardFromStored(input.card, input.now).elapsed_days;

  const log: ReviewLogRow = {
    id: newId(),
    cardId: input.card.id,
    mode: "cram",
    rating: Ratings[input.rating],
    stateBefore: input.card.state,
    stabilityBefore: input.card.stability,
    difficultyBefore: input.card.difficulty,
    learningStepsBefore: input.card.learningSteps,
    dueBefore: input.card.dueAt,
    elapsedDays: elapsed,
    scheduledDays: 0, // không có khoảng hẹn mới — card không được hẹn lại
    reviewedAt: toUtcIso(input.now),
  };
  await svc.repos.logs.appendCramLog(log);
  return { log };
}

/** Undo cram: chỉ xoá log vừa chèn — card chưa bao giờ đổi. */
export async function undoCram(svc: AppServices, logId: string): Promise<void> {
  await svc.repos.logs.removeLog(logId);
}