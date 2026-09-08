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
  createdAt: string;
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

/** Card + dữ liệu hiển thị mặt sau (FR-12): JOIN cards→vocab_items→collections. */
export interface CardWithContext extends CardRow {
  term: string;
  pos: Pos;
  meaningVi: string;
  ipa: string | null;
  example: string;
  collectionName: string;
}