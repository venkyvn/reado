/**
 * storage/repos/richJson.ts — JSON cho 3 cột rich vocab (migration v3).
 *
 * Quy ước docs/rich-vocab-cram-ddl.md mục 2: TEXT chứa JSON array of string;
 * rỗng = '[]'; ghi thì serialize, đọc thì parse. Dùng chung cho vocabItems
 * (map hàng + ghi) và cards (loadWithContext) — không import chéo giữa repos.
 */

/**
 * TEXT JSON → mảng string an toàn. JSON hỏng / không phải array của string →
 * `[]` (guard lúc ĐỌC — "không bao giờ đọc ra JSON hỏng"). Config cần cẩn
 * thận: updateRichFields cộng all-clean trước khi ghi nên hỏng chỉ đến từ
 * tay người hoặc provider cũ — fallback `[]` là đúng hợp đồng đó.
 */
export function parseJsonArrayOfString(raw: string | null | undefined): string[] {
  if (!raw) return []
  try {
    const parsed: unknown = JSON.parse(raw)
    if (!Array.isArray(parsed)) return []
    return parsed.filter((x): x is string => typeof x === "string")
  } catch {
    return []
  }
}

/** Mảng string → TEXT JSON ('[]' khi rỗng). */
export function serializeStringArray(items: string[]): string {
  return JSON.stringify(items)
}
