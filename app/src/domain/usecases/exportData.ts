/**
 * domain/usecases/exportData.ts — FR-16: gom dữ liệu theo scope rồi dựng hai file.
 *
 * Use-case này chỉ làm hai việc: đọc qua repo interface (không SQL) và giao dữ
 * liệu cho builder thuần trong `domain/export.ts`. NFR-05 ("export phải luôn hoạt
 * động") nghĩa là KHÔNG có nhánh nào ném lỗi vì dữ liệu rỗng — kho trống vẫn phải
 * cho ra file hợp lệ để owner biết export còn sống.
 *
 * Tên collection được resolve ở đây (một lần `collections.list()` → Map) thay vì
 * JOIN thêm trong SQL: builder cần TÊN đi kèm từng item, và Map này cũng dùng để
 * ghi `scope.collectionName` trong JSON.
 */
import { buildAnkiTsv, buildJsonExport, countsOf, toExportableSettings } from "../export";
import type { ExportCounts, ExportDataset, ExportItem, ExportScope } from "../export";
import type { AppServices } from "../services";
import { toUtcIso } from "../utils";

export interface ExportBundle {
  scope: ExportScope;
  counts: ExportCounts;
  /** Nội dung file TSV cho Anki — UI tự đặt tên file và tự giao xuống máy. */
  tsv: string;
  /** Nội dung file JSON đầy đủ (FSRS state + review logs). */
  json: string;
}

/** `collectionId === null` → export toàn bộ kho (FR-16 criterion 2: chọn được theo collection). */
export async function exportData(svc: AppServices, collectionId: string | null): Promise<ExportBundle> {
  const collections = await svc.repos.collections.list();
  const nameById = new Map(collections.map((c) => [c.id, c.name] as const));

  const scope: ExportScope = {
    collectionId,
    collectionName: collectionId === null ? null : (nameById.get(collectionId) ?? null),
  };

  // Bốn lời gọi độc lập; AppDb tự tuần tự hoá qua mutex nên không lo chen transaction.
  const [rows, cards, logs, settings] = await Promise.all([
    svc.repos.vocabItems.listByScope(collectionId),
    svc.repos.cards.listByScope(collectionId),
    svc.repos.logs.listByScope(collectionId),
    svc.repos.settings.get(),
  ]);

  const items: ExportItem[] = rows.map((r) => ({
    ...r,
    // FK bật (PRAGMA foreign_keys=ON) nên item mồ côi collection không thể tồn tại;
    // chuỗi rỗng là lưới an toàn để một dòng lạ không làm chết cả file export.
    collectionName: nameById.get(r.collectionId) ?? "",
  }));

  const dataset: ExportDataset = {
    scope,
    exportedAt: toUtcIso(svc.now()),
    items,
    cards,
    logs,
    settings: toExportableSettings(settings),
  };

  return { scope, counts: countsOf(dataset), tsv: buildAnkiTsv(items), json: buildJsonExport(dataset) };
}
