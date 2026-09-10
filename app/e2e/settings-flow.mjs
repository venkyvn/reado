/**
 * e2e/settings-flow.mjs — smoke test màn Cài đặt FR-15 (task 3.6) trên Chrome thật.
 *
 * Phép thử bám đúng những gì integration test KHÔNG chứng minh được: form thật,
 * lưu qua UI, và dữ liệu sống qua F5 (local-first).
 *
 *   1. Mặc định seed: CEFR B1 · hạn mức 10 · base URL Gemini · "chưa có key".
 *   2. Nhóm R1 KHOÁ chỉ hiện dạng chữ (request_retention 0.9 …) — không có input.
 *   3. Sửa CEFR + hạn mức + base URL + model + key → Lưu → báo đã lưu.
 *   4. Điều cấm #9: key KHÔNG BAO GIỜ nằm trong DOM (ô key rỗng sau khi lưu,
 *      chuỗi key không xuất hiện trong body) — kể cả sau F5.
 *   5. F5 → mở lại Cài đặt → giá trị đã lưu còn nguyên (local-first).
 *   6. Giá trị sai (hạn mức -1) bị TỪ CHỐI kèm thông điệp, DB không đổi.
 *   7. 0 lỗi console.
 *
 * Chạy: npm run e2e:settings   (cần dev server ở localhost:5173)
 */
import { rmSync } from "node:fs"
import puppeteer from "puppeteer-core"

const BASE = process.argv[2] ?? "http://localhost:5173/"
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
const PROFILE = "/tmp/reado-e2e-settings-profile"
// Profile cũ = DB cũ → giá trị cài đặt của lần chạy trước còn nguyên (C1, key...)
// Mỗi lượt chạy phải là DB mới — xoá profile ngay khi start.
rmSync(PROFILE, { recursive: true, force: true })
const SECRET = "AIza-e2e-secret-key-12345"

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

/** Điền field theo NHÃN hiển thị (label bọc input/select).
 *  Input điền bằng native value setter + event `input` — cách chính xác cho
 *  controlled component của React: click vào input type=number còn làm nhảy
 *  giá trị (spinner), và typing không đảm bảo thay hết text cũ. */
async function fillByLabel(page, labelText, value) {
  const handle = await page.evaluateHandle((text) => {
    const label = [...document.querySelectorAll("label")].find((l) =>
      (l.textContent ?? "").includes(text),
    )
    return label ? label.querySelector("input, select") : null
  }, labelText)
  const el = handle.asElement()
  if (!el) throw new Error(`không thấy field có nhãn "${labelText}"`)
  const tag = await el.evaluate((n) => n.tagName)
  if (tag === "SELECT") {
    await el.select(value)
    return
  }
  await page.evaluate(
    (text, val) => {
      const label = [...document.querySelectorAll("label")].find((l) =>
        (l.textContent ?? "").includes(text),
      )
      const field = label?.querySelector("input")
      if (!field) throw new Error(`không thấy input "${text}"`)
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set
      setter.call(field, val)
      field.dispatchEvent(new Event("input", { bubbles: true }))
    },
    labelText,
    value,
  )
}

async function readByLabel(page, labelText) {
  return page.evaluate((text) => {
    const label = [...document.querySelectorAll("label")].find((l) =>
      (l.textContent ?? "").includes(text),
    )
    const field = label?.querySelector("input, select")
    return field ? field.value : null
  }, labelText)
}

async function openSettings(page) {
  await page.evaluate(() => {
    const link = [...document.querySelectorAll("a")].find((a) =>
      (a.textContent ?? "").includes("Cài đặt"),
    )
    if (!link) throw new Error("không thấy link Cài đặt trên Trang chủ")
    link.click()
  })
  await page.waitForSelector(".settings", { timeout: 10000 })
  await page.waitForSelector(".settings table.kv", { timeout: 10000 })
}

async function readLockedRow(page, labelStart) {
  return page.evaluate((start) => {
    const row = [...document.querySelectorAll(".settings .kv tr")].find((tr) =>
      (tr.querySelector(".kv-k")?.textContent ?? "").startsWith(start),
    )
    return row ? (row.querySelector(".kv-v")?.textContent ?? "").trim() : null
  }, labelStart)
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

  // 1) Mở Cài đặt — mặc định seed.
  await openSettings(page)
  const defaults = {
    cefr: await readByLabel(page, "Trình độ CEFR"),
    limit: await readByLabel(page, "Hạn mức thẻ mới"),
    baseUrl: await readByLabel(page, "Base URL"),
    keyInput: await readByLabel(page, "API key"),
  }
  if (defaults.cefr !== "B1") throw new Error(`CEFR mặc định phải là B1: ${defaults.cefr}`)
  if (defaults.limit !== "10") throw new Error(`hạn mức mặc định phải là 10: ${defaults.limit}`)
  if (!defaults.baseUrl.includes("generativelanguage.googleapis.com")) {
    throw new Error(`base URL mặc định sai: ${defaults.baseUrl}`)
  }
  if (defaults.keyInput !== "") throw new Error("ô key phải RỖNG khi chưa có key")
  const keyStatus0 = await page.evaluate(
    () => document.querySelector(".settings")?.textContent ?? "",
  )
  if (!keyStatus0.includes("chưa có key")) throw new Error('trạng thái key phải là "chưa có key"')

  // 2) Nhóm KHOÁ ở R1: chỉ chữ, không có ô nhập nào trong section cuối.
  const retention = await readLockedRow(page, "Tỉ lệ ghi nhớ mục tiêu")
  if (retention !== "0.9") throw new Error(`request_retention hiển thị phải là 0.9: ${retention}`)
  const lockedInputs = await page.evaluate(() => {
    const sections = [...document.querySelectorAll(".settings section.card")]
    const locked = sections.find((s) =>
      (s.querySelector("h2")?.textContent ?? "").includes("Thuật toán ôn tập"),
    )
    return locked ? locked.querySelectorAll("input, select").length : -1
  })
  if (lockedInputs !== 0)
    throw new Error(`nhóm FSRS không được có ô nhập nào (thấy ${lockedInputs})`)

  // 3) Sửa + lưu.
  await fillByLabel(page, "Trình độ CEFR", "C1")
  await fillByLabel(page, "Hạn mức thẻ mới", "3")
  await fillByLabel(page, "Base URL", "https://gw.example/gemini")
  await fillByLabel(page, "Model", "gemini-3.6-flash")
  await fillByLabel(page, "API key", SECRET)
  await page.evaluate(() => {
    const btn = [...document.querySelectorAll(".settings button")].find((b) =>
      (b.textContent ?? "").includes("Lưu cài đặt"),
    )
    if (!btn) throw new Error("không thấy nút Lưu cài đặt")
    btn.click()
  })
  await page.waitForFunction(
    () => (document.querySelector(".settings")?.textContent ?? "").includes("Đã lưu"),
    { timeout: 10000 },
  )

  // 4) Điều cấm #9 — key không nằm trong DOM sau khi lưu.
  const afterSave = await page.evaluate(() => ({
    body: document.body.innerHTML,
    keyInput: (() => {
      const label = [...document.querySelectorAll("label")].find((l) =>
        (l.textContent ?? "").includes("API key"),
      )
      return label?.querySelector("input")?.value ?? null
    })(),
    status: document.querySelector(".settings")?.textContent ?? "",
  }))
  if (afterSave.body.includes(SECRET))
    throw new Error("API key LỌT VÀO DOM sau khi lưu (điều cấm #9)")
  if (afterSave.keyInput !== "") throw new Error("ô key phải được xoá trắng sau khi lưu")
  if (!afterSave.status.includes("đã có key lưu trên máy này")) {
    throw new Error("trạng thái key phải chuyển thành đã có key")
  }

  // 5) F5 → mở lại: giá trị sống qua reload, key vẫn không lộ.
  await page.reload({ waitUntil: "networkidle0", timeout: 30000 })
  await page.waitForSelector(".home", { timeout: 15000 })
  await openSettings(page)
  const persisted = {
    cefr: await readByLabel(page, "Trình độ CEFR"),
    limit: await readByLabel(page, "Hạn mức thẻ mới"),
    baseUrl: await readByLabel(page, "Base URL"),
    model: await readByLabel(page, "Model"),
    keyInput: await readByLabel(page, "API key"),
    body: await page.evaluate(() => document.body.innerHTML),
    status: await page.evaluate(() => document.querySelector(".settings")?.textContent ?? ""),
  }
  if (persisted.cefr !== "C1") throw new Error(`CEFR không sống qua F5: ${persisted.cefr}`)
  if (persisted.limit !== "3") throw new Error(`hạn mức không sống qua F5: ${persisted.limit}`)
  if (persisted.baseUrl !== "https://gw.example/gemini") {
    throw new Error(`base URL không sống qua F5: ${persisted.baseUrl}`)
  }
  if (persisted.model !== "gemini-3.6-flash")
    throw new Error(`model không sống qua F5: ${persisted.model}`)
  if (persisted.keyInput !== "")
    throw new Error("ô key phải RỖNG sau reload (không đổ key vào DOM)")
  if (persisted.body.includes(SECRET))
    throw new Error("API key lọt vào DOM sau reload (điều cấm #9)")
  if (!persisted.status.includes("đã có key lưu trên máy này")) {
    throw new Error("trạng thái đã có key không sống qua F5")
  }

  // 6) Giá trị sai bị từ chối + không ghi gì.
  await fillByLabel(page, "Hạn mức thẻ mới", "-1")
  await page.evaluate(() => {
    const btn = [...document.querySelectorAll(".settings button")].find((b) =>
      (b.textContent ?? "").includes("Lưu cài đặt"),
    )
    btn?.click()
  })
  await page.waitForSelector(".settings .errorbox", { timeout: 10000 })
  const errText = await page.evaluate(
    () => document.querySelector(".settings .errorbox")?.textContent ?? "",
  )
  if (!errText.includes("0 đến 999")) throw new Error(`thông điệp lỗi hạn mức sai: ${errText}`)
  await page.reload({ waitUntil: "networkidle0", timeout: 30000 })
  await page.waitForSelector(".home", { timeout: 15000 })
  await openSettings(page)
  const limitAfterReject = await readByLabel(page, "Hạn mức thẻ mới")
  if (limitAfterReject !== "3") throw new Error(`giá trị sai bị GHI vào DB: ${limitAfterReject}`)

  if (consoleErrors.length > 0) throw new Error(`console errors:\n${consoleErrors.join("\n")}`)

  console.log("e2e/settings-flow: PASS")
  console.log("  - mặc định seed: CEFR B1 · hạn mức 10 · base URL Gemini · chưa có key")
  console.log("  - nhóm FSRS R1 khoá: hiện chữ 0.9, 0 ô nhập")
  console.log("  - sửa + Lưu: C1 · 3 · gateway · model · key → báo đã lưu")
  console.log("  - điều cấm #9: key không nằm trong DOM (sau lưu và sau F5)")
  console.log("  - F5: C1 · 3 · base URL · model · trạng thái key sống nguyên")
  console.log("  - hạn mức -1 bị từ chối, DB vẫn 3")
  console.log("  - 0 lỗi console")
} finally {
  await browser.close()
}
