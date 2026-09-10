/**
 * e2e/secure-context.mjs — phép đo ba origin cho bug "iPhone không có OPFS"
 * (2026-09-08). Mỗi origin đo đúng các thứ quyết định, rồi so với kỳ vọng:
 *
 * 1. http://localhost:5173      → SECURE (đặc cách localhost), isolated, OPFS ✓
 *    — đây là lý do e2e chạy trên desktop KHÔNG bao giờ thấy bug của iPhone.
 * 2. http://192.168.1.200:5173  → KHÔNG secure, KHÔNG OPFS
 *    — tái hiện đúng ba cảnh báo mà iPhone báo (secure context là đặc quyền
 *      của localhost + https; http + IP LAN không có).
 * 3. https://192.168.1.200:5174 → SECURE + isolated + OPFS (cần `npm run cert`
 *    rồi `npm run dev:https`; cert tự ký nên Chrome chạy với
 *    --ignore-certificate-errors — trên iPhone thì người dùng bấm "tiếp tục").
 *
 * pass = cả ba origin khớp kỳ vọng. Chạy: npm run e2e:secure [lanIp]
 */
import puppeteer from "puppeteer-core"

const LAN_IP = process.argv[2] ?? "192.168.1.200"
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
const PROFILE = "/tmp/reado-sec-context-profile"

const ORIGINS = [
  {
    name: "localhost (http — desktop dev)",
    url: "http://localhost:5173/?screen=storage-check",
    expect: { secure: true, isolated: true, opfs: true },
  },
  {
    name: `LAN IP (http — đúng thứ iPhone đang mở)`,
    url: `http://${LAN_IP}:5173/?screen=storage-check`,
    expect: { secure: false, isolated: false, opfs: false },
  },
  {
    name: `LAN IP (https — phép sửa, cert dev tự ký)`,
    url: `https://${LAN_IP}:5174/?screen=storage-check`,
    expect: { secure: true, isolated: true, opfs: true },
  },
]

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
    "--ignore-certificate-errors", // cert dev tự ký — dev-only, KHÔNG dùng ở chế độ người dùng thật
    `--user-data-dir=${PROFILE}`,
    `--crash-dumps-dir=${PROFILE}`,
  ],
})

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms))
}

const results = []
try {
  const page = await browser.newPage()
  await page.setViewport({ width: 430, height: 900 })

  for (const origin of ORIGINS) {
    let navError = null
    try {
      await page.goto(origin.url, { waitUntil: "domcontentloaded", timeout: 30000 })
    } catch (e) {
      navError = e instanceof Error ? e.message.slice(0, 150) : String(e)
    }
    // storage-check tự render khi app boot xong; chờ bảng .kv xuất hiện.
    if (!navError) {
      try {
        await page.waitForSelector(".kv", { timeout: 30000 })
      } catch {
        /* để evaluate bên dưới báo thiếu */
      }
    }
    await sleep(400) // cho effect đếm số liệu kho chạy xong

    const m = await page.evaluate(() => {
      const rows = {}
      for (const tr of document.querySelectorAll(".kv tr")) {
        const k = tr.querySelector(".kv-k")?.textContent?.trim()
        const v = tr.querySelector(".kv-v")?.textContent?.trim()
        if (k) rows[k] = v ?? ""
      }
      return {
        url: location.href,
        isSecureContext,
        crossOriginIsolated,
        hasSharedArrayBuffer: typeof SharedArrayBuffer === "function",
        opfsApiPresent: typeof navigator.storage?.getDirectory === "function",
        rows,
        errorBanner: document.querySelector(".banner-error")?.textContent?.slice(0, 120) ?? null,
        warnBanner: Boolean(document.querySelector(".banner-warn")),
      }
    })

    const actual = {
      secure: Boolean(m.isSecureContext),
      isolated: Boolean(m.crossOriginIsolated),
      opfs: String(m.rows["OPFS active"] ?? "").startsWith("Có"),
    }
    const pass = JSON.stringify(actual) === JSON.stringify(origin.expect)
    results.push({
      name: origin.name,
      url: m.url,
      navError,
      expect: origin.expect,
      actual,
      opfsApiPresent: m.opfsApiPresent,
      secureRow: m.rows["Secure context"],
      errorBanner: m.errorBanner,
      warnBanner: m.warnBanner,
      pass,
    })

    // Chờ DB worker đóng/giải phóng giữa hai origin (tránh nhiễu profile).
    await sleep(600)
  }

  // Mắt xích cuối trên origin https: RELOAD và assert "Sống qua F5" xanh — đúng
  // phép thử owner làm trên iPhone (F5 xong từ phải còn). Không có bước này thì
  // "OPFS active" mới chỉ là lời hứa, chưa là bằng chứng persist qua reload.
  const persistUrl = ORIGINS[2].url
  await page.goto(persistUrl, { waitUntil: "domcontentloaded", timeout: 30000 })
  try {
    await page.waitForSelector(".kv", { timeout: 30000 })
  } catch {
    /* evaluate bên dưới sẽ thấy thiếu */
  }
  await sleep(400)
  const f5 = await page.evaluate(() => {
    for (const tr of document.querySelectorAll(".kv tr")) {
      const k = tr.querySelector(".kv-k")?.textContent?.trim()
      if (k === "Sống qua F5") return tr.querySelector(".kv-v")?.textContent?.trim() ?? ""
    }
    return ""
  })
  const persistOk = f5.startsWith("Có")
  results.push({
    name: "LAN IP (https) — reload lần 2: Sống qua F5",
    url: persistUrl,
    expect: { "Sống qua F5": "Có — ..." },
    actual: { "Sống qua F5": f5 },
    pass: persistOk,
  })

  const allPass = results.every((r) => r.pass)
  console.log(JSON.stringify(results, null, 2))
  console.log(
    allPass
      ? "✅ cả ba origin khớp kỳ vọng — chẩn đoán (http+IP không secure) và phép sửa (https) đều đã đo được"
      : "❌ có origin lệch kỳ vọng — xem bảng ở trên",
  )
  process.exitCode = allPass ? 0 : 1
} finally {
  await browser.close()
}
