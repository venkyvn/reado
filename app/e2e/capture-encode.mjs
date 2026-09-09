/**
 * e2e/capture-encode.mjs — verify đường ảnh gửi AI SAU quyết định 2026-09-09
 * (luôn chuẩn hoá: downscale cạnh dài ≤ 1600 + JPEG q0.80 — xem ui/imageToolkit.ts).
 *
 * Không gọi Gemini thật: tự dựng fake endpoint (cùng pattern read-flow) và dùng
 * chính request app gửi đi làm bằng chứng — server bắt body, tách inline_data,
 * giải base64, đọc dimension JPEG bằng SOF marker:
 *
 *   1. page-42.png (360×480, PNG)  → phải gửi image/jpeg, GIỮ 360×480 (không upscale)
 *   2. ảnh "photo" 3000×4000 (tự tạo từ page-47 bằng sips) → phải thành 1200×1600
 *
 * Chạy: npm run dev (localhost:5173) rồi `npm run e2e:encode`
 */
import { createServer } from "node:http";
import { execFileSync } from "node:child_process";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { writeFileSync } from "node:fs";
import puppeteer from "puppeteer-core";

const HERE = dirname(fileURLToPath(import.meta.url));
const URL_APP = process.argv[2] ?? "http://localhost:5173/";
const SAMPLE_A = resolve(process.argv[3] ?? join(HERE, "../../ref/sample/page-42.png"));
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PROFILE = "/tmp/reado-e2e-profile-encode";
const FAKE_PORT = 8791;
const FAKE_BASE = `http://127.0.0.1:${FAKE_PORT}`;

// Ảnh lớn cho ca 2 — sips upscale page-47 (750×1000) → 3000×4000. Upscale ở đây
// chỉ để CÓ pixel nhiều; app phải thu ngược về 1200×1600.
const BIG_SAMPLE = join(tmpdir(), "reado-e2e-big-3000x4000.png");
execFileSync("sips", ["-Z", "4000", resolve(join(HERE, "../../ref/sample/page-47.png")), "--out", BIG_SAMPLE], { stdio: "ignore" });

/** Đọc dimension JPEG từ SOF marker (c0–cf trừ c4/c8/cc). */
function jpegDims(buf) {
  let i = 2;
  while (i + 9 < buf.length) {
    if (buf[i] !== 0xff) { i++; continue; }
    const marker = buf[i + 1];
    if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
      return { h: buf.readUInt16BE(i + 5), w: buf.readUInt16BE(i + 7) };
    }
    if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd9)) { i += 2; continue; }
    i += 2 + buf.readUInt16BE(i + 2);
  }
  return null;
}

// Fake Gemini: bắt request (mime + base64) rồi trả envelope hợp lệ để app chạy tiếp.
const captured = []; // { mime, bytes, b64len }
const PAYLOAD = {
  segments: [{ source_en: "The crowd went wildly enthusiastic.", translation_vi: "Đám đông hào hứng cuồng nhiệt." }],
  vocabulary: [{
    term: "wildly", pos: "adv", ipa: "/ˈwaɪldli/", meaning_vi: "cuồng nhiệt", cefr: "B2",
    example: "The crowd went wildly enthusiastic.",
  }],
  summary_vi: "Đám đông hào hứng.",
};
const server = createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "content-type, x-goog-api-key");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }
  if (req.method === "POST" && req.url.endsWith(":generateContent")) {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        const parsed = JSON.parse(body);
        const img = parsed?.contents?.[0]?.parts?.find((p) => p.inline_data)?.inline_data;
        if (img?.data) {
          const buf = Buffer.from(img.data, "base64");
          captured.push({ mime: img.mime_type, bytes: buf.length, dims: jpegDims(buf) });
        }
      } catch { /* bỏ — check riêng bên dưới */ }
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({
        candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify(PAYLOAD) }] } }],
        usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 10 },
      }));
    });
    return;
  }
  res.writeHead(404);
  res.end();
});
await new Promise((r) => server.listen(FAKE_PORT, "127.0.0.1", r));

const results = [];
const check = (name, ok, detail = "") => {
  results.push({ name, ok });
  console.log(`${ok ? "✅" : "❌"} ${name}${detail ? ` — ${detail}` : ""}`);
};

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  // --no-sandbox --disable-gpu: Chrome chạy trong DSH seatbelt thì process con
  // (GPU/renderer) chết với "sandbox initialization failed: Operation not
  // permitted" (journal 3.5/3.14). Headless + profile dùng một lần → chấp nhận.
  args: [
    "--no-first-run",
    "--disable-crash-reporter",
    "--no-sandbox",
    "--disable-gpu",
    `--user-data-dir=${PROFILE}`,
  ],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 430, height: 900 });
  const consoleErrors = [];
  page.on("console", (m) => { if (m.type() === "error") consoleErrors.push(m.text()); });
  page.on("pageerror", (e) => consoleErrors.push(String(e)));
  await page.goto(URL_APP, { waitUntil: "networkidle0", timeout: 30000 });

  const clickByText = async (text) => {
    const ok = await page.evaluate((t) => {
      const btn = [...document.querySelectorAll("button")].find((b) => b.textContent.includes(t));
      if (!btn) return false;
      btn.click();
      return true;
    }, text);
    if (!ok) throw new Error(`không tìm thấy nút chứa "${text}"`);
  };
  const uploadAndAnalyze = async (samplePath) => {
    await page.waitForSelector("#capture-gallery", { timeout: 5000 });
    await (await page.$("#capture-gallery")).uploadFile(samplePath);
    await page.waitForSelector(".crop-canvas", { timeout: 10000 });
    await clickByText("Phân tích trang");
    // Profile mới lần đầu: form BYOK hiện ra → trỏ tới fake endpoint
    const gotForm = await page
      .waitForSelector('input[type="password"]', { timeout: 15000 })
      .then(() => true)
      .catch(() => false);
    if (gotForm) {
      await page.type('input[type="password"]', "fake-key");
      await page.evaluate(() => { document.querySelector('input[type="url"]').value = ""; });
      await page.type('input[type="url"]', FAKE_BASE);
      await clickByText("Lưu & phân tích ngay");
    }
    await page.waitForFunction(() => document.querySelector("h1")?.textContent === "Đọc trang", { timeout: 30000 });
  };

  // ---- Ca 1: ảnh nhỏ 360×480 — không upscale, mime phải là image/jpeg ----
  await clickByText("Chụp trang sách");
  await uploadAndAnalyze(SAMPLE_A);
  const cap1 = captured[0];
  check("ca 1: request tới AI có tới fake server", cap1 != null);
  if (cap1) {
    check("ca 1: mime_type = image/jpeg (hết đường gửi mime giả)", cap1.mime === "image/jpeg", cap1.mime);
    check("ca 1: giữ 360×480 — KHÔNG upscale ảnh nhỏ", cap1.dims?.w === 360 && cap1.dims?.h === 480, JSON.stringify(cap1.dims));
    const origBytes = (await import("node:fs")).statSync(SAMPLE_A).size;
    check("ca 1: bytes JPEG < bytes PNG gốc", cap1.bytes < origBytes, `${cap1.bytes} vs ${origBytes}`);
  }

  // ---- Ca 2: ảnh photo 3000×4000 — phải thu về 1200×1600 ----
  await clickByText("Về trang chủ");
  await clickByText("Chụp trang sách");
  await uploadAndAnalyze(BIG_SAMPLE);
  const cap2 = captured[1];
  check("ca 2: request thứ hai tới fake server", cap2 != null);
  if (cap2) {
    check("ca 2: 3000×4000 → 1200×1600 (cạnh dài ≤ 1600)", cap2.dims?.w === 1200 && cap2.dims?.h === 1600, JSON.stringify(cap2.dims));
    check("ca 2: mime_type = image/jpeg", cap2.mime === "image/jpeg", cap2.mime);
  }

  check("0 lỗi console", consoleErrors.length === 0, consoleErrors.slice(0, 3).join(" | "));

  const failed = results.filter((r) => !r.ok);
  console.log(JSON.stringify(results, null, 2));
  console.log(failed.length === 0 ? "✅ capture-encode PASS" : `❌ capture-encode FAIL: ${failed.length} mục`);
  process.exitCode = failed.length === 0 ? 0 : 1;
} finally {
  server.close();
  await browser.close();
}
