/**
 * e2e/home-flow.mjs — smoke test màn Trang chủ FR-14 (task 3.5) trên Chrome
 * thật: khối stats render đủ 3 con số (đến hạn / trang đã phân tích / streak)
 * với DB mới (toàn 0), hàng "tồn" ĐÚNG LÀ ẨN khi không có gì tồn (criterion 3 —
 * chỉ hiện khi > 0), nút ôn tập hiển thị con số trong nhãn, và 0 lỗi console.
 *
 * Giới hạn: profile e2e là DB MỚI nên mọi số = 0 — phép thử này chứng minh
 * wiring + render trong browser; phần "đúng con số khi CÓ dữ liệu" do
 * `homeStats.integration.test.ts` (SQLite thật) đảm nhiệm.
 *
 * Chạy: npm run e2e:home   (cần dev server ở localhost:5173)
 */
import puppeteer from "puppeteer-core";

const BASE = process.argv[2] ?? "http://localhost:5173/";
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PROFILE = "/tmp/reado-e2e-home-profile";

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
  const consoleErrors = [];
  page.on("console", (m) => {
    if (m.type() === "error") consoleErrors.push(m.text().slice(0, 200));
  });
  page.on("pageerror", (e) => consoleErrors.push(`pageerror: ${e.message.slice(0, 200)}`));

  await page.goto(BASE, { waitUntil: "networkidle0", timeout: 30000 });
  await page.waitForSelector(".home", { timeout: 15000 });

  // 1) Khối stats render đủ 3 hàng (đến hạn / trang đã phân tích / streak).
  await page.waitForSelector(".stats", { timeout: 10000 });
  const labels = await page.evaluate(() =>
    [...document.querySelectorAll(".stat-row .stat-label")].map((el) => el.textContent ?? ""),
  );
  const hasDue = labels.some((l) => l.includes("Đến hạn hôm nay"));
  const hasPages = labels.some((l) => l.includes("Trang đã phân tích"));
  const hasStreak = labels.some((l) => l.includes("Streak ôn tập"));
  if (!hasDue || !hasPages || !hasStreak) {
    throw new Error(`stats thiếu hàng — labels=${JSON.stringify(labels)}`);
  }

  // 2) DB mới → 3 số đều 0, và hàng tồn PHẢI VẮNG MẶT (chỉ hiện khi > 0).
  const statRows = await page.evaluate(() =>
    [...document.querySelectorAll(".stat-row")].map((el) => ({
      label: (el.querySelector(".stat-label")?.textContent ?? "").trim(),
      value: (el.querySelector(".stat-value")?.textContent ?? "").trim(),
    })),
  );
  const dueRow = statRows.find((r) => r.label.startsWith("Đến hạn"));
  const pageRow = statRows.find((r) => r.label.startsWith("Trang đã phân tích"));
  const streakRow = statRows.find((r) => r.label.startsWith("Streak"));
  if (!dueRow || dueRow.value !== "0") throw new Error(`đến hạn phải là 0 với DB mới: ${JSON.stringify(statRows)}`);
  if (!pageRow || pageRow.value !== "0") throw new Error(`trang phân tích phải là 0 với DB mới: ${JSON.stringify(statRows)}`);
  if (!streakRow || streakRow.value !== "0") throw new Error(`streak phải là 0 với DB mới: ${JSON.stringify(statRows)}`);
  const deferRow = statRows.find((r) => r.label.includes("Còn tồn"));
  if (deferRow) throw new Error("hàng tồn phải ẩn khi không có gì tồn");

  // 3) Nút Ôn tập hôm nay hiển thị con số (0) trong nhãn.
  const reviewText = await page.evaluate(() =>
    [...document.querySelectorAll("button")].find((el) => (el.textContent ?? "").includes("Ôn tập hôm nay"))
      ?.textContent ?? "",
  );
  if (!reviewText.includes("(0)")) throw new Error(`nút ôn tập thiếu số đến hạn: "${reviewText}"`);

  if (consoleErrors.length > 0) {
    throw new Error(`console errors:\n${consoleErrors.join("\n")}`);
  }

  console.log("e2e/home-flow: PASS");
  console.log("  - khối stats đủ 3 hàng (đến hạn / trang phân tích / streak)");
  console.log("  - DB mới → 3 số bằng 0, hàng tồn ẩn đúng rule criterion 3");
  console.log("  - nút Ôn tập hôm nay hiển thị số đến hạn");
  console.log("  - 0 lỗi console");
} finally {
  await browser.close();
}