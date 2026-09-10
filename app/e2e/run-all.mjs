/**
 * e2e/run-all.mjs — unified e2e runner: chạy tất cả e2e scripts theo thứ tự.
 *
 * Chạy: npm run e2e:all
 * Arg:  node e2e/run-all.mjs [url]
 */
import { execSync } from "node:child_process"
import { resolve } from "node:path"
import { readdirSync } from "node:fs"

const URL = process.argv[2] ?? "http://localhost:5173/"
const dir = resolve(import.meta.dirname)

// Lấy tất cả .mjs trừ run-all.mjs và seed.mjs
const scripts = readdirSync(dir)
  .filter((f) => f.endsWith(".mjs") && f !== "run-all.mjs" && f !== "seed.mjs")
  .sort()

let passed = 0
let failed = 0
const failures = []

for (const script of scripts) {
  const name = script.replace(".mjs", "")
  process.stdout.write(`\n▶ ${name}... `)
  try {
    execSync(`node ${resolve(dir, script)} ${URL}`, {
      stdio: "pipe",
      timeout: 60_000,
      cwd: dir,
    })
    process.stdout.write("✅\n")
    passed++
  } catch (err) {
    process.stdout.write("❌\n")
    const stderr = err.stderr?.toString() ?? err.message
    console.error(`  Lỗi: ${stderr.slice(0, 500)}`)
    failures.push({ name, error: stderr.slice(0, 200) })
    failed++
  }
}

console.log(`\n${"=".repeat(50)}`)
console.log(`Kết quả: ${passed} pass, ${failed} fail / ${scripts.length} tổng`)
if (failures.length > 0) {
  console.log("\nChi tiết lỗi:")
  for (const f of failures) {
    console.log(`  ❌ ${f.name}: ${f.error}`)
  }
  process.exit(1)
}
