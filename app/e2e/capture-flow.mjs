/**
 * e2e/capture-flow.mjs — smoke test màn capture bằng Chrome THẬT của hệ thống
 * (puppeteer-core trỏ vào Chrome có sẵn, không tải Chromium riêng).
 *
 * Chứng minh điều owner gặp thật ngày 2026-09-08: upload ảnh xong canvas preview
 * PHẢI có pixel (trước khi fix thì React set attribute width/height làm xoá
 * bitmap → preview trong suốt dù flow vẫn chạy).
 *
 * Chạy: npm run e2e   (cần dev server đang chạy ở localhost:5173)
 * Arg:  node e2e/capture-flow.mjs [url] [đường-dẫn-ảnh]
 */
import { resolve } from "node:path";
import puppeteer from "puppeteer-core";

const URL = process.argv[2] ?? "http://localhost:5173/";
const SAMPLE = resolve(process.argv[3] ?? "../ref/sample/page-42.png");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PROFILE = "/tmp/reado-e2e-profile";

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: [
    "--no-first-run",
    "--disable-crash-reporter",
    `--user-data-dir=${PROFILE}`,
    `--crash-dumps-dir=${PROFILE}`,
  ],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 430, height: 900 });
  await page.goto(URL, { waitUntil: "networkidle0", timeout: 30000 });

  const clickByText = async (text) => {
    const ok = await page.evaluate((t) => {
      const btn = [...document.querySelectorAll("button")].find((b) =>
        b.textContent.includes(t),
      );
      if (!btn) return false;
      btn.click();
      return true;
    }, text);
    if (!ok) throw new Error(`không tìm thấy nút chứa "${text}"`);
  };

  await clickByText("Chụp trang sách");
  await page.waitForSelector("#capture-gallery", { timeout: 5000 });
  const input = await page.$("#capture-gallery");
  await input.uploadFile(SAMPLE);
  await page.waitForSelector(".crop-canvas", { timeout: 10000 });
  await new Promise((r) => setTimeout(r, 400)); // chờ effect vẽ lại canvas

  const info = await page.evaluate(() => {
    const c = document.querySelector(".crop-canvas");
    const rect = c.getBoundingClientRect();
    const ctx = c.getContext("2d");
    const data = ctx.getImageData(0, 0, c.width, c.height).data;
    let opaque = 0;
    let samples = 0;
    for (let i = 3; i < data.length; i += 4 * 997) {
      samples++;
      if (data[i] > 0) opaque++;
    }
    return {
      displayW: Math.round(rect.width),
      displayH: Math.round(rect.height),
      attrW: c.width,
      attrH: c.height,
      opaqueSamples: opaque,
      samples,
    };
  });

  const pass = info.opaqueSamples > 0 && info.displayW > 50 && info.displayH > 50;
  console.log(JSON.stringify({ ...info, pass }, null, 2));
  console.log(pass ? "✅ preview canvas CÓ pixel thật" : "❌ preview canvas TRẮNG (bug tái hiện)");
  process.exitCode = pass ? 0 : 1;
} finally {
  await browser.close();
}