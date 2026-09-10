/**
 * integration test — task 3.13 Targeted review (cram theo tag) trên SQLite thật.
 * Hợp đồng docs/rich-vocab-cram-ddl.md mục 5 (D-3 + Q-11 phần đã chốt):
 *  - phiên cram KHÔNG lọc due_at, KHÔNG giới hạn daily_new_limit;
 *  - chấm cram KHÔNG đụng MỘT CỘT nào của cards;
 *  - log mode='cram', ảnh chụp TRƯỚC, scheduled_days=0;
 *  - undo cram = xoá log (card chưa từng đổi);
 *  - log cram KHÔNG ăn hạn mức thẻ mới của FR-11 (countIntroducedNew chỉ srs).
 */
import { describe, expect, it } from "vitest"
import { buildDueQueue } from "./review"
import { saveVocabulary } from "./save"
import { buildCramSession, gradeCram, listCramTags, undoCram } from "./cram"
import type { AppServices } from "../services"
import type { CardWithContext } from "../types"
import { createMemServices, createMemServicesBundle, sampleItem } from "../../testing/memServices"

const T0 = new Date("2026-09-09T09:00:00.000Z")

/** 12 thẻ new: 3 mang tag "idiom", cả 12 mang tag "batch". */
async function seed(): Promise<AppServices> {
  const svc = await createMemServices({ now: () => T0 })
  const def = await svc.repos.collections.getDefault()
  expect(def).not.toBeNull()
  await saveVocabulary(svc, {
    collectionId: def!.id,
    items: Array.from({ length: 12 }, (_, i) =>
      sampleItem({
        term: `word${i}`,
        example: `word${i} appears here.`,
        // 3 từ đầu mang tag "idiom"; tất cả mang "batch" → kiểm được cả
        // multi-tag trùng card lẫn số lượng vượt hạn mức.
        tags: i < 3 ? ["idiom", "batch"] : ["batch"],
      }),
    ),
    now: T0,
  })
  return svc
}

async function cardById(svc: AppServices, id: string): Promise<CardWithContext | null> {
  const rows = await svc.repos.cards.loadWithContext([id])
  return rows[0] ?? null
}

describe("listCramTags — đếm đúng số card mỗi tag", () => {
  it("3 card tag 'idiom', 12 card tag 'batch' — mỗi tag một dòng", async () => {
    const svc = await seed()
    const tags = await listCramTags(svc)
    const idiom = tags.find((t) => t.tag === "idiom")
    const batch = tags.find((t) => t.tag === "batch")
    expect(idiom?.cardCount).toBe(3)
    expect(batch?.cardCount).toBe(12)
    expect(tags).toHaveLength(2)
  })
})

describe("buildCramSession — dựng phiên đúng hợp đồng", () => {
  it("chỉ gồm card mang tag đã chọn; multi-select hợp mọi card khớp ÍT NHẤT một tag", async () => {
    const svc = await seed()
    const only = await buildCramSession(svc, ["idiom"])
    expect(only).toHaveLength(3)
    expect(only.every((c) => c.tags.includes("idiom"))).toBe(true)
  })

  it("KHÔNG giới hạn daily_new_limit (12 thẻ > hạn mức 10 vẫn vào đủ)", async () => {
    const svc = await seed()
    // Hàng đợi thường chỉ cho 10 (hạn mức), cram phải cho đủ 12.
    const regular = await buildDueQueue(svc, T0)
    expect(regular.total).toBe(10)
    const cram = await buildCramSession(svc, ["batch"])
    expect(cram).toHaveLength(12)
  })

  it("KHÔNG lọc due_at — thẻ due trong quá khứ lẫn tương lai đều vào phiên", async () => {
    const { services: svc, appDb } = await createMemServicesBundle({ now: () => T0 })
    const def = await svc.repos.collections.getDefault()
    await saveVocabulary(svc, {
      collectionId: def!.id,
      items: Array.from({ length: 12 }, (_, i) =>
        sampleItem({ term: `word${i}`, example: `word${i} appears here.`, tags: ["batch"] }),
      ),
      now: T0,
    })

    // Đẩy due_at của hai thẻ ra xa bằng SQL trực tiếp (đường sản phẩm không cho).
    const all = await svc.repos.cards.listByTags(["batch"])
    const past = all[0]
    const future = all[11]
    await appDb.exec(
      `update cards set state = 'review', stability = 1, difficulty = 5, reps = 1,
             scheduled_days = 1, last_review_at = ?, due_at = ? where id = ?`,
      ["2026-01-01T00:00:00.000Z", "2026-01-02T00:00:00.000Z", past.id], // quá khứ
    )
    await appDb.exec(
      `update cards set state = 'review', stability = 1, difficulty = 5, reps = 1,
             scheduled_days = 1, last_review_at = ?, due_at = ? where id = ?`,
      ["2026-09-09T00:00:00.000Z", "2027-01-01T00:00:00.000Z", future.id], // tương lai
    )
    const cram = await buildCramSession(svc, ["batch"])
    expect(cram.map((c) => c.id)).toContain(past.id)
    expect(cram.map((c) => c.id)).toContain(future.id)
    expect(cram).toHaveLength(12)
  })

  it("tag rỗng / không tồn tại → phiên rỗng, không ném lỗi", async () => {
    const svc = await seed()
    expect(await buildCramSession(svc, [])).toEqual([])
    expect(await buildCramSession(svc, ["no-such-tag"])).toEqual([])
  })
})

describe("gradeCram — chấm không đụng FSRS state", () => {
  it("log mode='cram' là ảnh chụp TRƯỚC + scheduled_days=0; cards không đổi cột nào", async () => {
    const svc = await seed()
    const session = await buildCramSession(svc, ["idiom"])
    const before = session[0]
    const beforeRow = (await cardById(svc, before.id))!

    const { log } = await gradeCram(svc, { card: before, rating: "Easy", now: T0 })

    expect(log.mode).toBe("cram")
    expect(log.rating).toBe(4) // Easy
    expect(log.stateBefore).toBe(before.state)
    expect(log.dueBefore).toBe(before.dueAt)
    expect(log.stabilityBefore).toBe(before.stability)
    expect(log.scheduledDays).toBe(0)

    // cards KHÔNG đổi MỘT cột nào — đúng D-3.
    const afterRow = (await cardById(svc, before.id))!
    expect(afterRow.state).toBe(beforeRow.state)
    expect(afterRow.stability).toBe(beforeRow.stability)
    expect(afterRow.difficulty).toBe(beforeRow.difficulty)
    expect(afterRow.reps).toBe(beforeRow.reps)
    expect(afterRow.lapses).toBe(beforeRow.lapses)
    expect(afterRow.dueAt).toBe(beforeRow.dueAt)
    expect(afterRow.lastReviewAt).toBe(beforeRow.lastReviewAt)

    // log thật nằm trong DB và đọc lại đúng.
    const stored = await svc.repos.logs.getById(log.id)
    expect(stored?.mode).toBe("cram")
    expect(stored?.stateBefore).toBe(before.state)
  })

  it("cram thẻ new KHÔNG ăn hạn mức thẻ mới của FR-11 (introducedToday vẫn 0)", async () => {
    const svc = await seed()
    const session = await buildCramSession(svc, ["idiom"])
    await gradeCram(svc, { card: session[0], rating: "Good", now: T0 })
    const queue = await buildDueQueue(svc, T0)
    expect(queue.plan.introducedToday).toBe(0)
    expect(queue.total).toBe(10) // hạn mức nguyên vẹn
  })
})

describe("undoCram — xoá log, không cần restore card", () => {
  it("sau undo: log biến mất, card y nguyên, người dùng gặp lại đúng thẻ", async () => {
    const svc = await seed()
    const session = await buildCramSession(svc, ["idiom"])
    const before = session[0]
    const beforeDue = before.dueAt

    const { log } = await gradeCram(svc, { card: before, rating: "Good", now: T0 })
    await undoCram(svc, log.id)

    expect(await svc.repos.logs.getById(log.id)).toBeNull()
    const after = (await cardById(svc, before.id))!
    expect(after.dueAt).toBe(beforeDue)
    expect(after.state).toBe(before.state)
  })
})
