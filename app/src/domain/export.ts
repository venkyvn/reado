/**
 * domain/export.ts — FR-16: dựng NỘI DUNG file export từ dữ liệu thuần.
 *
 * Thuần domain: không DB, không network, không một string UI tiếng Việt nào
 * (conventions mục 1 — chữ người dùng thấy chỉ nằm ở `ui/`). NFR-05 đòi export
 * PHẢI luôn hoạt động (điều kiện để owner dám dồn dữ liệu nhiều năm vào đây),
 * nên file này không được phụ thuộc gì ngoài dữ liệu nó nhận.
 *
 * Ba criterion của FR-16 → hai định dạng:
 * 1. TSV nhập được vào Anki: `term`, `pos`, `ipa`, `meaning_vi`, `cefr`, câu gốc,
 *    và **tên collection**.
 * 2. Scope theo collection (không buộc lấy hết) — do use-case quyết, hàm ở đây
 *    chỉ nhận đúng tập item đã lọc.
 * 3. JSON máy đọc được: kèm trạng thái FSRS của card + toàn bộ review_logs.
 *
 * Về header của file TSV: Anki bỏ qua mọi dòng bắt đầu bằng `#`, và tab là
 * separator mặc định của nó — nên kể cả khi hai directive dưới đây không được bản
 * Anki nào đó hiểu, file vẫn import đúng. (Agent KHÔNG verify được danh sách
 * directive đầy đủ của Anki lúc viết file này — web search hỏng; vì vậy chỉ dùng
 * `#separator` + `#html` là hai thứ chắc chắn, còn mô tả cột để dạng comment
 * thường thay vì mạo nhận một directive chưa kiểm chứng.)
 *
 * Điều cấm #9 (secrets): settings chỉ đi qua WHITELIST — `ai_api_key` và
 * `ai_base_url` KHÔNG BAO GIỜ vào file export. base_url bị loại luôn vì một số
 * gateway nhúng token vào chính URL đó.
 *
 * Góc cạnh đã biết, cố ý KHÔNG xử lý: nếu `term` bắt đầu bằng "#" thì dòng đó
 * đứng đầu cột 1 sẽ bị Anki coi là comment. Xác suất với từ vựng sách gần như 0,
 * và tự ý sửa dữ liệu (thêm escape/đổi ký tự) thì tệ hơn là ghi chú lại ở đây.
 */
import type { CardRow, Cefr, ReviewLogRow, Settings, VocabItemRow } from "./types";

/** Một vocabulary item kèm TÊN collection (FR-16 đòi tên, không phải id). */
export interface ExportItem extends VocabItemRow {
  collectionName: string;
}

export interface ExportScope {
  /** null = tất cả collection. */
  collectionId: string | null;
  /** null khi scope là tất cả; tên thật (dữ liệu, không phải UI copy) khi scope một collection. */
  collectionName: string | null;
}

export interface ExportCounts {
  vocabItems: number;
  cards: number;
  reviewLogs: number;
}

/** Settings qua whitelist — xem điều cấm #9 ở header file. */
export interface ExportableSettings {
  cefrLevel: Cefr;
  dailyNewLimit: number;
  requestRetention: number;
  maximumInterval: number;
  enableFuzz: boolean;
  dayCutoffHour: number;
  fsrsParams: string | null;
  fsrsVersion: string | null;
  aiProvider: string;
  aiModel: string | null;
}

export interface ExportDataset {
  scope: ExportScope;
  /** UTC ISO (điều cấm #7: không mất timezone — mọi mốc thời gian là `...Z`). */
  exportedAt: string;
  items: ExportItem[];
  cards: CardRow[];
  logs: ReviewLogRow[];
  settings: ExportableSettings;
}

export const EXPORT_FORMAT = "reado-export";
export const EXPORT_VERSION = 1;

/** Thứ tự cột của file TSV — cũng là thứ tự Anki map vào field của note type. */
export const ANKI_TSV_COLUMNS = [
  "term",
  "pos",
  "ipa",
  "meaning_vi",
  "cefr",
  "example",
  "collection",
] as const;

export function toExportableSettings(s: Settings): ExportableSettings {
  // Thêm field mới vào Settings thì PHẢI quyết định có export nó không — danh
  // sách này cố ý viết tay từng dòng, không spread, để secret không lọt theo.
  return {
    cefrLevel: s.cefrLevel,
    dailyNewLimit: s.dailyNewLimit,
    requestRetention: s.requestRetention,
    maximumInterval: s.maximumInterval,
    enableFuzz: s.enableFuzz,
    dayCutoffHour: s.dayCutoffHour,
    fsrsParams: s.fsrsParams,
    fsrsVersion: s.fsrsVersion,
    aiProvider: s.aiProvider,
    aiModel: s.aiModel,
  };
}

/**
 * Field của TSV không được chứa tab/xuống dòng (Anki coi đó là ranh giới
 * field/dòng) — thay bằng khoảng trắng. KHÔNG đổi nội dung chữ.
 */
function tsvField(value: string | null): string {
  return (value ?? "").replace(/[\t\r\n]+/g, " ").trim();
}

/** TSV cho Anki: header directive + mỗi item một dòng, tab ngăn cách. */
export function buildAnkiTsv(items: readonly ExportItem[]): string {
  const header = [
    "#separator:tab",
    "#html:false",
    `# columns: ${ANKI_TSV_COLUMNS.join(" | ")}`,
    "# Exported from Reado (FR-16). Anki: File > Import, chọn file này.",
  ];
  const lines = items.map((it) =>
    [
      tsvField(it.term),
      tsvField(it.pos),
      tsvField(it.ipa),
      tsvField(it.meaningVi),
      tsvField(it.cefr),
      tsvField(it.example),
      tsvField(it.collectionName),
    ].join("\t"),
  );
  return [...header, ...lines].join("\n") + "\n";
}

export function countsOf(d: ExportDataset): ExportCounts {
  return { vocabItems: d.items.length, cards: d.cards.length, reviewLogs: d.logs.length };
}

/**
 * JSON đầy đủ cho máy đọc: vocabulary + card (nguyên bộ state FSRS) + review_logs
 * (ảnh chụp TRƯỚC khi chấm — điều cấm #1, giữ nguyên ngữ nghĩa khi export).
 */
export function buildJsonExport(d: ExportDataset): string {
  return (
    JSON.stringify(
      {
        format: EXPORT_FORMAT,
        version: EXPORT_VERSION,
        exportedAt: d.exportedAt,
        scope: d.scope,
        counts: countsOf(d),
        settings: d.settings,
        vocabItems: d.items,
        cards: d.cards,
        reviewLogs: d.logs,
      },
      null,
      2,
    ) + "\n"
  );
}
