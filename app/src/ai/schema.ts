/**
 * ai/schema.ts — response schema gửi Gemini (UPPERCASE subset mà Gemini hiểu).
 *
 * Ghi chú từ Phase 0 (verify.mjs): Gemini không nhận `additionalProperties`/
 * `minLength` ở vài phiên bản, nên bản request schema bỏ 2 khoá đó; phần
 * `additionalProperties:false` + `minLength` được enforce NGHIÊM NGẶT phía
 * client ở domain/verify.ts (validateAiPayload) — hợp đồng prompt-spec mục 4.
 */
export function geminiSchema(): Record<string, unknown> {
  return {
    type: "OBJECT",
    properties: {
      segments: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: ["source_en", "translation_vi"],
          properties: {
            source_en: { type: "STRING" },
            translation_vi: { type: "STRING" },
          },
        },
      },
      vocabulary: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: ["term", "pos", "ipa", "meaning_vi", "cefr", "example"],
          properties: {
            term: { type: "STRING" },
            pos: { type: "STRING", enum: ["noun", "verb", "adj", "adv", "phrase", "other"] },
            ipa: { type: "STRING" },
            meaning_vi: { type: "STRING" },
            cefr: { type: "STRING", enum: ["A2", "B1", "B2", "C1"] },
            example: { type: "STRING" },
            // Rich vocab (3.12, owner 2026-09-08): OPTIONAL — không đưa vào required
            // nên provider/schema-bản-cũ vẫn ra output hợp lệ. maxItems theo RV-1
            // (owner chốt 3/3/4 — docs/rich-vocab-cram-ddl.md mục 3).
            tags: { type: "ARRAY", items: { type: "STRING" }, maxItems: 4 },
            synonyms: { type: "ARRAY", items: { type: "STRING" }, maxItems: 3 },
            antonyms: { type: "ARRAY", items: { type: "STRING" }, maxItems: 3 },
          },
        },
      },
      summary_vi: { type: "STRING" },
    },
    required: ["segments", "vocabulary", "summary_vi"],
  };
}