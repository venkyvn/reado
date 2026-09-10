/**
 * scripts/analytics.mjs — thống kê dùng app tại máy (ADR-019): chạy trên dữ liệu
 * THẬT qua file xuất JSON của FR-16, không cần mở app.
 *
 * Vì sao không query thẳng SQLite: DB sống trong OPFS của trình duyệt (per-origin),
 * Node không đọc được OPFS. Đường không cần code mới ở app: màn export của Reado
 * (FR-16) cho ra file JSON đầy đủ (items + cards + review_logs + settings) — file
 * này là ảnh chụp dữ liệu thật, đủ cho mọi số đo dưới đây TRỪ latency/token AI
 * (bảng analyses không nằm trong export; xem ghi chú ở output).
 *
 * Cách dùng:
 *   1. Trong app: Kho từ vựng → Export → lưu file JSON (màn "Sao lưu dữ liệu").
 *   2. node scripts/analytics.mjs <đường-dẫn-file.json>
 *   (hoặc `npm run analytics -- <file>`)
 *
 * Output: báo cáo dạng bảng + một khối JSON thuần ở cuối (pipe được).
 */
import { readFileSync } from "node:fs"

function usage() {
  console.error(
    "Cách dùng: node scripts/analytics.mjs <đường-dẫn-reado-export.json>\n" +
      "  (Export dữ liệu trong app Reado trước — màn Xuất/Sao lưu của FR-16.)",
  )
  process.exit(1)
}

const filePath = process.argv[2]
if (!filePath) usage()

let raw
try {
  raw = readFileSync(filePath, "utf8")
} catch {
  console.error(`Không đọc được file: ${filePath}`)
  usage()
}

let data
try {
  data = JSON.parse(raw)
} catch {
  console.error(`File ${filePath} không phải JSON hợp lệ.`)
  usage()
}

const { items = [], cards = [], logs = [], settings = null, exportedAt = null, scope = null } = data
const isReado = Array.isArray(items) && Array.isArray(cards) && Array.isArray(logs)
if (!isReado) {
  console.error(
    `File ${filePath} không đúng định dạng reado-export (cần items/cards/logs). ` +
      `Kiểm tra lại bước export trong app.`,
  )
  usage()
}

// --- Tiện ích thời gian: ngày học tính theo giờ chuyển ngày + timezone của máy chạy. ---
const cutoffHour = settings?.dayCutoffHour ?? 4
const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone

function dayLabel(iso) {
  if (!iso) return null
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return null
  const shifted = new Date(d.getTime() - cutoffHour * 3_600_000)
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(shifted)
}

function todayLabel() {
  const now = new Date()
  const shifted = new Date(now.getTime() - cutoffHour * 3_600_000)
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(shifted)
}

function* lastNDays(n) {
  const t = todayLabel()
  const [y, m, d] = t.split("-").map(Number)
  for (let i = n; i >= 1; i--) {
    const dt = new Date(Date.UTC(y, m - 1, d - i))
    yield dt.toISOString().slice(0, 10)
  }
}

// --- Các phép đo (M-01 → M-08 của PRD; xem ADR-019). ---

// M-01/M-02: tần suất ôn + hàng đợi hiện tại.
const studyDays = new Map()
for (const l of logs) {
  const label = dayLabel(l.reviewedAt)
  if (!label) continue
  studyDays.set(label, (studyDays.get(label) ?? 0) + 1)
}

let streak = 0
const cursor = new Date(new Date().toISOString().slice(0, 10))
if (!studyDays.has(todayLabel())) cursor.setUTCDate(cursor.getUTCDate() - 1)
for (let i = 0; i < 3650; i++) {
  const label = cursor.toISOString().slice(0, 10)
  if (!studyDays.has(label)) break
  streak++
  cursor.setUTCDate(cursor.getUTCDate() - 1)
}

const last7 = [...lastNDays(7)].map((d) => studyDays.get(d) ?? 0)
const nowIso = new Date().toISOString()
const dueCards = cards.filter(
  (c) => c.suspendedAt === null && c.dueAt !== null && c.dueAt <= nowIso,
)
const dueByState = new Map()
for (const c of dueCards) dueByState.set(c.state, (dueByState.get(c.state) ?? 0) + 1)

// M-04/M-05: hiệu quả ôn (phân bố chấm) + leech.
const ratings = { 1: 0, 2: 0, 3: 0, 4: 0 }
const modes = new Map()
let cramReviews = 0
for (const l of logs) {
  if (l.rating >= 1 && l.rating <= 4) ratings[l.rating]++
  if (l.mode) {
    modes.set(l.mode, (modes.get(l.mode) ?? 0) + 1)
    if (l.mode !== "srs") cramReviews++
  }
}
const leechCards = cards.filter((c) => (c.lapses ?? 0) >= 3 && c.suspendedAt === null)

// M-08: tốc độ bồi kho (growth) từ createdAt của items.
const addedByDay = new Map()
for (const it of items) {
  const label = dayLabel(it.createdAt)
  if (!label) continue
  addedByDay.set(label, (addedByDay.get(label) ?? 0) + 1)
}
const addedLast7 = [...lastNDays(7)].map((d) => addedByDay.get(d) ?? 0)

// Card theo state + direction (cái nhìn chung về kho).
const cardStates = new Map()
const byDirection = { receptive: 0, productive: 0 }
for (const c of cards) {
  cardStates.set(c.state, (cardStates.get(c.state) ?? 0) + 1)
  byDirection[c.direction] = (byDirection[c.direction] ?? 0) + 1
}

// --- Báo cáo ---
const fmt = (n) => String(n).padStart(5)
const bar = (label, value) => console.log(`${label.padEnd(34)} ${fmt(value)}`)

console.log(`\n=== Reado Analytics — ${filePath} ===`)
if (scope?.collectionName) console.log(`Xuất theo collection: ${scope.collectionName}`)
if (exportedAt) console.log(`Thời điểm export: ${exportedAt}`)
console.log(`Múi giờ tính ngày học: ${timeZone} (giờ chuyển ngày ${cutoffHour}:00)`)

console.log("\n--- Tổng kho ---")
bar("Từ vựng (vocab items)", items.length)
bar("Thẻ (cards)", cards.length)
for (const [s, n] of cardStates) bar(`  state = ${s}`, n)
bar("  receptive", byDirection.receptive)
bar("  productive", byDirection.productive)
bar("Lượt chấm từ trước tới nay", logs.length)
bar(
  "Số từ mới thêm 7 ngày qua",
  addedLast7.reduce((a, b) => a + b, 0),
)

console.log("\n--- Hàng đợi hiện tại (chưa áp hạn mức) ---")
bar("Thẻ đến hạn", dueCards.length)
for (const [s, n] of dueByState) bar(`  ${s}`, n)

console.log("\n--- Thói quen ôn (M-01/M-02) ---")
bar("Ngày có ôn (tất cả)", studyDays.size)
bar("Streak hiện tại (ngày)", streak)
bar(
  "Lượt chấm 7 ngày qua",
  last7.reduce((a, b) => a + b, 0),
)
console.log(`  Theo ngày (cũ → mới): ${last7.join(", ")}`)

console.log("\n--- Chất lượng chấm (M-04/M-05) ---")
for (const [r, n] of Object.entries(ratings)) bar(`  rating = ${r}`, n)
bar("  tổng chấm srs", logs.length - cramReviews)
bar("  tổng chấm ngoài srs (cram…)", cramReviews)
bar("Thẻ leech tiềm năng (lapses ≥ 3)", leechCards.length)

console.log("\n--- AI (M-03) ---")
console.log("  File export FR-16 KHÔNG chứa bảng analyses (latency/token AI).")
console.log("  Số đo đó nằm trong màn Kiểm tra lưu trữ của app — xem tại đó.")

const summary = {
  file: filePath,
  exportedAt,
  timeZone,
  dayCutoffHour: cutoffHour,
  totals: {
    vocabItems: items.length,
    cards: cards.length,
    cardsByState: Object.fromEntries(cardStates),
    reviews: logs.length,
  },
  queue: { dueNow: dueCards.length, dueByState: Object.fromEntries(dueByState) },
  habits: { studyDays: studyDays.size, streak, reviewsLast7: last7, perDay: last7 },
  quality: { ratings, nonSrsReviews: cramReviews, potentialLeeches: leechCards.length },
  growth: { addedLast7, perDay: addedLast7 },
}
console.log("\n--- JSON ---")
console.log(JSON.stringify(summary, null, 2))
