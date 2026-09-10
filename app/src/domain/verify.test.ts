/**
 * domain/verify.test.ts — kiểm schema (prompt-spec mục 4) + ba nhánh xác minh
 * (mục 6). Đây chính là các criterion kiểm được bằng máy của FR-02.
 */
import { describe, expect, it } from "vitest"
import {
  normalizePageText,
  normalizeRichField,
  toAnalysisResult,
  validateAiPayload,
  verificationOf,
} from "./verify"
import type { AiPayload } from "./verify"

describe("normalizePageText (mục 6)", () => {
  it("đưa nháy cong về nháy thẳng, gạch – — về gạch -", () => {
    expect(normalizePageText("He said “hello” — it’s fine – really")).toBe(
      `he said "hello" - it's fine - really`,
    )
  })

  it("gộp whitespace dòng mới thành khoảng trắng đơn, lowercase, trim", () => {
    expect(normalizePageText("  The   Cat\n\nSat  ")).toBe("the cat sat")
  })
})

describe("verificationOf — ba nhánh (mục 6)", () => {
  const page = normalizePageText(
    "The staggering scale of the problem. He proved remarkably resilient.",
  )

  it("example có thật và chứa term → verified", () => {
    expect(verificationOf(page, "staggering", "The staggering scale of the problem.")).toBe(
      "verified",
    )
  })

  it("example có thật nhưng KHÔNG chứa term → suspect", () => {
    expect(verificationOf(page, "resilient", "The staggering scale of the problem.")).toBe(
      "suspect",
    )
  })

  it("example không đối chiếu được → unverified (AI tự bịa câu)", () => {
    expect(verificationOf(page, "staggering", "Prices were staggering last year.")).toBe(
      "unverified",
    )
  })

  it("khác biệt hoa thường và khoảng trắng không làm sai nhánh", () => {
    expect(verificationOf(page, "  STAGGERING ", " The staggering  scale of the problem. ")).toBe(
      "verified",
    )
  })
})

describe("validateAiPayload (mục 4 — additionalProperties:false mọi cấp)", () => {
  const base = {
    segments: [{ source_en: "Hello.", translation_vi: "Xin chào." }],
    vocabulary: [
      {
        term: "hello",
        pos: "noun",
        ipa: "/həˈloʊ/",
        meaning_vi: "xin chào",
        cefr: "A2",
        example: "Hello.",
      },
    ],
    summary_vi: "Lời chào.",
  }

  it("payload đúng chuẩn → 0 vi phạm", () => {
    expect(validateAiPayload(structuredClone(base))).toEqual([])
  })

  it("key lạ ở root bị bắt (additionalProperties:false)", () => {
    const bad = { ...structuredClone(base), extra: 1 }
    expect(validateAiPayload(bad).join("\n")).toContain('key lạ "extra"')
  })

  it("key lạ trong item vocabulary bị bắt", () => {
    const bad = structuredClone(base)
    ;(bad.vocabulary[0] as Record<string, unknown>).extra = "x"
    expect(validateAiPayload(bad).join("\n")).toContain("vocabulary[0]: key lạ")
  })

  it("thiếu field bắt buộc bị bắt", () => {
    const bad = structuredClone(base)
    delete (bad.vocabulary[0] as Record<string, unknown>).example
    expect(validateAiPayload(bad).join("\n")).toContain('thiếu "example"')
  })

  it("pos ngoài enum bị bắt", () => {
    const bad = structuredClone(base)
    ;(bad.vocabulary[0] as Record<string, unknown>).pos = "conjunction"
    expect(validateAiPayload(bad).join("\n")).toContain("pos: ngoài enum")
  })

  it("field rỗng bị bắt bởi minLength (ipa là ngoại lệ duy nhất)", () => {
    const bad = structuredClone(base)
    bad.segments[0].source_en = ""
    const bad2 = structuredClone(base)
    bad2.vocabulary[0].ipa = "" // được phép rỗng
    expect(validateAiPayload(bad).join("\n")).toContain("source_en: độ dài < 1")
    expect(validateAiPayload(bad2)).toEqual([])
  })
})

describe("rich vocab (task 3.12) — 3 field optional, bổ trợ, giới hạn RV-1 3/3/4", () => {
  const itemWithRich = {
    term: "lend",
    pos: "verb",
    ipa: "/lend/",
    meaning_vi: "cho mượn",
    cefr: "B1",
    example: "Could you lend me a hand?",
    tags: ["idiom", "everyday"],
    synonyms: ["loan", "give"],
    antonyms: ["borrow"],
  }

  it("payload có 3 field hợp lệ → validateAiPayload 0 vi phạm (key KHÔNG bị coi là lạ)", () => {
    const payload = {
      segments: [
        {
          source_en: "Could you lend me a hand?",
          translation_vi: "Bạn giúp tôi một tay được không?",
        },
      ],
      vocabulary: [itemWithRich],
      summary_vi: "Nhờ giúp đỡ.",
    }
    expect(validateAiPayload(payload)).toEqual([])
  })

  it("thiếu 3 field (output cũ / provider chặt schema) → vẫn hợp lệ, result điền []", () => {
    // Key tags/synonyms/antonyms VẮNG MẶT hẳn khỏi object — vẫn satisfies
    // AiPayload vì 3 field là optional (hợp đồng 3.12 mục 3).
    const payload = {
      segments: [
        {
          source_en: "Could you lend me a hand?",
          translation_vi: "Bạn giúp tôi một tay được không?",
        },
      ],
      vocabulary: [
        {
          term: "lend",
          pos: "verb",
          ipa: "/lend/",
          meaning_vi: "cho mượn",
          cefr: "B1",
          example: "Could you lend me a hand?",
        },
      ],
      summary_vi: "Nhờ giúp đỡ.",
    } satisfies AiPayload
    const result = toAnalysisResult(payload, {
      promptTokens: 1,
      candidatesTokens: 1,
      latencyMs: 1,
      promptVersion: 2,
    })
    expect(result.vocabulary[0].tags).toEqual([])
    expect(result.vocabulary[0].synonyms).toEqual([])
    expect(result.vocabulary[0].antonyms).toEqual([])
  })

  it("sai type (string thay vì array) → KHÔNG ném lỗi, điền [] — field phụ không được phá cả trang", () => {
    expect(normalizeRichField("idiom", 4)).toEqual([])
    expect(normalizeRichField({}, 4)).toEqual([])
    expect(normalizeRichField(null, 4)).toEqual([])
  })

  it("vượt giới hạn → cắt về RV-1 (4 tag / 3 syn / 3 ant) thay vì từ chối payload", () => {
    expect(normalizeRichField(["a", "b", "c", "d", "e"], 4)).toEqual(["a", "b", "c", "d"])
    expect(normalizeRichField(["a", "b", "c", "d"], 3)).toEqual(["a", "b", "c"])
  })

  it("trim + bỏ rỗng + dedupe không phân biệt hoa thường, giữ entry đầu", () => {
    expect(normalizeRichField([" Business ", "", "business", "Tech"], 4)).toEqual([
      "Business",
      "Tech",
    ])
  })
})
