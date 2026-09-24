#!/usr/bin/env node
/**
 * scripts/verify/ab-compress.mjs — A/B: nén ảnh trước khi gửi Gemini có làm mất
 * chất lượng đọc (M-03) không, và tiết kiệm được bao nhiêu token/latency?
 *
 * Bối cảnh quyết định:
 *   - App hiện tại (imageToolkit.ts): không crop/xoay → gửi NGUYÊN bytes gốc;
 *     có crop/xoay → re-encode JPEG 0.95 full-size. Cả hai đường đều KHÔNG thu
 *     nhỏ pixel. Ảnh photo thật 3024×4032 → Gemini tính token theo PIXEL
 *     (≈ W×H/258), nên ảnh full-res ăn hàng chục nghìn token mỗi lần Analyze.
 *   - Đề xuất đang bàn: luôn resize xuống maxDimension + JPEG q0.75–0.80 trước
 *     khi gửi. Script này là bằng chứng trước khi đổi code.
 *
 * CÁCH CHẠY (từ root repo, owner đã điền .env — chung .env với verify.mjs):
 *   node --env-file=.env scripts/verify/ab-compress.mjs [thưMụcẢnh] [--dry]
 *   node --env-file=.env scripts/verify/ab-compress.mjs ref/sample
 *
 * Bốn biến thể:
 *   goc         — bytes gốc, mime theo đuôi file   (đường sản xuất hiện tại, = REFERENCE)
 *   jpg95-full  — JPEG q0.95, giữ nguyên kích thước  (đường "có crop" hiện tại)
 *   jpg80-1400  — resize cạnh dài tối đa 1400px + JPEG q0.80  (sweet spot đề xuất)
 *   jpg85-1600  — resize cạnh dài tối đa 1600px + JPEG q0.85  (biên trên an toàn)
 * Quy tắc: KHÔNG upscale — ảnh nhỏ hơn ngưỡng thì biến thể chỉ đổi codec/quality.
 *
 * So với reference (goc) trên cùng một ảnh:
 *   - CER (%) của toàn văn trang (segments.source_en ghép lại) — metric chính.
 *   - Từ mất/thêm (multiset diff) của toàn văn trang.
 *   - Vocab: term mất/thêm, and meaning_vi khác cho term chung.
 * Lưu ý nhiễu lấy mẫu: mỗi biến thể là một lần gọi độc lập; CER càng gần 0 càng
 * khó quy kết cho ảnh hay cho nhiễu. Kết luận cần cả chiều ngược: nếu nén nặng
 * vẫn không tệ hơn, thì chốt được; nếu tệ rõ (CER % đơn vị), mới đáng bàn.
 *
 * Nén bằng `sips` (Chỉ macOS — owner đang dùng mac; resize Lanczos, JA tốt hơn
 * canvas drawImage của app, nên kết quả này là GIỚI HẠN LẠC QUAN cho app).
 *
 * Đầu ra: bảng console + scripts/verify/output/ab-last-run.json (đã gitignore) +
 * ảnh biến thể trong scripts/verify/output/ab-variants/ (để owner mở xem bằng mắt).
 */

import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, writeFileSync, mkdirSync, statSync } from "node:fs";
import { join, extname, basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const ARGS = process.argv.slice(2).filter((a) => !a.startsWith("--"));
const DRY = process.argv.includes("--dry");
const SAMPLES_DIR = ARGS[0] ? resolve(ARGS[0]) : join(HERE, "samples");
const OUT_DIR = join(HERE, "output");
const VAR_DIR = join(OUT_DIR, "ab-variants");

// ------------------------------ env (chung .env với verify.mjs) ------------------------------
const env = process.env;
const BASE_URL = env.BASE_URL || "https://generativelanguage.googleapis.com";
const MODEL = env.MODEL || "";
const API_KEY = env.API_KEY || "";
const CEFR_LEVEL = (env.CEFR_LEVEL || "B1").toUpperCase();

function die(msg) {
  console.error(`[lỗi] ${msg}`);
  process.exit(1);
}

// ------------------------------ prompt + schema (đồng bộ verify.mjs — prompt v2) ------------------------------
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

// ------------------------------ chuẩn hoá text + diff ------------------------------
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

function wordsOf(s) {
  return normalizePageText(s).split(" ").filter(Boolean);
}

/** Multiset diff theo từ — trả {missing, added, common}. Không nhạy thứ tự. */
function bagDiff(refWords, hypWords) {
  const r = new Map(), h = new Map();
  for (const w of refWords) r.set(w, (r.get(w) || 0) + 1);
  for (const w of hypWords) h.set(w, (h.get(w) || 0) + 1);
  let missing = 0, added = 0, common = 0;
  const all = new Set([...r.keys(), ...h.keys()]);
  for (const w of all) {
    const a = r.get(w) || 0, b = h.get(w) || 0;
    common += Math.min(a, b);
    missing += Math.max(0, a - b);
    added += Math.max(0, b - a);
  }
  return { missing, added, common };
}

/** Khoảng cách Levenshtein (DP full — text trang ≤ vài nghìn ký tự, đủ nhanh). */
function lev(a, b) {
  if (a === b) return 0;
  const m = a.length, n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  let prev = Array.from({ length: n + 1 }, (_, j) => j);
  for (let i = 1; i <= m; i++) {
    const cur = new Array(n + 1);
    cur[0] = i;
    for (let j = 1; j <= n; j++) {
      cur[j] = Math.min(
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[n];
}

/** CER (%) = lev / max(|ref|, |hyp|) — nhanh hơn và không lệch khi hyp khác độ dài. */
function cer(ref, hyp) {
  const d = lev(ref, hyp);
  const denom = Math.max(ref.length, hyp.length, 1);
  return (d / denom) * 100;
}

// ------------------------------ xác minh example (cùng thuật toán verify.mjs) ------------------------------
function verifyExamples(pageText, vocabulary) {
  const normPage = normalizePageText(pageText);
  let verified = 0, suspect = 0, unverified = 0, termNotOnPage = 0;
  for (const v of vocabulary) {
    const normExample = normalizePageText(v.example);
    const normTerm = normalizePageText(v.term);
    const isVerified = normPage.includes(normExample);
    const hasTerm = normExample.includes(normTerm);
    if (isVerified && hasTerm) verified++;
    else if (isVerified && !hasTerm) suspect++;
    else unverified++;
    if (!normPage.includes(normTerm)) termNotOnPage++;
  }
  return { verified, suspect, unverified, termNotOnPage };
}

// ------------------------------ tạo biến thể bằng sips ------------------------------
function sips(args) {
  return execFileSync("sips", args, { stdio: ["ignore", "pipe", "pipe"] });
}

function readDims(path) {
  const out = sips(["-g", "pixelWidth", "-g", "pixelHeight", path]).toString();
  const w = Number(/pixelWidth: (\d+)/.exec(out)?.[1]);
  const h = Number(/pixelHeight: (\d+)/.exec(out)?.[1]);
  return { w, h };
}

/** Ước lượng token ảnh theo quy tắc Gemini công bố: max(1, round(W×H/258));
 *  kèm bản "effective" sau khi Gemini tự scale cạnh dài xuống 3072 (tài liệu API).
 *  Chỉ là ƯỚC LƯỢNG để so tương đối — token thật lấy từ usageMetadata khi chạy. */
function estImageTokens(w, h) {
  const raw = Math.max(1, Math.round((w * h) / 258));
  const k = Math.min(1, 3072 / Math.max(w, h));
  const eff = Math.max(1, Math.round(((w * k) * (h * k)) / 258));
  return { raw, eff };
}

function buildVariants(inputPath, baseName) {
  mkdirSync(VAR_DIR, { recursive: true });
  const origStats = statSync(inputPath);
  const origDims = readDims(inputPath);

  const defs = [
    { id: "goc", label: "ảnh gốc (bytes nguyên — reference)", make: null },
    { id: "jpg95-full", label: "JPEG q0.95, giữ size (đường crop hiện tại)", make: { max: null, q: 95 } },
    { id: "jpg80-1400", label: "JPEG q0.80, cạnh dài ≤ 1400px", make: { max: 1400, q: 80 } },
    { id: "jpg85-1600", label: "JPEG q0.85, cạnh dài ≤ 1600px", make: { max: 1600, q: 85 } },
  ];

  const variants = defs.map((d) => {
    if (d.id === "goc") {
      return {
        id: d.id, label: d.label,
        file: inputPath, mime: MIME_BY_EXT[extname(inputPath).toLowerCase()] || "image/jpeg",
        bytes: origStats.size, dims: origDims, resized: false,
      };
    }
    const outPath = join(VAR_DIR, `${baseName}.${d.id}.jpg`);
    const args = ["-s", "format", "jpeg", "-s", "formatOptions", String(d.make.q)];
    // sips -Z UPSCALE ảnh nhỏ hơn ngưỡng → chỉ resize khi ảnh THẬT SỰ lớn hơn.
    // (Upscale không thêm thông tin, chỉ đốt thêm token — không bao giờ làm trong app.)
    if (d.make.max && Math.max(origDims.w, origDims.h) > d.make.max) {
      args.unshift("-Z", String(d.make.max));
    }
    args.push(inputPath, "--out", outPath);
    sips(args);
    const st = statSync(outPath);
    const dims = readDims(outPath);
    return {
      id: d.id, label: d.label,
      file: outPath, mime: "image/jpeg",
      bytes: st.size, dims, resized: dims.w !== origDims.w || dims.h !== origDims.h,
    };
  });
  return { origDims, variants };
}

// ------------------------------ gọi Gemini (có retry cho lỗi tạm thời) ------------------------------
const RETRYABLE_STATUS = new Set([408, 429, 500, 502, 503, 504]);
const MAX_ATTEMPTS = 5;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function analyzeOnce(imageB64, mimeType) {
  const url = `${BASE_URL}/v1beta/models/${MODEL}:generateContent`;
  const body = {
    contents: [{
      role: "user",
      parts: [
        { inline_data: { mime_type: mimeType, data: imageB64 } },
        { text: PROMPT },
      ],
    }],
    // temperature 0 để loại nhiễu lấy mẫu — biến độc lập chỉ còn là ẢNH.
    // (Lệch so với app: app KHÔNG set temperature; đây là script đo, không phải prompt sản phẩm.)
    generationConfig: {
      temperature: 0,
      response_mime_type: "application/json",
      response_schema: geminiSchema(),
    },
  };
  const started = Date.now();
  let res;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": API_KEY,
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    return { ok: false, latencyMs: Date.now() - started, transient: true, apiError: `network: ${e.message}` };
  }
  const latencyMs = Date.now() - started;
  let raw = "";
  try { raw = await res.text(); } catch { /* giữ rỗng */ }

  if (!res.ok) {
    return {
      ok: false,
      latencyMs,
      transient: RETRYABLE_STATUS.has(res.status),
      apiError: `HTTP ${res.status}: ${raw.slice(0, 300)}`,
    };
  }

  let envelope = null;
  try { envelope = JSON.parse(raw); } catch {
    return { ok: false, latencyMs, transient: false, apiError: "response không phải JSON" };
  }

  const candidate = envelope?.candidates?.[0];
  const usage = envelope?.usageMetadata || {};
  if (!candidate) {
    return { ok: false, latencyMs, transient: false, apiError: `không có candidates (body: ${raw.slice(0, 200)})`, usage };
  }

  const finishReason = candidate.finishReason || "(thiếu)";
  const text = candidate?.content?.parts?.map((p) => p.text || "").join("") || "";
  if (finishReason !== "STOP") {
    // RECITATION/MAX_TOKENS/SAFETY — không retry (retry không sửa được nội dung).
    return { ok: false, latencyMs, transient: false, apiError: `finishReason=${finishReason}`, usage };
  }

  let data = null;
  try { data = JSON.parse(text); } catch {
    return { ok: false, latencyMs, transient: true, apiError: "output text không parse được thành JSON", usage };
  }

  const violations = validateStrict(data);
  return { ok: true, latencyMs, violations, usage, data };
}

/** Gọi + retry backoff cho lỗi tạm thời (503 high demand, 429, 5xx, network).
 *  Trả kèm attempts + totalLatencyMs (tổng thời gian kể cả chờ). */
async function analyzeImage(imageB64, mimeType, tag) {
  let last = null;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const res = await analyzeOnce(imageB64, mimeType);
    if (res.ok) return { ...res, attempts: attempt };
    last = res;
    if (!res.transient || attempt === MAX_ATTEMPTS) break;
    const wait = [2000, 5000, 10000, 20000][attempt - 1] ?? 20000;
    console.log(`        ↻ ${tag}: ${res.apiError.split("\n")[0]} — thử lại sau ${wait / 1000}s (lần ${attempt}/${MAX_ATTEMPTS})`);
    await sleep(wait);
  }
  return { ...last, attempts: MAX_ATTEMPTS };
}

// ------------------------------ main ------------------------------
const IMG_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp", ".heic"]);
const MIME_BY_EXT = {
  ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
  ".png": "image/png", ".webp": "image/webp", ".heic": "image/heic",
};

if (!DRY) {
  if (!MODEL) die("thiếu MODEL trong .env — điền model đang dùng");
  if (!API_KEY) die("thiếu API_KEY trong .env");
}
if (!["A2", "B1", "B2", "C1"].includes(CEFR_LEVEL)) die(`CEFR_LEVEL="${CEFR_LEVEL}" không hợp lệ (A2|B1|B2|C1)`);

const files = readdirSync(SAMPLES_DIR)
  .filter((f) => IMG_EXTS.has(extname(f).toLowerCase()))
  .sort();

if (files.length === 0) die(`không thấy ảnh nào trong ${SAMPLES_DIR}`);
if (DRY) console.log("[dry] chỉ tạo biến thể + đo kích thước, KHÔNG gọi API.\n");

console.log("=".repeat(88));
console.log("READO — A/B NÉN ẢNH TRƯỚC KHI GỬI GEMINI (quyết định: imageToolkit.ts)");
console.log(`model=${MODEL}  cefr=${CEFR_LEVEL}  base_url=${BASE_URL}`);
console.log(`ảnh: ${files.length}  ·  biến thể/ảnh: 4  ·  reference = "goc" (đường sản xuất hiện tại)`);
console.log("temperature=0 (lệch app có chủ ý, để tách biến ảnh khỏi nhiễu lấy mẫu)");
console.log("=".repeat(88));

mkdirSync(VAR_DIR, { recursive: true });

const perImage = []; // { file, origDims, variants: [...], calls: [...] }
for (const file of files) {
  const full = join(SAMPLES_DIR, file);
  const baseName = basename(file, extname(file));
  const { origDims, variants } = buildVariants(full, baseName);

  const info = variants.map((v) => {
    const t = estImageTokens(v.dims.w, v.dims.h);
    return {
      id: v.id,
      label: v.label,
      dims: `${v.dims.w}×${v.dims.h}`,
      bytes: v.bytes,
      kb: (v.bytes / 1024).toFixed(1),
      estTok: t.eff,
      estTokRaw: t.raw,
      resized: v.resized,
    };
  });

  console.log(`\n${file}  (gốc ${origDims.w}×${origDims.h}, ${(statSync(full).size / 1024).toFixed(1)} KB)`);
  for (const v of info) {
    console.log(`  ${v.id.padEnd(12)} ${v.dims.padStart(10)}  ${v.kb.padStart(8)} KB  est-token≈${String(v.estTok).padStart(6)}${v.resized ? "  (đã resize)" : ""}  — ${v.label}`);
  }

  perImage.push({ file, full, baseName, origDims, variants, info });
}

if (DRY) {
  console.log("\n[dry] xong — ảnh biến thể ở", VAR_DIR);
  process.exit(0);
}

// ------------------------------ chạy API: mỗi ảnh × 4 biến thể ------------------------------
const rows = [];
let callNo = 0;
const totalCalls = perImage.length * 4;

for (const img of perImage) {
  // reference = biến thể "goc" của ảnh này
  const refVariant = img.variants.find((v) => v.id === "goc");
  const refB64 = readFileSync(refVariant.file).toString("base64");

  // Chạy reference TRƯỚC (còn để các biến thể sau so với nó).
  const ordered = [refVariant, ...img.variants.filter((v) => v.id !== "goc")];
  const refRes = await analyzeImage(refB64, refVariant.mime, `${img.file}·goc`);

  // Dữ liệu reference dùng để so diff — rỗng nếu reference chết.
  let refText = "";
  let refWordList = [];
  let refVocabMap = new Map();
  let refRow = null;
  if (refRes.ok) {
    const refPageText = refRes.data.segments.map((s) => s.source_en).join(" ");
    refText = normalizePageText(refPageText);
    refWordList = wordsOf(refPageText);
    refVocabMap = new Map(
      (refRes.data.vocabulary || []).map((v) => [normalizePageText(v.term), v]),
    );
    const rv = verifyExamples(refPageText, refRes.data.vocabulary || []);
    refRow = {
      image: img.file, variant: "goc", role: "reference",
      status: refRes.violations.length === 0 ? "schema_ok" : "schema_fail",
      latencyMs: refRes.latencyMs,
      attempts: refRes.attempts,
      usage: refRes.usage,
      promptTokens: Number(refRes.usage?.promptTokenCount || 0),
      candidatesTokens: Number(refRes.usage?.candidatesTokenCount || 0),
      totalTokens: Number(refRes.usage?.totalTokenCount || 0),
      segments: refRes.data.segments.length,
      vocabTotal: (refRes.data.vocabulary || []).length,
      ...rv,
      diff: null,
    };
    rows.push(refRow);
    callNo++;
    console.log(`[${String(callNo).padStart(2)}/${totalCalls}] goc ${img.file.padEnd(20)} ` +
      `lat=${refRow.latencyMs}ms  tok=${refRow.totalTokens}  seg=${refRow.segments}  vocab=${refRow.vocabTotal}  ` +
      `verified/suspect/unverified=${rv.verified}/${rv.suspect}/${rv.unverified}${refRow.status === "schema_fail" ? "  SCHEMA FAIL" : ""}`);
  } else {
    rows.push({ image: img.file, variant: "goc", role: "reference", status: "api_error", ...refRes });
    callNo++;
    console.log(`[${String(callNo).padStart(2)}/${totalCalls}] goc ${img.file.padEnd(20)} ERRRR: ${refRes.apiError}`);
  }

  for (const v of ordered.slice(1)) {
    const b64 = readFileSync(v.file).toString("base64");
    const res = await analyzeImage(b64, v.mime, `${img.file}·${v.id}`);
    callNo++;

    if (!res.ok) {
      rows.push({ image: img.file, variant: v.id, role: "variant", status: "api_error", ...res });
      console.log(`[${String(callNo).padStart(2)}/${totalCalls}] ${v.id.padEnd(12)} ${img.file.padEnd(20)} ERRRR: ${res.apiError}`);
      continue;
    }

    const pageText = res.data.segments.map((s) => s.source_en).join(" ");
    const normText = normalizePageText(pageText);
    const rv = verifyExamples(pageText, res.data.vocabulary || []);

    // so với reference (nếu có)
    let diff = null;
    if (refRow) {
      const refNorm = refText;
      const c = cer(refNorm, normText);
      const wd = bagDiff(refWordList, wordsOf(pageText));
      const hypVocab = new Map(
        (res.data.vocabulary || []).map((x) => [normalizePageText(x.term), x]),
      );
      const missingTerms = [...refVocabMap.keys()].filter((t) => !hypVocab.has(t));
      const addedTerms = [...hypVocab.keys()].filter((t) => !refVocabMap.has(t));
      let meaningDiff = 0;
      for (const [t, refV] of refVocabMap) {
        const hV = hypVocab.get(t);
        if (hV && normalizePageText(hV.meaning_vi) !== normalizePageText(refV.meaning_vi)) meaningDiff++;
      }
      diff = {
        cerPct: Number(c.toFixed(3)),
        refChars: refNorm.length,
        hypChars: normText.length,
        missingWords: wd.missing,
        addedWords: wd.added,
        missingTerms,
        addedTerms,
        meaningDiff,
      };
    }

    const row = {
      image: img.file, variant: v.id, role: "variant",
      status: res.violations.length === 0 ? "schema_ok" : "schema_fail",
      latencyMs: res.latencyMs,
      attempts: res.attempts,
      usage: res.usage,
      promptTokens: Number(res.usage?.promptTokenCount || 0),
      candidatesTokens: Number(res.usage?.candidatesTokenCount || 0),
      totalTokens: Number(res.usage?.totalTokenCount || 0),
      segments: res.data.segments.length,
      vocabTotal: (res.data.vocabulary || []).length,
      ...rv,
      diff,
    };
    rows.push(row);

    const infoI = img.info.find((i) => i.id === v.id);
    console.log(`[${String(callNo).padStart(2)}/${totalCalls}] ${v.id.padStart(12)} ${img.file.padEnd(20)} ` +
      `lat=${res.latencyMs}ms  tok=${row.totalTokens}  seg=${row.segments}  vocab=${row.vocabTotal}  ` +
      `verified/suspect/unverified=${rv.verified}/${rv.suspect}/${rv.unverified}` +
      (diff ? `  CER=${diff.cerPct}%  từ -${diff.missingWords}/+${diff.addedWords}  vocab -${diff.missingTerms.length}/+${diff.addedTerms.length} nghĩa≠${diff.meaningDiff}` : "") +
      (row.status === "schema_fail" ? "  SCHEMA FAIL" : ""));

    await sleep(1200); // nhịp thở — model đang quá tải (503) vào giờ cao điểm
  }
}

// ------------------------------ tổng hợp ------------------------------
console.log("\n" + "=".repeat(88));
console.log("TỔNG HỢP — trung bình theo biến thể (reference = goc)");
console.log("=".repeat(88));

const variantIds = ["goc", "jpg95-full", "jpg80-1400", "jpg85-1600"];
const head = `${"biến thể".padEnd(12)} ${"bytes KB".padStart(9)} ${"ước-token".padStart(10)} ${"token thật".padStart(11)} ${"p50 lat".padStart(8)} ${"CER%".padStart(7)} ${"từ-/+".padStart(10)} ${"vocab-/+".padStart(10)} ${"nghĩa≠".padStart(7)} ${"schema".padEnd(7)}`;
console.log(head);
console.log("-".repeat(88));

const summary = {};
for (const vId of variantIds) {
  const imgInfos = perImage.map((im) => im.info.find((i) => i.id === vId));
  const calls = rows.filter((r) => r.variant === vId && r.status !== "api_error");
  const okRows = calls.filter((r) => r.status === "schema_ok");
  const lats = calls.map((r) => r.latencyMs).filter((x) => x != null).sort((a, b) => a - b);
  const p50 = lats.length ? lats[Math.floor((lats.length - 1) / 2)] : null;
  const mean = (arr) => arr.length ? Math.round(arr.reduce((a, b) => a + b, 0) / arr.length) : null;
  const meanNum = (arr, d = 2) => arr.length ? Number((arr.reduce((a, b) => a + b, 0) / arr.length).toFixed(d)) : null;

  const s = {
    label: calls[0]?.variant ? imgInfos.find((i) => i.id === vId)?.label : "",
    meanKb: meanNum(imgInfos.map((i) => Number(i.kb))),
    meanEstTok: mean(imgInfos.map((i) => i.estTok)),
    meanRealTok: mean(calls.map((r) => r.totalTokens)),
    meanPromptTok: mean(calls.map((r) => r.promptTokens)),
    p50LatMs: p50,
    meanCer: meanNum(okRows.map((r) => r.diff?.cerPct).filter((x) => x != null), 3),
    meanMissingWords: meanNum(okRows.map((r) => r.diff?.missingWords).filter((x) => x != null), 1),
    meanAddedWords: meanNum(okRows.map((r) => r.diff?.addedWords).filter((x) => x != null), 1),
    meanMissingTerms: meanNum(okRows.map((r) => r.diff?.missingTerms.length).filter((x) => x != null), 1),
    meanAddedTerms: meanNum(okRows.map((r) => r.diff?.addedTerms.length).filter((x) => x != null), 1),
    meanMeaningDiff: meanNum(okRows.map((r) => r.diff?.meaningDiff).filter((x) => x != null), 1),
    schemaOk: okRows.length,
    calls: calls.length,
  };
  summary[vId] = s;

  console.log(
    vId.padEnd(12) +
    String(s.meanKb ?? "—").padStart(9) +
    String(s.meanEstTok ?? "—").padStart(10) +
    String(s.meanRealTok ?? "—").padStart(11) +
    String(s.p50LatMs ?? "—").padStart(8) +
    String(s.meanCer ?? "—").padStart(7) +
    `${String(s.meanMissingWords ?? "—")}/${String(s.meanAddedWords ?? "—")}`.padStart(10) +
    `${String(s.meanMissingTerms ?? "—")}/${String(s.meanAddedTerms ?? "—")}`.padStart(10) +
    String(s.meanMeaningDiff ?? "—").padStart(7) +
    (`${s.schemaOk}/${s.calls}`).padStart(6) +
    `  — ${s.label || ""}`,
  );
}

const apiErrors = rows.filter((r) => r.status === "api_error");
const refMissing = rows.filter((r) => r.variant === "goc" && r.status === "api_error");
if (apiErrors.length) {
  console.log(`\n⚠ ${apiErrors.length} lần gọi lỗi API (đã retry tối đa ${MAX_ATTEMPTS} lần) — loại khỏi trung bình:`);
  for (const e of apiErrors) {
    console.log(`   - ${e.image} · ${e.variant}: ${String(e.apiError).split("\n")[0]}`);
  }
}
if (refMissing.length) {
  console.log(`⚠ ${refMissing.length} ảnh KHÔNG có reference (goc lỗi) → cột CER/từ/vocab của ảnh đó bỏ trống;`);
  console.log("   chạy lại khi model bớt tải (503) để có đủ cặp so sánh.");
}
console.log(`   (trung bình tính trên ${rows.filter((r) => r.status === "schema_ok").length}/${totalCalls} lần gọi schema_ok)`);

console.log("\nGhi chú đọc kết quả:");
console.log("  • CER%: % ký tự sai của toàn văn trang so với bản gốc (reference). Càng gần 0 càng giống.");
console.log("  • từ -/+: số từ của toàn văn trang bị MẤT / THÊM so với bản gốc (đếm multiset, không nhạy thứ tự).");
console.log("  • vocab -/+: số term xuất hiện ở bản gốc mà biến thể KHÔNG trích ra / ngược lại; nghĩa≠: term chung nhưng nghĩa khác.");
console.log("  • CER nhỏ (<1%) phần lớn có thể là nhiễu lấy mẫu — kết luận cần nhìn cả cụm jpg80-1400 vs jpg85-1600");
console.log("    và chiều nghịch: nén nặng hơn mà vẫn không tệ hơn → chốt được; xấu đi rõ theo độ nén mới là tín hiệu thật.");
console.log("  • Ảnh mẫu NHỎ (≤1600px) thì cột resize không có tác dụng — cần bộ ảnh full-res để đo phần tiết kiệm token.");
console.log("  • Nén bằng sips (Lanczos, Mac) tốt hơn canvas drawImage của app → giới hạn lạc quan cho app thật.");

const report = {
  ran_at: new Date().toISOString(),
  config: { model: MODEL, base_url: BASE_URL, cefr: CEFR_LEVEL, temperature: 0, prompt: "prompt v2 (đồng bộ verify.mjs)", nozzle: "sips" },
  images: perImage.map((im) => ({ file: im.file, origDims: im.origDims, variants: im.info })),
  rows,
  summary,
};
writeFileSync(join(OUT_DIR, "ab-last-run.json"), JSON.stringify(report, null, 2));
console.log(`\nreport: scripts/verify/output/ab-last-run.json`);
console.log(`ảnh biến thể: ${VAR_DIR}/`);