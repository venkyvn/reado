/**
 * storage/workerStorage.ts — đầu main thread của DB trong Worker.
 *
 * Spawn `dbWorker.ts` (Vite xử lý `new Worker(new URL(...), {type:"module"})` cho
 * cả dev lẫn build), chờ tín hiệu `ready` để biết storageMode + warnings, rồi phơi
 * một `DbTransport` RPC cho facade `createAppDb`.
 *
 * Nếu worker không lên được (timeout/fatal), hàm NÉM lỗi — người gọi
 * (openStorage.ts) quyết định fallback, không tự ý giả vờ persist.
 */
import { createAppDb } from "./db";
import type { AppDb, DbTransport } from "./db";
import type { BindValue } from "./syncDb";
import type { StorageMode } from "./kernel";
import type { WorkerMessage, WorkerRequest } from "./dbWorker";

export interface WorkerStorage {
  appDb: AppDb;
  mode: StorageMode;
  warnings: string[];
  terminate(): void;
}

/** Worker phải tự mở wasm + migrate + seed; 20s là trần rộng rãi cho máy chậm. */
const READY_TIMEOUT_MS = 20_000;

interface Pending {
  resolve(rows: unknown[] | undefined): void;
  reject(error: Error): void;
}

export async function openWorkerStorage(): Promise<WorkerStorage> {
  const worker = new Worker(new URL("./dbWorker.ts", import.meta.url), { type: "module" });
  const pending = new Map<number, Pending>();
  let seq = 0;

  function send(kind: WorkerRequest["kind"], sql: string, bind?: BindValue[]): Promise<unknown[] | undefined> {
    const id = ++seq;
    return new Promise<unknown[] | undefined>((resolve, reject) => {
      pending.set(id, { resolve, reject });
      worker.postMessage({ id, kind, sql, bind } satisfies WorkerRequest);
    });
  }

  const ready = await new Promise<{ mode: StorageMode; warnings: string[] }>((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Worker DB không báo ready sau ${READY_TIMEOUT_MS}ms`));
    }, READY_TIMEOUT_MS);

    worker.onmessage = (event: MessageEvent<WorkerMessage>) => {
      const msg = event.data;
      if ("type" in msg) {
        if (msg.type === "ready") {
          clearTimeout(timer);
          resolve({ mode: msg.mode, warnings: msg.warnings });
        } else if (msg.type === "fatal") {
          clearTimeout(timer);
          reject(new Error(msg.error));
        }
        return;
      }
      const entry = pending.get(msg.id);
      if (!entry) return;
      pending.delete(msg.id);
      if (msg.ok) entry.resolve(msg.rows);
      else entry.reject(new Error(msg.error));
    };

    worker.onerror = (event) => {
      clearTimeout(timer);
      reject(new Error(event.message || "Worker DB gặp lỗi không rõ"));
    };
  }).finally(() => {
    // Sau ready, onmessage ở trên vẫn sống và tiếp tục phục vụ RPC — chỉ dọn timer.
  });

  const transport: DbTransport = {
    async exec(sql, bind) {
      await send("exec", sql, bind);
    },
    async all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T[]> {
      const rows = await send("all", sql, bind);
      return (rows ?? []) as T[];
    },
  };

  return {
    appDb: createAppDb(transport),
    mode: ready.mode,
    warnings: ready.warnings,
    terminate() {
      for (const entry of pending.values()) entry.reject(new Error("Worker DB đã bị đóng"));
      pending.clear();
      worker.terminate();
    },
  };
}
