/**
 * integration test — FR-14 các con số trang chủ, chạy trên SQLite thật. Bộ test
 * này LẦN LƯỢT là các criterion trong PRD (AGENTS mục 4: dùng criteria trực
 * tiếp làm test). Seed qua đúng đường sản phẩm saveVocabulary → buildDueQueue →
 * gradeCard → recordAnalyzedPage.
 */
import { describe, expect, it } from "vitest"
import type { AnalysisResult } from "../../domain/types"
import { getHomeStats } from "../../domain/usecases/homeStats"
import { recordAnalyzedPage } from "../../domain/usecases/analyze"
import { buildDueQueue, gradeCard } from "../../domain/usecases/review"
import { saveVocabulary } from "../../domain/usecases/save"
import type { AppServices } from "../services"
import { createMemServices, sampleItem } from "../../testing/memServices"

const DAY = 24 * 60 * 60 * 1000
// 2026-09-10T02:00Z = 09:00 giờ Ho_Chi_Minh (UTC+7) → sau cutoff 4h, ngày học 09-10.
const T0 = new Date("2026-09-10T02:00:00.000Z")

async function saveItems(svc: AppServices, n: number, now: Date): Promise<void> {
  const items = Array.from({ length: n }, (_, i) =>
    sampleItem({ term: `word${i}`, example: `Sentence with word${i}.` }),
  )
  await saveVocabulary(svc, {
    collectionId: (await svc.repos.collections.getDefault())!.id,
    items,
    now,
  })
}

function sampleAnalysis(): AnalysisResult {
  return {
    segments: [],
    vocabulary: [],
    summaryVi: "",
    usage: { promptTokens: 12, candidatesTokens: 34 },
    latencyMs: 18900,
    promptVersion: 3,
  }
}

describe("FR-14 criterion 1+2 — con số đến hạn là số SẼ ôn (đã áp hạn mức thẻ mới)", () => {
  it("12 thẻ mới, limit 10 → đến hạn 10; phần vượt là con số TỒN RIÊNG", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 12, T0)

    const stats = await getHomeStats(svc)

    expect(stats.dailyNewLimit).toBe(10)
    expect(stats.dueToday).toBe(10) // 12 due thật, nhưng chỉ 10 được ôn
    expect(stats.backlog).toBe(2) // phần tồn — criterion 3: nhãn riêng là việc của UI
  })

  it("con số bằng đúng total của màn ôn tập — không có đường đếm thứ hai", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 12, T0)

    const stats = await getHomeStats(svc)
    const queue = await buildDueQueue(svc, new Date(svc.now()))

    expect(stats.dueToday).toBe(queue.total)
  })

  it("đã giới thiệu vài thẻ hôm nay → hạn mức còn lại đúng, tồn tăng", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 12, T0)
    const queue = await buildDueQueue(svc, T0)
    // Chấm 2 thẻ mới Good → review, due ≥ ngày mai → không còn đến hạn hôm nay.
    await gradeCard(svc, { card: queue.cards[0], rating: "Good", now: T0 })
    await gradeCard(svc, { card: queue.cards[1], rating: "Good", now: T0 })

    const stats = await getHomeStats(svc)
    // 10 thẻ mới còn due; đã giới thiệu 2 → còn slot 8, tồn 2.
    expect(stats.introducedToday).toBe(2)
    expect(stats.dueToday).toBe(8)
    expect(stats.backlog).toBe(2)
  })
})

describe("FR-14 criterion 5 — streak theo giờ chuyển ngày, không theo nửa đêm", () => {
  it("đêm 3h (trước cutoff) tính vào ngày học trước → streak không đứt oan", async () => {
    // Asia/Ho_Chi_Minh (UTC+7). 20:00Z ngày 09 = 03:00 local ngày 10 → trước
    // cutoff 4h → vẫn ngày HỌC 09-09. Đây là tình huống người học đêm mà PRD
    // nói "streak đứt oan nếu dùng nửa đêm hệ thống".
    let clock = new Date("2026-09-09T05:00:00.000Z") // 12:00 local ngày 09-09
    const svc = await createMemServices({
      now: () => new Date(clock),
      timeZone: "Asia/Ho_Chi_Minh",
    })
    await saveItems(svc, 1, clock)

    // Sáng 09-09 ôn 1 thẻ → ngày học 09-09 có ôn.
    const morning = await buildDueQueue(svc, clock)
    await gradeCard(svc, { card: morning.cards[0], rating: "Good", now: clock })

    // Đêm 03:00 local "ngày 10" — ngày HỌC hiện tại vẫn là 09-09 → streak 1,
    // không phải 0 (nửa đêm hệ thống đã sang ngày mới).
    clock = new Date("2026-09-09T20:00:00.000Z")
    const night = await getHomeStats(svc)
    expect(night.streakDays).toBe(1)

    // Sáng thật 10-09 (09:00 local): hôm nay CHƯA ôn, hôm qua có → streak còn.
    clock = new Date("2026-09-10T02:00:00.000Z")
    const nextMorning = await getHomeStats(svc)
    expect(nextMorning.streakDays).toBe(1)
  })

  it("hai ngày học liên tiếp (kể cả vắt qua đêm) → streak 2", async () => {
    let clock = new Date("2026-09-09T05:00:00.000Z") // trưa local 09-09
    const svc = await createMemServices({
      now: () => new Date(clock),
      timeZone: "Asia/Ho_Chi_Minh",
    })
    await saveItems(svc, 2, clock)

    // Đêm 03:00 local "ngày 10": ôn thẻ đầu — vẫn ngày học 09-09.
    clock = new Date("2026-09-09T20:00:00.000Z")
    const night = await buildDueQueue(svc, clock)
    await gradeCard(svc, { card: night.cards[0], rating: "Good", now: clock })

    // Sáng 10-09: ôn thẻ còn lại — ngày học 10-09.
    clock = new Date("2026-09-10T02:00:00.000Z")
    const morning = await buildDueQueue(svc, clock)
    await gradeCard(svc, { card: morning.cards[0], rating: "Good", now: clock })

    const stats = await getHomeStats(svc)
    expect(stats.streakDays).toBe(2)
  })
})

describe("FR-14 criterion 4 — leech (suspended) không được tính vào con số nào", () => {
  it("card review suspended đến hạn hôm nay bị loại khỏi đến hạn", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 1, T0)
    // lấy một item để gắn card suspended (direction productive ≠ receptive có sẵn)
    const item = (await svc.repos.vocabItems.listByScope(null))[0]

    await svc.repos.cards.insertBatch([
      {
        id: "leech1".padEnd(32, "a"),
        vocabItemId: item.id,
        direction: "productive",
        state: "review",
        stability: 5,
        difficulty: 4,
        reps: 6,
        lapses: 4,
        learningSteps: 0,
        scheduledDays: 10,
        lastReviewAt: new Date(T0.getTime() - DAY).toISOString(),
        dueAt: new Date(T0.getTime() - DAY).toISOString(), // quá hạn — sẽ bị đưa ra nếu không suspended
        suspendedAt: new Date(T0.getTime() - DAY).toISOString(),
      },
    ])

    const stats = await getHomeStats(svc)
    expect(stats.dueToday).toBe(1) // chỉ thẻ new gốc; leech bị loại
    expect(stats.backlog).toBe(0)
  })

  it("card NEW suspended không ăn hạn mức, không nằm trong tồn", async () => {
    const svc = await createMemServices({ now: () => T0 })
    await saveItems(svc, 11, T0) // 11 new due; limit 10 → tồn 1
    const item = (await svc.repos.vocabItems.listByScope(null))[0]

    await svc.repos.cards.insertBatch([
      {
        id: "leech2".padEnd(32, "b"),
        vocabItemId: item.id,
        direction: "productive",
        state: "new",
        stability: 0,
        difficulty: 0,
        reps: 0,
        lapses: 0,
        learningSteps: 0,
        scheduledDays: 0,
        lastReviewAt: null,
        dueAt: T0.toISOString(), // due hôm nay nhưng suspended → không được đếm
        suspendedAt: T0.toISOString(),
      },
    ])

    const stats = await getHomeStats(svc)
    expect(stats.dueToday).toBe(10)
    expect(stats.backlog).toBe(1) // tồn vẫn 1 (từ 11 thẻ thật), leech không làm nó thành 2
  })
})

describe("FR-14 criterion 1 — số trang đã phân tích đếm từ sự kiện thật", () => {
  it("chưa phân tích gì → 0; mỗi lần recordAnalyzedPage thành công → +1", async () => {
    const svc = await createMemServices({ now: () => T0 })

    expect((await getHomeStats(svc)).analyzedPages).toBe(0)

    await recordAnalyzedPage(svc, sampleAnalysis())
    await recordAnalyzedPage(svc, sampleAnalysis())

    expect((await getHomeStats(svc)).analyzedPages).toBe(2)
  })
})
