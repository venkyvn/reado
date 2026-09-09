/**
 * ui/readSegments.ts — logic THUẦN cho màn đọc song ngữ (FR-05), không import
 * React để test được như ui/swipe.ts.
 *
 * - `buildGlossIndex`: từ `vocabulary` của trang dựng bảng tra theo term đã
 *   chuẩn hoá — dùng CHUNG `normalizePageText` của domain/verify (cùng một
 *   khái niệm "khớp" với xác minh example của FR-02). Một term chuẩn hoá có
 *   nhiều dòng (nhiều nghĩa) → lấy dòng ĐẦU tiên: gloss chỉ là trợ giúp đọc,
 *   không phải nguồn sự thật (nguồn sự thật là màn duyệt từ).
 * - `splitWithGloss`: chẻ `source_en` thành node text/vocab để UI tô highlight
 *   và bắt chạm. Khớp theo TOKEN (chữ cái Unicode, chấp nhận nháy/gạch nối
 *   GIỮA token), term nhiều từ khớp cửa sổ token liên tiếp và ưu tiên term
 *   DÀI trước; vùng đã khớp không bị khớp chồng. Khoảng trắng + dấu câu giữ
 *   NGUYÊN văn (ghép các node lại = đúng chuỗi gốc).
 */
import type { AnalyzedItem, AnalysisResult } from "../domain/types";
import { normalizePageText } from "../domain/verify";

/** Một trang trong buffer phiên đọc (FR-05 c.4). */
export interface SessionPage {
  /** id ổn định TRONG PHIÊN — neo để đánh dấu trang "đã lưu" (chống lưu trùng). */
  pageId: string;
  analysis: AnalysisResult;
  collectionId: string;
  /** Trang này ĐÃ được lưu vào kho (FR-03/FR-09) lúc `savedAt`, gồm `savedCount`
   *  từ. Màn đọc KHÔNG cho vào "Chọn từ" lần hai với trang đã lưu — bug owner
   *  báo 2026-09-09 (đọc lại phiên → lưu lại → trùng từ). Chỉ sống trong phiên
   *  như cả buffer: F5/đóng tab = hết phiên = bị xoá (Q-10). */
  savedAt?: string;
  savedCount?: number;
}

/** Q-10 chốt 2026-09-08: buffer giữ 10 trang GẦN NHẤT, phần cũ trôi đi. */
export const READ_SESSION_MAX = 10;

/** Nối trang mới phân tích vào cuối buffer, cắt về READ_SESSION_MAX. */
export function appendSessionPage(pages: SessionPage[], page: SessionPage): SessionPage[] {
  return [...pages, page].slice(-READ_SESSION_MAX);
}

/**
 * Đánh dấu trang `pageId` đã lưu vào kho (FR-09) — thuần, không đột biến.
 * pageId không có trong buffer (vd: trang đã trôi khỏi 10 trang gần nhất) thì
 * trả về bản sao y nguyên — không lỗi, không đánh nhầm trang khác.
 */
export function markPageSaved(
  pages: SessionPage[],
  pageId: string,
  savedAt: string,
  savedCount: number,
): SessionPage[] {
  return pages.map((p) => (p.pageId === pageId ? { ...p, savedAt, savedCount } : p));
}

export interface GlossEntry {
  /** key ổn định cho React + trạng thái gloss đang mở; prefix để không đụng
   *  giữa các trang trong buffer. */
  key: string;
  term: string;
  pos: string;
  ipa: string;
  meaningVi: string;
  /** dạng chuẩn hoá để khớp — tính sẵn 1 lần. */
  norm: string;
  /** số token của term — dùng để khớp cửa sổ nhiều token. */
  wordCount: number;
}

export type ReadNode =
  | { kind: "text"; text: string }
  | { kind: "vocab"; text: string; matchKey: string };

interface Token {
  start: number;
  end: number;
  norm: string;
}

/** Token chữ: Unicode letters DIGITS, cho phép ' ’ - – — ở GIỮA (don't,
 *  mid-19th). Dấu câu nằm NGOÀI token → tự thành text giữa các token. */
const WORD_RE = /[\p{L}\p{N}]+(?:['\u2019\-\u2013\u2014][\p{L}\p{N}]+)*/gu;

function tokensOf(text: string): Token[] {
  const out: Token[] = [];
  for (const m of text.matchAll(WORD_RE)) {
    const start = m.index;
    out.push({ start, end: start + m[0].length, norm: normalizePageText(m[0]) });
  }
  return out;
}

/** Từ vocabulary → bảng gloss. Dedupe theo term chuẩn hoá, giữ dòng đầu. */
export function buildGlossIndex(vocabulary: AnalyzedItem[], prefix = ""): GlossEntry[] {
  const seen = new Set<string>();
  const entries: GlossEntry[] = [];
  vocabulary.forEach((v, i) => {
    const norm = normalizePageText(v.term);
    const wordCount = tokensOf(norm).length;
    // term trống / không có token nào ("...", chỉ số riêng…) không bao giờ khớp
    // được → bỏ khỏi index luôn.
    if (norm === "" || wordCount === 0 || seen.has(norm)) return;
    seen.add(norm);
    entries.push({
      key: `${prefix}v${i}`,
      term: v.term,
      pos: v.pos,
      ipa: v.ipa,
      meaningVi: v.meaningVi,
      norm,
      wordCount,
    });
  });
  // Term nhiều từ trước (cửa sổ to thắng), cùng độ dài thì term dài hơn,
  // còn lại giữ thứ tự gốc (sort ổn định).
  return [...entries].sort(
    (a, b) => b.wordCount - a.wordCount || b.norm.length - a.norm.length,
  );
}

/** Map key → GlossEntry để UI tra gloss khi chạm. */
export function glossIndexMap(entries: GlossEntry[]): Map<string, GlossEntry> {
  return new Map(entries.map((e) => [e.key, e]));
}

/**
 * Chẻ đoạn gốc thành node để render: từ nằm trong bảng gloss → node vocab
 * (hiện highlight + chạm được), phần còn lại → text nguyên văn.
 */
export function splitWithGloss(sourceEn: string, entries: GlossEntry[]): ReadNode[] {
  const tokens = tokensOf(sourceEn);
  if (tokens.length === 0 || entries.length === 0) {
    return sourceEn === "" ? [] : [{ kind: "text", text: sourceEn }];
  }

  // matchStart.get(i) = {key, len} của khớp bắt đầu tại token i;
  // occupied[j] = token j đã nằm trong khớp nào đó (không khớp lồng).
  const matchStart = new Map<number, { key: string; len: number }>();
  const occupied = new Array<boolean>(tokens.length).fill(false);

  for (const e of entries) {
    if (e.wordCount <= 0) continue;
    for (let i = 0; i + e.wordCount <= tokens.length; i++) {
      let blocked = false;
      for (let j = i; j < i + e.wordCount; j++) {
        if (occupied[j]) {
          blocked = true;
          break;
        }
      }
      if (blocked) continue;
      const windowText = tokens
        .slice(i, i + e.wordCount)
        .map((t) => t.norm)
        .join(" ");
      if (windowText === e.norm) {
        for (let j = i; j < i + e.wordCount; j++) occupied[j] = true;
        matchStart.set(i, { key: e.key, len: e.wordCount });
        i += e.wordCount - 1; // nhảy qua cửa sổ vừa khớp
      }
    }
  }

  // Dựng node theo thứ tự gốc; mọi ký tự không phải token (khoảng trắng, dấu
  // câu) nằm giữa các token được phát lại đúng vị trí. Text node LIỀN KỀ được
  // gộp để mảng node gọn (đoạn dài ít node React hơn).
  const nodes: ReadNode[] = [];
  const pushText = (text: string) => {
    if (text === "") return;
    const last = nodes[nodes.length - 1];
    if (last && last.kind === "text") last.text += text;
    else nodes.push({ kind: "text", text });
  };
  let cursor = 0;
  for (let i = 0; i < tokens.length; ) {
    const t = tokens[i];
    pushText(sourceEn.slice(cursor, t.start));
    const m = matchStart.get(i);
    if (m) {
      const last = tokens[i + m.len - 1];
      nodes.push({ kind: "vocab", text: sourceEn.slice(t.start, last.end), matchKey: m.key });
      cursor = last.end;
      i += m.len;
    } else {
      pushText(sourceEn.slice(t.start, t.end));
      cursor = t.end;
      i += 1;
    }
  }
  pushText(sourceEn.slice(cursor));
  return nodes;
}