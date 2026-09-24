#!/usr/bin/env node
/**
 * scripts/verify/verify.mjs — Phase 0: kiểm chứng A-01 / A-02 (Reado).
 *
 * Zero-dependency, chạy bằng Node.
 *
 * CÁCH CHẠY (từ root repo, owner đã điền .env):
 *   node --env-file=.env scripts/verify/verify.mjs
 *
 * CÁI NÓ LÀM — theo docs/agent/prompt-spec.md:
 *   - A-01 (mục 4/8): gửi MỘT lần gọi multimodal (ảnh + prompt) cho mỗi ảnh,
 *     validate output nghiêm ngặt theo schema mục 4 (kể cả
 *     `additionalProperties:false` mọi cấp và `minLength`).
 *   - Xác minh `example` ba nhánh verified/suspect/unverified — thuật toán mục 6.
 *   - Đo độ trễ mỗi trang → p50/p95 (NFR-01: mục tiêu ≤ 15s / p95 ≤ 30s — giả định
 *     cần đo lại, PRD NFR-01).
 *   - Đếm token prompt/candidates → ước lượng cost nếu chủ cấu hình giá
 *     (NFR-02: ở R1 chỉ ĐO và GHI LẠI).
 *
 * CẢNH BÁO prompt-spec mục 8: prompt ở đây là BẢN DỰNG LẠI (mục 3), KHÔNG phải
 * prompt baseline nguyên văn (mục 2). Kết quả chạy script này chứng minh được
 * A-01, nhưng A-02 PHẢI do owner so với baseline thật + output thủ công của owner.
 *
 * Đầu vào: ảnh trong thư mục samples (arg đầu tiên, mặc định scripts/verify/samples/).
 *      Định dạng: .jpg .jpeg .png .webp
 *      Không bắt buộc: file manual đặt cạnh ảnh cùng tên, đuôi `.manual.txt` HOẶC
 *      `.txt` — output thủ công của owner cho cùng trang đó, để owner so A-02 bằng
 *      mắt khi đọc bảng kết quả.
 *
 * Đầu ra: bảng console + scripts/verify/output/last-run.json (đã gitignore).
 */

import { readFileSync, readdirSync, writeFileSync, mkdirSync, statSync } from "node:fs";
import { join, extname, basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = fileURLToPath(new URL(".", import.meta.url));
// Thư mục ảnh: arg đầu tiên, mặc định ./samples bên cạnh script.
const SAMPLES_DIR = process.argv[2] ? resolve(process.argv[2]) : join(HERE, "samples");
const OUTPUT_DIR = join(HERE, "output");
const RAW_DIR = join(OUTPUT_DIR, "raw");

// ------------------------------ env ------------------------------
const env = process.env;
const PROVIDER = (env.PROVIDER || "gemini").toLowerCase();
const BASE_URL = env.BASE_URL || "https://generativelanguage.googleapis.com";
const MODEL = env.MODEL || "";
const API_KEY = env.API_KEY || "";
const CEFR_LEVEL = (env.CEFR_LEVEL || "B1").toUpperCase();
const PRICE_INPUT = Number(env.PRICE_INPUT_PER_1M || 0); // USD / 1M token, tuỳ chọn
const PRICE_OUTPUT = Number(env.PRICE_OUTPUT_PER_1M || 0);

function die(msg) {
  console.error(`[lỗi] ${msg}`);
  process.exit(1);
}
if (PROVIDER !== "gemini") die(`PROVIDER="${PROVIDER}" chưa được hỗ trợ ở Phase 0 (chỉ "gemini")`);
if (!MODEL) die("thiếu MODEL trong .env — điền model multimodal Gemini đang dùng");
if (!API_KEY) die("thiếu API_KEY trong .env — đọc .env.example, KHÔNG nhập key vào bất kỳ file nào khác");
if (!["A2", "B1", "B2", "C1"].includes(CEFR_LEVEL)) die(`CEFR_LEVEL="${CEFR_LEVEL}" không hợp lệ (A2|B1|B2|C1)`);

// ------------------------------ prompt ------------------------------
// Bản dựng lại — prompt-spec mục 3, thay {CEFR_LEVEL}.
const PROMPT = `Bạn là một dịch giả chuyên nghiệp có kiến thức sư phạm về giảng dạy tiếng Anh.

Đầu vào là ảnh một trang văn bản tiếng Anh nguyên bản — có thể là trang sách giấy,
bài báo mạng, hoặc tài liệu chuyên ngành. Trình độ người đọc: ${CEFR_LEVEL}.

Đọc toàn bộ văn bản trên trang và trả về JSON đúng schema được cung cấp, gồm ba phần:

1. segments — chia văn bản thành các đoạn nhỏ theo đúng thứ tự xuất hiện trên trang.
   Mỗi đoạn gồm:
   - source_en: nguyên văn tiếng Anh, GIỮ ĐÚNG TỪNG CHỮ như trên trang. Không sửa
     lỗi, không chuẩn hoá, không lược bỏ. Đây là bản ghi của trang.
   - translation_vi: bản dịch tiếng Việt mượt mà và sát nghĩa. Ưu tiên cách diễn đạt
     tự nhiên của người Việt hơn là dịch từng chữ.

2. vocabulary — từ vựng và cụm từ đáng học đối với người ở trình độ ${CEFR_LEVEL}.
   Bỏ qua những từ quá cơ bản so với trình độ đó. Mỗi phần tử gồm:
   - term: từ hoặc cụm từ, GIỮ ĐÚNG DẠNG XUẤT HIỆN trên trang. Gặp
     "weathered the storm" thì trả về đúng vậy, không đưa về nguyên thể.
   - pos: một trong noun | verb | adj | adv | phrase | other. Không bao giờ để trống;
     không xác định được thì dùng "other".
   - ipa: phiên âm IPA của term.
   - meaning_vi: nghĩa tiếng Việt trong ĐÚNG NGỮ CẢNH của trang này. Nếu từ có nhiều
     nghĩa, chỉ trả nghĩa đang được dùng ở đây.
   - cefr: một trong A2 | B1 | B2 | C1.
   - example: câu chứa term, TRÍCH NGUYÊN VĂN từ trang. Đây là ràng buộc bắt buộc:
     không được tự đặt câu, không được sửa câu, không được ghép câu. Câu này phải
     xuất hiện y nguyên trong một phần tử source_en ở trên.

     BA field bổ trợ sau đây là KHÔNG BẮT BUỘC — thiếu field nào cũng được chấp nhận:
   - tags: tối đa 4 chủ đề ngắn của từ (1–2 từ mỗi tag, viết thường), ví dụ
     "business", "technology", "idiom". Chỉ gắn tag khi thực sự rõ chủ đề; các
     tag nên tái sử dụng nhãn ngắn gọn, không bịa tag mơ hồ.
   - synonyms: tối đa 3 từ/cụm đồng nghĩa THẬT với nghĩa đang dùng, đúng từ loại.
   - antonyms: tối đa 3 từ/cụm trái nghĩa THẬT, đúng từ loại.
     Không có từ phù hợp thì bỏ trống mảng ([]) hoặc bỏ field — đừng điền cho có.

3. summary_vi — tóm tắt ý chính của trang bằng tiếng Việt.

Nếu một từ trên trang có hai nghĩa khác nhau ở hai chỗ khác nhau, trả về nó thành
HAI phần tử riêng trong vocabulary, mỗi phần tử một nghĩa và một example.

Nếu ảnh không đọc được hoặc không chứa văn bản tiếng Anh, trả về vocabulary và
segments rỗng thay vì đoán.`;

// ------------------------------ schema ------------------------------
// schema mục 4 gửi cho Gemini: bản OpenAPI subset Gemini hiểu.
// Ghi chú: Gemini API không nhận `additionalProperties`/`minLength` ở vài phiên bản,
// nên bản request schema bỏ 2 khoá đó; phần `additionalProperties:false` và
// `minLength` được enforce NGHIÊM NGẶT phía client ở validateStrict() bên dưới.
function geminiSchema() {
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
            // Rich vocab (3.12): OPTIONAL — maxItems theo RV-1 (3 syn / 3 ant / 4 tag).
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

// ------------------------------ validate nghiêm ngặt ------------------------------
// Đúng schema mục 4: additionalProperties:false ở MỌI cấp, đủ required, đủ enum,
// minLength theo mục 4 (ipa là ngoại lệ duy nhất — cho phép chuỗi rỗng).
const POS_ENUM = ["noun", "verb", "adj", "adv", "phrase", "other"];
const CEFR_ENUM = ["A2", "B1", "B2", "C1"];

function validateStrict(data) {
  const errs = [];
  const isObj = (x) => typeof x === "object" && x !== null && !Array.isArray(x);

  const checkKeys = (obj, allowed, path) => {
    for (const k of Object.keys(obj)) {
      if (!allowed.includes(k)) errs.push(`${path}: key lạ "${k}" (additionalProperties:false)`);
    }
  };
  const strMin = (v, n, path) => {
    if (typeof v !== "string") { errs.push(`${path}: phải là string`); return; }
    if (v.length < n) errs.push(`${path}: độ dài < ${n}`);
  };

  if (!isObj(data)) { errs.push("root: không phải object"); return errs; }
  checkKeys(data, ["segments", "vocabulary", "summary_vi"], "root");
  for (const req of ["segments", "vocabulary", "summary_vi"]) {
    if (!(req in data)) errs.push(`root: thiếu "${req}"`);
  }

  const { segments, vocabulary, summary_vi } = data;
  if (Array.isArray(segments)) {
    segments.forEach((s, i) => {
      const p = `segments[${i}]`;
      if (!isObj(s)) { errs.push(`${p}: không phải object`); return; }
      checkKeys(s, ["source_en", "translation_vi"], p);
      for (const req of ["source_en", "translation_vi"]) if (!(req in s)) errs.push(`${p}: thiếu "${req}"`);
      strMin(s.source_en, 1, `${p}.source_en`);
      strMin(s.translation_vi, 1, `${p}.translation_vi`);
    });
  } else errs.push("segments: phải là array");

  if (Array.isArray(vocabulary)) {
    vocabulary.forEach((v, i) => {
      const p = `vocabulary[${i}]`;
      if (!isObj(v)) { errs.push(`${p}: không phải object`); return; }
      checkKeys(v, ["term", "pos", "ipa", "meaning_vi", "cefr", "example", "tags", "synonyms", "antonyms"], p);
      for (const req of ["term", "pos", "ipa", "meaning_vi", "cefr", "example"]) {
        if (!(req in v)) errs.push(`${p}: thiếu "${req}"`);
      }
      strMin(v.term, 1, `${p}.term`);
      if (typeof v.pos !== "string" || !POS_ENUM.includes(v.pos)) errs.push(`${p}.pos: ngoài enum (thấy "${v.pos}")`);
      if (typeof v.ipa !== "string") errs.push(`${p}.ipa: phải là string`);
      strMin(v.meaning_vi, 1, `${p}.meaning_vi`);
      if (typeof v.cefr !== "string" || !CEFR_ENUM.includes(v.cefr)) errs.push(`${p}.cefr: ngoài enum (thấy "${v.cefr}")`);
      strMin(v.example, 1, `${p}.example`);
    });
  } else errs.push("vocabulary: phải là array");

  if (typeof summary_vi !== "string") errs.push("summary_vi: phải là string");

  return errs;
}

// ------------------------------ xác minh example (mục 6) ------------------------------
function normalizePageText(s) {
  return String(s)
    .normalize("NFKC")
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, "-")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

// Trả về {verified, suspect, unverified, termNotOnPage} — đếm theo mục 6.
function verifyExamples(pageText, vocabulary) {
  const normPage = normalizePageText(pageText);
  let verified = 0, suspect = 0, unverified = 0, termNotOnPage = 0;
  const bad = []; // danh sách {term, example(cắt), branch} để đọc tay khi cần (mục 8)
  for (const v of vocabulary) {
    const normExample = normalizePageText(v.example);
    const normTerm = normalizePageText(v.term);
    const isVerified = normPage.includes(normExample);
    const hasTerm = normExample.includes(normTerm);
    let branch;
    if (isVerified && hasTerm) { branch = "verified"; verified++; }
    else if (isVerified && !hasTerm) { branch = "suspect"; suspect++; }
    else { branch = "unverified"; unverified++; }
    if (!normPage.includes(normTerm)) termNotOnPage++; // ghi chú chẩn đoán, không phải nhánh
    if (branch !== "verified") {
      bad.push({ term: v.term, exempl: v.example.slice(0, 90), branch });
    }
  }
  return { verified, suspect, unverified, termNotOnPage, bad };
}

// ------------------------------ đo 3 field rich vocab (3.12) ------------------------------
// Field bổ trợ nên KHÔNG được tham gia verdict schema (hợp đồng 3.12 mục 3) — chỉ
// đo tỷ lệ để đánh giá prompt v2: bao nhiêu item thực chất mang field, bao nhiêu
// "điền cho có" (vượt giới hạn RV-1 thì vẫn tính có mặt, ghi chú riêng). Trả:
// { withRich, exceedingLimit }
function measureRich(vocabulary) {
  let withRich = 0;
  let exceedingLimit = 0;
  for (const v of vocabulary || []) {
    const t = Array.isArray(v.tags) ? v.tags.filter((x) => typeof x === "string") : [];
    const s = Array.isArray(v.synonyms) ? v.synonyms.filter((x) => typeof x === "string") : [];
    const a = Array.isArray(v.antonyms) ? v.antonyms.filter((x) => typeof x === "string") : [];
    if (t.length > 0 || s.length > 0 || a.length > 0) withRich++;
    if (t.length > 4 || s.length > 3 || a.length > 3) exceedingLimit++;
  }
  return { withRich, exceedingLimit };
}

// ------------------------------ gọi Gemini ------------------------------
async function analyzeImage(imageB64, mimeType) {
  const url = `${BASE_URL}/v1beta/models/${MODEL}:generateContent`;
  const body = {
    contents: [{
      role: "user",
      parts: [
        { inline_data: { mime_type: mimeType, data: imageB64 } },
        { text: PROMPT },
      ],
    }],
    generationConfig: {
      response_mime_type: "application/json",
      response_schema: geminiSchema(),
    },
  };
  const started = Date.now();
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-goog-api-key": API_KEY,
    },
    body: JSON.stringify(body),
  });
  const latencyMs = Date.now() - started;

  let raw = "";
  try { raw = await res.text(); } catch { /* giữ rỗng */ }

  if (!res.ok) {
    return {
      ok: false,
      latencyMs,
      apiError: `HTTP ${res.status}: ${raw.slice(0, 300)}`,
      raw,
    };
  }

  let envelope = null;
  try { envelope = JSON.parse(raw); } catch {
    return { ok: false, latencyMs, apiError: `response không phải JSON`, raw };
  }

  const candidate = envelope?.candidates?.[0];
  const usage = envelope?.usageMetadata || {};
  if (!candidate) {
    return { ok: false, latencyMs, apiError: `không có candidates (body: ${raw.slice(0, 200)})`, usage, raw };
  }

  const finishReason = candidate.finishReason || "(thiếu)";
  const text = candidate?.content?.parts
    ?.map((p) => p.text || "")
    .join("") || "";
  if (finishReason !== "STOP") {
    return { ok: false, latencyMs, apiError: `finishReason=${finishReason}`, usage, raw, text };
  }

  let data = null;
  try { data = JSON.parse(text); } catch {
    return { ok: false, latencyMs, apiError: `output text không parse được thành JSON`, usage, raw, text };
  }

  const violations = validateStrict(data);
  return { ok: true, latencyMs, violations, usage, raw, data };
}

// ------------------------------ thống kê ------------------------------
function pct(sorted, p) {
  if (sorted.length === 0) return null;
  const idx = (sorted.length - 1) * p;
  const lo = Math.floor(idx), hi = Math.ceil(idx);
  if (lo === hi) return sorted[lo];
  return Math.round(sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo));
}

function costOf(usage) {
  if (!PRICE_INPUT && !PRICE_OUTPUT) return null; // chưa cấu hình giá → chỉ đếm token
  const pin = Number(usage.promptTokenCount || 0);
  const pout = Number(usage.candidatesTokenCount || 0);
  return (pin * PRICE_INPUT + pout * PRICE_OUTPUT) / 1_000_000;
}

// ------------------------------ main ------------------------------
const IMG_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp"]);
const MIME = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp" };

const files = readdirSync(SAMPLES_DIR)
  .filter((f) => IMG_EXTS.has(extname(f).toLowerCase()))
  .sort();

if (files.length === 0) {
  die(`không thấy ảnh nào trong ${SAMPLES_DIR} — bỏ 5-10 ảnh trang thật vào đó (task 0.3), rồi chạy lại`);
}

// Manual file đi kèm ảnh: ưu tiên <base>.manual.txt, rồi <base>.txt.
function findManual(imageFile) {
  const base = basename(imageFile, extname(imageFile));
  for (const cand of [`${base}.manual.txt`, `${base}.txt`]) {
    const full = join(SAMPLES_DIR, cand);
    try { if (statSync(full).isFile()) return full; } catch { /* thử cái sau */ }
  }
  return null;
}

console.log("=".repeat(78));
console.log("READO — Phase 0: kiểm chứng A-01/A-02");
console.log(`provider=${PROVIDER}  model=${MODEL}  cefr=${CEFR_LEVEL}  base_url=${BASE_URL}`);
console.log(`ảnh: ${files.length}  ·  prompt đang dùng = docs/agent/prompt-spec.md mục 3 (BẢN DỰNG LẠI)`);
console.log("CẢNH BÁO mục 8: kết quả này chứng minh A-01. A-02 phải do owner so với");
console.log("  baseline nguyên văn (mục 2) + file .manual.txt tương ứng từng ảnh.");
console.log("=".repeat(78));

mkdirSync(RAW_DIR, { recursive: true });
mkdirSync(OUTPUT_DIR, { recursive: true });

const rows = [];
for (const [i, file] of files.entries()) {
  const full = join(SAMPLES_DIR, file);
  const manual = findManual(file);
  const hasManual = manual !== null;

  const mime = MIME[extname(file).toLowerCase()];
  const b64 = readFileSync(full).toString("base64");

  const res = await analyzeImage(b64, mime);

  let row;
  if (!res.ok) {
    row = { file, status: "api_error", ...res };
  } else {
    const pageText = res.data.segments.map((s) => s.source_en).join(" ");
    const v = verifyExamples(pageText, res.data.vocabulary || []);
    const manualTokens = hasManual
      ? readFileSync(manual, "utf8").split(/\r?\n/).filter((l) => l.trim() && !l.trim().startsWith("#")).length
      : null;
    row = {
      file,
      status: res.violations.length === 0 ? "schema_ok" : "schema_fail",
      latencyMs: res.latencyMs,
      violations: res.violations,
      usage: res.usage,
      cost: costOf(res.usage),
      vocabTotal: (res.data.vocabulary || []).length,
      segments: res.data.segments.length,
      ...v,
      rich: measureRich(res.data.vocabulary),
      manual: hasManual ? { file: basename(manual), lines: manualTokens } : null,
    };
    writeFileSync(join(RAW_DIR, basename(file, extname(file)) + ".json"), JSON.stringify(res.data, null, 2));
  }
  rows.push(row);

  const vv = row.vocabTotal !== undefined
    ? `${row.verified}/${row.suspect}/${row.unverified}`
    : "—";
  const status = row.status === "schema_ok" ? "OK " : row.status === "schema_fail" ? "FAIL" : "ERR";
  console.log(`[${String(i + 1).padStart(2)}/${files.length}] ${status}  ${file.padEnd(34)} ` +
    `lat=${row.latencyMs ?? "—"}ms  verified/suspect/unverified=${vv}  tok=${row.usage?.totalTokenCount ?? "—"}`);
  if (row.apiError) console.log(`        apiError: ${row.apiError}`);
  if (row.violations?.length) {
    console.log(`        schema violations (${row.violations.length}, in tối đa 5):`);
    for (const e of row.violations.slice(0, 5)) console.log(`          - ${e}`);
  }
  if (row.bad?.length) {
    console.log(`        chưa verified (${row.bad.length}) — mẫu để đọc tay (mục 8):`);
    for (const b of row.bad.slice(0, 5)) {
      console.log(`          [${b.branch}] ${b.term} → "${b.exempl}"`);
    }
  }
  if (row.termNotOnPage) console.log(`        note: ${row.termNotOnPage} term không xuất hiện trên page_text (chẩn đoán OCR/cắt câu)`);
  if (row.rich) console.log(`        rich: ${row.rich.withRich}/${row.vocabTotal} items có tags/syn/ant  (vượt giới hạn RV-1: ${row.rich.exceedingLimit})`);
  if (row.manual) console.log(`        A-02: có bản manual "${row.manual.file}" (${row.manual.lines} dòng) — so bằng mắt theo bảng trên`);
}

// tổng hợp
const okRows = rows.filter((r) => r.latencyMs != null);
const lats = okRows.map((r) => r.latencyMs).sort((a, b) => a - b);
const schemaOk = rows.filter((r) => r.status === "schema_ok").length;
const schemaFail = rows.filter((r) => r.status === "schema_fail").length;
const apiErr = rows.filter((r) => r.status === "api_error").length;
const tot = { verified: 0, suspect: 0, unverified: 0 };
for (const r of rows) {
  if (r.verified != null) { tot.verified += r.verified; tot.suspect += r.suspect; tot.unverified += r.unverified; }
}
const totVin = tot.verified + tot.suspect + tot.unverified;
const richTot = { withRich: 0, total: 0, exceeding: 0 };
for (const r of rows) {
  if (r.rich) { richTot.withRich += r.rich.withRich; richTot.total += r.vocabTotal || 0; richTot.exceeding += r.rich.exceedingLimit; }
}
const totTokens = rows.reduce((a, r) => a + Number(r.usage?.totalTokenCount || 0), 0);
const totCost = rows.reduce((a, r) => a + (r.cost || 0), 0);

console.log("\n" + "=".repeat(78));
console.log("TỔNG HỢP");
console.log("=".repeat(78));
console.log(`ảnh: ${files.length}  schema_ok: ${schemaOk}  schema_fail: ${schemaFail}  api_error: ${apiErr}`);
console.log(`A-01 (một lần gọi → đúng schema mục 4): ${schemaOk === files.length && apiErr === 0 ? "ĐẠT" : "CHƯA ĐẠT / cần xử lý theo prompt-spec mục 8"}`);
console.log(`độ trễ: p50=${pct(lats, 0.5) ?? "—"}ms  p95=${pct(lats, 0.95) ?? "—"}ms  ` +
  `(NFR-01 giả định: ≤15s, p95≤30s — đo để xem lại, không phải verdict)`.trim());
const vRate = totVin ? Math.round((tot.verified / totVin) * 100) : null;
console.log(`example — verified/suspect/unverified: ${tot.verified}/${tot.suspect}/${tot.unverified}` +
  (vRate != null ? `  (tỷ lệ verified ${vRate}%)` : "") +
  "  — chưa có ngưỡng: số đo đầu tiên LÀ cái đặt ngưỡng (mục 8)");
const richRate = richTot.total ? Math.round((richTot.withRich / richTot.total) * 100) : null;
console.log(`rich vocab (prompt v2): ${richTot.withRich}/${richTot.total} items có ≥1 field (${richRate ?? "—"}%)  ·  vượt giới hạn RV-1: ${richTot.exceeding}`);
console.log(`token tổng: ${totTokens}${totCost ? `  cost≈$${totCost.toFixed(5)} (giá từ env)` : "  (cost: chưa cấu hình giá — NFR-02 chỉ cần đo và ghi lại)"}`);
console.log(`raw output từng ảnh: ${RAW_DIR}/`);
console.log("\nTIẾP THEO — owner: (1) so A-02 từng ảnh với baseline mục 2 + file .manual.txt;");
console.log("(2) điền kết quả vào ROADMAP.md (mục 6 — nhật ký task 0.8); (3) go/no-go ở Phase 0.");

const report = {
  ran_at: new Date().toISOString(),
  config: { provider: PROVIDER, base_url: BASE_URL, model: MODEL, cefr: CEFR_LEVEL, prompt: "prompt-spec mục 3 (dựng lại)" },
  summary: {
    images: files.length, schema_ok: schemaOk, schema_fail: schemaFail, api_error: apiErr,
    latency: { p50: pct(lats, 0.5), p95: pct(lats, 0.95) },
    example: { ...tot, verified_rate: vRate },
    rich_vocab: { ...richTot, coverage_rate: richRate },
    tokens_total: totTokens,
    cost_usd_total: totCost || null,
  },
  rows,
};
writeFileSync(join(OUTPUT_DIR, "last-run.json"), JSON.stringify(report, null, 2));
console.log(`report: ${join(OUTPUT_DIR, "last-run.json")}`);