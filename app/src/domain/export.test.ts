/**
 * domain/export.test.ts — test ba criterion của FR-16 ở tầng THUẦN (builder),
 * cộng một test cho điều cấm #9 (secret không được vào file export).
 *
 * AGENTS mục 4: criterion Given/When/Then dùng trực tiếp làm test, không viết lại
 * thành ngôn ngữ khác.
 */
import { describe, expect, it } from "vitest"
import {
  ANKI_TSV_COLUMNS,
  EXPORT_FORMAT,
  EXPORT_VERSION,
  buildAnkiTsv,
  buildJsonExport,
  countsOf,
  toExportableSettings,
} from "./export"
import type { ExportDataset, ExportItem } from "./export"
import type { CardRow, ReviewLogRow, Settings } from "./types"

function item(overrides: Partial<ExportItem> = {}): ExportItem {
  return {
    id: "v1",
    collectionId: "c1",
    term: "staggering",
    termNormalized: "staggering",
    pos: "adj",
    ipa: "/ˈstæɡərɪŋ/",
    meaningVi: "đáng kinh ngạc",
    example: "The staggering scale of the problem.",
    cefr: "B2",
    tags: [],
    synonyms: [],
    antonyms: [],
    createdAt: "2026-09-08T02:00:00.000Z",
    collectionName: "The Giver — ch.2",
    ...overrides,
  }
}

function card(overrides: Partial<CardRow> = {}): CardRow {
  return {
    id: "k1",
    vocabItemId: "v1",
    direction: "receptive",
    state: "review",
    stability: 4.2,
    difficulty: 5.1,
    reps: 3,
    lapses: 1,
    learningSteps: 0,
    scheduledDays: 4,
    lastReviewAt: "2026-09-07T02:00:00.000Z",
    dueAt: "2026-09-11T02:00:00.000Z",
    suspendedAt: null,
    ...overrides,
  }
}

function log(overrides: Partial<ReviewLogRow> = {}): ReviewLogRow {
  return {
    id: "l1",
    cardId: "k1",
    mode: "srs",
    rating: 3,
    stateBefore: "new",
    stabilityBefore: 0,
    difficultyBefore: 0,
    learningStepsBefore: 0,
    dueBefore: "2026-09-06T02:00:00.000Z",
    elapsedDays: 0,
    scheduledDays: 1,
    reviewedAt: "2026-09-06T02:00:00.000Z",
    ...overrides,
  }
}

function settings(overrides: Partial<Settings> = {}): Settings {
  return {
    cefrLevel: "B1",
    dailyNewLimit: 10,
    aiProvider: "gemini",
    aiBaseUrl: "https://generativelanguage.googleapis.com/v1beta",
    aiApiKey: "SUPER-SECRET-KEY-DO-NOT-LEAK",
    aiModel: "gemini-3.6-flash",
    requestRetention: 0.9,
    maximumInterval: 365,
    enableFuzz: true,
    dayCutoffHour: 4,
    fsrsParams: null,
    fsrsVersion: null,
    ...overrides,
  }
}

function dataset(overrides: Partial<ExportDataset> = {}): ExportDataset {
  return {
    scope: { collectionId: null, collectionName: null },
    exportedAt: "2026-09-08T12:00:00.000Z",
    items: [item()],
    cards: [card()],
    logs: [log()],
    settings: toExportableSettings(settings()),
    ...overrides,
  }
}

describe("FR-16 criterion 1 — export đủ field, nhập được vào Anki", () => {
  it("mỗi item một dòng TSV, đủ 7 cột: term/pos/ipa/meaning_vi/cefr/example/TÊN collection", () => {
    const tsv = buildAnkiTsv([
      item(),
      item({ id: "v2", term: "giver", pos: "noun", ipa: null, cefr: null }),
    ])
    const dataLines = tsv.split("\n").filter((l) => l !== "" && !l.startsWith("#"))

    expect(dataLines).toHaveLength(2)
    const cols = dataLines[0].split("\t")
    expect(cols).toHaveLength(ANKI_TSV_COLUMNS.length)
    expect(cols).toEqual([
      "staggering",
      "adj",
      "/ˈstæɡərɪŋ/",
      "đáng kinh ngạc",
      "B2",
      "The staggering scale of the problem.",
      "The Giver — ch.2", // criterion đòi TÊN collection, không phải id
    ])
    // ipa/cefr null → ô rỗng chứ không phải chữ "null"
    expect(dataLines[1].split("\t")[2]).toBe("")
    expect(dataLines[1].split("\t")[4]).toBe("")
  })

  it("header khai báo separator=tab và html=false; dòng mô tả cột là comment Anki bỏ qua", () => {
    const tsv = buildAnkiTsv([item()])
    const lines = tsv.split("\n")
    expect(lines[0]).toBe("#separator:tab")
    expect(lines[1]).toBe("#html:false")
    expect(lines[2]).toContain(ANKI_TSV_COLUMNS.join(" | "))
    // mọi dòng trước dữ liệu đều bắt đầu bằng # → Anki bỏ qua kể cả khi không hiểu directive
    expect(lines.slice(0, 4).every((l) => l.startsWith("#"))).toBe(true)
  })

  it("tab/xuống dòng trong field bị thay bằng khoảng trắng — không phá ranh giới cột/dòng", () => {
    const tsv = buildAnkiTsv([item({ meaningVi: "dòng1\ndòng2", example: "có\ttab" })])
    const dataLines = tsv.split("\n").filter((l) => l !== "" && !l.startsWith("#"))
    expect(dataLines).toHaveLength(1) // xuống dòng không đẻ thêm dòng dữ liệu
    expect(dataLines[0].split("\t")).toHaveLength(ANKI_TSV_COLUMNS.length) // tab không đẻ thêm cột
    expect(dataLines[0]).toContain("dòng1 dòng2")
    expect(dataLines[0]).toContain("có tab")
  })

  it("kho rỗng vẫn cho file hợp lệ (chỉ header) — NFR-05: export không được chết", () => {
    const tsv = buildAnkiTsv([])
    expect(tsv.split("\n").filter((l) => l !== "" && !l.startsWith("#"))).toHaveLength(0)
    expect(tsv.startsWith("#separator:tab")).toBe(true)
  })
})

describe("FR-16 criterion 3 — JSON kèm trạng thái FSRS + review log", () => {
  it("JSON parse được, có format/version/scope/counts, card giữ nguyên bộ FSRS, log giữ ảnh chụp TRƯỚC", () => {
    const json = buildJsonExport(dataset())
    const parsed = JSON.parse(json) as Record<string, unknown>

    expect(parsed.format).toBe(EXPORT_FORMAT)
    expect(parsed.version).toBe(EXPORT_VERSION)
    expect(parsed.exportedAt).toBe("2026-09-08T12:00:00.000Z")
    expect(parsed.counts).toEqual({ vocabItems: 1, cards: 1, reviewLogs: 1 })

    const cards = parsed.cards as CardRow[]
    expect(cards[0]).toMatchObject({
      state: "review",
      stability: 4.2,
      difficulty: 5.1,
      reps: 3,
      lapses: 1,
      dueAt: "2026-09-11T02:00:00.000Z",
    })

    const logs = parsed.reviewLogs as ReviewLogRow[]
    expect(logs[0]).toMatchObject({
      rating: 3,
      stateBefore: "new",
      stabilityBefore: 0,
      dueBefore: "2026-09-06T02:00:00.000Z",
    })

    const items = parsed.vocabItems as ExportItem[]
    expect(items[0].collectionName).toBe("The Giver — ch.2")
  })

  it("scope một collection được ghi rõ trong JSON (id + tên)", () => {
    const json = buildJsonExport(
      dataset({ scope: { collectionId: "c1", collectionName: "The Giver — ch.2" } }),
    )
    expect(JSON.parse(json).scope).toEqual({
      collectionId: "c1",
      collectionName: "The Giver — ch.2",
    })
  })
})

describe("Điều cấm #9 — secret không bao giờ vào file export", () => {
  it("whitelist settings loại ai_api_key VÀ ai_base_url (gateway có thể nhúng token trong URL)", () => {
    const s = settings()
    const exported = toExportableSettings(s)

    expect(Object.keys(exported)).not.toContain("aiApiKey")
    expect(Object.keys(exported)).not.toContain("aiBaseUrl")
    expect(exported.aiProvider).toBe("gemini") // phần không secret vẫn giữ
    expect(exported.cefrLevel).toBe("B1")
  })

  it("chuỗi key không xuất hiện ở bất kỳ đâu trong JSON lẫn TSV", () => {
    const secret = settings().aiApiKey!
    const d = dataset()
    expect(buildJsonExport(d)).not.toContain(secret)
    expect(buildAnkiTsv(d.items)).not.toContain(secret)
    expect(buildJsonExport(d)).not.toContain("aiApiKey")
  })
})

describe("countsOf — con số hiện cho owner sau khi export", () => {
  it("đếm đúng ba loại", () => {
    expect(
      countsOf(
        dataset({
          items: [item(), item({ id: "v2" })],
          cards: [card()],
          logs: [log(), log({ id: "l2" })],
        }),
      ),
    ).toEqual({
      vocabItems: 2,
      cards: 1,
      reviewLogs: 2,
    })
  })
})
