/**
 * storage/syncDb.ts — LÕI ĐỒNG BỘ của tầng storage: nơi duy nhất chạm handle oo1
 * của sqlite-wasm, cùng pragmas/migrate/seed.
 *
 * Vì sao phải tách khỏi db.ts: sqlite-wasm TỪ CHỐI cài VFS "opfs" ở main thread —
 * nguyên văn trong lib: "The OPFS sqlite3_vfs cannot run in the main thread because
 * it requires Atomics.wait()". VFS thay thế "opfs-sahpool" cũng không dùng được ở
 * main thread vì Chrome không expose `createSyncAccessHandle` ngoài Worker (đã đo
 * thật bằng `npm run e2e:opfs`: isWorkerScope=false, apiPresent=false). Hệ quả:
 * DB PHẢI sống trong Web Worker (dbWorker.ts), nên mọi lời gọi từ main thread đều
 * bất đồng bộ — xem facade `AppDb` trong db.ts.
 *
 * File này chạy ở đúng nơi DB sống: trong Worker (browser, OPFS) hoặc in-process
 * (Node/vitest, :memory:).
 */
import type { Kernel } from "./kernel";
import { migrate } from "./migrate";
import { ensureDefaultCollection, ensureSettingsRow } from "./seed";

export type BindValue = string | number | null | Uint8Array;

export interface SyncDb {
  /** Chạy SQL không cần kết quả (INSERT/UPDATE/PRAGMA/DDL). */
  exec(sql: string, bind?: BindValue[]): void;
  /** SELECT trả danh sách hàng object (key giữ nguyên alias SQL). */
  all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T[];
  /** SELECT lấy hàng đầu (hoặc undefined). */
  get<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T | undefined;
  /** Gói khối ghi trong BEGIN IMMEDIATE/COMMIT; lỗi → ROLLBACK + ném lại. */
  transaction<T>(fn: (tx: SyncDb) => T): T;
}

/** Handle oo1 typed hẹp — tránh đánh nhau với overload đồ sộ của package. */
interface Oo1Handle {
  exec(opts: { sql: string; bind?: BindValue[] }): unknown;
  exec(opts: { sql: string; bind?: BindValue[]; rowMode: "object"; returnValue: "resultRows" }): unknown;
}

export function createSyncDb(handle: unknown): SyncDb {
  const h = handle as Oo1Handle;

  function exec(sql: string, bind?: BindValue[]): void {
    h.exec({ sql, bind });
  }
  function all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T[] {
    const rows = h.exec({ sql, bind, rowMode: "object", returnValue: "resultRows" });
    return (rows ?? []) as T[];
  }
  function get<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): T | undefined {
    return all<T>(sql, bind)[0];
  }
  function transaction<T>(fn: (tx: SyncDb) => T): T {
    h.exec({ sql: "BEGIN IMMEDIATE" });
    try {
      const out = fn(syncDb);
      h.exec({ sql: "COMMIT" });
      return out;
    } catch (e) {
      try {
        h.exec({ sql: "ROLLBACK" });
      } catch {
        // rollback hỏng thì transaction gốc vẫn phải chết — không che lỗi chính.
      }
      throw e;
    }
  }

  const syncDb: SyncDb = { exec, all, get, transaction };
  return syncDb;
}

export interface InitSyncDbResult {
  db: SyncDb;
  /** Cảnh báo vận hành (journal_mode/WAL...) — phải được hiển thị, không nuốt. */
  warnings: string[];
}

/**
 * Mở xong thì pragmas + migrate + seed — chạy MỘT lần, ở đúng nơi DB sống.
 * Idempotent (migrate đánh số, seed kiểm tra trước khi insert).
 */
export function initSyncDb(kernel: Kernel): InitSyncDbResult {
  const db = createSyncDb(kernel.db);
  const warnings = applyPragmas(db);
  migrate(db);
  ensureDefaultCollection(db);
  ensureSettingsRow(db);
  return { db, warnings };
}

function applyPragmas(db: SyncDb): string[] {
  const warnings: string[] = [];
  // FK enforcement tuyệt đối bật — schema dựa vào on delete cascade.
  db.exec("PRAGMA foreign_keys = ON");
  // WAL mong muốn (solution-design mục 5: an toàn dữ liệu + snapshot) nhưng tuỳ
  // thuộc VFS — không phải lỗi nếu fallback (ghi vẫn qua transaction).
  try {
    const row = db.get<{ journal_mode: string }>("PRAGMA journal_mode = WAL");
    const mode = String(row?.journal_mode ?? "").toLowerCase();
    if (mode !== "wal") {
      warnings.push(
        `journal_mode = ${mode || "(rỗng)"} — VFS này không hỗ trợ WAL; từng transaction vẫn nguyên tử, còn dữ liệu có BỀN qua F5 hay không thì do nhánh OPFS (cảnh báo phía trên) quyết.`,
      );
    }
  } catch (e) {
    warnings.push(`Không áp được WAL: ${e instanceof Error ? e.message : String(e)}`);
  }
  return warnings;
}
