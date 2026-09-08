/**
 * domain/utils.ts — tiện ích thuần. Không import gì ngoài domain.
 */
import { CEFR_VALUES, POS_VALUES } from "./types";
import type { Cefr, Pos } from "./types";

/**
 * uuid 32 ký tự hex không gạch (solution-design mục 5) — client tự sinh, offline được.
 *
 * `crypto.randomUUID` chỉ tồn tại ở secure context (https/localhost) và trình duyệt
 * mới (Chrome ≥92, Safari ≥15.4). Khi mở app qua `http://<IP-LAN>` (test trên điện
 * thoại) hoặc WebView cũ thì nó là undefined → bootstrap chết. Fallback: UUID v4
 * từ `crypto.getRandomValues` (có ở MỌI context, kể cả insecure); nếu không có Web
 * Crypto luôn (môi trường nhúng cực cổ) thì dùng Math.random — độc nhất đủ cho id
 * client, không phải secret.
 */
export function newId(): string {
  const c = globalThis.crypto;
  if (c && typeof c.randomUUID === "function") {
    return c.randomUUID().replace(/-/g, "");
  }
  const bytes = new Uint8Array(16);
  if (c && typeof c.getRandomValues === "function") {
    c.getRandomValues(bytes);
  } else {
    for (let i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256);
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
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