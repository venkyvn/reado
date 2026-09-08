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
          },
        },
      },
      summary_vi: { type: "STRING" },
    },
    required: ["segments", "vocabulary", "summary_vi"],
  };
}