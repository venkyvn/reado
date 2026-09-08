/**
 * domain/utils.ts — tiện ích thuần. Không import gì ngoài domain.
 */
import { CEFR_VALUES, POS_VALUES } from "./types";
import type { Cefr, Pos } from "./types";

/** uuid 32 ký tự hex không gạch (solution-design mục 5) — client tự sinh, offline được. */
export function newId(): string {
  return crypto.randomUUID().replace(/-/g, "");
}

/** Timestamp chuẩn của Reado: ISO-8601 UTC với Z (solution-design mục 4.3). */
export function toUtcIso(d: Date): string {
  return d.toISOString();
}

/** SHA-256 (hex) của dữ liệu — dùng chống submit đúp FR-02 (cùng ảnh hai lần). */
export async function sha256Hex(data: ArrayBuffer | Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", data as BufferSource);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function isPos(x: unknown): x is Pos {
  return typeof x === "string" && (POS_VALUES as readonly string[]).includes(x);
}

export function isCefr(x: unknown): x is Cefr {
  return typeof x === "string" && (CEFR_VALUES as readonly string[]).includes(x);
}