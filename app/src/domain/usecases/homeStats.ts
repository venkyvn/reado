/**
 * domain/usecases/homeStats.ts — FR-14: mấy con số của trang chủ.
 *
 * - `dueToday` — số card người dùng SẼ ôn hôm nay: nhánh review/relearning đến
 *   hạn (không giới hạn) + thẻ mới ĐÃ áp hạn mức daily_new_limit. Dùng ĐÚNG
 *   applyNewLimit của queue FR-11 nên con số này bằng đúng `total` màn ôn tập
 *   tính quyết định — không có đường đếm thứ hai nào lệch bóng (criterion 2).
 * - `backlog` — phần tồn: thẻ mới bị hoãn vì hết hạn mức hôm nay. Là con số
 *   RIÊNG, nhãn riêng (criterion 3) — không gộp vào dueToday.
 * - `analyzedPages` — đếm từ bảng analyses (sự kiện thật, không phải counter).
 * - `streakDays` — từ review_logs qua domain/streak (giờ chuyển ngày FR-11).
 *
 * Card leech (suspended_at ≠ null) tự bị các query nhánh loại qua WHERE
 * `suspended_at is null` — criterion 4 của FR-14 không cần thêm điều kiện.
 */
import { applyNewLimit } from "../queue";
import type { AppServices } from "../services";
import { computeStreak, dayLabelOf } from "../streak";
import { dayBounds } from "../time";
import { toUtcIso } from "../utils";

export interface HomeStats {
  /** Số card thực sự sẽ được ôn hôm nay (đã áp hạn mức thẻ mới). */
  dueToday: number;
  /** Thẻ mới bị hoãn sang ngày sau vì vượt hạn mức — phần "tồn", nhãn riêng. */
  backlog: number;
  introducedToday: number;
  dailyNewLimit: number;
  /** Tổng số trang đã phân tích thành công từ trước tới nay. */
  analyzedPages: number;
  /** Số ngày ôn liên tục theo giờ chuyển ngày (FR-11). */
  streakDays: number;
}

export async function getHomeStats(svc: AppServices): Promise<HomeStats> {
  const now = svc.now();
  const settings = await svc.repos.settings.get();
  const timeZone = svc.timeZone();
  const bounds = dayBounds(now, settings.dayCutoffHour, timeZone);
  const nowIso = toUtcIso(now);

  const [reviewCards, newCards, introducedToday, analyzedPages, reviewedAts] = await Promise.all([
    svc.repos.cards.listDueReviews({ nowUtc: nowIso, scopeCollectionIds: null, limit: null }),
    svc.repos.cards.listDueNews({ nowUtc: nowIso, scopeCollectionIds: null, limit: null }),
    svc.repos.logs.countIntroducedNew(toUtcIso(bounds.dayStart), toUtcIso(bounds.dayEnd)),
    svc.repos.analyses.countAll(),
    svc.repos.logs.listReviewedAts(),
  ]);

  const plan = applyNewLimit(reviewCards, newCards, introducedToday, settings.dailyNewLimit);
  const studyDays = new Set(
    reviewedAts.map((iso) => dayLabelOf(iso, settings.dayCutoffHour, timeZone)),
  );

  return {
    dueToday: plan.cards.length,
    backlog: plan.newDeferred.length,
    introducedToday,
    dailyNewLimit: plan.dailyNewLimit,
    analyzedPages,
    streakDays: computeStreak(studyDays, bounds.dayLabel),
  };
}