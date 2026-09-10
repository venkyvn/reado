/**
 * app/bootstrap.ts — lắp ráp dependencies thật theo dependency rule
 * (solution-design mục 3.1): storage thật + scheduler thật + Gemini thật → AppServices.
 *
 * Kết quả là thứ DUY NHẤT UI được cầm; UI không bao giờ import storage/ai trực tiếp.
 *
 * Storage do `openStorage()` quyết: browser → Web Worker + OPFS (persist thật);
 * Node/test hoặc worker hỏng → in-process :memory: kèm cảnh báo (không giả vờ persist).
 */
import { createGeminiProvider } from "../ai/gemini"
import { createScheduler } from "../domain/scheduler"
import type { AppServices } from "../domain/services"
import { readBootProbe, writeBootProbe } from "../storage/bootProbe"
import { toUtcIso } from "../domain/utils"
import { openStorage } from "../storage/openStorage"
import { createRepos } from "../storage/repos"

export interface BootstrapResult {
  services: AppServices
  /** Cảnh báo vận hành (VFS/OPFS/WAL) — app phải HIỂN THỊ, không nuốt. */
  storageWarnings: string[]
  /** "opfs" = lưu thật; "memory" = mất khi đóng — app phải cảnh báo rõ. */
  storageMode: "opfs" | "memory"
  /** Marker của lần mở TRƯỚC — null nghĩa là dữ liệu chưa từng sống qua reload. */
  previousBootAt: string | null
}

/**
 * MỘT page load = MỘT bootstrap. App.tsx gọi hàm này trong `useEffect` dưới
 * StrictMode, mà StrictMode (dev) mount→unmount→mount nên effect chạy HAI lần; cờ
 * `cancelled` bên đó chỉ bỏ KẾT QUẢ của lần đầu chứ không ngăn lần đầu chạy thật.
 * Nếu để bootstrap chạy đôi thì: mở hai Worker + hai connection OPFS vào cùng một
 * file (connection bị bỏ không ai terminate → leak), migrate/seed chạy hai lần, và
 * marker boot bị lần chạy đầu ghi TRƯỚC khi lần thứ hai đọc — làm phép thử "sống
 * qua F5" xanh giả ngay cả khi DB là :memory:. Nên khoá ở đây, bằng singleton.
 */
let bootPromise: Promise<BootstrapResult> | null = null

export function bootstrap(): Promise<BootstrapResult> {
  bootPromise ??= runBootstrap().catch((e: unknown) => {
    // Boot hỏng thì KHÔNG cache lỗi — cho phép lần mount sau thử lại.
    bootPromise = null
    throw e
  })
  return bootPromise
}

async function runBootstrap(): Promise<BootstrapResult> {
  const storage = await openStorage()
  const repos = createRepos(storage.appDb)
  const settings = await repos.settings.get()

  // Đọc marker cũ TRƯỚC khi ghi marker mới — thứ tự này là cả ý nghĩa của phép thử.
  const previousBootAt = await readBootProbe(storage.appDb)
  await writeBootProbe(storage.appDb, toUtcIso(new Date()))

  const services: AppServices = {
    repos,
    scheduler: createScheduler({
      requestRetention: settings.requestRetention,
      maximumInterval: settings.maximumInterval,
      enableFuzz: settings.enableFuzz,
    }),
    ai: createGeminiProvider(),
    now: () => new Date(),
    timeZone: () => Intl.DateTimeFormat().resolvedOptions().timeZone,
  }

  return {
    services,
    storageWarnings: storage.warnings,
    storageMode: storage.mode,
    previousBootAt,
  }
}
