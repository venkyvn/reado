/**
 * e2e/cram-flow.mjs — smoke test task 3.13 (Targeted review theo tag) trên
 * Chrome thật: seed 2 thẻ mang tag (cùng origin, worker dọn xong trước khi app
 * boot) → Ôn tập → lối vào "Ôn theo chủ đề" → màn chọn tag đếm đúng số thẻ →
 * chọn 1 tag → phiên cram 1/1 → lật thấy chips tag + khối đồng nghĩa → chấm →
 * màn "Xong buổi ôn" → quay lại ôn hằng ngày vẫn CÒN NGUYÊN thẻ (cram không
 * động đến lịch) → 0 lỗi console.
 *
 * Giới hạn thừa nhận: phần "chấm cram không đổi MỘT cột nào của cards" được
 * giữ bằng cram.integration.test.ts (SQLite thật); đây là smoke UI wiring.
 *
 * Chạy: npm run e2e:cram   (cần dev server ở localhost:5173)
 */
import { rmSync } from "node:fs";
import puppeteer from "puppeteer-core";

const BASE = process.argv[2] ?? "http://localhost:5173/";
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PROFILE = "/tmp/reado-e2e-cram-profile";
// Profile cũ = DB cũ → seed lần 2 làm tag đếm gấp đôi thẻ (business 2 thay vì 1).
// Mỗi lượt chạy phải là DB mới — xoá profile ngay khi start.
rmSync(PROFILE, { recursive: true, force: true });

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  // --no-sandbox --disable-gpu (2026-09-09): Chrome trong DSH seatbelt chết process
  // con với "GPU process isn't usable / sandbox initialization failed" — môi trường,
  // không phải bug app (xem journal 3.5). Headless + profile /tmp dùng một lần.
  args: [
    "--no-first-run",
    "--disable-crash-reporter",
    "--no-sandbox",
    "--disable-gpu",
    `--user-data-dir=${PROFILE}`,
    `--crash-dumps-dir=${PROFILE}`,
  ],
});

async function clickByText(page, selector, text) {
  const handle = await page.evaluateHandle(
    (sel, txt) =>
      [...document.querySelectorAll(sel)].find((el) => (el.textContent ?? "").includes(txt)) ?? null,
    selector,
    text,
  );
  const el = handle.asElement();
  if (!el) throw new Error(`không tìm thấy ${selector} chứa "${text}"`);
  await el.click();
}

/** Tích checkbox trong hàng tag chứa text. */
async function checkTag(page, text) {
  const handle = await page.evaluateHandle(
    (txt) => {
      const row = [...document.querySelectorAll(".cram-tag-row")].find((el) =>
        (el.textContent ?? "").includes(txt),
      );
      if (!row) return null;
      const box = row.querySelector('input[type="checkbox"]');
      return box ?? null;
    },
    text,
  );
  const el = handle.asElement();
  if (!el) throw new Error(`không thấy hàng tag "${text}"`);
  await el.click();
}

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 430, height: 900 });
  // Chặn favicon.ico — Chrome tự dò dù index.html không khai → 404 noise làm
  // hỏng check "0 lỗi console" (console không mang URL nên không lọc được text).
  // abort cũng sinh ERR_FAILED trên console nên trả 200 rỗng cho Chrome im lặng.
  await page.setRequestInterception(true);
  page.on("request", (req) => {
    if (req.url().endsWith("/favicon.ico")) {
      void req.respond({ status: 200, contentType: "image/x-icon", body: "" });
      return;
    }
    void req.continue();
  });
  const consoleErrors = [];
  page.on("console", (m) => {
    if (m.type() === "error") consoleErrors.push(m.text().slice(0, 200));
  });
  page.on("pageerror", (e) => consoleErrors.push(`pageerror: ${e.message.slice(0, 200)}`));
  // Chẩn đoán: ghi URL của mọi response 404 vào cùng danh sách lỗi — "Failed to
  // load resource" của console không mang URL, không biết file nào mất tích.
  page.on("response", (r) => {
    if (r.status() === 404 && !r.url().endsWith("/favicon.ico")) {
      consoleErrors.push(`404: ${r.url()}`);
    }
  });

  // 1) Seed 2 thẻ có tag vào OPFS của origin test.
  await page.goto(`${BASE}e2e/seed.html`, { waitUntil: "load", timeout: 30000 });
  await page.waitForFunction(
    () => {
      const t = document.querySelector("#status")?.textContent ?? "";
      return t.startsWith("SEEDED") || t.startsWith("FAIL");
    },
    { timeout: 30000 },
  );
  const seedText = await page.$eval("#status", (el) => el.textContent ?? "");
  console.log("seed:", seedText);
  if (!seedText.startsWith("SEEDED")) throw new Error(`seed thất bại: ${seedText}`);

  // 2) App → Home → Ôn tập (màn session đang đứng ở thẻ đầu).
  await page.goto(BASE, { waitUntil: "networkidle0", timeout: 30000 });
  await page.waitForSelector(".home", { timeout: 20000 });
  await clickByText(page, "button", "Ôn tập");
  await page.waitForSelector(".review-card", { timeout: 20000 });
  const beforeCramTerm = await page.$eval(".review-term", (el) => (el.textContent ?? "").trim());

  // 3) Lối vào cram: link cuối màn Ôn tập.
  await clickByText(page, "a", "Ôn theo chủ đề");
  await page.waitForFunction(
    () => document.querySelector("h1")?.textContent?.includes("Ôn theo chủ đề") === true,
    { timeout: 10000 },
  );

  // 4) Màn chọn tag: 3 tag với số thẻ đúng (business 1 · shared 2 · speech 1).
  await page.waitForFunction(
    () => document.querySelectorAll(".cram-tag-row").length === 3,
    { timeout: 10000 },
  );
  const tagInfo = await page.evaluate(() =>
    [...document.querySelectorAll(".cram-tag-row")].map((el) => (el.textContent ?? "").trim()),
  );
  console.log("tags:", tagInfo.join(" | "));
  const business = tagInfo.find((t) => t.startsWith("business"));
  if (!business || !business.includes("1 thẻ")) throw new Error(`tag business sai số thẻ: ${business}`);
  const shared = tagInfo.find((t) => t.startsWith("shared"));
  if (!shared || !shared.includes("2 thẻ")) throw new Error(`tag shared sai số thẻ: ${shared}`);

  // 5) Chọn "business" → bắt đầu → phiên đúng 1 thẻ.
  await checkTag(page, "business");
  await clickByText(page, "button", "Bắt đầu ôn");
  await page.waitForSelector(".review-card", { timeout: 10000 });
  const cramTerm = await page.$eval(".review-term", (el) => (el.textContent ?? "").trim());
  if (cramTerm !== "staggering") throw new Error(`phiên cram phải là staggering, thấy "${cramTerm}"`);
  await page.waitForFunction(
    () => document.querySelector(".review-meta")?.textContent?.includes("1/1") === true,
    { timeout: 5000 },
  );

  // 6) Lật mặt sau: chips tag (business/shared) + khối đồng nghĩa astonishing.
  await page.click(".review-card");
  await page.waitForSelector(".review-card.flipped", { timeout: 10000 });
  await page.waitForFunction(
    () =>
      document.querySelectorAll(".chip-tag").length === 2 &&
      [...document.querySelectorAll(".review-extra-line")].some((el) =>
        (el.textContent ?? "").includes("astonishing"),
      ),
    { timeout: 5000 },
  );

  // 7) Chấm Tốt → màn kết thúc buổi cram.
  await clickByText(page, ".grade-btn", "Tốt");
  await page.waitForFunction(
    () => document.querySelector("h1")?.textContent?.includes("Xong buổi ôn theo chủ đề") === true,
    { timeout: 10000 },
  );

  // 8) Quay lại ôn hằng ngày: thẻ VẪN CÒN đó (cram không đổi lịch/hạn mức).
  await clickByText(page, "button", "Về ôn tập hằng ngày");
  await page.waitForSelector(".review-card", { timeout: 10000 });
  const afterCramTerm = await page.$eval(".review-term", (el) => (el.textContent ?? "").trim());
  if (afterCramTerm !== beforeCramTerm) {
    throw new Error(`hàng đợi ôn thường bị đổi sau cram: "${beforeCramTerm}" → "${afterCramTerm}"`);
  }

  if (consoleErrors.length > 0) {
    throw new Error(`lỗi console: ${consoleErrors.join(" | ")}`);
  }
  console.log("cram-flow PASS: chọn tag → phiên 1/1 → lật thấy chips + đồng nghĩa → chấm → lịch thường không đổi · 0 lỗi");
} finally {
  await browser.close();
}