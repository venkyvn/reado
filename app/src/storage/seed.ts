/**
 * storage/seed.ts — dữ liệu khởi đầu bắt buộc:
 *
 * 1. Collection MẶC ĐỊNH ("Kho tạm", is_default=1) — FR-17 phần is_default:
 *    collection_id không bao giờ null nên phải luôn có chỗ tiếp nhận. Đây là
 *    bất biến hệ thống: không có dòng nào khác được is_default=1.
 * 2. Hàng settings id=1 — phần còn lại theo DEFAULT của DDL.
 *
 * Cả hai idempotent: chạy lại không sinh trùng.
 */
import type { AppDb } from "./db";
import { newId, toUtcIso } from "../domain/utils";

export function ensureDefaultCollection(appDb: AppDb): void {
  const existing = appDb.get<{ id: string }>(
    "select id from collections where is_default = 1 limit 1",
  );
  if (existing) return;
  appDb.exec("insert into collections (id, name, is_default, created_at) values (?, ?, 1, ?)", [
    newId(),
    "Kho tạm",
    toUtcIso(new Date()),
  ]);
}

export function ensureSettingsRow(appDb: AppDb): void {
  const existing = appDb.get<{ id: number }>("select id from settings where id = 1");
  if (existing) return;
  appDb.exec("insert into settings (id) values (1)");
}