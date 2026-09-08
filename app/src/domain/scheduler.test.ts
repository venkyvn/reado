/**
 * Test Q-12 + ánh xạ review_logs — chính là 3 unit test giải pháp yêu cầu viết
 * ngay khi cài ts-fsrs (solution-design mục 9), cộng 2 test chốt cái bẫy log.due
 * đã verify thực nghiệm 2026-09-08.
 */
import { describe, expect, it } from "vitest";
import { State } from "ts-fsrs";
import { createScheduler, Ratings } from "./scheduler";
import { dayBounds } from "./time";

const TZ = "Asia/Bangkok";
const NOW = new Date("2026-09-08T10:00:00Z"); // 17:00 giờ địa phương

function makeScheduler() {
  return createScheduler({
    requestRetention: 0.9,
    maximumInterval: 36500,
    enableFuzz: false, // deterministic cho test
  });
}

describe("Q-12 — learning steps OFF (chốt 2026-09-08)", () => {
  it("thẻ mới + Again → state Review, interval ≥ 1 ngày, không bao giờ Learning", () => {
    const s = makeScheduler();
    const fresh = s.createNewCard(NOW);
    const { card } = s.grade(fresh, Ratings.Again, NOW);

    expect(card.state).toBe(State.Review); // 2
    expect(card.scheduled_days).toBeGreaterThanOrEqual(1);
    expect(card.due.getTime()).toBeGreaterThan(NOW.getTime());
    expect(card.last_review).toBeDefined();
  });

  it("thẻ mới + Good → state Review, due_at không sớm hơn đầu ngày học NGÀY MAI", () => {
    const s = makeScheduler();
    const tomorrowStart = new Date(dayBounds(NOW, 4, TZ).dayStart.getTime() + 24 * 3600 * 1000);

    const { card } = s.grade(s.createNewCard(NOW), Ratings.Good, NOW);

    expect(card.state).toBe(State.Review);
    expect(card.due.getTime()).toBeGreaterThanOrEqual(tomorrowStart.getTime());
  });

  it("review + Again → vẫn Review (không Relearning), quay lại sau ≥ 1 ngày", () => {
    const s = makeScheduler();
    const afterFirst = s.grade(s.createNewCard(NOW), Ratings.Good, NOW).card;

    const { card, snapshot } = s.grade(afterFirst, Ratings.Again, NOW);

    expect(card.state).toBe(State.Review); // không phải Relearning
    expect(card.lapses).toBe(1);
    expect(card.due.getTime()).toBeGreaterThan(NOW.getTime());
    expect(snapshot.stateBefore).toBe(State.Review); // log pre-snapshot: lần chấm này xảy ra khi card đang ở Review
  });
});

describe("ánh xạ review_logs — ảnh chụp TRƯỚC khi chấm", () => {
  it("snapshot giữ nguyên state/stability TRƯỚC, card mang giá trị SAU", () => {
    const s = makeScheduler();
    const fresh = s.createNewCard(NOW);
    expect(fresh.stability).toBe(0);

    const { card, snapshot } = s.grade(fresh, Ratings.Good, NOW);

    expect(snapshot.stateBefore).toBe(State.New); // trước: New
    expect(snapshot.stabilityBefore).toBe(0); // trước: 0
    expect(card.state).toBe(State.Review); // sau: Review
    expect(card.stability).toBeGreaterThan(0); // sau: đã tăng
  });

  it("dueBefore được chụp từ card trong tay — KHÔNG tin log.due (bẫy đã verify)", () => {
    const s = makeScheduler();
    const reviewCard = s.grade(s.createNewCard(NOW), Ratings.Good, NOW).card;
    const dueAtGradeTime = reviewCard.due; // due của card lúc sắp chấm

    const { snapshot } = s.grade(reviewCard, Ratings.Again, NOW);

    expect(snapshot.dueBefore.toISOString()).toBe(dueAtGradeTime.toISOString());
    // log.due của ts-fsrs (ngày review trước) KHÁC dueBefore — chính khác biệt này đã
    // làm sập nhiều implement: elapsed_days được tính từ last_review, không từ due.
    expect(snapshot.dueBefore.getTime()).not.toBe(NOW.getTime());
  });
});