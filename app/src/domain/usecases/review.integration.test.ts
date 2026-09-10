/**
 * integration test — vòng lặp walking skeleton chạy trên storage THẬT:
 * save (FR-09) → hàng đợi hai nhánh (FR-11) → chấm + log ảnh chụp TRƯỚC (FR-12)
 * → undo về đúng state cũ (FR-12). Đây là bản test của các criterion
 * Given/When/Then trong PRD (AGENTS mục 4: criterion là test case).
 */
import { describe, expect, it } from "vitest"
import { buildDueQueue, gradeCard, undoGrade } from "./review"
import type { AppServices } from "../services"
import { createMemServices, sampleItem } from "../../testing/memServices"

const DAY = 24 * 60 * 60 * 1000
const T0 = new Date("2026-09-09T09:00:00.000Z") // 16:00 giờ VN — sau cutoff 4h

async function saveItems(svc: AppServices, count: number, now: Date) {
  const defaultCol = await svc.repos.collections.getDefault()
  expect(defaultCol).not.toBeNull()
  const { saveVocabulary } = await import("./save")
  return saveVocabulary(svc, {
    collectionId: defaultCol!.id,
    items: Array.from({ length: count }, (_, i) =>
      sampleItem({ term: `word${i}`, example: `word${i} appears here.` }),
    ),
    now,
  })
}

describe("FR-09 — lưu item thành card new, đến hạn ngay", () => {
  it("item chọn → vocab_items + card state=new, due_at=now", async () => {
    const svc = await createMemServices({ now: () => T0 })
    const result = await saveItems(svc, 2, T0)

    expect(result.saved).toBe(2)
    const defaultCol = await svc.repos.collections.getDefault()
    const items = await svc.repos.vocabItems.listByCollection(defaultCol!.id)
    expect(items).toHaveLength(2)
    expect(items[0].termNormalized).toBe("word0") // khớp bất biến dạng hiển thị

    const due = await svc.repos.cards.listDueNews({
      nowUtc: T0.toISOString(),
      scopeCollectionIds: null,
      limit: null,
    })
    expect(due).toHaveLength(2)
    for (const c of due) {
      expect(c.state).toBe("new")
      expect(c.dueAt).toBe(T0.toISOString())
    }
  })

  it("collection mặc định tồn tại sẵn (FR-17 phần is_default)", async () => {
    const svc = await createMemServices()
    const def = await svc.repos.collections.getDefault()
    expect(def).not.toBeNull()
    expect(def!.isDefault).toBe(true)
    expect(def!.name.length).toBeGreaterThan(0)
  })
})

describe("FR-11 — hàng đợi hai nhánh + hạn mức thẻ mới", () => {
  it("vượt daily_new_limit → chỉ đưa đủ 10, hoãn phần còn lại", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 12, T0)

    const queue = await buildDueQueue(svc, T0)
    expect(queue.total).toBe(10)
    expect(queue.deferredNew).toBe(2)
    expect(queue.cards.every((c) => c.state === "new")).toBe(true)
  })

  it("thẻ đã GIỚI THIỆU hôm nay (đếm từ log) trừ vào hạn mức", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 12, T0)

    let queue = await buildDueQueue(svc, T0)
    // chấm 3 thẻ ĐẦU TIÊN trong hàng đợi bằng rating Good
    for (let i = 0; i < 3; i++) {
      await gradeCard(svc, {
        card: queue.cards[i],
        rating: "Good",
        now: new Date(T0.getTime() + i * 1000),
      })
    }

    queue = await buildDueQueue(svc, new Date(T0.getTime() + 4000))
    expect(queue.plan.introducedToday).toBe(3)
    // hạn mức còn 7 → trong 9 thẻ new còn lại chỉ 7 vào hàng đợi
    expect(queue.total).toBe(7)
    expect(queue.deferredNew).toBe(2)
  })

  it("thẻ ôn lại KHÔNG bị giới hạn, xếp TRƯỚC thẻ mới", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 1, T0)
    const first = await buildDueQueue(svc, T0)
    await gradeCard(svc, { card: first.cards[0], rating: "Good", now: T0 })

    // Ngày học sau: thẻ kia đã thành review, due ≥ ngày mai → chưa tới hạn.
    const T1 = new Date(T0.getTime() + 4 * DAY)
    await saveItems(svc, 12, T1) // 12 thẻ mới due T1
    const queue = await buildDueQueue(svc, T1)
    const reviewCard = queue.cards.find((c) => c.state === "review")
    expect(reviewCard).toBeDefined()
    expect(reviewCard!.collectionName.length).toBeGreaterThan(0)
    // nhánh review đứng đầu hàng đợi
    expect(queue.cards[0].state).toBe("review")
    // tổng = 1 review (không giới hạn) + 10 new (giới hạn)
    expect(queue.total).toBe(11)
  })

  it("ranh giới ngày theo day_cutoff (4h) — đếm lại hạn mức theo log đúng ngày học", async () => {
    const svc = await createMemServices({
      now: () => new Date("2026-09-09T01:00:00Z"),
      timeZone: "UTC",
    })
    await saveItems(svc, 12, new Date("2026-09-09T01:00:00Z"))

    // 1h sáng (giờ UTC) < cutoff 4h → thuộc ngày học 2026-09-08
    const nightGradeTime = new Date("2026-09-09T01:30:00Z")
    const nightQueue = await buildDueQueue(svc, nightGradeTime)
    await gradeCard(svc, { card: nightQueue.cards[0], rating: "Good", now: nightGradeTime })

    // Vẫn trong buổi đêm đó (01:31) → ngày học 09-08 → đếm được 1 đã giới thiệu
    const stillNight = await buildDueQueue(svc, new Date("2026-09-09T01:31:00Z"))
    expect(stillNight.plan.introducedToday).toBe(1)

    // Sáng hôm sau 05:00 → ngày học MỚI (09-09) → hạn mức reset về 0 đã giới thiệu
    const nextMorning = await buildDueQueue(svc, new Date("2026-09-09T05:00:00Z"))
    expect(nextMorning.plan.introducedToday).toBe(0)
    expect(nextMorning.total).toBe(10) // đủ hạn mức, không bị con số đêm qua ăn vào
  })
})

describe("FR-12 — chấm thẻ: log là ảnh chụp TRƯỚC, undo về đúng state cũ", () => {
  it("chấm Good thẻ mới → state review, due ≥ ngày mai, log giữ trạng thái TRƯỚC", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 1, T0)
    const queue = await buildDueQueue(svc, T0)
    const before = queue.cards[0]

    const { updatedCard, log } = await gradeCard(svc, { card: before, rating: "Good", now: T0 })

    // log = ảnh chụp TRƯỚC khi chấm
    expect(log.stateBefore).toBe("new")
    expect(log.dueBefore).toBe(before.dueAt)
    expect(log.stabilityBefore).toBe(0)
    expect(log.difficultyBefore).toBe(0)
    expect(log.mode).toBe("srs")

    // card = trạng thái SAU khi chấm
    expect(updatedCard.state).toBe("review")
    expect(updatedCard.lastReviewAt).toBe(T0.toISOString())
    expect(Date.parse(updatedCard.dueAt)).toBeGreaterThanOrEqual(T0.getTime() + DAY)

    // và DB thật phản ánh đúng như vậy
    const row = await svc.repos.logs.getById(log.id)
    expect(row!.stateBefore).toBe("new")
    expect(row!.dueBefore).toBe(before.dueAt)
  })

  it("learning steps TẮT: chấm Again thẻ mới vẫn đi Review, không rơi learning", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 1, T0)
    const queue = await buildDueQueue(svc, T0)

    const { updatedCard } = await gradeCard(svc, { card: queue.cards[0], rating: "Again", now: T0 })
    expect(updatedCard.state).toBe("review")
    expect(updatedCard.learningSteps).toBe(0)
    expect(Date.parse(updatedCard.dueAt)).toBeGreaterThanOrEqual(T0.getTime() + DAY)
  })

  it("undo: card về ĐÚNG trạng thái trước chấm (kể cả due_at), log bị xoá", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 1, T0)
    const queue = await buildDueQueue(svc, T0)
    const before = queue.cards[0]

    const { updatedCard, log } = await gradeCard(svc, { card: before, rating: "Easy", now: T0 })
    expect(updatedCard.dueAt).not.toBe(before.dueAt) // chắc chắn đã đổi

    await undoGrade(svc, { logId: log.id, restoreCard: before })

    const gone = await svc.repos.logs.getById(log.id)
    expect(gone).toBeNull()

    const news = await svc.repos.cards.listDueNews({
      nowUtc: T0.toISOString(),
      scopeCollectionIds: null,
      limit: null,
    })
    const restored = news.find((c) => c.id === before.id)
    expect(restored).toBeDefined()
    expect(restored!.state).toBe(before.state)
    expect(restored!.state).toBe("new")
    expect(restored!.dueAt).toBe(before.dueAt) // criterion: kể cả due_at
    expect(restored!.reps).toBe(before.reps)
    expect(restored!.stability).toBe(before.stability)

    // và hạn mức không bị lần chấm nhầm ăn mất
    const queueAfter = await buildDueQueue(svc, T0)
    expect(queueAfter.plan.introducedToday).toBe(0)
  })
})
