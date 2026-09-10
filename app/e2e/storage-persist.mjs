/**
 * e2e/storage-persist.mjs — kiểm chứng OPFS persistence TRÊN CHROME THẬT ở dev
 * server (bằng chứng cho SPIKE storage / task 1.3, và để phân biệt hai giả thuyết
 * khi owner báo "F5 xong mất dữ liệu"):
 *
 *   (a) app rơi về chế độ memory (OPFS fail) -> mất data thật
 *   (b) OPFS chạy, data còn, chỉ là R1 chưa có màn xem lại kho từ
 *
 * Cách đo: đọc màn ?screen=storage-check (app tự báo storageMode + warning),
 * rồi tự ghi một file probe vào OPFS, RELOAD trang, đọc lại probe. Nếu probe
 * sống qua reload mà app báo "OPFS active = Có" => persistence thật.
 *
 * Chạy: npm run e2e:storage   (cần dev server ở localhost:5173)
 */
import puppeteer from "puppeteer-core"

const BASE = process.argv[2] ?? "http://localhost:5173/"
const CHECK_URL = `${BASE}?screen=storage-check`
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
const PROFILE = "/tmp/reado-e2e-profile"
// Tên file probe phải hardcode bên trong các hàm evaluate (page.evaluate serialize
// hàm, không thấy const ở scope Node).

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

/** Đọc bảng kv + banner + console error của trang storage-check. */
async function scrape(page) {
  return page.evaluate(() => {
    const rows = {}
    for (const tr of document.querySelectorAll(".kv tr")) {
      const k = tr.querySelector(".kv-k")?.textContent?.trim()
      const v = tr.querySelector(".kv-v")?.textContent?.trim()
      if (k) rows[k] = v ?? ""
    }
    return {
      rows,
      banners: [...document.querySelectorAll(".banner")].map((b) => b.textContent.trim()),
      mentionsMemoryFallback: document.body.innerText.includes("bộ nhớ tạm"),
    }
  })
}

const writeProbe = (token) =>
  navigator.storage.getDirectory().then(async (root) => {
    const fh = await root.getFileHandle("reado-e2e-probe.txt", { create: true })
    const w = await fh.createWritable()
    await w.write(token)
    await w.close()
    return true
  })

const readProbe = () =>
  navigator.storage.getDirectory().then(async (root) => {
    try {
      const fh = await root.getFileHandle("reado-e2e-probe.txt")
      return await (await fh.getFile()).text()
    } catch {
      return null
    }
  })

const removeProbe = () =>
  navigator.storage
    .getDirectory()
    .then((root) => root.removeEntry("reado-e2e-probe.txt"))
    .catch(() => false)

try {
  const page = await browser.newPage()
  await page.setViewport({ width: 430, height: 900 })
  const consoleErrors = []
  const consoleAll = []
  const opfsRequests = []
  page.on("console", (m) => {
    const t = m.text()
    consoleAll.push(`${m.type()}: ${t.slice(0, 160)}`)
    if (m.type() === "error") consoleErrors.push(t.slice(0, 200))
  })
  // Bắt đúng URL mà sqlite-wasm dùng để spawn worker OPFS proxy — nghi phạm chính
  // khi proxyUri là URL tương đối (không có <script src> trong app ESM/bundler).
  page.on("request", (r) => {
    const u = r.url()
    if (/opfs|proxy|sqlite3\.wasm/i.test(u)) opfsRequests.push(`REQ ${r.resourceType()} ${u}`)
  })
  page.on("response", async (res) => {
    const u = res.url()
    if (/opfs|proxy/i.test(u)) {
      const ct = res.headers()["content-type"] ?? "?"
      opfsRequests.push(`RES ${res.status()} ${ct} ${u}`)
    }
  })
  page.on("requestfailed", (r) => {
    const u = r.url()
    if (/opfs|proxy/i.test(u)) opfsRequests.push(`FAILED ${u} :: ${r.failure()?.errorText}`)
  })

  // opfs-verbose: bật log nội bộ của sqlite-wasm về OPFS (urlParams hook của lib).
  await page.goto(`${CHECK_URL}&opfs-verbose=2`, {
    waitUntil: "networkidle0",
    timeout: 30000,
  })
  await page.waitForSelector(".kv", { timeout: 15000 })
  await new Promise((r) => setTimeout(r, 600)) // chờ effect đọc DB xong

  const before = await scrape(page)
  const coi = await page.evaluate(() => globalThis.crossOriginIsolated === true)
  const opfsApi = await page.evaluate(() => typeof navigator.storage?.getDirectory === "function")

  const token = `persist-${Date.now()}`
  const wrote = await page.evaluate(writeProbe, token).catch((e) => `ERR: ${e.message}`)

  await page.reload({ waitUntil: "networkidle0", timeout: 30000 })
  await page.waitForSelector(".kv", { timeout: 15000 })
  await new Promise((r) => setTimeout(r, 600))

  const after = await scrape(page)
  const readBack = await page.evaluate(readProbe).catch((e) => `ERR: ${e.message}`)
  await page.evaluate(removeProbe)

  const probeSurvivedReload = readBack === token
  // Bằng chứng QUYẾT ĐỊNH: marker boot của chính app (bảng _boot_probe, ghi qua
  // AppDb → repo path thật). Sau reload mà đọc được marker của lần mở trước thì
  // dữ liệu app sống qua reload thật — không suy ra gián tiếp từ OPFS của trình
  // duyệt. Trước fix (DB ở main thread → :memory:) hàng này vĩnh viễn "Chưa thấy".
  const appDataSurvivedReload = after.rows["Sống qua F5"]?.startsWith("Có") === true
  const firstBootSawNoMarker = before.rows["Sống qua F5"]?.startsWith("Chưa") === true
  const appSaysOpfs = after.rows["OPFS active"]?.startsWith("Có") === true
  const verdict =
    appSaysOpfs && appDataSurvivedReload && probeSurvivedReload
      ? "PERSIST-OK"
      : appSaysOpfs
        ? "OPFS-NHUNG-DATA-KHONG-QUA-RELOAD"
        : "MEMORY-FALLBACK"

  console.log(
    JSON.stringify(
      {
        crossOriginIsolated: coi,
        opfsApiAvailable: opfsApi,
        probe: { wrote, token, readBack, probeSurvivedReload },
        appMarker: { appDataSurvivedReload, firstBootSawNoMarker },
        storageCheckBeforeReload: before.rows,
        storageCheckAfterReload: after.rows,
        banners: after.banners,
        mentionsMemoryFallback: after.mentionsMemoryFallback,
        opfsRequests: opfsRequests.slice(0, 12),
        consoleErrors: consoleErrors.slice(0, 5),
        consoleAll: consoleAll.slice(0, 20),
        verdict,
      },
      null,
      2,
    ),
  )
  process.exitCode = verdict === "PERSIST-OK" ? 0 : 1
} finally {
  await browser.close()
}
