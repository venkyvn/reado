/**
 * e2e/review-swipe.mjs — chuẩn vuốt mặt trước thẻ ôn tập (chủ chốt 2026-09-09)
 * trên Chrome thật, kéo bằng chuột CDP:
 *
 *   seed (cùng origin, worker dọn xong trước khi app boot) → mở app → Ôn tập
 *   → thấy hint vuốt → vuốt TRÁI chấm Easy ⇒ sang thẻ kế + nút Undo nổi xuất
 *   hiện → bấm Undo ⇒ thẻ cũ quay lại đúng + pill biến mất → vuốt PHẢI chấm
 *   Good ⇒ sang thẻ kế → chạm lật mặt sau (thấy 4 nút) → bấm Dễ ⇒ phiên 2/2
 *   đóng → 0 lỗi console.
 *
 * Giới hạn thừa nhận: kéo bằng chuột (không phải ngón tay thật); luật ngưỡng/
 * trục đã do ui/swipe.test.ts giữ. Profile riêng /tmp → DB mới mỗi lần chạy.
 *
 * Chạy: npm run e2e:swipe   (cần dev server ở localhost:5173)
 */
import { rmSync } from "node:fs"
import puppeteer from "puppeteer-core"

const BASE = process.argv[2] ?? "http://localhost:5173/"
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
const PROFILE = "/tmp/reado-e2e-swipe-profile"
// Profile cũ = DB cũ → seed lần 2 thêm thẻ trùng (như cram-flow). Xoá ngay khi start.
rmSync(PROFILE, { recursive: true, force: true })

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

/** Kéo thẻ ngang dx px bằng CDP (sinh pointer events kiểu chuột). */
async function dragCard(page, dx) {
  const handle = await page.$(".review-card")
  if (!handle) throw new Error("không thấy .review-card để kéo")
  const box = await handle.boundingBox()
  if (!box) throw new Error("thẻ đang ẩn — không đo được bounding box")
  const x = box.x + box.width / 2
  const y = box.y + box.height / 2
  const steps = 18
  const step = dx / steps
  await page.mouse.move(x, y)
  await page.mouse.down()
  for (let i = 1; i <= steps; i++) {
    await page.mouse.move(x + step * i, y)
  }
  await page.mouse.up()
}

try {
  const page = await browser.newPage()
  await page.setViewport({ width: 430, height: 900 })
  // Chặn favicon.ico (Chrome tự dò → 404/ERR_FAILED noise hỏng check console);
  // respond 200 rỗng thay vì abort vì abort cũng sinh lỗi console.
  await page.setRequestInterception(true)
  page.on("request", (req) => {
    if (req.url().endsWith("/favicon.ico")) {
      void req.respond({ status: 200, contentType: "image/x-icon", body: "" })
      return
    }
    void req.continue()
  })
  const consoleErrors = []
  page.on("console", (m) => {
    if (m.type() === "error") consoleErrors.push(m.text().slice(0, 200))
  })
  page.on("pageerror", (e) => consoleErrors.push(`pageerror: ${e.message.slice(0, 200)}`))

  // 1) Seed 2 thẻ vào OPFS của origin test (worker seed đã terminate xong trước
  //    khi app boot → không bao giờ 2 connection cùng file).
  await page.goto(`${BASE}e2e/seed.html`, { waitUntil: "load", timeout: 30000 })
  await page.waitForFunction(
    () => {
      const t = document.querySelector("#status")?.textContent ?? ""
      return t.startsWith("SEEDED") || t.startsWith("FAIL")
    },
    { timeout: 30000 },
  )
  const seedText = await page.$eval("#status", (el) => el.textContent ?? "")
  console.log("seed:", seedText)
  if (!seedText.startsWith("SEEDED")) {
    throw new Error(`seed thất bại: ${seedText}`)
  }

  // 2) Mở app → Ôn tập.
  await page.goto(BASE, { waitUntil: "networkidle0", timeout: 30000 })
  await page.waitForSelector(".home", { timeout: 20000 })
  await clickByText(page, "button", "Ôn tập")
  await page.waitForSelector(".review-card", { timeout: 20000 })

  const termOf = () => page.$eval(".review-term", (el) => (el.textContent ?? "").trim())

  // Hint vuốt hiện trên mặt trước.
  await page.waitForFunction(
    () => document.querySelector(".review-flip-hint")?.textContent?.includes("vuốt") === true,
    { timeout: 5000 },
  )

  const firstTerm = await termOf()
  console.log("thẻ 1:", firstTerm)

  // 3) Vuốt TRÁI → chấm Easy → sang thẻ kế + nút Undo NỔI xuất hiện.
  await dragCard(page, -150)
  await page.waitForFunction(
    (first) => {
      const t = document.querySelector(".review-term")
      return t !== null && (t.textContent ?? "").trim() !== first
    },
    { timeout: 8000 },
    firstTerm,
  )
  const secondTerm = await termOf()
  console.log("thẻ 2 sau vuốt trái (Easy):", secondTerm)
  if (secondTerm === firstTerm) throw new Error(`thẻ không đổi sau vuốt trái — vẫn "${firstTerm}"`)
  await page.waitForSelector(".undo-pill", { timeout: 5000 })

  // 4) Undo → thẻ 1 quay lại ĐÚNG + pill biến mất.
  await page.click(".undo-pill")
  await page.waitForFunction(
    (first) => {
      const t = document.querySelector(".review-term")
      return t !== null && (t.textContent ?? "").trim() === first
    },
    { timeout: 8000 },
    firstTerm,
  )
  await page.waitForFunction(() => document.querySelector(".undo-pill") === null, { timeout: 5000 })

  // 5) Vuốt PHẢI → chấm Good → sang thẻ kế.
  await dragCard(page, 150)
  await page.waitForFunction(
    (first) => {
      const t = document.querySelector(".review-term")
      return t !== null && (t.textContent ?? "").trim() !== first
    },
    { timeout: 8000 },
    firstTerm,
  )

  // 6) Chạm (click) → lật mặt sau: 4 nút chấm FSRS.
  await page.click(".review-card")
  await page.waitForSelector(".review-card.flipped", { timeout: 10000 })
  await page.waitForFunction(() => document.querySelectorAll(".grade-btn").length === 4, {
    timeout: 5000,
  })

  // 7) Bấm Dễ → phiên đóng (đủ 2/2 thẻ).
  await page.evaluate(() => {
    const btn = [...document.querySelectorAll(".grade-btn")].find(
      (b) => (b.textContent ?? "").trim() === "Dễ",
    )
    if (!btn) throw new Error("không thấy nút Dễ")
    btn.click()
  })
  await page.waitForFunction(
    () => document.querySelector("h1")?.textContent?.includes("Xong lượt") === true,
    { timeout: 10000 },
  )

  if (consoleErrors.length > 0) {
    throw new Error(`lỗi console: ${consoleErrors.join(" | ")}`)
  }
  console.log("review-swipe PASS: vuốt trái Easy · vuốt phải Good · undo 1 bước · chạm lật · 0 lỗi")
} finally {
  await browser.close()
}
