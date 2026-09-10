/**
 * storage/dbWorker.ts — Web Worker CHỨA DB SQLite. Đây là chỗ duy nhất sqlite-wasm
 * được phép mở OPFS trong browser.
 *
 * Lý do tồn tại (không phải sở thích kiến trúc): sqlite-wasm kiểm tra
 * `typeof WorkerGlobalScope` và từ chối cài VFS "opfs" ở main thread — nguyên văn:
 * "The OPFS sqlite3_vfs cannot run in the main thread because it requires
 * Atomics.wait()". VFS thay thế "opfs-sahpool" cũng vô dụng ở main thread vì Chrome
 * không expose `createSyncAccessHandle` ngoài Worker. Đã đo thật trên Chrome 152
 * bằng `npm run e2e:opfs` (isWorkerScope=false, apiPresent=false, trong khi OPFS
 * của chính trình duyệt thì ghi/đọc và sống qua reload bình thường).
 *
 * Trước khi có file này, app mở DB ở main thread → lib im lặng bỏ qua VFS → kernel
 * rơi về `:memory:` → **owner lưu từ xong F5 là mất sạch**. Bug đó là lý do file
 * này ra đời; bằng chứng hết bug là `npm run e2e:storage` (verdict PERSIST-OK).
 *
 * Giao thức: main gửi `{id, kind: "exec"|"all", sql, bind}`, worker trả
 * `{id, ok, rows?}` hoặc `{id, ok:false, error}`. Lúc khởi động worker gửi
 * `{type:"ready", mode, warnings}` hoặc `{type:"fatal", error}`. Request tới trước
 * khi DB sẵn sàng được xếp hàng, không rơi.
 */
import { openKernel } from "./kernel"
import { initSyncDb } from "./syncDb"
import type { BindValue, SyncDb } from "./syncDb"
import type { StorageMode } from "./kernel"

export interface WorkerRequest {
  id: number
  kind: "exec" | "all"
  sql: string
  bind?: BindValue[]
}

export type WorkerMessage =
  | { type: "ready"; mode: StorageMode; warnings: string[] }
  | { type: "fatal"; error: string }
  | { id: number; ok: true; rows?: unknown[] }
  | { id: number; ok: false; error: string }

/**
 * Worker scope không nằm trong lib DOM của tsconfig, nên lấy postMessage/onmessage
 * qua một cast hẹp thay vì thêm lib "WebWorker" (tránh đụng global của app).
 */
const ctx = globalThis as unknown as {
  postMessage(message: WorkerMessage): void
  onmessage: ((event: { data: WorkerRequest }) => void) | null
}

let db: SyncDb | null = null
const queued: WorkerRequest[] = []

function handle(req: WorkerRequest): void {
  const live = db
  if (!live) {
    // Chưa boot xong mà đã có request → xếp hàng (boot xong sẽ xả).
    queued.push(req)
    return
  }
  try {
    if (req.kind === "exec") {
      live.exec(req.sql, req.bind)
      ctx.postMessage({ id: req.id, ok: true })
    } else {
      ctx.postMessage({ id: req.id, ok: true, rows: live.all(req.sql, req.bind) })
    }
  } catch (err) {
    ctx.postMessage({
      id: req.id,
      ok: false,
      error: err instanceof Error ? err.message : String(err),
    })
  }
}

ctx.onmessage = (event) => handle(event.data)

void (async () => {
  try {
    const kernel = await openKernel()
    const init = initSyncDb(kernel)
    db = init.db
    ctx.postMessage({
      type: "ready",
      mode: kernel.mode,
      warnings: [...kernel.warnings, ...init.warnings],
    })
    for (const req of queued.splice(0)) handle(req)
  } catch (err) {
    ctx.postMessage({ type: "fatal", error: err instanceof Error ? err.message : String(err) })
  }
})()
