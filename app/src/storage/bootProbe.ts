/**
 * storage/bootProbe.ts — marker khởi động: bằng chứng DỮ LIỆU APP sống qua reload.
 *
 * Vì sao có file này: ngày 2026-09-08 owner báo "f5 xong k thấy mấy từ đã lưu đâu
 * cả". Nguyên nhân là DB mở ở main thread nên sqlite-wasm bỏ qua VFS OPFS và rơi
 * về `:memory:` — mà cảnh báo thì không đủ đập vào mắt. Sửa xong (DB vào Worker)
 * vẫn cần một phép thử TỰ ĐỘNG phân biệt được "persist thật" với "vẫn là memory",
 * vì hai trạng thái đó trông y hệt nhau trong một phiên: ghi gì cũng thành công,
 * chỉ lần mở SAU mới lộ ra.
 *
 * Cơ chế: mỗi lần boot đọc marker của lần mở trước, rồi ghi marker mới. Nếu đọc
 * được → dữ liệu đã qua được một lần reload → persist thật. Nếu luôn null → DB
 * là memory. Hiện trên màn `?screen=storage-check` để owner tự kiểm trên iPhone.
 *
 * `_boot_probe` là bảng HẠ TẦNG (như `_migrations`), không phải schema sản phẩm —
 * xem comment trong migrate.ts.
 */
import type { AppDb } from "./db"

const KEY = "last_boot_at"

/** ISO timestamp của lần mở app TRƯỚC, hoặc null nếu chưa từng persist được. */
export async function readBootProbe(appDb: AppDb): Promise<string | null> {
  const row = await appDb.get<{ value: string }>("select value from _boot_probe where key = ?", [
    KEY,
  ])
  return row?.value ?? null
}

/** Ghi marker cho lần mở kế tiếp đọc (upsert — chạy mọi boot, không phình bảng). */
export async function writeBootProbe(appDb: AppDb, atUtcIso: string): Promise<void> {
  await appDb.exec(
    `insert into _boot_probe (key, value) values (?, ?)
     on conflict(key) do update set value = excluded.value`,
    [KEY, atUtcIso],
  )
}
