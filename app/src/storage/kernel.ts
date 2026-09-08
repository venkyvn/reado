/**
 * storage/kernel.ts — mở SQLite-WASM, chọn VFS.
 *
 * - Browser: `oo1.OpfsDb` (VFS "opfs" của sqlite.org/wasm) → lưu thật vào OPFS.
 *   Cần SharedArrayBuffer ⇒ cần COOP/COEP headers (vite.config.ts đã bật cho
 *   dev/preview; production phải cấu hình phía host — SPIKE storage).
 *   Lưu ý: VFS "opfs" không chạy Safari < 17 (owner test iPhone, iOS hiện
 *   đại — ổn; nếu hỏng, SPIKE sẽ hiện rõ ở màn /storage-check).
 * - Không OPFS (thiếu COI, trình duyệt cũ, hoặc Node test): in-memory, và app
 *   phải HIỂN THỊ cảnh báo dữ liệu không được lưu — không giả vờ persist.
 */
import sqlite3InitModule from "@sqlite.org/sqlite-wasm";
import wasmUrl from "@sqlite.org/sqlite-wasm/sqlite3.wasm?url";
import type { Database, Sqlite3Static } from "@sqlite.org/sqlite-wasm";

export type StorageMode = "opfs" | "memory";

export interface Kernel {
  sqlite3: Sqlite3Static;
  db: Database;
  mode: StorageMode;
  warnings: string[];
}

// Type của package chỉ khai `init()` không tham số; runtime thật nhận Emscripten
// Module config (locateFile) — kiểm trong index.mjs của sqlite-wasm 3.53.
const typedInit = sqlite3InitModule as unknown as (cfg?: {
  locateFile?: (file: string) => string;
}) => Promise<Sqlite3Static>;

async function initModule(): Promise<Sqlite3Static> {
  // Browser: Emscripten tự đoán đường dẫn sqlite3.wasm từ import.meta.url — sau
  // khi Vite bundle thì chỗ đó SAI, nên locateFile trỏ thẳng asset Vite emit
  // (`?url`). Node (vitest): `?url` trả request-path dạng "/node_modules/..." —
  // không phải fs path, mà readAsync của node build mở thẳng bằng fs — nên ghép
  // cwd vào cho trúng. (đã probe thực tế: src/testing/probe đã chạy 1 lần)
  return typedInit({ locateFile: () => locateWasmFile() });
}

/** Suy ra vị trí file sqlite3.wasm cho đúng môi trường đang chạy. */
function locateWasmFile(): string {
  const g = globalThis as {
    process?: { versions?: { node?: string }; cwd?: () => string };
  };
  if (typeof g.process?.versions?.node === "string" && typeof g.process.cwd === "function") {
    return g.process.cwd() + (wasmUrl.startsWith("/") ? wasmUrl : `/${wasmUrl}`);
  }
  return wasmUrl;
}

export async function openMemoryKernel(): Promise<Kernel> {
  const sqlite3 = await initModule();
  return { sqlite3, db: new sqlite3.oo1.DB(":memory:"), mode: "memory", warnings: [] };
}

export async function openKernel(): Promise<Kernel> {
  const sqlite3 = await initModule();
  const warnings: string[] = [];

  const hasIsolated = typeof globalThis.crossOriginIsolated === "boolean" && globalThis.crossOriginIsolated;

  if (sqlite3.oo1.OpfsDb && hasIsolated) {
    try {
      const db = new sqlite3.oo1.OpfsDb("reado.db");
      return { sqlite3, db, mode: "opfs", warnings };
    } catch (e) {
      warnings.push(
        `Mở OPFS thất bại (${e instanceof Error ? e.message : String(e)}) — chạy bộ nhớ tạm; ` +
          "dữ liệu SẼ MẤT khi đóng tab. Xem /?screen=storage-check.",
      );
    }
  } else if (!hasIsolated) {
    warnings.push(
      "Thiếu crossOriginIsolated (server phải gửi COOP/COEP) — chạy bộ nhớ tạm; " +
        "dữ liệu SẼ MẤT khi đóng tab. Xem /?screen=storage-check.",
    );
  } else {
    warnings.push("VFS OPFS không được đăng ký — chạy bộ nhớ tạm; dữ liệu SẼ MẤT khi đóng tab.");
  }

  return { sqlite3, db: new sqlite3.oo1.DB(":memory:"), mode: "memory", warnings };
}