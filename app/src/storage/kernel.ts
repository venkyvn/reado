/**
 * storage/kernel.ts — mở SQLite-WASM, chọn VFS.
 *
 * Chạy ở ĐÂU thì OPFS mới sống (đo thật bằng `npm run e2e:opfs` trên Chrome 152):
 * - **Web Worker**: VFS "opfs" cài được (lib đòi `WorkerGlobalScope` vì nó dùng
 *   `Atomics.wait()`), VFS "opfs-sahpool" cũng được (cần `createSyncAccessHandle`,
 *   chỉ Worker mới có). → persist thật, đây là đường browser dùng (dbWorker.ts).
 * - **Main thread**: cả hai VFS đều bị từ chối → chỉ còn `:memory:` → mất khi F5.
 *   App vì thế PHẢI mở DB trong Worker; mở ở main thread là bug (đã từng xảy ra).
 * - **Node/vitest**: không có OPFS → `:memory:`, đúng ý cho test.
 *
 * VFS "opfs" cần SharedArrayBuffer ⇒ cần COOP/COEP (vite.config.ts đã bật cho
 * dev/preview; production phải cấu hình phía host). VFS "opfs-sahpool" KHÔNG cần
 * SAB/COOP-COEP nên được giữ làm nhánh dự phòng — đổi lại nó không hỗ trợ WAL và
 * file DB nằm dạng opaque trong pool (applyPragmas sẽ báo journal_mode thật).
 *
 * Điều kiện TIÊN QUYẾT của cả hai nhánh OPFS: **secure context** (OPFS chỉ tồn
 * tại trong secure context; crossOriginIsolated cũng đòi secure context). Trang
 * mở qua http:// + IP LAN KHÔNG secure — chỉ localhost/127.0.0.1 và https://
 * được trình duyệt đặc cách. Đo thật 2026-09-08: iPhone mở http://192.168.1.200
 * → dính đủ ba cảnh báo fallback; mở https (cert dev tự ký, `npm run cert` +
 * `npm run dev:https`) → OPFS chạy bình thường. Vì thế có "nhánh 0" bên dưới:
 * chặn sớm thay vì để ba nhánh thử mò rồi rải cảnh báo loạn xạ.
 */
import sqlite3InitModule from "@sqlite.org/sqlite-wasm"
import wasmUrl from "@sqlite.org/sqlite-wasm/sqlite3.wasm?url"
import type { Database, Sqlite3Static } from "@sqlite.org/sqlite-wasm"

export type StorageMode = "opfs" | "memory"

export interface Kernel {
  sqlite3: Sqlite3Static
  db: Database
  mode: StorageMode
  warnings: string[]
}

/** Một tên file duy nhất cho mọi nhánh OPFS — đổi tên là orphan data cũ. */
const DB_FILE = "reado.db"

// Type của package chỉ khai `init()` không tham số; runtime thật nhận Emscripten
// Module config (locateFile) — kiểm trong index.mjs của sqlite-wasm 3.53.
const typedInit = sqlite3InitModule as unknown as (cfg?: {
  locateFile?: (file: string) => string
}) => Promise<Sqlite3Static>

async function initModule(): Promise<Sqlite3Static> {
  // Browser: Emscripten tự đoán đường dẫn sqlite3.wasm từ import.meta.url — sau
  // khi Vite bundle thì chỗ đó SAI, nên locateFile trỏ thẳng asset Vite emit
  // (`?url`). Node (vitest): `?url` trả request-path dạng "/node_modules/..." —
  // không phải fs path, mà readAsync của node build mở thẳng bằng fs — nên ghép
  // cwd vào cho trúng. (đã probe thực tế: src/testing/probe đã chạy 1 lần)
  return typedInit({ locateFile: () => locateWasmFile() })
}

/** Suy ra vị trí file sqlite3.wasm cho đúng môi trường đang chạy. */
function locateWasmFile(): string {
  const g = globalThis as {
    process?: { versions?: { node?: string }; cwd?: () => string }
  }
  if (typeof g.process?.versions?.node === "string" && typeof g.process.cwd === "function") {
    return g.process.cwd() + (wasmUrl.startsWith("/") ? wasmUrl : `/${wasmUrl}`)
  }
  return wasmUrl
}

/** Đang ở Worker scope? (sqlite-wasm dùng đúng tiêu chí này để cho phép VFS "opfs".) */
function inWorkerScope(): boolean {
  return typeof (globalThis as { WorkerGlobalScope?: unknown }).WorkerGlobalScope !== "undefined"
}

function message(e: unknown): string {
  return e instanceof Error ? e.message : String(e)
}

export async function openMemoryKernel(): Promise<Kernel> {
  const sqlite3 = await initModule()
  return { sqlite3, db: new sqlite3.oo1.DB(":memory:"), mode: "memory", warnings: [] }
}

export async function openKernel(): Promise<Kernel> {
  const sqlite3 = await initModule()
  const warnings: string[] = []
  const worker = inWorkerScope()

  // Nhánh 0 — secure context là tiên quyết của OPFS lẫn crossOriginIsolated.
  // `=== false` (không phải truthy check) vì ở Node/`vitest` giá trị là undefined
  // — test không phải browser thì không đi nhánh này mà rơi xuống đường memory
  // quen thuộc của mấy nhánh dưới.
  const secureFlag = (globalThis as { isSecureContext?: boolean }).isSecureContext
  if (secureFlag === false) {
    warnings.push(
      "Trang không phải SECURE CONTEXT (đang mở qua http:// + IP LAN — trình duyệt chỉ đặc cách localhost và https://). OPFS và Service Worker bị chặn HOÀN TOÀN nên mọi VFS bền đều vô nghĩa; đang chạy bộ nhớ tạm và dữ liệu SẼ MẤT khi đóng tab/F5. Hãy mở app bằng https:// (dev: `npm run cert` + `npm run dev:https`).",
    )
    return { sqlite3, db: new sqlite3.oo1.DB(":memory:"), mode: "memory", warnings }
  }

  const hasIsolated =
    typeof globalThis.crossOriginIsolated === "boolean" && globalThis.crossOriginIsolated

  // Nhánh 1 — VFS "opfs": VFS chính theo docs sqlite.org/wasm (dùng async proxy
  // worker, cần SAB ⇒ cần COOP/COEP). `OpfsDb` chỉ tồn tại khi VFS cài thành công.
  if (sqlite3.oo1.OpfsDb) {
    try {
      const db = new sqlite3.oo1.OpfsDb(DB_FILE)
      warnings.push('VFS "opfs" (async proxy worker) — dữ liệu lưu thật trên máy.')
      return { sqlite3, db, mode: "opfs", warnings }
    } catch (e) {
      warnings.push(`Mở VFS "opfs" thất bại (${message(e)}) — thử VFS dự phòng.`)
    }
  } else {
    warnings.push(
      worker
        ? 'VFS "opfs" không được đăng ký trong Worker (thiếu SharedArrayBuffer/COOP-COEP?) — thử VFS dự phòng.'
        : 'VFS "opfs" không chạy được ở main thread (sqlite-wasm đòi Worker vì cần Atomics.wait) — thử VFS dự phòng.',
    )
  }

  // Nhánh 2 — VFS "opfs-sahpool": không cần proxy worker/SAB, nhưng vẫn cần Worker
  // (createSyncAccessHandle không có ở main thread). Capacity ≥ 2× số file DB vì
  // journal; ta có 1 DB nên 8 là rộng rãi và có thể nới bằng addCapacity().
  if (typeof sqlite3.installOpfsSAHPoolVfs === "function") {
    try {
      await sqlite3.installOpfsSAHPoolVfs({ initialCapacity: 8, clearOnInit: false })
      const db = new sqlite3.oo1.DB(DB_FILE, "c", "opfs-sahpool")
      warnings.push('VFS "opfs-sahpool" (dự phòng) — dữ liệu lưu thật trên máy.')
      return { sqlite3, db, mode: "opfs", warnings }
    } catch (e) {
      warnings.push(`Cài VFS "opfs-sahpool" thất bại (${message(e)}).`)
    }
  }

  // Nhánh 3 — không persist được: nói rõ, đừng giả vờ.
  if (!worker) {
    warnings.push(
      "Đang ở main thread nên không VFS OPFS nào dùng được — chạy bộ nhớ tạm; dữ liệu SẼ MẤT khi đóng tab hoặc F5.",
    )
  }
  if (!hasIsolated) {
    warnings.push(
      'Thiếu crossOriginIsolated (server phải gửi COOP/COEP) — VFS "opfs" không dùng được.',
    )
  }
  return { sqlite3, db: new sqlite3.oo1.DB(":memory:"), mode: "memory", warnings }
}
