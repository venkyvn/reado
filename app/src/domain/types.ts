/**
 * domain/types.ts — kiểu dữ liệu thuần của Reado.
 *
 * Domain là trung tâm của dependency rule (solution-design mục 3.1): mọi tầng
 * khác trỏ vào đây, file này không import gì ngoài chính domain. Kiểu dùng
 * camelCase; ánh xạ snake_case của SQLite nằm ở tầng storage.
 */

/** pos dùng enum có "other" (prompt-spec mục 4: giá trị thoát hiểm, không bịa). */
export const POS_VALUES = ["noun", "verb", "adj", "adv", "phrase", "other"] as const;
export type Pos = (typeof POS_VALUES)[number];

export const CEFR_VALUES = ["A2", "B1", "B2", "C1"] as const;
export type Cefr = (typeof CEFR_VALUES)[number];

/** Ba nhánh xác minh `example` (prompt-spec mục 6, FR-02). */
export type Verification = "verified" | "suspect" | "unverified";

/** Một vocabulary item AI trả về, đã gắn nhánh xác minh. */
export interface AnalyzedItem {
  term: string;
  pos: Pos;
  ipa: string;
  meaningVi: string;
  cefr: Cefr;
  example: string;
  verification: Verification;
  /**
   * Rich vocab (task 3.12, owner 2026-09-08): AI sinh kèm lúc capture, user
   * sửa được. 3 field KHÔNG tham gia xác minh example — thuần bổ trợ; thiếu
   * thì verify.ts điền `[]`. Giới hạn 3/3/4 (RV-1: owner chọn 2026-09-09).
   */
  tags: string[];
  synonyms: string[];
  antonyms: string[];
}

export interface Segment {
  sourceEn: string;
  translationVi: string;
}

/** Kết quả một lần gọi analysis (FR-02) — hợp đồng của ai/provider. */
export interface AnalysisResult {
  segments: Segment[];
  vocabulary: AnalyzedItem[];
  summaryVi: string;
  /** NFR-02: đo & ghi lại, chưa đặt ngưỡng. */
  usage: { promptTokens: number; candidatesTokens: number };
  latencyMs: number;
  promptVersion: number;
}

/** BỐN trạng thái FSRS — điều cấm #2 của coding-conventions: không gộp. */
export const CARD_STATES = ["new", "learning", "review", "relearning"] as const;
export type CardState = (typeof CARD_STATES)[number];

export type CardDirection = "receptive" | "productive";

export interface CollectionRow {
  id: string;
  name: string;
  isDefault: boolean;
  createdAt: string;
}

export interface VocabItemRow {
  id: string;
  collectionId: string;
  term: string;
  /** lowercase + trim, KHÔNG lemmatize (Q-06). */
  termNormalized: string;
  pos: Pos;
  ipa: string | null;
  meaningVi: string;
  example: string;
  cefr: Cefr | null;
  /** Rich vocab v3 (task 3.12) — JSON array of string, luôn là mảng (rỗng = []). */
  tags: string[];
  synonyms: string[];
  antonyms: string[];
  createdAt: string;
}

/**
 * Ba field rich vocab dưới dạng mảng — hình dạng dùng chung cho AI output,
 * hàng DB đã parse, và patch khi user sửa ở màn duyệt/kho (task 3.12).
 */
export interface RichVocabFields {
  tags: string[];
  synonyms: string[];
  antonyms: string[];
}

/** Một tag có trong kho + số card mang tag đó — màn chọn tag của cram (3.13). */
export interface TagCount {
  tag: string;
  cardCount: number;
}

/**
 * FR-08 Vocabulary List: một dòng trong danh sách kho từ — từ + collection NAME
 * (join ngay ở tầng repo) + CARD_STATE hiện tại để lọc "trạng thái ôn tập"
 * (criterion 2 của FR-08). Cùng một `term` nhiều nghĩa = NHIỀU dòng
 * (criterion 3: không gộp) — phân biệt bằng pos + câu gốc khi hiển thị.
 */
export interface LibraryItemRow extends VocabItemRow {
  collectionName: string;
  cardState: CardState;
}

export interface CardRow {
  id: string;
  vocabItemId: string;
  direction: CardDirection;
  state: CardState;
  stability: number;
  difficulty: number;
  reps: number;
  lapses: number;
  learningSteps: number;
  scheduledDays: number;
  lastReviewAt: string | null;
  /** UTC ISO. KHÔNG tính lại on-the-fly (điều cấm #8). */
  dueAt: string;
  suspendedAt: string | null;
}

/** review_logs — ảnh chụp TRƯỚC khi chấm (điều cấm #1). mode ở R1 luôn "srs". */
export interface ReviewLogRow {
  id: string;
  cardId: string;
  mode: "srs" | "cram" | "distinguish" | "recall";
  rating: number;
  stateBefore: CardState;
  stabilityBefore: number;
  difficultyBefore: number;
  learningStepsBefore: number;
  dueBefore: string;
  elapsedDays: number;
  scheduledDays: number;
  reviewedAt: string;
}

/** Bảng settings (id luôn = 1) — kèm 4 cột BYOK (Q-03), điều cấm #9: key từ user. */
export interface Settings {
  cefrLevel: Cefr;
  dailyNewLimit: number;
  aiProvider: string;
  aiBaseUrl: string;
  aiApiKey: string | null;
  aiModel: string | null;
  requestRetention: number;
  maximumInterval: number;
  enableFuzz: boolean;
  dayCutoffHour: number;
  fsrsParams: string | null;
  fsrsVersion: string | null;
}

/** Card + dữ liệu hiển thị mặt sau (FR-12): JOIN cards→vocab_items→collections.
 *  Task 3.12: mang thêm 3 field rich vocab để mặt sau hiện khối "Mở rộng". */
export interface CardWithContext extends CardRow {
  term: string;
  pos: Pos;
  meaningVi: string;
  ipa: string | null;
  example: string;
  collectionName: string;
  tags: string[];
  synonyms: string[];
  antonyms: string[];
}

/**
 * Bảng analyses (migration v2) — MỘT dòng = MỘT trang đã phân tích THÀNH CÔNG.
 * Nguồn đếm "số trang đã phân tích" của FR-14 (đếm từ sự kiện thật, không phải
 * counter) + nơi lưu số đo NFR-02 cho M-03 về sau. Không chứa api_key (#9),
 * không chứa ảnh (NFR-04).
 */
export interface AnalysisRecord {
  id: string;
  /** UTC ISO-8601 thời điểm phân tích hoàn tất. */
  analyzedAt: string;
  cefr: Cefr | null;
  provider: string | null;
  model: string | null;
  promptVersion: number | null;
  latencyMs: number | null;
  tokensIn: number | null;
  tokensOut: number | null;
}

/**
 * Một PHIÊN ĐỌC đã lưu bền (task 3.15, Q-10-reopen 2026-09-09): 1 dòng = 1 trang
 * đã phân tích thành công. Chỉ text + dịch (A-08 của PRD sai → nới NFR-04 phần
 * text; ẢNH VẪN CẤM). `id` trùng `analyses.id` của lần gọi — provenance trực
 * tiếp. `savedAt` null = trang chưa được "Chọn từ → Lưu" (luật lưu 1 lần).
 */
export interface ReadingSessionRow {
  id: string;
  collectionId: string;
  segments: Segment[];
  /** Vocabulary nguyên vẹn của trang (JSON) — gloss tô từ + "Chọn từ" của
   *  trang CHƯA lưu đều cần nó. Có thể stale sau khi user sửa ở màn duyệt:
   *  gloss chỉ là trợ giúp đọc, nguồn sự thật là vocab_items. */
  vocabulary: AnalyzedItem[];
  summaryVi: string;
  /** Số từ AI trích xuất trên trang — cho thẻ tóm tắt ở danh sách. */
  vocabCount: number;
  createdAt: string;
  savedAt: string | null;
  savedCount: number;
}