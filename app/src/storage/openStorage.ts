/**
 * storage/openStorage.ts — chọn chỗ sống cho DB, theo đúng thứ tự ưu tiên:
 *
 *   1. Browser  → Web Worker + OPFS (persist thật)          → mode "opfs"
 *   2. Worker hỏng → in-process :memory: + CẢNH BÁO RÕ       → mode "memory"
 *   3. Node/vitest → in-process :memory: (không cần persist) → mode "memory"
 *
 * Nguyên tắc: thà hiện cảnh báo "dữ liệu sẽ mất" còn hơn giả vờ persist — đó là
 * lý do nhánh 2 không im lặng. Vụ F5 mất dữ liệu của owner (2026-09-08) chính là
 * app rơi vào memory mà cảnh báo không đủ đập vào mắt.
 */
import { createLocalAppDb } from "./db";
import type { AppDb } from "./db";
import { openKernel } from "./kernel";
import type { StorageMode } from "./kernel";
import { initSyncDb } from "./syncDb";
import { openWorkerStorage } from "./workerStorage";

export interface Storage {
  appDb: AppDb;
  mode: StorageMode;
  warnings: string[];
}

/**
 * Phân biệt browser với Node/vitest. Không dùng `typeof Worker` một mình: một số
 * runtime Node có Worker (worker_threads) với ngữ nghĩa khác hẳn Web Worker.
 */
const looksLikeBrowser =
  typeof globalThis.document !== "undefined" && typeof globalThis.Worker === "function";

export async function openStorage(): Promise<Storage> {
  if (looksLikeBrowser) {
    try {
      const worker = await openWorkerStorage();
      return { appDb: worker.appDb, mode: worker.mode, warnings: worker.warnings };
    } catch (e) {
      const reason = e instanceof Error ? e.message : String(e);
      const local = await openLocalStorage();
      return {
        appDb: local.appDb,
        mode: "memory",
        warnings: [
          `Worker DB không khởi động được (${reason}) — chạy bộ nhớ tạm; dữ liệu SẼ MẤT khi đóng tab hoặc F5.`,
          ...local.warnings,
        ],
      };
    }
  }
  return openLocalStorage();
}

/** In-process: Node/vitest, hoặc fallback khi Worker chết. */
async function openLocalStorage(): Promise<Storage> {
  const kernel = await openKernel();
  const init = initSyncDb(kernel);
  return {
    appDb: createLocalAppDb(init.db),
    mode: kernel.mode,
    warnings: [...kernel.warnings, ...init.warnings],
  };
}
