/**
 * storage/db.ts — `AppDb`: facade BẤT ĐỒNG BỘ mà repos/domain nhìn thấy.
 *
 * Vì sao async: DB SQLite sống trong Web Worker (VFS OPFS không chạy được ở main
 * thread — xem syncDb.ts), nên mỗi câu SQL là một vòng postMessage. Repos vốn đã
 * là hàm async nên chỉ cần thêm `await`; domain/usecase/UI không đổi một dòng.
 *
 * Hai transport cho cùng một facade:
 * - `createLocalAppDb`  : in-process (Node/vitest, :memory:) — await là hình thức.
 * - `openWorkerStorage` : RPC sang Worker (browser, OPFS) — xem workerStorage.ts.
 *
 * Khoá (mutex) là phần quan trọng: `transaction` phải giữ độc quyền suốt khối ghi,
 * nếu không một lời gọi concurrent khác sẽ chen câu SQL của nó VÀO GIỮA transaction
 * của mình (cùng một connection). `tx` truyền vào callback cố ý KHÔNG khoá — khoá
 * đã được giữ rồi, khoá lại thì chết cứng (deadlock).
 */
import type { BindValue, SyncDb } from "./syncDb";

export type { BindValue };

export interface AppDb {
  /** Chạy SQL không cần kết quả (INSERT/UPDATE/PRAGMA/DDL). */
  exec(sql: string, bind?: BindValue[]): Promise<void>;
  /** SELECT trả danh sách hàng object (key giữ nguyên alias SQL). */
  all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T[]>;
  /** SELECT lấy hàng đầu (hoặc undefined). */
  get<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T | undefined>;
  /** Gói khối ghi trong BEGIN IMMEDIATE/COMMIT; lỗi → ROLLBACK + ném lại. */
  transaction<T>(fn: (tx: AppDb) => Promise<T> | T): Promise<T>;
}

/** Cách AppDb nói chuyện với DB thật: in-process hoặc qua Worker RPC. */
export interface DbTransport {
  exec(sql: string, bind?: BindValue[]): Promise<void>;
  all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T[]>;
}

export function createAppDb(transport: DbTransport): AppDb {
  // Hàng đợi tuần tự: mỗi op chờ op trước xong hẳn (kể cả khi op trước ném lỗi).
  let tail: Promise<unknown> = Promise.resolve();

  function exclusive<T>(fn: () => Promise<T>): Promise<T> {
    const run = tail.then(fn, fn);
    tail = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  }

  async function rawExec(sql: string, bind?: BindValue[]): Promise<void> {
    await transport.exec(sql, bind);
  }
  async function rawAll<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T[]> {
    return transport.all<T>(sql, bind);
  }
  async function rawGet<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T | undefined> {
    const rows = await transport.all<T>(sql, bind);
    return rows[0];
  }

  /** Facade KHÔNG khoá — chỉ dùng bên trong transaction (khoá đã được giữ). */
  const tx: AppDb = {
    exec: rawExec,
    all: rawAll,
    get: rawGet,
    transaction() {
      // Transaction lồng nhau: SQLite không hỗ trợ BEGIN trong BEGIN. Báo rõ thay
      // vì để SQLite ném lỗi khó hiểu.
      throw new Error("transaction lồng nhau không được hỗ trợ");
    },
  };

  function execGuarded(sql: string, bind?: BindValue[]): Promise<void> {
    return exclusive(() => transport.exec(sql, bind));
  }
  function allGuarded<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T[]> {
    return exclusive(() => transport.all<T>(sql, bind));
  }
  async function getGuarded<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T | undefined> {
    const rows = await exclusive(() => transport.all<T>(sql, bind));
    return rows[0];
  }
  function transactionGuarded<T>(fn: (t: AppDb) => Promise<T> | T): Promise<T> {
    return exclusive(async () => {
      await transport.exec("BEGIN IMMEDIATE");
      try {
        const out = await fn(tx);
        await transport.exec("COMMIT");
        return out;
      } catch (e) {
        try {
          await transport.exec("ROLLBACK");
        } catch {
          // rollback hỏng thì transaction gốc vẫn phải chết — không che lỗi chính.
        }
        throw e;
      }
    });
  }

  return { exec: execGuarded, all: allGuarded, get: getGuarded, transaction: transactionGuarded };
}

/** Transport in-process: bọc lõi đồng bộ (Node/vitest, hoặc fallback memory). */
export function createLocalAppDb(sync: SyncDb): AppDb {
  return createAppDb({
    async exec(sql, bind) {
      sync.exec(sql, bind);
    },
    async all<T = Record<string, unknown>>(sql: string, bind?: BindValue[]): Promise<T[]> {
      return sync.all<T>(sql, bind);
    },
  });
}
