/**
 * domain/repositories.ts — interface repository mà storage phải implement
 * (solution-design mục 3.1: storage implement interface do domain định nghĩa).
 *
 * Domain chỉ biết các interface này — không bao giờ biết SQLite/WASM. UI cũng
 * không chạm repo trực tiếp; nó đi qua use-case (domain/usecases/).
 */
import type {
  AnalysisRecord,
  CardState,
  CardWithContext,
  CardRow,
  CollectionRow,
  LibraryItemRow,
  ReviewLogRow,
  Settings,
  VocabItemRow,
} from "./types";

/** Tham số truy vấn thẻ đến hạn (nhánh của FR-11). */
export interface ListDueParams {
  /** now UTC ISO. */
  nowUtc: string;
  /** null = toàn cục (R1); scope theo FR-18 chỉ đến ở Phase 3. */
  scopeCollectionIds: string[] | null;
  limit: number | null;
}

export interface CollectionsRepository {
  list(): Promise<CollectionRow[]>;
  getDefault(): Promise<CollectionRow | null>;
  create(name: string, isDefault: boolean, now: Date): Promise<CollectionRow>;
}

export interface VocabItemsRepository {
  /**
   * Lưu một lô từ + card `new` tương ứng — MỘT transaction (nếu tách ra thì
   * một nửa lô lưu được, nửa kia không mà không gì báo). Chỉ insert, chưa
   * cần update/delete ở R1 (FR-08/FR-17 đầy đủ thuộc Phase 3).
   */
  persistCapture(vocabRows: VocabItemRow[], cardRows: CardRow[]): Promise<void>;
  listByCollection(collectionId: string): Promise<VocabItemRow[]>;
  /**
   * FR-16 export: `null` = TẤT CẢ collection, khác null = đúng một.
   * Cùng quy ước "null là toàn cục" với `ListDueParams.scopeCollectionIds`.
   */
  listByScope(collectionId: string | null): Promise<VocabItemRow[]>;
  /**
   * FR-08 Vocabulary List: toàn bộ kho kèm tên collection + trạng thái ôn tập,
   * lọc được theo từng tiêu chí trong `filter` (null = "không lọc tiêu chí đó",
   * ba tiêu chí cùng áp một lúc được). Sắp theo `term` (không phân biệt hoa
   * thường) để các dòng cùng `term` khác nghĩa NẰM CẠNH NHAU — FR-08 criterion
   * 3 cấm gộp chúng thành một dòng.
   */
  listLibrary(filter: LibraryFilter): Promise<LibraryItemRow[]>;
}

/** Bộ lọc FR-08 — mỗi trường null nghĩa là "không lọc theo tiêu chí này". */
export interface LibraryFilter {
  collectionId: string | null;
  cefr: string | null;
  state: CardState | null;
}

/** Bộ field FSRS + lịch của một card (chấm thẻ và undo đều ghi nguyên bộ). */
export interface SrsFields {
  state: CardState;
  stability: number;
  difficulty: number;
  reps: number;
  lapses: number;
  learningSteps: number;
  scheduledDays: number;
  lastReviewAt: string | null;
  dueAt: string;
}

export interface CardsRepository {
  insertBatch(rows: CardRow[]): Promise<void>;
  /** NHÁNH 1 — card review/relearning đến hạn, không giới hạn, due_at asc. */
  listDueReviews(opts: ListDueParams): Promise<CardRow[]>;
  /** NHÁNH 2 — card mới đến hạn, due_at asc; giới hạn nằm ở domain/queue. */
  listDueNews(opts: ListDueParams): Promise<CardRow[]>;
  /** Lấy dữ liệu hiển thị thẻ (FR-12) theo đúng thứ tự id truyền vào. */
  loadWithContext(cardIds: string[]): Promise<CardWithContext[]>;
  /** FR-16 export: card của mọi item trong scope; `null` = tất cả collection. */
  listByScope(collectionId: string | null): Promise<CardRow[]>;
}

export interface ReviewLogsRepository {
  /**
   * MỘT lần chấm = MỘT transaction: insert review_logs (ảnh chụp TRƯỚC khi
   * chấm) + update toàn bộ field FSRS của card. Điều cấm #3 — không bao giờ
   * tách hai câu lệnh này, nếu không review mất khỏi training data vĩnh viễn.
   */
  appendGrade(log: ReviewLogRow, cardId: string, fields: SrsFields): Promise<void>;
  /**
   * Undo một bước (solution-design mục 8.2): delete log sai + khôi phục card
   * về snapshot TRƯỚC lúc chấm — transaction thứ hai. Snapshot đầy đủ (kể cả
   * reps/lapses) do phiên ôn giữ trong memory, log theo research schema
   * không chứa hai cột đó.
   */
  rollbackGrade(logId: string, cardId: string, fields: SrsFields): Promise<void>;
  /** Đếm thẻ mới ĐÃ GIỚI THIỆU trong ngày học [fromUtc, toUtc) — từ log, không
   *  từ counter (FR-11 criterion: counter và log lệch nhau là lỗi vô hình). */
  countIntroducedNew(fromUtc: string, toUtc: string): Promise<number>;
  /** Mọi reviewed_at (UTC ISO, tăng dần) — đầu vào tính streak của FR-14.
   *  "Ngày ôn" phải tính lại ở domain qua dayBounds (giờ chuyển ngày + múi
   *  giờ device), nên repo chỉ trả timestamp thô, không nửa vời nhóm sẵn. */
  listReviewedAts(): Promise<string[]>;
  getById(logId: string): Promise<ReviewLogRow | null>;
  /** FR-16 export: log của mọi card trong scope; `null` = tất cả collection. */
  listByScope(collectionId: string | null): Promise<ReviewLogRow[]>;
}

export interface SettingsRepository {
  get(): Promise<Settings>;
  updatePartial(patch: Partial<Settings>): Promise<Settings>;
}

/** Bảng analyses (migration v2) — sự kiện "đã phân tích một trang thành công". */
export interface AnalysesRepository {
  insert(record: AnalysisRecord): Promise<void>;
  /** Tổng số trang đã phân tích (FR-14 — đếm từ sự kiện, không phải counter). */
  countAll(): Promise<number>;
}

export interface ReadoRepos {
  collections: CollectionsRepository;
  vocabItems: VocabItemsRepository;
  cards: CardsRepository;
  logs: ReviewLogsRepository;
  settings: SettingsRepository;
  analyses: AnalysesRepository;
}