/**
 * integration test — FR-16 export chạy trên storage THẬT (SQLite in-memory),
 * dữ liệu seed qua đúng đường sản phẩm: `saveVocabulary` (FR-09) rồi `gradeCard`
 * (FR-12). Ba criterion của FR-16 trong PRD là ba describe dưới đây; AGENTS mục 4:
 * criterion dùng trực tiếp làm test, không viết lại thành ngôn ngữ khác.
 */
import { describe, expect, it } from "vitest"
import { exportData } from "./exportData"
import { buildDueQueue, gradeCard } from "./review"
import { saveVocabulary } from "./save"
import type { AppServices } from "../services"
import type { CardRow, ReviewLogRow } from "../types"
import { createMemServices, sampleItem } from "../../testing/memServices"

const T0 = new Date("2026-09-09T09:00:00.000Z")

interface Seeded {
  svc: AppServices
  defaultId: string
  bookId: string
}

/** Kho tạm 1 từ + collection sách 2 từ, tất cả qua use-case thật. */
async function seed(): Promise<Seeded> {
  const svc = await createMemServices({ now: () => T0 })
  const def = await svc.repos.collections.getDefault()
  expect(def).not.toBeNull()
  const book = await svc.repos.collections.create("The Giver — ch.2", false, T0)

  await saveVocabulary(svc, {
    collectionId: def!.id,
    items: [sampleItem({ term: "alpha", example: "alpha appears here." })],
    now: T0,
  })
  await saveVocabulary(svc, {
    collectionId: book.id,
    items: [
      sampleItem({ term: "beta", example: "beta appears here." }),
      sampleItem({ term: "gamma", ipa: "", cefr: "B1", example: "gamma appears here." }),
    ],
    now: T0,
  })
  return { svc, defaultId: def!.id, bookId: book.id }
}

/** Dòng dữ liệu (bỏ comment `#`) của file TSV. */
function dataLines(tsv: string): string[][] {
  return tsv
    .split("\n")
    .filter((l) => l !== "" && !l.startsWith("#"))
    .map((l) => l.split("\t"))
}

describe("FR-16 criterion 1 — export toàn bộ vocabulary kèm đủ field, định dạng Anki", () => {
  it("TSV có đủ 3 từ với term/pos/ipa/meaning_vi/cefr/câu gốc và TÊN collection", async () => {
    const { svc } = await seed()
    const bundle = await exportData(svc, null)

    expect(bundle.counts.vocabItems).toBe(3)
    const rows = dataLines(bundle.tsv)
    expect(rows).toHaveLength(3)
    for (const r of rows) expect(r).toHaveLength(7)

    const terms = rows.map((r) => r[0]).sort()
    expect(terms).toEqual(["alpha", "beta", "gamma"])

    const alpha = rows.find((r) => r[0] === "alpha")!
    expect(alpha[1]).toBe("adj") // pos
    expect(alpha[2]).toBe("/ˈstæɡərɪŋ/") // ipa
    expect(alpha[3]).toBe("đáng kinh ngạc") // meaning_vi
    expect(alpha[4]).toBe("B2") // cefr
    expect(alpha[5]).toBe("alpha appears here.") // câu gốc
    expect(alpha[6]).toBe("Kho tạm") // TÊN collection, không phải id

    // ipa rỗng → null ở DB → ô rỗng trong file (không phải chữ "null")
    const gamma = rows.find((r) => r[0] === "gamma")!
    expect(gamma[2]).toBe("")
    expect(gamma[4]).toBe("B1")
    expect(gamma[6]).toBe("The Giver — ch.2")
  })
})

describe("FR-16 criterion 2 — export THEO collection, không buộc lấy hết", () => {
  it("chọn một collection → chỉ từ của collection đó, không lẫn kho tạm", async () => {
    const { svc, bookId, defaultId } = await seed()

    const book = await exportData(svc, bookId)
    expect(book.counts.vocabItems).toBe(2)
    expect(
      dataLines(book.tsv)
        .map((r) => r[0])
        .sort(),
    ).toEqual(["beta", "gamma"])
    expect(book.tsv).not.toContain("alpha")
    expect(book.scope).toEqual({ collectionId: bookId, collectionName: "The Giver — ch.2" })

    const def = await exportData(svc, defaultId)
    expect(def.counts.vocabItems).toBe(1)
    expect(dataLines(def.tsv).map((r) => r[0])).toEqual(["alpha"])
  })

  it("card và log cũng bị lọc theo đúng scope (không rò collection khác vào JSON)", async () => {
    const { svc, bookId } = await seed()
    const queue = await buildDueQueue(svc, T0)
    const bookCard = queue.cards.find((c) => c.collectionName === "The Giver — ch.2")!
    await gradeCard(svc, { card: bookCard, rating: "Good", now: T0 })

    const book = await exportData(svc, bookId)
    expect(book.counts.cards).toBe(2) // 2 từ của collection sách
    expect(book.counts.reviewLogs).toBe(1) // chỉ log của card vừa chấm
    const parsed = JSON.parse(book.json) as { cards: CardRow[]; reviewLogs: ReviewLogRow[] }
    expect(
      parsed.cards.every((c) => c.vocabItemId === bookCard.vocabItemId || c.state !== undefined),
    ).toBe(true)
    expect(parsed.reviewLogs[0].cardId).toBe(bookCard.id)

    const all = await exportData(svc, null)
    expect(all.counts.cards).toBe(3)
    expect(all.counts.reviewLogs).toBe(1)
  })
})

describe("FR-16 criterion 3 — JSON kèm trạng thái FSRS + review log, máy đọc được", () => {
  it("sau khi chấm: card trong JSON mang state/stability/difficulty/dueAt THẬT từ DB", async () => {
    const { svc } = await seed()
    const queue = await buildDueQueue(svc, T0)
    const target = queue.cards[0]
    const { updatedCard, log } = await gradeCard(svc, { card: target, rating: "Good", now: T0 })

    const bundle = await exportData(svc, null)
    const parsed = JSON.parse(bundle.json) as {
      format: string
      version: number
      exportedAt: string
      counts: { vocabItems: number; cards: number; reviewLogs: number }
      cards: CardRow[]
      reviewLogs: ReviewLogRow[]
    }

    expect(parsed.format).toBe("reado-export")
    expect(parsed.version).toBe(1)
    expect(parsed.exportedAt).toBe(T0.toISOString()) // clock injectable, tất định
    expect(parsed.counts).toEqual({ vocabItems: 3, cards: 3, reviewLogs: 1 })

    const exportedCard = parsed.cards.find((c) => c.id === target.id)!
    expect(exportedCard.state).toBe(updatedCard.state)
    expect(exportedCard.stability).toBe(updatedCard.stability)
    expect(exportedCard.difficulty).toBe(updatedCard.difficulty)
    expect(exportedCard.reps).toBe(updatedCard.reps)
    expect(exportedCard.dueAt).toBe(updatedCard.dueAt)
    expect(exportedCard.state).toBe("review") // learning steps tắt (Q-12)

    // log export vẫn là ảnh chụp TRƯỚC khi chấm (điều cấm #1 — export không đổi ngữ nghĩa)
    const exportedLog = parsed.reviewLogs[0]
    expect(exportedLog.id).toBe(log.id)
    expect(exportedLog.stateBefore).toBe("new")
    expect(exportedLog.stabilityBefore).toBe(0)
    expect(exportedLog.dueBefore).toBe(target.dueAt)
    expect(exportedLog.rating).toBe(3) // Good
  })

  it("API key đã lưu trong settings KHÔNG xuất hiện trong JSON (điều cấm #9, test end-to-end)", async () => {
    const { svc } = await seed()
    await svc.repos.settings.updatePartial({
      aiApiKey: "e2e-secret-key-12345",
      aiBaseUrl: "https://gw.example/secret-path",
    })

    const bundle = await exportData(svc, null)
    expect(bundle.json).not.toContain("e2e-secret-key-12345")
    expect(bundle.json).not.toContain("secret-path")
    expect(bundle.json).not.toContain("aiApiKey")
    // phần không secret vẫn đi theo để khôi phục được cấu hình học
    expect(JSON.parse(bundle.json).settings).toMatchObject({
      dailyNewLimit: 10,
      requestRetention: 0.9,
      dayCutoffHour: 4,
    })
  })
})

describe("NFR-05 — export phải LUÔN hoạt động", () => {
  it("collection rỗng: không ném lỗi, counts 0, TSV vẫn hợp lệ (chỉ header)", async () => {
    const { svc } = await seed()
    const empty = await svc.repos.collections.create("Sách chưa đọc", false, T0)

    const bundle = await exportData(svc, empty.id)
    expect(bundle.counts).toEqual({ vocabItems: 0, cards: 0, reviewLogs: 0 })
    expect(dataLines(bundle.tsv)).toHaveLength(0)
    expect(bundle.tsv.startsWith("#separator:tab")).toBe(true)
    expect(JSON.parse(bundle.json).counts.vocabItems).toBe(0)
  })

  it("scope một collection không tồn tại → vẫn trả bundle (tên null), không crash", async () => {
    const { svc } = await seed()
    const bundle = await exportData(svc, "khong-ton-tai")
    expect(bundle.scope).toEqual({ collectionId: "khong-ton-tai", collectionName: null })
    expect(bundle.counts.vocabItems).toBe(0)
  })
})
