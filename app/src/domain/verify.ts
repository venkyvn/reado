/**
 * domain/verify.ts — kiểm schema + xác minh `example` ba nhánh (FR-02).
 *
 * Chuyển nguyên văn từ scripts/verify/verify.mjs (Phase 0 đã chạy thật, 3/3
 * schema + 20/20 verified) sang thư viện dùng chung cho app. Hợp đồng:
 * prompt-spec mục 4 (validate NGHIÊM NGẶT: additionalProperties:false mọi cấp,
 * đủ required, đủ enum, minLength — ipa là ngoại lệ duy nhất) và mục 6 (ba
 * nhánh verified/suspect/unverified).
 *
 * QUY TẮC (FR-02 + mục 6):
 * - item không khớp → đánh dấu, KHÔNG tự loại, KHÔNG tự sửa — tỷ lệ
 *   unverified là tín hiệu chất lượng prompt (M-03).
 */
import { AnalysisError } from "./errors"
import { POS_VALUES, CEFR_VALUES } from "./types"
import type { AnalyzedItem, AnalysisResult, Cefr, Pos, Segment, Verification } from "./types"

/** Payload thô AI trả về — tên field giữ nguyên hợp đồng prompt-spec mục 4.
 *  Ba field rich vocab (3.12) là OPTIONAL: output cũ vẫn hợp lệ. */
export interface AiPayload {
  segments: { source_en: string; translation_vi: string }[]
  vocabulary: {
    term: string
    pos: string
    ipa: string
    meaning_vi: string
    cefr: string
    example: string
    tags?: unknown
    synonyms?: unknown
    antonyms?: unknown
  }[]
  summary_vi: string
}

/** Số field rich vocab được phép trên mỗi từ (RV-1 owner chốt 2026-09-09:
 *  3 synonyms / 3 antonyms / 4 tags). */
export const RICH_LIMITS = { tags: 4, synonyms: 3, antonyms: 3 } as const

/**
 * Chuẩn hoá MỘT field rich vocab từ payload AI (có thể thiếu/sai type).
 *
 * Chốt thiết kế 3.12: field là OPTIONAL và bổ trợ — chúng KHÔNG được làm hỏng cả
 * trang phân tích vì một field phụ. Vì vậy:
 * - sai type / thiếu → `[]` (không ném lỗi schema);
 * - đúng type thì trim + bỏ rỗng + dedupe, cắt về giới hạn RV-1 khi AI vượt
 *   (chặn "chảy văn" nhưng không từ chối cả payload hợp lệ);
 * - provider trả `null` (JSON-schema optional thường coi null là vắng mặt) → `[]`.
 */
export function normalizeRichField(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) return []
  const seen = new Set<string>()
  const out: string[] = []
  for (const raw of value) {
    if (typeof raw !== "string") continue
    const s = raw.trim()
    if (s === "" || seen.has(s.toLowerCase())) continue
    seen.add(s.toLowerCase())
    out.push(s)
    if (out.length >= limit) break
  }
  return out
}

export function isPlainObject(x: unknown): x is Record<string, unknown> {
  return typeof x === "object" && x !== null && !Array.isArray(x)
}

/** Validate nghiêm ngặt theo prompt-spec mục 4. Trả về danh sách vi phạm. */
export function validateAiPayload(data: unknown): string[] {
  const errs: string[] = []

  const checkKeys = (obj: Record<string, unknown>, allowed: string[], path: string) => {
    for (const k of Object.keys(obj)) {
      if (!allowed.includes(k)) errs.push(`${path}: key lạ "${k}" (additionalProperties:false)`)
    }
  }
  const strMin = (v: unknown, n: number, path: string) => {
    if (typeof v !== "string") {
      errs.push(`${path}: phải là string`)
      return
    }
    if (v.length < n) errs.push(`${path}: độ dài < ${n}`)
  }

  if (!isPlainObject(data)) {
    errs.push("root: không phải object")
    return errs
  }
  checkKeys(data, ["segments", "vocabulary", "summary_vi"], "root")
  for (const req of ["segments", "vocabulary", "summary_vi"]) {
    if (!(req in data)) errs.push(`root: thiếu "${req}"`)
  }

  const segments = data.segments
  if (Array.isArray(segments)) {
    segments.forEach((s, i) => {
      const p = `segments[${i}]`
      if (!isPlainObject(s)) {
        errs.push(`${p}: không phải object`)
        return
      }
      checkKeys(s, ["source_en", "translation_vi"], p)
      for (const req of ["source_en", "translation_vi"]) {
        if (!(req in s)) errs.push(`${p}: thiếu "${req}"`)
      }
      strMin(s.source_en, 1, `${p}.source_en`)
      strMin(s.translation_vi, 1, `${p}.translation_vi`)
    })
  } else {
    errs.push("segments: phải là array")
  }

  const vocabulary = data.vocabulary
  if (Array.isArray(vocabulary)) {
    vocabulary.forEach((v, i) => {
      const p = `vocabulary[${i}]`
      if (!isPlainObject(v)) {
        errs.push(`${p}: không phải object`)
        return
      }
      checkKeys(
        v,
        ["term", "pos", "ipa", "meaning_vi", "cefr", "example", "tags", "synonyms", "antonyms"],
        p,
      )
      for (const req of ["term", "pos", "ipa", "meaning_vi", "cefr", "example"]) {
        if (!(req in v)) errs.push(`${p}: thiếu "${req}"`)
      }
      strMin(v.term, 1, `${p}.term`)
      if (typeof v.pos !== "string" || !(POS_VALUES as readonly string[]).includes(v.pos)) {
        errs.push(`${p}.pos: ngoài enum (thấy "${v.pos}")`)
      }
      if (typeof v.ipa !== "string") errs.push(`${p}.ipa: phải là string`)
      strMin(v.meaning_vi, 1, `${p}.meaning_vi`)
      if (typeof v.cefr !== "string" || !(CEFR_VALUES as readonly string[]).includes(v.cefr)) {
        errs.push(`${p}.cefr: ngoài enum (thấy "${v.cefr}")`)
      }
      strMin(v.example, 1, `${p}.example`)
    })
  } else {
    errs.push("vocabulary: phải là array")
  }

  if (typeof data.summary_vi !== "string") errs.push("summary_vi: phải là string")

  return errs
}

/** Chuẩn hoá văn bản để so khớp (prompt-spec mục 6): NFKC, nháy cong→thẳng,
 *  gạch – —→-, gộp whitespace, trim, lowercase. */
export function normalizePageText(s: string): string {
  return s
    .normalize("NFKC")
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201C\u201D]/g, '"')
    .replace(/[\u2013\u2014]/g, "-")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase()
}

/** Đối chiếu MỘT item với văn bản trang → nhánh xác minh (mục 6). */
export function verificationOf(normPage: string, term: string, example: string): Verification {
  const normExample = normalizePageText(example)
  const normTerm = normalizePageText(term)
  const isVerified = normPage.includes(normExample)
  const hasTerm = normExample.includes(normTerm)
  if (isVerified && hasTerm) return "verified"
  if (isVerified && !hasTerm) return "suspect" // câu thật nhưng không chứa term → thẻ vô dụng
  return "unverified"
}

/**
 * Payload đã validate sạch → AnalysisResult + gắn nhánh xác minh từng item.
 * Không tự loại item nào — tỷ lệ unverified là tín hiệu M-03.
 */
export function toAnalysisResult(
  payload: AiPayload,
  meta: {
    promptTokens: number
    candidatesTokens: number
    latencyMs: number
    promptVersion: number
  },
): AnalysisResult {
  const normPage = normalizePageText(payload.segments.map((s) => s.source_en).join(" "))
  const vocabulary: AnalyzedItem[] = payload.vocabulary.map((v) => ({
    term: v.term,
    pos: v.pos as Pos,
    ipa: v.ipa,
    meaningVi: v.meaning_vi,
    cefr: v.cefr as Cefr,
    example: v.example,
    verification: verificationOf(normPage, v.term, v.example),
    // Rich vocab (3.12): optional + bổ trợ — thiếu/sai type → [] chứ không lỗi.
    tags: normalizeRichField(v.tags, RICH_LIMITS.tags),
    synonyms: normalizeRichField(v.synonyms, RICH_LIMITS.synonyms),
    antonyms: normalizeRichField(v.antonyms, RICH_LIMITS.antonyms),
  }))
  const segments: Segment[] = payload.segments.map((s) => ({
    sourceEn: s.source_en,
    translationVi: s.translation_vi,
  }))
  return {
    segments,
    vocabulary,
    summaryVi: payload.summary_vi,
    usage: meta,
    latencyMs: meta.latencyMs,
    promptVersion: meta.promptVersion,
  }
}

/** Parse chuỗi text AI trả về → payload hợp lệ, nếu không ném AnalysisError. */
export function parseAndValidateAiText(text: string): AiPayload {
  let raw: unknown
  try {
    raw = JSON.parse(text)
  } catch {
    throw new AnalysisError("bad_json", "output text không parse được thành JSON")
  }
  const violations = validateAiPayload(raw)
  if (violations.length > 0) {
    throw new AnalysisError("schema", `output vỡ schema: ${violations.join("; ")}`)
  }
  const payload = raw as AiPayload
  if (payload.vocabulary.length === 0 && payload.segments.length === 0) {
    // prompt-spec mục 3: ảnh không đọc được / không phải tiếng Anh → rỗng thay vì đoán.
    // FR-04 ở Phase 3 sẽ phân biệt kỹ hơn; ở walking skeleton đã báo đúng chỗ rỗng.
    throw new AnalysisError("unreadable", "AI trả về rỗng — ảnh mờ hoặc không chứa tiếng Anh")
  }
  return payload
}
