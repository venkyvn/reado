/**
 * e2e/export-flow.mjs — smoke test màn Xuất dữ liệu (FR-16, task 3.7) trên Chrome
 * thật: route chạy, query collections chạy, use-case + giao file chạy, UI hiện kết
 * quả, và NỘI DUNG file thật (đọc từ textarea fallback) đúng header Anki.
 *
 * Giới hạn phải nói thẳng: profile e2e là DB MỚI nên kho rỗng — phép thử này
 * chứng minh wiring end-to-end trong browser, KHÔNG chứng minh nội dung export khi
 * có dữ liệu thật (phần đó do 7 test trong `export.integration.test.ts` chạy trên
 * SQLite thật đảm nhiệm). Muốn xem export có data: mở app đã dùng thật.
 *
 * Chạy: npm run e2e:export   (cần dev server ở localhost:5173)
 */
import fs from "node:fs"
import path from "node:path"
import puppeteer from "puppeteer-core"

const BASE = process.argv[2] ?? "http://localhost:5173/"
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
const PROFILE = "/tmp/reado-e2e-export-profile"
const DOWNLOADS = "/tmp/reado-e2e-downloads"
// Mỗi lần chạy phải sạch, kẻo file của lần trước giả làm bằng chứng của lần này.
fs.rmSync(DOWNLOADS, { recursive: true, force: true })
fs.mkdirSync(DOWNLOADS, { recursive: true })

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

/** Bấm phần tử chứa đúng chuỗi text (app không có data-testid). */
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

  // Tải xuống headless: cho phép và trỏ vào thư mục tạm để không treo/không prompt.
  await page._client().send("Page.setDownloadBehavior", {
    behavior: "allow",
    downloadPath: DOWNLOADS,
  })

  await page.goto(BASE, { waitUntil: "networkidle0", timeout: 30000 })
  await page.waitForSelector(".home", { timeout: 15000 })

  // 1) Từ Home vào màn export bằng link (NFR-08 không bị ảnh hưởng: capture vẫn 1 chạm).
  await clickByText(page, "a", "Xuất dữ liệu")
  await page.waitForFunction(
    () => document.querySelector("h1")?.textContent?.includes("Xuất dữ liệu") === true,
    { timeout: 10000 },
  )

  const hasScopeSelect = await page.evaluate(() => {
    const sel = document.querySelector("#export-scope")
    return Boolean(sel) && (sel.textContent ?? "").includes("Toàn bộ kho")
  })

  // 2) Bấm xuất TSV.
  await clickByText(page, "button", "TSV cho Anki")
  await page.waitForSelector(".kv", { timeout: 15000 })

  const result = await page.evaluate(() => {
    const rows = {}
    for (const tr of document.querySelectorAll(".kv tr")) {
      const k = tr.querySelector(".kv-k")?.textContent?.trim()
      const v = tr.querySelector(".kv-v")?.textContent?.trim()
      if (k) rows[k] = v ?? ""
    }
    const details = document.querySelector("details")
    if (details) details.open = true
    const ta = document.querySelector("textarea.dump")
    return {
      rows,
      banner: document.querySelector(".banner")?.textContent?.trim() ?? "",
      filename: rows["File"] ?? "",
      contentHead: ta ? ta.value.slice(0, 200) : null,
      hasErrorBanner: Boolean(document.querySelector(".banner-error")),
    }
  })

  const contentOk =
    typeof result.contentHead === "string" &&
    result.contentHead.startsWith("#separator:tab") &&
    result.contentHead.includes("#html:false")
  const filenameOk = /^reado-\d{8}-.*\.tsv$/.test(result.filename)
  const countsOk =
    result.rows["Từ vựng"] !== undefined && !Number.isNaN(Number(result.rows["Từ vựng"]))

  // Bằng chứng mạnh nhất: file THẬT nằm trên đĩa (Chrome headless tải vào downloadPath).
  // Không có file này thì "download" chỉ là lời hứa của trình duyệt.
  const dl = fs.existsSync(DOWNLOADS)
    ? fs
        .readdirSync(DOWNLOADS)
        .filter((f) => f.endsWith(".tsv"))
        .sort()
    : []
  const landed =
    dl.length > 0 ? fs.readFileSync(path.join(DOWNLOADS, dl[dl.length - 1]), "utf8") : null
  const fileLandedOk = typeof landed === "string" && landed.startsWith("#separator:tab")

  const pass =
    hasScopeSelect &&
    !result.hasErrorBanner &&
    contentOk &&
    filenameOk &&
    countsOk &&
    fileLandedOk &&
    consoleErrors.length === 0

  console.log(
    JSON.stringify(
      {
        hasScopeSelect,
        banner: result.banner,
        rows: result.rows,
        filename: result.filename,
        filenameOk,
        contentHead: result.contentHead,
        contentOk,
        countsOk,
        downloadsOnDisk: dl,
        fileLandedOk,
        landedHead: typeof landed === "string" ? landed.slice(0, 120) : null,
        consoleErrors: consoleErrors.slice(0, 5),
        pass,
      },
      null,
      2,
    ),
  )
  console.log(pass ? "✅ màn export chạy end-to-end trong browser" : "❌ màn export có vấn đề")
  process.exitCode = pass ? 0 : 1
} finally {
  await browser.close()
}
