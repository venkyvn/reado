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
 *
 * ⚰ Bia mộ (2026-09-09): `SessionPage`/`appendSessionPage`/`markPageSaved`/
 * `READ_SESSION_MAX` (buffer phiên in-memory theo Q-10 cũ) đã XÓA — thay bằng
 * bảng `reading_sessions` bền theo collection (task 3.15, Q-10-reopen; MVP_PLAN
 * mục 4 hàng "Buffer phiên đọc để Ở ĐÂU" là bia mộ của quyết định cũ).
 */
import type { AnalyzedItem, AnalysisResult, ReadingSessionRow } from "../domain/types";
import { normalizePageText } from "../domain/verify";

/** Tái dựng `AnalysisResult` cho màn duyệt từ ("Chọn từ") từ phiên đọc đã lưu
 *  (task 3.15). usage/latency/promptVersion không còn ý nghĩa lúc đọc lại — để
 *  0, màn duyệt từ không dùng chúng. */
export function analysisFromSession(row: ReadingSessionRow): AnalysisResult {
  return {
    segments: row.segments,
    vocabulary: row.vocabulary,
    summaryVi: row.summaryVi,
    usage: { promptTokens: 0, candidatesTokens: 0 },
    latencyMs: 0,
    promptVersion: 0,
  };
}

export interface GlossEntry {
  /** key ổn định cho React + trạng thái gloss đang mở; prefix để không đụng
   *  giữa các trang của màn đọc. */
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