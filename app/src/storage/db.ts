/**
 * storage/db.ts — AppDb: wrapper mỏng quanh handle oo1 của sqlite-wasm.
 *
 * UI/domain KHÔNG nhìn thấy file này (chỉ repos thật dùng nó) — dependency rule
 * giữ nguyên: domain định interface, storage implement. Mọi câu SQL trong repo
 * đi qua `all/get/exec`; mọi ghi đa bước đi qua `transaction`.
 */
import type { Kernel } from "./kernel";
import { migrate } from "./migrate";
import { ensureDefaultCollection, ensureSettingsRow } from "./seed";

export type BindValue = string | number | null | Uint8Array;

export interface AppDb {
  kernel: Kernel;
  /** Chạy SQL không cần kết quả (INSERT/UPDATE/PRAGMA/DDL). */
  exec(sql: string, bind?: BindValue[]): void;
  /** SELECT trả danh sách hàng object (key giữ nguyên alias SQL). */
  all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T[];
  /** SELECT lấy hàng đầu (hoặc undefined). */
  get<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T | undefined;
  /** Gói khối ghi trong BEGIN IMMEDIATE/COMMIT; lỗi → ROLLBACK + ném lại. */
  transaction<T>(fn: (tx: AppDb) => T): T;
}

/** Handle oo1 typed hẹp — tránh đánh nhau với overload đồ sộ của package. */
interface Oo1Handle {
  exec(opts: { sql: string; bind?: BindValue[] }): unknown;
  exec(opts: { sql: string; bind?: BindValue[]; rowMode: "object"; returnValue: "resultRows" }): unknown;
}

export function createAppDb(kernel: Kernel): AppDb {
  const handle = kernel.db as unknown as Oo1Handle;

  function exec(sql: string, bind?: BindValue[]): void {
    handle.exec({ sql, bind });
  }
  function all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T[] {
    const rows = handle.exec({ sql, bind, rowMode: "object", returnValue: "resultRows" });
    return (rows ?? []) as T[];
  }
  function get<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T | undefined {
    return all<T>(sql, bind)[0];
  }
  function transaction<T>(fn: (tx: AppDb) => T): T {
    handle.exec({ sql: "BEGIN IMMEDIATE" });
    try {
      const out = fn(appDb);
      handle.exec({ sql: "COMMIT" });
      return out;
    } catch (e) {
      try {
        handle.exec({ sql: "ROLLBACK" });
      } catch {
        // rollback hỏng thì transaction gốc vẫn phải chết — không che lỗi chính.
      }
      throw e;
    }
  }

  const appDb: AppDb = { kernel, exec, all, get, transaction };
  return appDb;
}

/**
 * Mở + migrate + seed. Trả AppDb sẵn sàng dùng, kèm danh sách cảnh báo vận hành
 * (VFS, journal_mode...) để app hiển thị — không nuốt im lặng.
 */
export function initAppDb(kernel: Kernel): AppDb {
  const appDb = createAppDb(kernel);
  const pragmaWarnings = applyPragmas(appDb);
  kernel.warnings.push(...pragmaWarnings);
  migrate(appDb);
  ensureDefaultCollection(appDb);
  ensureSettingsRow(appDb);
  return appDb;
}

function applyPragmas(appDb: AppDb): string[] {
  const warnings: string[] = [];
  // FK enforcement tuyệt đối bật — schema dựa vào on delete cascade.
  appDb.exec("PRAGMA foreign_keys = ON");
  // WAL mong muốn (solution-design mục 5: an toàn dữ liệu + snapshot) nhưng tuỳ
  // thuộc VFS — không phải lỗi nếu fallback (ghi vẫn qua transaction).
  try {
    const row = appDb.get<{ journal_mode: string }>("PRAGMA journal_mode = WAL");
    const mode = String(row?.journal_mode ?? "").toLowerCase();
    if (mode !== "wal") {
      warnings.push(`journal_mode = ${mode || "(rỗng)"} — VFS này không hỗ trợ WAL; dữ liệu vẫn an toàn nhờ transaction.`);
    }
  } catch (e) {
    warnings.push(`Không áp được WAL: ${e instanceof Error ? e.message : String(e)}`);
  }
  return warnings;
}