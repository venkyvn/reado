/**
 * e2e/library-flow.mjs — smoke test màn Kho từ vựng (FR-08, task 3.4) trên Chrome
 * thật: route chạy, ba bộ lọc render, empty-state đúng cả hai nhánh (kho trống →
 * banner origin-aware; có lọc nhưng 0 khớp → nhắc bỏ lọc), quay về Home, và
 * KHÔNG có lỗi console.
 *
 * Giới hạn phải nói thẳng: profile e2e là DB MỚI nên kho rỗng — phép thử này chứng
 * minh wiring + UI trong browser; phần "lọc ra đúng dòng khi CÓ dữ liệu" do
 * `library.integration.test.ts` (SQLite thật) đảm nhiệm — 55/55 green.
 *
 * Chạy: npm run e2e:library   (cần dev server ở localhost:5173)
 */
import puppeteer from "puppeteer-core"

const BASE = process.argv[2] ?? "http://localhost:5173/"
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
const PROFILE = "/tmp/reado-e2e-library-profile"

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
})

async function clickByText(page, selector, text) {
  const handle = await page.evaluateHandle(
    (sel, txt) =>
      [...document.querySelectorAll(sel)].find((el) => (el.textContent ?? "").includes(txt)) ??
      null,
    selector,
    text,
  )
  const el = handle.asElement()
  if (!el) throw new Error(`không tìm thấy ${selector} chứa "${text}"`)
  await el.click()
}

try {
  const page = await browser.newPage()
  await page.setViewport({ width: 430, height: 900 })
  const consoleErrors = []
  page.on("console", (m) => {
    if (m.type() === "error") consoleErrors.push(m.text().slice(0, 200))
  })
  page.on("pageerror", (e) => consoleErrors.push(`pageerror: ${e.message.slice(0, 200)}`))

  await page.goto(BASE, { waitUntil: "networkidle0", timeout: 30000 })
  await page.waitForSelector(".home", { timeout: 15000 })

  // 1) Home → Kho từ vựng (NFR-08 không bị đụng: capture vẫn 1 chạm).
  await clickByText(page, "button", "Kho từ vựng")
  await page.waitForFunction(
    () => document.querySelector("h1")?.textContent?.includes("Kho từ vựng") === true,
    { timeout: 10000 },
  )

  // 2) Ba bộ lọc đúng rule: collection / CEFR / trạng thái ôn tập.
  for (const id of ["lib-collection", "lib-cefr", "lib-state"]) {
    await page.waitForSelector(`#${id}`, { timeout: 10000 })
  }

  // 3) Kho trống (profile mới): đếm 0 từ + empty-state origin-aware.
  await page.waitForFunction(
    () => document.querySelector(".muted")?.textContent?.includes("0 từ") === true,
    { timeout: 10000 },
  )
  const emptyBanner = await page.evaluate(() =>
    [...document.querySelectorAll(".banner-warn")].some((el) =>
      (el.textContent ?? "").includes("Chưa có từ nào ở địa chỉ này"),
    ),
  )
  if (!emptyBanner) throw new Error("thiếu empty-state origin-aware khi kho trống")

  // Collection mặc định luôn có sẵn trong select (FR-17 / spawn tài khoản).
  const hasDefault = await page.evaluate(() =>
    [...document.querySelectorAll("#lib-collection option")].some((el) =>
      (el.textContent ?? "").includes("mặc định"),
    ),
  )
  if (!hasDefault) throw new Error("select collection thiếu collection mặc định")

  // 4) Đổi bộ lọc → nhánh "0 khớp" (không còn là banner origin-aware).
  await page.select("#lib-state", "review")
  await page.waitForFunction(
    () =>
      [...document.querySelectorAll("p.muted")].some((el) =>
        (el.textContent ?? "").includes("Không có từ nào khớp bộ lọc"),
      ) &&
      ![...document.querySelectorAll(".banner-warn")].some((el) =>
        (el.textContent ?? "").includes("Chưa có từ nào ở địa chỉ này"),
      ),
    { timeout: 10000 },
  )

  // 5) Về Home.
  await clickByText(page, "button", "Về trang chủ")
  await page.waitForSelector(".home", { timeout: 10000 })

  if (consoleErrors.length > 0) {
    throw new Error(`console errors:\n${consoleErrors.join("\n")}`)
  }

  console.log("e2e/library-flow: PASS")
  console.log("  - route + 3 bộ lọc render")
  console.log("  - empty-state origin-aware khi kho trống")
  console.log("  - nhánh '0 khớp' sau khi lọc trạng thái review")
  console.log("  - collection mặc định có trong select")
  console.log("  - về Home, 0 lỗi console")
} finally {
  await browser.close()
}
